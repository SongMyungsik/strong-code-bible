import 'package:flutter/material.dart';
import 'package:flutter_html/flutter_html.dart';

import 'strong_lexicon_db.dart';

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// 데이터 소스: assets/strong_lexicon.db (StrongLexiconDb, strong_lexicon_db.dart)
//   - 기존 strongcode.json / strongcode2.json 은 더 이상 사용하지 않습니다.
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// StrongCodePage
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

class StrongCodePage extends StatefulWidget {
  final String code; // 예: 'H430', 'G216'

  const StrongCodePage({super.key, required this.code});

  static void navigate(BuildContext context, String code) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => StrongCodePage(code: code)),
    );
  }

  @override
  State<StrongCodePage> createState() => _StrongCodePageState();
}

class _StrongCodePageState extends State<StrongCodePage> {
  bool _loading = true;
  String? _errorMsg;
  Map<String, dynamic>? _entry;

  /// 코드 첫 글자로 H/G 판별
  String get _prefix => widget.code.toUpperCase().startsWith('G') ? 'G' : 'H';

  /// 화면 표시용 코드: H/G 접두 문자만 대문자로, 접미사(a/b 등)는 원래 표기 유지
  String get _displayCode {
    final c = widget.code;
    return c.isEmpty ? c : c[0].toUpperCase() + c.substring(1);
  }

  /// 언어 표시 이름
  String get _langLabel => _prefix == 'G' ? '헬라어 (신약)' : '히브리어 (구약)';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final entry = await StrongLexiconDb.getEntry(widget.code);
      setState(() {
        _entry = entry;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _errorMsg = e.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // H/G에 따라 앱바 색상 구분
    final appBarColor =
        _prefix == 'G'
            ? Colors.indigo[700]! // 신약: 인디고
            : Colors.purple[700]!; // 구약: 퍼플

    return Scaffold(
      backgroundColor: const Color(0xFFF5F0FF),
      appBar: AppBar(
        backgroundColor: appBarColor,
        foregroundColor: Colors.white,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '스트롱 코드  $_displayCode',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            Text(
              _langLabel,
              style: const TextStyle(fontSize: 12, color: Colors.white70),
            ),
          ],
        ),
      ),
      body: _buildBody(appBarColor),
    );
  }

  Widget _buildBody(Color accentColor) {
    if (_loading) return const Center(child: CircularProgressIndicator());

    if (_errorMsg != null) {
      return _ErrorView(title: 'DB 로드 오류', body: _errorMsg!);
    }

    if (_entry == null) {
      return _ErrorView(title: '코드를 찾지 못했습니다', body: '검색한 코드: $_displayCode');
    }

    return _DetailView(
      code: _displayCode,
      entry: _entry!,
      accentColor: accentColor,
      isGreek: _prefix == 'G',
    );
  }
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// 상세 레이아웃
//   단어(word)                       │ 횟수(times, 없으면 박스 생략)
//   발음(pronunciation_en/ko)
//   품사(class, 없으면 박스 생략)
//   뜻(meaning + explanation_html, HTML 렌더링) ──────────────
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

class _DetailView extends StatelessWidget {
  final String code;
  final Map<String, dynamic> entry;
  final Color accentColor;
  final bool isGreek;

  const _DetailView({
    required this.code,
    required this.entry,
    required this.accentColor,
    required this.isGreek,
  });

  String _v(String key) => entry[key]?.toString() ?? '';

  /// 단어 박스 (+ 횟수 정보가 있을 때만 옆에 횟수 박스 추가)
  Widget _buildWordRow() {
    final wordBox = _LabeledBox(
      label: '단어',
      accentColor: accentColor,
      child: Text(
        _v('word'),
        style: TextStyle(
          fontSize: 22,
          // 히브리어: EzraSIL / 헬라어: 기본 폰트
          fontFamily: isGreek ? null : 'EzraSIL',
          height: 1.4,
        ),
        textAlign: isGreek ? TextAlign.left : TextAlign.right,
        textDirection: isGreek ? TextDirection.ltr : TextDirection.rtl,
      ),
    );

    final timesValue = entry['times'];
    if (timesValue == null) {
      // 횟수 정보가 없는 항목(헬라어 전체, 히브리어 대부분) → 단어 박스만 표시
      return wordBox;
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(flex: 3, child: wordBox),
        const SizedBox(width: 10),
        Expanded(
          flex: 2,
          child: _LabeledBox(
            label: '횟수',
            accentColor: accentColor,
            child: Text(
              '$timesValue',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        16,
        16,
        16,
        16 + MediaQuery.of(context).padding.bottom, // 하단 시스템 영역 회피
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── 코드 배지 ────────────────────────────────────────────────────
          Center(
            child: Container(
              margin: const EdgeInsets.only(bottom: 20),
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 10),
              decoration: BoxDecoration(
                color: accentColor,
                borderRadius: BorderRadius.circular(30),
                boxShadow: [
                  BoxShadow(
                    color: accentColor.withValues(alpha: 0.35),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Text(
                code,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 2,
                ),
              ),
            ),
          ),

          // ── 행 1: 단어 | 횟수(있을 때만) ─────────────────────────────────
          _buildWordRow(),

          const SizedBox(height: 12),

          // ── 행 2: 발음 ───────────────────────────────────────────────────
          _LabeledBox(
            label: '발음',
            accentColor: accentColor,
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    _v('pronunciation_en'),
                    style: const TextStyle(fontSize: 16),
                  ),
                ),
                if (_v('pronunciation_ko').isNotEmpty) ...[
                  const SizedBox(width: 8),
                  Container(width: 1, height: 20, color: Colors.grey[300]),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _v('pronunciation_ko'),
                      style: const TextStyle(fontSize: 16),
                      textAlign: TextAlign.right,
                    ),
                  ),
                ],
              ],
            ),
          ),

          // ── 행 3: 품사(있을 때만) ────────────────────────────────────────
          if (_v('class').isNotEmpty) ...[
            const SizedBox(height: 12),
            _LabeledBox(
              label: '품사',
              accentColor: accentColor,
              child: Align(
                alignment: Alignment.centerLeft,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: accentColor.withValues(alpha: 0.08),
                    border: Border.all(
                      color: accentColor.withValues(alpha: 0.4),
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    _v('class'),
                    style: TextStyle(
                      fontSize: 14,
                      color: accentColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
          ],

          const SizedBox(height: 12),

          // ── 뜻 ──────────────────────────────────────────────────────────
          _LabeledBox(
            label: '뜻',
            accentColor: accentColor,
            minHeight: 160,
            child: Html(
              data:
                  [
                    if (_v('meaning').isNotEmpty)
                      '<b>${_v('meaning')}</b><br><br>',
                    _v('explanation_html'),
                  ].join(),
              style: {
                'body': Style(
                  fontSize: FontSize(16),
                  lineHeight: const LineHeight(1.7),
                  margin: Margins.zero,
                  padding: HtmlPaddings.zero,
                ),
                'a': Style(
                  color: accentColor,
                  textDecoration: TextDecoration.none,
                ),
              },
              onLinkTap: (url, attributes, element) {
                if (url == null || !url.startsWith('strong://')) return;
                final refCode = url.replaceFirst('strong://', '');
                StrongCodePage.navigate(context, refCode);
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// 공통 레이블 박스
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

class _LabeledBox extends StatelessWidget {
  final String label;
  final Widget child;
  final Color accentColor;
  final double minHeight;

  const _LabeledBox({
    required this.label,
    required this.child,
    required this.accentColor,
    this.minHeight = 0,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      constraints: BoxConstraints(minHeight: minHeight),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: accentColor.withValues(alpha: 0.3)),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
            decoration: BoxDecoration(
              color: accentColor.withValues(alpha: 0.08),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(12),
              ),
            ),
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: accentColor,
                letterSpacing: 0.5,
              ),
            ),
          ),
          Padding(padding: const EdgeInsets.all(14), child: child),
        ],
      ),
    );
  }
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// 오류 표시
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

class _ErrorView extends StatelessWidget {
  final String title;
  final String body;
  const _ErrorView({required this.title, required this.body});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(32),
      child: Column(
        children: [
          const SizedBox(height: 40),
          Icon(Icons.search_off, size: 72, color: Colors.purple[200]),
          const SizedBox(height: 16),
          Text(
            title,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: Text(
              body,
              style: const TextStyle(fontSize: 14, height: 1.6),
            ),
          ),
        ],
      ),
    );
  }
}
