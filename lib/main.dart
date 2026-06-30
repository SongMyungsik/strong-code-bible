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
      title: '스트롱코드성경',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(primarySwatch: Colors.purple),
      home: const StartPage(),
    );
  }
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// 스트롱 코드 파서
//   실제 데이터 형식: "태초에 H7225 하나님이 H430 ..."
//   → 공백으로 구분된 H+숫자 패턴을 코드로 인식 (H0 포함)
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

final _strongCodeRegex = RegExp(r'\b[HG]\d+[a-zA-Z]?\b', caseSensitive: false);

/// 절 텍스트를 일반 텍스트 / 스트롱 코드 조각으로 분리
List<({bool isCode, String text})> parseVerseText(String verse) {
  final result = <({bool isCode, String text})>[];
  int cursor = 0;

  for (final match in _strongCodeRegex.allMatches(verse)) {
    // 코드 앞 일반 텍스트
    if (match.start > cursor) {
      result.add((isCode: false, text: verse.substring(cursor, match.start)));
    }
    // 스트롱 코드 (예: H7225, G1061a)
    //   접미사(a/b 등)는 원래 표기(소문자)를 그대로 유지하고,
    //   H/G 접두 문자만 대문자로 통일한다.
    final raw = match.group(0)!;
    final normalized =
        raw.isEmpty ? raw : raw[0].toUpperCase() + raw.substring(1);
    result.add((isCode: true, text: normalized));
    cursor = match.end;
  }

  if (cursor < verse.length) {
    result.add((isCode: false, text: verse.substring(cursor)));
  }

  return result;
}

/// 절 텍스트를 (단어, 연결된 스트롱코드) 단위로 재구성
///   - 코드 자체는 화면에 표시하지 않고, 코드 바로 앞 단어와 짝지어서
///     그 단어를 탭 가능(밑줄)하게 만드는 데만 사용한다.
///   - 예: "태초에 H7225 하나님이" → [("태초에", "H7225"), (" 하나님이", null)]
List<({String text, String? code})> _groupWordsWithCodes(String verse) {
  final parts = parseVerseText(verse);
  final result = <({String text, String? code})>[];

  String pendingText = '';
  for (final part in parts) {
    if (!part.isCode) {
      pendingText += part.text;
      continue;
    }

    // 코드를 만나면, 직전에 쌓인 일반 텍스트의 "마지막 단어"만 코드와 연결하고
    // 그 앞부분(공백 포함)은 분리해서 그대로 일반 텍스트로 둔다.
    final trimmedRight = pendingText.replaceFirst(RegExp(r'\s+$'), '');
    final trailingSpace = pendingText.substring(trimmedRight.length);
    final wordMatch = RegExp(r'(\S+)$').firstMatch(trimmedRight);

    if (wordMatch != null) {
      final before = trimmedRight.substring(0, wordMatch.start);
      if (before.isNotEmpty) result.add((text: before, code: null));
      result.add((text: wordMatch.group(0)!, code: part.text));
    } else if (trimmedRight.isNotEmpty) {
      result.add((text: trimmedRight, code: null));
    }
    if (trailingSpace.isNotEmpty) result.add((text: trailingSpace, code: null));

    pendingText = '';
  }

  if (pendingText.isNotEmpty) {
    result.add((text: pendingText, code: null));
  }

  return result;
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

  String selectedBook = bookList.first;
  int selectedChapter = 1;
  List<dynamic> allVerses = [];
  List<String> verses = [];
  double fontSize = 18.0;
  bool isLoading = false;

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

      // 스트롱 코드 제거 후 읽기
      final plain = verses[i]
          .replaceFirst(RegExp(r'^\d+\.\s?'), '')
          .replaceAll(_strongCodeRegex, '');

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
    try {
      final data = await rootBundle.loadString('assets/strongbible.json');
      final decoded = json.decode(data) as List;
      if (mounted) {
        setState(() {
          allVerses = decoded;
          loadVerses();
        });
      }
    } catch (e) {
      /* 로드 실패 */
    }
  }

  void loadVerses() {
    if (mounted) {
      setState(() {
        verses =
            allVerses
                .where(
                  (v) =>
                      v['book'] == selectedBook &&
                      v['chapter'].toString() == selectedChapter.toString(),
                )
                .map<String>(
                  (v) => '${v['paragraph']}. ${v['strongbible'] ?? '[본문 없음]'}',
                )
                .toList();
      });
    }
  }

  void onBookChanged(String? value) {
    if (value != null) {
      _stopAll();
      setState(() {
        selectedBook = value;
        selectedChapter = 1;
      });
      loadVerses();
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

  Widget _buildVerseRichText(String verseText, int idx) {
    final isHighlighted = _readingVerseIndex == idx;
    final grouped = _groupWordsWithCodes(verseText);
    final spans = <InlineSpan>[];

    for (final part in grouped) {
      if (part.code == null) {
        // ── 일반 텍스트 (코드 없음) ──
        spans.add(
          TextSpan(
            text: part.text,
            style: TextStyle(
              fontSize: fontSize,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
              backgroundColor: isHighlighted ? Colors.yellow[200] : null,
            ),
          ),
        );
      } else {
        // ── 스트롱 코드가 연결된 단어 → 밑줄 + 탭하면 StrongCodePage로 이동 ──
        final code = part.code!;
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
                part.text,
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
          '[스트롱코드성경]',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black),
        ),
        centerTitle: false,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: Image.asset(
              'assets/images/church_logo.png',
              width: 110,
              height: 32,
            ),
          ),
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
                        initialValue: selectedBook,
                        items:
                            bookList
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
          BottomNavigationBarItem(icon: Icon(Icons.info_outline), label: 'About'),
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
