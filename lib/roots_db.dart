import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart' show rootBundle;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

/// strongs_roots.db 전용 헬퍼.
/// - Windows/Linux: assets의 DB를 문서 폴더로 복사한 뒤 sqflite로 오픈 (기존 방식)
/// - Web: path_provider/sqflite가 동작하지 않으므로, assets/roots_web.json을
///   통째로 메모리에 올려서 Dart 코드로 직접 관계를 찾는다.
class RootsDb {
  // ── 데스크톱(Windows/Linux) 경로 ──────────────────────────────────────
  static Database? _db;

  static Future<Database> _openDb() async {
    if (_db != null) return _db!;

    final docsDir = await getApplicationDocumentsDirectory();
    final dbPath = p.join(docsDir.path, 'strongs_roots.db');

    final assetBytes = await rootBundle.load('assets/strongs_roots.db');
    final assetLength = assetBytes.lengthInBytes;

    final localFile = File(dbPath);
    final needsCopy =
        !await localFile.exists() || await localFile.length() != assetLength;

    if (needsCopy) {
      await localFile.writeAsBytes(
        assetBytes.buffer.asUint8List(assetBytes.offsetInBytes, assetLength),
      );
    }

    _db = await openDatabase(dbPath, readOnly: true);
    return _db!;
  }

  // ── 웹 경로: JSON을 한 번만 읽어 메모리에 올려둔다 ──────────────────────
  static Map<String, dynamic>? _webEntries; // scode -> {word, translit, ...}
  static Map<String, List<String>>? _webChildren; // parent -> [child, ...]
  static Map<String, List<String>>? _webParents; // child -> [parent, ...]

  static Future<void> _loadWeb() async {
    if (_webEntries != null) return;

    final jsonStr = await rootBundle.loadString('assets/roots_web.json');
    final decoded = json.decode(jsonStr) as Map<String, dynamic>;

    _webEntries = decoded['entries'] as Map<String, dynamic>;

    final children = <String, List<String>>{};
    final parents = <String, List<String>>{};
    for (final e in decoded['edges'] as List<dynamic>) {
      final child = e[0] as String;
      final parent = e[1] as String;
      children.putIfAbsent(parent, () => []).add(child);
      parents.putIfAbsent(child, () => []).add(parent);
    }
    _webChildren = children;
    _webParents = parents;
  }

  /// entries 맵의 한 항목 + scode를 rawQuery 결과와 같은 모양의 Map으로 변환
  static Map<String, Object?> _rowFor(String scode, int depth) {
    final e = _webEntries![scode] as Map<String, dynamic>?;
    return {
      'depth': depth,
      'scode': scode,
      'lang': scode.startsWith('G') ? 'G' : 'H',
      'word': e?['word'],
      'translit': e?['translit'],
      'gloss': e?['gloss'],
      'pos': e?['pos'],
      'freq': e?['freq'],
      'is_root': (e?['is_root'] == true) ? 1 : 0,
    };
  }

  static Future<List<Map<String, Object?>>> _rootFamilyWeb(String scode) async {
    await _loadWeb();

    // 1) 최상위 부모까지 올라간다 (최대 5단계, 순환 방지 겸용)
    var top = scode;
    for (var i = 0; i < 5; i++) {
      final ps = _webParents![top];
      if (ps == null || ps.isEmpty) break;
      top = ps.first;
    }

    // 2) 거기서부터 다시 내려오며 depth 3까지 모은다
    final result = <Map<String, Object?>>[];
    final seen = <String>{};
    void walk(String code, int depth) {
      if (depth > 3 || seen.contains(code)) return;
      seen.add(code);
      result.add(_rowFor(code, depth));
      for (final child in _webChildren![code] ?? const <String>[]) {
        walk(child, depth + 1);
      }
    }

    walk(top, 0);

    // 기존 rawQuery와 같은 정렬: depth asc, freq desc
    result.sort((a, b) {
      final d = (a['depth'] as int).compareTo(b['depth'] as int);
      if (d != 0) return d;
      final fa = (a['freq'] as int?) ?? -1;
      final fb = (b['freq'] as int?) ?? -1;
      return fb.compareTo(fa);
    });
    return result;
  }

  // ── 공개 API: 플랫폼에 따라 자동 분기 ───────────────────────────────────
  static Future<List<Map<String, Object?>>> rootFamily(String scode) async {
    if (kIsWeb) return _rootFamilyWeb(scode);

    final db = await _openDb();

    final top = await db.rawQuery('''
      WITH RECURSIVE up(code, depth) AS (
        SELECT ?, 0
        UNION ALL
        SELECT e.parent, up.depth + 1
        FROM root_edge e JOIN up ON e.child = up.code
        WHERE up.depth < 5
      )
      SELECT code FROM up ORDER BY depth DESC LIMIT 1
    ''', [scode]);

    final topCode = top.isNotEmpty ? top.first['code'] as String : scode;

    return db.rawQuery('''
      WITH RECURSIVE down(code, depth) AS (
        SELECT ?, 0
        UNION ALL
        SELECT e.child, d.depth + 1
        FROM root_edge e JOIN down d ON e.parent = d.code
        WHERE d.depth < 3
      )
      SELECT d.depth AS depth, e.*
      FROM down d
      JOIN entry e ON e.scode = d.code
      ORDER BY d.depth, e.freq DESC
    ''', [topCode]);
  }
}