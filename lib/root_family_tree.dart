import 'package:flutter/material.dart';
import 'roots_db.dart';
import 'strong_code_page.dart';

/// 어근(부모) → 파생 단어(자식)를 트리 모양으로 그리는 위젯.
/// 자식 수에 맞춰 가로 폭을 자동으로 나눠 배치한다.
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

  static const double boxWidth = 108;
  static const double boxHeight = 64;
  static const double vGap = 34; // 부모-자식 사이 세로 간격

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final n = children.length;
        final totalWidth = constraints.maxWidth;

        // 자식이 너무 많으면 가로 스크롤로 전환 (한 줄에 최대 4개 기준)
        final needsScroll = n > 4;
        final laneWidth = needsScroll
            ? boxWidth + 16
            : totalWidth / n;

        final contentWidth = needsScroll ? laneWidth * n : totalWidth;
        final rootX = contentWidth / 2 - boxWidth / 2;

        Widget canvas = SizedBox(
          width: contentWidth,
          height: boxHeight * 2 + vGap + 8,
          child: CustomPaint(
            painter: _TreePainter(
              color: color,
              rootCenterX: rootX + boxWidth / 2,
              childCenterXs: List.generate(
                n,
                (i) => laneWidth * i + laneWidth / 2,
              ),
              boxHeight: boxHeight,
              vGap: vGap,
            ),
            child: Stack(
              children: [
                Positioned(
                  left: rootX,
                  top: 0,
                  child: _WordBox(row: root, color: color, bold: true, width: boxWidth),
                ),
                for (int i = 0; i < n; i++)
                  Positioned(
                    left: laneWidth * i + (laneWidth - boxWidth) / 2,
                    top: boxHeight + vGap,
                    child: _WordBox(row: children[i], color: color, width: boxWidth),
                  ),
              ],
            ),
          ),
        );

        return needsScroll
            ? SingleChildScrollView(scrollDirection: Axis.horizontal, child: canvas)
            : canvas;
      },
    );
  }
}

class _TreePainter extends CustomPainter {
  final Color color;
  final double rootCenterX;
  final List<double> childCenterXs;
  final double boxHeight;
  final double vGap;

  _TreePainter({
    required this.color,
    required this.rootCenterX,
    required this.childCenterXs,
    required this.boxHeight,
    required this.vGap,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withValues(alpha: 0.55)
      ..strokeWidth = 1.6
      ..style = PaintingStyle.stroke;

    final branchY = boxHeight + vGap / 2;

    // 부모 아래로 내려오는 줄기
    canvas.drawLine(Offset(rootCenterX, boxHeight), Offset(rootCenterX, branchY), paint);

    if (childCenterXs.length == 1) {
      // 자식이 하나면 그냥 직선으로
      canvas.drawLine(
        Offset(rootCenterX, branchY),
        Offset(childCenterXs.first, boxHeight + vGap),
        paint,
      );
      return;
    }

    final minX = childCenterXs.reduce((a, b) => a < b ? a : b);
    final maxX = childCenterXs.reduce((a, b) => a > b ? a : b);

    // 가로 분기선
    canvas.drawLine(Offset(minX, branchY), Offset(maxX, branchY), paint);

    // 각 자식으로 내려가는 세로선
    for (final x in childCenterXs) {
      canvas.drawLine(Offset(x, branchY), Offset(x, boxHeight + vGap), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _TreePainter oldDelegate) => false;
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
        height: 64,
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
                fontSize: bold ? 16 : 14,
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