import 'package:flutter/services.dart' show rootBundle;
import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

/// strongs_roots.db 전용 헬퍼.
/// StrongLexiconDb의 _open() 패턴을 그대로 따른다:
/// assets -> 문서 폴더로 최초 1회 복사 -> sqflite로 오픈.
class RootsDb {
  static Database? _db;

  static Future<Database> _open() async {
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
        assetBytes.buffer.asUint8List(
          assetBytes.offsetInBytes,
          assetLength,
        ),
      );
    }

    _db = await openDatabase(dbPath, readOnly: true);
    return _db!;
  }

  /// 특정 scode(예: 'H3789')가 속한 어근 가족 전체를 가져온다.
  /// 1) 최상위 부모까지 올라간 뒤 2) 거기서 다시 내려오며 자식들을 모은다.
  /// 반환되는 각 row에는 depth(0=최상위 어근)가 포함된다.
  static Future<List<Map<String, Object?>>> rootFamily(String scode) async {
    final db = await _open();

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