import 'package:flutter/material.dart';
import 'strong_code_page.dart';
import 'strong_lexicon_db.dart';

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// 스트롱 코드 목록 화면
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

class StrongCodeListPage extends StatefulWidget {
  const StrongCodeListPage({super.key});

  @override
  State<StrongCodeListPage> createState() => _StrongCodeListPageState();
}

class _StrongCodeListPageState extends State<StrongCodeListPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  bool _hebrewLoading = true;
  bool _greekLoading  = true;

  List<_CodeEntry> _hebrewList = [];
  List<_CodeEntry> _greekList  = [];

  // 검색어
  String _hebrewQuery = '';
  String _greekQuery  = '';

  final _hebrewSearchCtrl = TextEditingController();
  final _greekSearchCtrl  = TextEditingController();

  final _hebrewScrollCtrl = ScrollController();
  final _greekScrollCtrl  = ScrollController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadBoth();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _hebrewSearchCtrl.dispose();
    _greekSearchCtrl.dispose();
    _hebrewScrollCtrl.dispose();
    _greekScrollCtrl.dispose();
    super.dispose();
  }

  void _jumpBy(ScrollController ctrl, List<_CodeEntry> entries, int delta) {
    if (!ctrl.hasClients || entries.isEmpty) return;
    final maxExtent = ctrl.position.maxScrollExtent;
    final pixelsPerItem = maxExtent / entries.length;
    final currentIndex = (ctrl.offset / pixelsPerItem).round();
    final targetIndex = (currentIndex + delta).clamp(0, entries.length - 1);
    ctrl.animateTo(
      targetIndex * pixelsPerItem,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
    );
  }

  void _jumpToStart(ScrollController ctrl) {
    if (!ctrl.hasClients) return;
    ctrl.animateTo(0, duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
  }

  void _jumpToEnd(ScrollController ctrl) {
    if (!ctrl.hasClients) return;
    ctrl.animateTo(
      ctrl.position.maxScrollExtent,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
    );
  }

  Future<void> _loadBoth() async {
    await Future.wait([_loadHebrew(), _loadGreek()]);
  }

  Future<void> _loadHebrew() async {
    try {
      final rows = await StrongLexiconDb.getAll('OT');
      final list = _toSortedList(rows);
      if (mounted) {
        setState(() { _hebrewList = list; _hebrewLoading = false; });
      }
    } catch (e) {
      debugPrint('[StrongCodeList] Hebrew load error: $e');
      if (mounted) {
        setState(() => _hebrewLoading = false);
      }
    }
  }

  Future<void> _loadGreek() async {
    try {
      final rows = await StrongLexiconDb.getAll('NT');
      final list = _toSortedList(rows);
      if (mounted) {
        setState(() { _greekList = list; _greekLoading = false; });
      }
    } catch (e) {
      debugPrint('[StrongCodeList] Greek load error: $e');
      if (mounted) {
        setState(() => _greekLoading = false);
      }
    }
  }

  /// DB 행 → 번호 순 정렬 리스트
  List<_CodeEntry> _toSortedList(List<Map<String, dynamic>> rows) {
    final list = <_CodeEntry>[];
    for (final item in rows) {
      // DB에 저장된 표기를 그대로 사용 (접미사 a/b 등은 소문자 그대로 유지)
      final code = item['strongnumber'] as String;
      final numStr = code.replaceAll(RegExp(r'[^0-9]'), '');
      final num = int.tryParse(numStr) ?? 999999;
      list.add(_CodeEntry(
        code       : code,
        number     : num,
        word       : item['word']?.toString() ?? '',
        explanation: item['meaning']?.toString() ?? '',
        pronunciation: item['pronunciation_en']?.toString() ?? '',
        korean     : item['pronunciation_ko']?.toString() ?? '',
        times      : item['times']?.toString() ?? '',
      ));
    }
    list.sort((a, b) => a.number.compareTo(b.number));
    return list;
  }

  List<_CodeEntry> _filtered(List<_CodeEntry> src, String query) {
    if (query.isEmpty) return src;
    final q = query.trim().toLowerCase();

    // 숫자만 입력 (예: "300") → 코드 번호만 검색 (앞부분 일치)
    final isNumericQuery = RegExp(r'^\d+$').hasMatch(q);

    // H/G + 숫자 (+ a/b 등 접미사) 형태 (예: "H300", "G12", "g1061a") → 코드 필드만 검색
    final isCodeQuery = RegExp(r'^[hg]\d+[a-z]?$').hasMatch(q);

    if (isNumericQuery) {
      // 코드에서 숫자만 추출 후 정확히 일치 비교
      return src.where((e) {
        final codeNum = e.code.replaceAll(RegExp(r'[^0-9]'), '');
        return codeNum == q;
      }).toList();
    } else if (isCodeQuery) {
      // H/G + 숫자: 코드 필드 정확히 일치
      return src.where((e) =>
        e.code.toLowerCase() == q
      ).toList();
    } else {
      // 일반 텍스트: 단어·뜻·발음에서 검색 (코드 제외)
      return src.where((e) =>
        e.word.toLowerCase().contains(q) ||
        e.explanation.toLowerCase().contains(q) ||
        e.pronunciation.toLowerCase().contains(q) ||
        e.korean.toLowerCase().contains(q)
      ).toList();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color.fromARGB(255, 235, 245, 178),
        elevation: 0,
        title: const Text(
          '[스트롱 코드 목록]',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black),
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.purple[700],
          labelColor: Colors.purple[700],
          unselectedLabelColor: Colors.grey,
          tabs: const [
            Tab(text: '히브리어 (구약)'),
            Tab(text: '헬라어 (신약)'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildList(
            loading     : _hebrewLoading,
            entries     : _filtered(_hebrewList, _hebrewQuery),
            total       : _hebrewList.length,
            isGreek     : false,
            searchCtrl  : _hebrewSearchCtrl,
            onSearch    : (v) => setState(() => _hebrewQuery = v),
            scrollCtrl  : _hebrewScrollCtrl,
          ),
          _buildList(
            loading     : _greekLoading,
            entries     : _filtered(_greekList, _greekQuery),
            total       : _greekList.length,
            isGreek     : true,
            searchCtrl  : _greekSearchCtrl,
            onSearch    : (v) => setState(() => _greekQuery = v),
            scrollCtrl  : _greekScrollCtrl,
          ),
        ],
      ),
    );
  }

  Widget _buildList({
    required bool loading,
    required List<_CodeEntry> entries,
    required int total,
    required bool isGreek,
    required TextEditingController searchCtrl,
    required ValueChanged<String> onSearch,
    required ScrollController scrollCtrl,
  }) {
    final accentColor = isGreek ? Colors.indigo[700]! : Colors.purple[700]!;
    final chipBg      = isGreek ? Colors.indigo[100]! : Colors.purple[100]!;
    final chipBorder  = isGreek ? Colors.indigo.shade300 : Colors.purple.shade300;
    final chipText    = isGreek ? Colors.indigo[800]! : Colors.purple[800]!;

    if (loading) {
      return const Center(child: CircularProgressIndicator());
    }

    return Column(
      children: [
        // ── 검색창 ────────────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: TextField(
            controller: searchCtrl,
            onChanged: onSearch,
            decoration: InputDecoration(
              hintText: '코드번호 · 단어 · 뜻 검색',
              prefixIcon: const Icon(Icons.search, size: 20),
              suffixIcon: searchCtrl.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, size: 18),
                      onPressed: () {
                        searchCtrl.clear();
                        onSearch('');
                      },
                    )
                  : null,
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(24),
                borderSide: BorderSide(color: accentColor.withValues(alpha: 0.4)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(24),
                borderSide: BorderSide(color: accentColor.withValues(alpha: 0.3)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(24),
                borderSide: BorderSide(color: accentColor, width: 1.5),
              ),
              contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 10),
              isDense: true,
            ),
          ),
        ),

        // ── 건수 표시 ─────────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.only(left: 16, bottom: 4),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              '${entries.length} / $total 건',
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
          ),
        ),

        // ── 목록 ──────────────────────────────────────────────────────────
        Expanded(
          child: entries.isEmpty
              ? Center(
                  child: Text(
                    '결과가 없습니다.',
                    style: TextStyle(color: Colors.grey[500]),
                  ),
                )
              : ListView.separated(
                  controller: scrollCtrl,
                  itemCount: entries.length,
                  separatorBuilder: (_, __) =>
                      Divider(height: 1, color: Colors.grey[200]),
                  itemBuilder: (context, i) {
                    final e = entries[i];
                    return InkWell(
                      onTap: () => StrongCodePage.navigate(context, e.code),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // ── 1행: 코드칩 + word + 횟수 ─────────────────
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                // 코드 칩
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 7, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: chipBg,
                                    border: Border.all(
                                        color: chipBorder, width: 0.8),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    e.code,
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: chipText,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                // 원어 단어
                                Expanded(
                                  child: Text(
                                    e.word.isNotEmpty ? e.word : '-',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontFamily: isGreek ? null : 'EzraSIL',
                                      fontWeight: FontWeight.w600,
                                    ),
                                    textDirection: isGreek
                                        ? TextDirection.ltr
                                        : TextDirection.rtl,
                                    textAlign: isGreek
                                        ? TextAlign.left
                                        : TextAlign.right,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                // 횟수 (우측 끝)
                                if (e.times.isNotEmpty)
                                  RichText(
                                    text: TextSpan(
                                      children: [
                                        TextSpan(
                                          text: e.times,
                                          style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.bold,
                                            color: accentColor,
                                          ),
                                        ),
                                        TextSpan(
                                          text: '회',
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: Colors.grey[500],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                              ],
                            ),

                            // ── 2행: 발음 | 한글발음 병기 ──────────────────
                            if (e.pronunciation.isNotEmpty ||
                                e.korean.isNotEmpty) ...[
                              const SizedBox(height: 3),
                              Row(
                                children: [
                                  if (e.pronunciation.isNotEmpty)
                                    Text(
                                      e.pronunciation,
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey[600],
                                        fontStyle: FontStyle.italic,
                                      ),
                                    ),
                                  if (e.pronunciation.isNotEmpty &&
                                      e.korean.isNotEmpty) ...[
                                    Text(
                                      '  |  ',
                                      style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey[400]),
                                    ),
                                  ],
                                  if (e.korean.isNotEmpty)
                                    Text(
                                      e.korean,
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey[700],
                                      ),
                                    ),
                                ],
                              ),
                            ],

                            // ── 3행: 뜻 ────────────────────────────────────
                            if (e.explanation.isNotEmpty) ...[
                              const SizedBox(height: 3),
                              Text(
                                e.explanation,
                                style: const TextStyle(fontSize: 13),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),

        // ── 이동 버튼 바 ──────────────────────────────────────────────────
        SafeArea(
          top: false,
          child: Container(
          color: accentColor.withValues(alpha: 0.06),
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _JumpButton(label: '처음',  onTap: () => _jumpToStart(scrollCtrl)),
              _JumpButton(label: '-1000', onTap: () => _jumpBy(scrollCtrl, entries, -1000)),
              _JumpButton(label: '-100',  onTap: () => _jumpBy(scrollCtrl, entries, -100)),
              _JumpButton(label: '-10',   onTap: () => _jumpBy(scrollCtrl, entries, -10)),
              _JumpButton(label: '+10',   onTap: () => _jumpBy(scrollCtrl, entries, 10)),
              _JumpButton(label: '+100',  onTap: () => _jumpBy(scrollCtrl, entries, 100)),
              _JumpButton(label: '+1000', onTap: () => _jumpBy(scrollCtrl, entries, 1000)),
              _JumpButton(label: '끝',    onTap: () => _jumpToEnd(scrollCtrl)),
            ],
          ),
        ),
        ), // SafeArea
      ],
    );
  }
}

class _JumpButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _JumpButton({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 5),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: Colors.grey.shade300),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          label,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// 데이터 모델
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

class _CodeEntry {
  final String code;
  final int    number;
  final String word;
  final String explanation;
  final String pronunciation;
  final String korean;
  final String times;

  const _CodeEntry({
    required this.code,
    required this.number,
    required this.word,
    required this.explanation,
    required this.pronunciation,
    required this.korean,
    required this.times,
  });
}