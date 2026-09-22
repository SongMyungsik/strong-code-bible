import 'package:flutter/material.dart';
import 'roots_db.dart';
import 'strong_code_page.dart';

/// 어근(부모) → 파생 단어(자식)를 트리 모양으로 그리는 위젯.
/// 파생 단어는 어근 아래로 한 줄씩 세로로 쌓는다.
class RootFamilyTree extends StatelessWidget {
  final String scode;
  final Color accentColor;

  const RootFamilyTree({
    super.key,
    required this.scode,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map<String, Object?>>>(
      future: RootsDb.rootFamily(scode),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Padding(
            padding: EdgeInsets.all(24),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        if (snapshot.hasError) {
          return Padding(
            padding: const EdgeInsets.all(16),
            child: Text('오류: ${snapshot.error}'),
          );
        }
        final rows = snapshot.data ?? [];
        if (rows.isEmpty) return const SizedBox.shrink();

        // depth 0 = 최상위 어근. 없으면 첫 행을 대신 쓴다.
        final rootRow = rows.firstWhere(
          (r) => r['depth'] == 0,
          orElse: () => rows.first,
        );
        final children = rows.where((r) => r != rootRow).toList();

        if (children.isEmpty) {
          // 자식이 없으면 트리를 그릴 이유가 없다 — 단어 박스 하나만.
          return Center(child: _WordBox(row: rootRow, color: accentColor, bold: true));
        }

        return _TreeLayout(root: rootRow, children: children, color: accentColor);
      },
    );
  }
}

class _TreeLayout extends StatelessWidget {
  final Map<String, Object?> root;
  final List<Map<String, Object?>> children;
  final Color color;

  const _TreeLayout({
    required this.root,
    required this.children,
    required this.color,
  });

  static const double boxHeight = 72;
  static const double rowGap = 8; // 행 사이 세로 간격
  static const double trunkX = 24; // 왼쪽 줄기의 x 위치
  static const double indent = 48; // 자식 박스가 시작하는 x 위치

  @override
  Widget build(BuildContext context) {
    // 어근은 위에, 파생 단어는 그 아래로 한 줄씩 쌓는다 (아래로 스크롤).
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _WordBox(row: root, color: color, bold: true, width: 140),
        for (int i = 0; i < children.length; i++)
          SizedBox(
            height: boxHeight + rowGap,
            child: CustomPaint(
              painter: _BranchPainter(
                color: color,
                isLast: i == children.length - 1,
                trunkX: trunkX,
                indent: indent,
                centerY: rowGap + boxHeight / 2,
              ),
              child: Padding(
                padding: const EdgeInsets.only(left: indent, top: rowGap),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: _WordBox(row: children[i], color: color, width: 200),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _BranchPainter extends CustomPainter {
  final Color color;
  final bool isLast;
  final double trunkX;
  final double indent;
  final double centerY;

  _BranchPainter({
    required this.color,
    required this.isLast,
    required this.trunkX,
    required this.indent,
    required this.centerY,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withValues(alpha: 0.55)
      ..strokeWidth = 1.6
      ..style = PaintingStyle.stroke;

    // 세로 줄기: 마지막 행은 박스 높이 중앙까지만
    canvas.drawLine(
      Offset(trunkX, 0),
      Offset(trunkX, isLast ? centerY : size.height),
      paint,
    );
    // 줄기에서 박스로 가는 가로선
    canvas.drawLine(Offset(trunkX, centerY), Offset(indent, centerY), paint);
  }

  @override
  bool shouldRepaint(covariant _BranchPainter old) =>
      old.color != color || old.isLast != isLast;
}

class _WordBox extends StatelessWidget {
  final Map<String, Object?> row;
  final Color color;
  final bool bold;
  final double width;

  const _WordBox({
    required this.row,
    required this.color,
    this.bold = false,
    this.width = 108,
  });

  @override
  Widget build(BuildContext context) {
    final scode = row['scode'] as String;
    final word = row['word'] as String? ?? '';
    final translit = row['translit'] as String? ?? '';
    final gloss = row['gloss'] as String? ?? '';

    return GestureDetector(
      onTap: () => StrongCodePage.navigate(context, scode),
      child: Container(
        width: width,
        height: 72,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: bold ? color.withValues(alpha: 0.12) : Colors.white,
          border: Border.all(color: color.withValues(alpha: bold ? 0.7 : 0.35)),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              word,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textDirection: TextDirection.rtl,
              style: TextStyle(
                fontFamily: 'EzraSIL',
                fontSize: bold ? 24 : 22,
                fontWeight: bold ? FontWeight.bold : FontWeight.normal,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              gloss.isNotEmpty ? gloss : translit,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 10, color: Colors.black54),
            ),
          ],
        ),
      ),
    );
  }
}