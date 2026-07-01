import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_tts/flutter_tts.dart';

import 'book_map.dart';
import 'chapter.dart';
import 'start_page.dart';
import 'strong_code_page.dart';
import 'strong_code_list_page.dart'; // ← 새로 추가한 파일
import 'about_page.dart';

import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  if (!kIsWeb && (Platform.isWindows || Platform.isLinux)) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }
  runApp(const BibleApp());
}

class BibleApp extends StatelessWidget {
  const BibleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '스트롱성경',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(primarySwatch: Colors.purple),
      home: const StartPage(),
    );
  }
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// BibleHomePage
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

class BibleHomePage extends StatefulWidget {
  const BibleHomePage({super.key});

  @override
  State<BibleHomePage> createState() => _BibleHomePageState();
}

class _BibleHomePageState extends State<BibleHomePage> {
  int _selectedIndex = 1;

  bool _isOT = true;
  String selectedBook = bookList.first;
  int selectedChapter = 1;
  List<dynamic> allVerses = [];
  List<Map<String, dynamic>> verses = [];
  double fontSize = 18.0;
  bool isLoading = false;

  static const _otBooks = [
    '창세기',
    '출애굽기',
    '레위기',
    '민수기',
    '신명기',
    '여호수아',
    '사사기',
    '룻기',
    '사무엘상',
    '사무엘하',
    '열왕기상',
    '열왕기하',
    '역대상',
    '역대하',
    '에스라',
    '느헤미야',
    '에스더',
    '욥기',
    '시편',
    '잠언',
    '전도서',
    '아가',
    '이사야',
    '예레미야',
    '예레미야애가',
    '에스겔',
    '다니엘',
    '호세아',
    '요엘',
    '아모스',
    '오바댜',
    '요나',
    '미가',
    '나훔',
    '하박국',
    '스바냐',
    '학개',
    '스가랴',
    '말라기',
  ];
  static const _ntBooks = [
    '마태복음',
    '마가복음',
    '누가복음',
    '요한복음',
    '사도행전',
    '로마서',
    '고린도전서',
    '고린도후서',
    '갈라디아서',
    '에베소서',
    '빌립보서',
    '골로새서',
    '데살로니가전서',
    '데살로니가후서',
    '디모데전서',
    '디모데후서',
    '디도서',
    '빌레몬서',
    '히브리서',
    '야고보서',
    '베드로전서',
    '베드로후서',
    '요한일서',
    '요한이서',
    '요한삼서',
    '유다서',
    '요한계시록',
  ];

  // TTS 상태
  bool _isReading = false;
  bool _isTtsBusy = false;
  int? _readingVerseIndex;

  final FlutterTts flutterTts = FlutterTts();
  final ScrollController _verseScrollCtrl = ScrollController();

  @override
  void initState() {
    super.initState();
    _initTts();
    loadBibleData();
  }

  @override
  void dispose() {
    flutterTts.stop();
    _verseScrollCtrl.dispose();
    super.dispose();
  }

  // ── TTS ──────────────────────────────────────────────────────────────────

  Future<void> _initTts() async {
    await flutterTts.setVolume(1.0);
    await flutterTts.setPitch(1.0);
    await flutterTts.setSpeechRate(0.45);
    await flutterTts.awaitSpeakCompletion(true);
  }

  Future<void> _stopAll() async {
    await flutterTts.stop();
    if (mounted) {
      setState(() {
        _isReading = false;
        _isTtsBusy = false;
        _readingVerseIndex = null;
      });
    }
  }

  Future<void> _startChapterReading() async {
    if (verses.isEmpty) return;
    await flutterTts.setLanguage('ko-KR');

    for (int i = 0; i < verses.length; i++) {
      if (!_isReading || !mounted) break;

      final plain = verses[i]['text'] as String? ?? '';

      setState(() {
        _isTtsBusy = false;
        _readingVerseIndex = i;
      });

      await flutterTts.speak(plain);

      if (_isReading && i < verses.length - 1) {
        await Future.delayed(const Duration(milliseconds: 500));
      }
    }

    if (mounted) _stopAll();
  }

  void _toggleChapterReading() {
    if (_isReading) {
      _stopAll();
    } else {
      setState(() {
        _isReading = true;
        _isTtsBusy = true;
      });
      _startChapterReading();
    }
  }

  // ── 데이터 로드 ──────────────────────────────────────────────────────────

  Future<void> loadBibleData() async {
    final idx = bookList.indexOf(selectedBook);
    if (idx < 0) return;
    final num = (idx + 1).toString().padLeft(2, '0');
    final path = 'assets/books/${num}_$selectedBook.json';
    try {
      final data = await rootBundle.loadString(path);
      final decoded = json.decode(data) as List;
      if (!mounted) return;
      setState(() => allVerses = decoded);
      loadVerses();
    } catch (e) {
      /* 로드 실패 */
    }
  }

  void loadVerses() {
    if (!mounted) return;
    setState(() {
      verses =
          allVerses
              .where((v) => (v['chapter'] as int?) == selectedChapter)
              .map<Map<String, dynamic>>(
                (v) => Map<String, dynamic>.from(v as Map),
              )
              .toList();
    });
  }

  void _onTestamentChanged(bool isOT) {
    if (_isOT == isOT) return;
    _stopAll();
    final newBook = isOT ? _otBooks.first : _ntBooks.first;
    setState(() {
      _isOT = isOT;
      selectedBook = newBook;
      selectedChapter = 1;
      allVerses = [];
      verses = [];
    });
    loadBibleData();
  }

  void onBookChanged(String? value) {
    if (value != null) {
      _stopAll();
      setState(() {
        selectedBook = value;
        selectedChapter = 1;
        allVerses = [];
        verses = [];
      });
      loadBibleData();
    }
  }

  void onChapterChanged(int? value) {
    if (value != null) {
      _stopAll();
      setState(() {
        selectedChapter = value;
      });
      loadVerses();
    }
  }

  void changeChapter(int diff) {
    final chapterLen = chapterCount[selectedBook]?.length ?? 1;
    _stopAll();
    setState(() {
      selectedChapter = (selectedChapter + diff).clamp(1, chapterLen);
    });
    loadVerses();
  }

  void _onItemTapped(int index) {
    if (index == 0) {
      Navigator.pop(context);
    } else if (index == 2) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const StrongCodeListPage()),
      );
    } else if (index == 3) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const AboutPage()),
      );
    } else {
      _stopAll();
      setState(() => _selectedIndex = index);
    }
  }

  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  // 절 텍스트 → RichText (스트롱 코드는 숨기고, 연결된 단어에 밑줄)
  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  Widget _buildVerseRichText(Map<String, dynamic> verseData, int idx) {
    final isHighlighted = _readingVerseIndex == idx;
    final verseNum = verseData['verse'];
    final text = verseData['text'] as String? ?? '';
    final wordList =
        (verseData['words'] as List?)?.cast<Map<String, dynamic>>() ?? [];

    TextStyle plainStyle() => TextStyle(
      fontSize: fontSize,
      fontWeight: FontWeight.bold,
      color: Colors.black87,
      backgroundColor: isHighlighted ? Colors.yellow[200] : null,
    );

    final spans = <InlineSpan>[
      TextSpan(text: '$verseNum. ', style: plainStyle()),
    ];

    int cursor = 0;
    for (final entry in wordList) {
      final word = entry['word'] as String? ?? '';
      final code = entry['strong'] as String? ?? '';
      if (word.isEmpty) continue;

      final pos = text.indexOf(word, cursor);
      if (pos == -1) continue;

      if (pos > cursor) {
        spans.add(
          TextSpan(text: text.substring(cursor, pos), style: plainStyle()),
        );
      }

      if (code.isEmpty) {
        spans.add(TextSpan(text: word, style: plainStyle()));
      } else {
        final isGreek = code.toUpperCase().startsWith('G');
        final linkColor =
            isHighlighted
                ? Colors.orange.shade600
                : isGreek
                ? Colors.indigo.shade400
                : Colors.purple.shade400;
        spans.add(
          WidgetSpan(
            alignment: PlaceholderAlignment.baseline,
            baseline: TextBaseline.alphabetic,
            child: GestureDetector(
              onTap: () => StrongCodePage.navigate(context, code),
              child: Text(
                word,
                style: TextStyle(
                  fontSize: fontSize,
                  fontWeight: FontWeight.bold,
                  color: linkColor,
                  backgroundColor: isHighlighted ? Colors.yellow[200] : null,
                  decoration: TextDecoration.none,
                ),
              ),
            ),
          ),
        );
      }
      cursor = pos + word.length;
    }

    if (cursor < text.length) {
      spans.add(TextSpan(text: text.substring(cursor), style: plainStyle()));
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5.0, horizontal: 12.0),
      child: RichText(text: TextSpan(children: spans)),
    );
  }

  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  // build
  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color.fromARGB(255, 235, 245, 178),
        elevation: 0,
        title: const Text(
          '[스트롱성경]',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.black,
            fontSize: 16,
          ),
        ),
        centerTitle: false,
        actions: [
          _TestamentBtn(
            label: '구약',
            selected: _isOT,
            color: Colors.purple,
            onTap: () => _onTestamentChanged(true),
          ),
          const SizedBox(width: 4),
          _TestamentBtn(
            label: '신약',
            selected: !_isOT,
            color: Colors.indigo,
            onTap: () => _onTestamentChanged(false),
          ),
          const SizedBox(width: 10),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // ── 상단 컨트롤 바 ────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(
                vertical: 8.0,
                horizontal: 12.0,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Slider(
                      min: 12,
                      max: 32,
                      divisions: 20,
                      label: fontSize.toStringAsFixed(0),
                      value: fontSize,
                      onChanged: (val) => setState(() => fontSize = val),
                    ),
                  ),
                  Text(
                    fontSize.toStringAsFixed(0),
                    style: const TextStyle(fontSize: 14),
                  ),
                  const SizedBox(width: 10),

                  // 읽기 / 정지
                  ElevatedButton(
                    onPressed: _toggleChapterReading,
                    style: ElevatedButton.styleFrom(
                      shape: const CircleBorder(),
                      padding: EdgeInsets.zero,
                      backgroundColor: _isReading ? Colors.red : Colors.green,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(36, 36),
                    ),
                    child:
                        _isReading
                            ? const Icon(Icons.stop, size: 20)
                            : _isTtsBusy
                            ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                            : const Icon(Icons.volume_up, size: 20),
                  ),
                  const SizedBox(width: 10),

                  // 이전 장
                  ElevatedButton(
                    onPressed: isLoading ? null : () => changeChapter(-1),
                    style: ElevatedButton.styleFrom(
                      shape: const CircleBorder(),
                      padding: EdgeInsets.zero,
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(36, 36),
                    ),
                    child: const Icon(Icons.arrow_back_ios, size: 20),
                  ),
                  const SizedBox(width: 10),

                  // 다음 장
                  ElevatedButton(
                    onPressed: isLoading ? null : () => changeChapter(1),
                    style: ElevatedButton.styleFrom(
                      shape: const CircleBorder(),
                      padding: EdgeInsets.zero,
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(36, 36),
                    ),
                    child: const Icon(Icons.arrow_forward_ios, size: 20),
                  ),
                ],
              ),
            ),

            // ── 책 / 장 드롭다운 ──────────────────────────────────────────
            Center(
              child: SizedBox(
                width: MediaQuery.of(context).size.width * 0.95,
                child: Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: DropdownButtonFormField<String>(
                        key: ValueKey(_isOT),
                        initialValue: selectedBook,
                        items:
                            (_isOT ? _otBooks : _ntBooks)
                                .map(
                                  (book) => DropdownMenuItem(
                                    value: book,
                                    child: Text(book),
                                  ),
                                )
                                .toList(),
                        onChanged: onBookChanged,
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: const Color.fromARGB(255, 194, 195, 250),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 1,
                      child: DropdownButtonFormField<int>(
                        initialValue: selectedChapter,
                        items:
                            (chapterCount[selectedBook] ?? [1])
                                .map(
                                  (ch) => DropdownMenuItem(
                                    value: ch,
                                    child: Text('$ch장'),
                                  ),
                                )
                                .toList(),
                        onChanged: onChapterChanged,
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: const Color.fromARGB(255, 193, 255, 193),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 6),

            // ── 성경 본문 ──────────────────────────────────────────────────
            Expanded(
              child:
                  verses.isEmpty
                      ? Center(
                        child: Text(
                          '데이터 없음',
                          style: TextStyle(fontSize: fontSize),
                        ),
                      )
                      : ListView.builder(
                        key: ValueKey('$selectedBook-$selectedChapter'),
                        controller: _verseScrollCtrl,
                        itemCount: verses.length,
                        itemBuilder:
                            (context, idx) =>
                                _buildVerseRichText(verses[idx], idx),
                      ),
            ),
          ],
        ),
      ),

      // ── 하단 내비게이션 ───────────────────────────────────────────────────
      bottomNavigationBar: BottomNavigationBar(
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: '홈'),
          BottomNavigationBarItem(icon: Icon(Icons.menu_book), label: '스트롱성경'),
          BottomNavigationBarItem(icon: Icon(Icons.list_alt), label: '코드목록'),
          BottomNavigationBarItem(
            icon: Icon(Icons.info_outline),
            label: 'About',
          ),
        ],
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        selectedItemColor: const Color.fromARGB(255, 255, 53, 53),
        unselectedItemColor: Colors.grey,
        type: BottomNavigationBarType.fixed,
      ),
    );
  }
}

class _TestamentBtn extends StatelessWidget {
  final String label;
  final bool selected;
  final Color color;
  final VoidCallback onTap;

  const _TestamentBtn({
    required this.label,
    required this.selected,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? color : Colors.transparent,
          border: Border.all(color: selected ? color : Colors.grey.shade400),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : Colors.grey.shade600,
            fontWeight: FontWeight.bold,
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}
