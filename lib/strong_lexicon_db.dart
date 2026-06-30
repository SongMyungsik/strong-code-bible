import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart' show rootBundle;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// assets/strong_lexicon.db  (히브리어 + 헬라어 스트롱 코드 전체 사전, 14,338건)
// assets/strong_lexicon.json (위 db와 동일한 내용의 웹용 사본)
//
// 웹(kIsWeb)에서는 sqflite를 쓸 수 없으므로 JSON을 메모리에 올려 조회하고,
// 그 외 플랫폼(Android/Windows 등)에서는 기존처럼 sqflite를 사용합니다.
//
// Windows/Linux 데스크톱에서 sqflite를 쓰려면 main.dart 맨 앞에서
// 한 번만 초기화해야 합니다 (Bible.db 쪽에서 이미 하고 있다면 중복 불필요):
//
//   import 'package:sqflite_common_ffi/sqflite_ffi.dart';
//   void main() {
//     if (!kIsWeb && (Platform.isWindows || Platform.isLinux)) {
//       sqfliteFfiInit();
//       databaseFactory = databaseFactoryFfi;
//     }
//     runApp(const MyApp());
//   }
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

class StrongLexiconDb {
  static Database? _db;

  // ── 웹용 메모리 캐시 ──────────────────────────────────────────────────
  static List<Map<String, dynamic>>? _webRows;
  static Map<String, Map<String, dynamic>>? _webIndex;

  static Future<void> _loadWeb() async {
    if (_webRows != null) return;
    final jsonStr = await rootBundle.loadString('assets/strong_lexicon.json');
    final decoded = json.decode(jsonStr) as List<dynamic>;
    _webRows = decoded.cast<Map<String, dynamic>>();
    _webIndex = {
      for (final row in _webRows!) row['strongnumber'] as String: row,
    };
  }

  static Future<Database> _open() async {
    if (_db != null) return _db!;

    final docsDir = await getApplicationDocumentsDirectory();
    final dbPath = p.join(docsDir.path, 'strong_lexicon.db');

    final assetBytes = await rootBundle.load('assets/strong_lexicon.db');
    final assetLength = assetBytes.lengthInBytes;

    final localFile = File(dbPath);
    final needsCopy =
        !await localFile.exists() || await localFile.length() != assetLength;

    if (needsCopy) {
      await localFile.writeAsBytes(
        assetBytes.buffer.asUint8List(
          assetBytes.offsetInBytes,
          assetBytes.lengthInBytes,
        ),
        flush: true,
      );
    }

    _db = await openDatabase(dbPath, readOnly: true);
    return _db!;
  }

  /// code 예: 'H430', 'G1061a' (소문자 접미사가 붙는 경우가 있음)
  /// 반환 컬럼: strongnumber, testament, word, pronunciation_ko,
  ///           pronunciation_en, meaning, class, times, explanation_html
  static Future<Map<String, dynamic>?> getEntry(String code) async {
    // H/G 접두 문자만 대문자로 통일하고, 접미사(a/b 등)는 원래 표기를 그대로 둔다.
    // (사전에 'G1061a'처럼 소문자 접미사로 저장돼 있어서, 전체를 대문자로
    //  바꿔버리면 'G1061A'가 되어 조회가 실패한다.)
    final normalized =
        code.isEmpty ? code : code[0].toUpperCase() + code.substring(1);

    if (kIsWeb) {
      await _loadWeb();
      var row = _webIndex![normalized];

      if (row == null) {
        final base = normalized.replaceFirst(RegExp(r'[a-zA-Z]$'), '');
        if (base != normalized) row = _webIndex![base];
      }

      if (row == null) {
        final codeNum = normalized.replaceAll(RegExp(r'[^0-9]'), '');
        final prefix = normalized.toUpperCase().startsWith('G') ? 'G' : 'H';
        if (codeNum.isNotEmpty) row = _webIndex!['$prefix$codeNum'];
      }

      return row;
    }

    final db = await _open();

    var rows = await db.query(
      'strong_lexicon',
      where: 'strongnumber = ?',
      whereArgs: [normalized],
    );

    if (rows.isEmpty) {
      // 접미사 붙은 코드가 사전에 없는 경우, 접미사를 뗀 기본 번호로 한 번 더 시도
      final base = normalized.replaceFirst(RegExp(r'[a-zA-Z]$'), '');
      if (base != normalized) {
        rows = await db.query(
          'strong_lexicon',
          where: 'strongnumber = ?',
          whereArgs: [base],
        );
      }
    }

    if (rows.isEmpty) {
      // 그 외 표기 차이(공백 등) 대비해 숫자만 추출해서 한 번 더 시도
      final codeNum = normalized.replaceAll(RegExp(r'[^0-9]'), '');
      final prefix = normalized.toUpperCase().startsWith('G') ? 'G' : 'H';
      if (codeNum.isNotEmpty) {
        rows = await db.query(
          'strong_lexicon',
          where: 'strongnumber = ?',
          whereArgs: ['$prefix$codeNum'],
        );
      }
    }

    return rows.isEmpty ? null : rows.first;
  }

  /// 기존 StrongCodeCache.clear()를 쓰던 곳이 있다면 동일하게 대응
  static void clear() {
    _db?.close();
    _db = null;
    _webRows = null;
    _webIndex = null;
  }

  /// testament: 'OT'(히브리어/구약) 또는 'NT'(헬라어/신약) 전체 목록 조회
  /// (목록 화면 등에서 사용. 정렬은 호출하는 쪽에서 번호순으로 합니다.)
  static Future<List<Map<String, dynamic>>> getAll(String testament) async {
    if (kIsWeb) {
      await _loadWeb();
      return _webRows!.where((r) => r['testament'] == testament).toList();
    }

    final db = await _open();
    return db.query(
      'strong_lexicon',
      where: 'testament = ?',
      whereArgs: [testament],
    );
  }
}
