import 'package:flutter/material.dart';
import 'roots_db.dart';

/// 어근 가족을 세로 목록으로 보여주는 가장 단순한 버전.
/// 동작 확인용 — 나중에 트리 모양으로 바꿀 때 이 위젯을 교체하면 된다.
class RootFamilyList extends StatelessWidget {
  final String scode; // 예: 'H3789'

  const RootFamilyList({super.key, required this.scode});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map<String, Object?>>>(
      future: RootsDb.rootFamily(scode),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Padding(
            padding: EdgeInsets.all(16),
            child: CircularProgressIndicator(),
          );
        }
        if (snapshot.hasError) {
          return Padding(
            padding: const EdgeInsets.all(16),
            child: Text('오류: ${snapshot.error}'),
          );
        }
        final rows = snapshot.data ?? [];
        if (rows.isEmpty) {
          return const Padding(
            padding: EdgeInsets.all(16),
            child: Text('어근 가족 정보가 없습니다.'),
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Text('어근 가족', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
            for (final r in rows)
              ListTile(
                dense: true,
                contentPadding: EdgeInsets.only(
                  left: 16.0 + (r['depth'] as int) * 20.0, // depth만큼 들여쓰기
                  right: 16,
                ),
                title: Text(
                  '${r['word']}  (${r['translit']})',
                  style: TextStyle(
                    fontWeight: (r['is_root'] == 1)
                        ? FontWeight.bold
                        : FontWeight.normal,
                  ),
                ),
                subtitle: Text('${r['gloss'] ?? ''}'),
                trailing: r['freq'] != null ? Text('${r['freq']}회') : null,
              ),
          ],
        );
      },
    );
  }
}