import 'package:flutter/material.dart';

class AboutPage extends StatelessWidget {
  const AboutPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'About',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color.fromARGB(255, 255, 53, 53),
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: const [
          _SectionCard(
            number: '1',
            title: '스트롱코드 성경이란?',
            content:
                '스트롱코드 성경은 성경의 각 단어에 스트롱 번호(Strong\'s Number)를 연결하여, '
                '원어(히브리어·헬라어) 의미를 쉽게 찾아볼 수 있도록 만든 성경입니다.\n\n'
                '단어를 탭하면 해당 원어의 뜻, 발음, 어원 등 상세 정보를 바로 확인할 수 있습니다.',
          ),
          SizedBox(height: 16),
          _SectionCard(
            number: '2',
            title: '성경 본문',
            content:
                '본 앱은 구약성경(히브리어)과 신약성경(헬라어)의 전체 본문을 수록하고 있습니다.\n\n'
                '• 구약: 히브리어 원어 스트롱코드 (H 코드)\n'
                '• 신약: 헬라어 원어 스트롱코드 (G 코드)',
          ),
          SizedBox(height: 16),
          _SectionCard(
            number: '3',
            title: '스트롱코드란?',
            content:
                '스트롱코드(Strong\'s Concordance Number)는 19세기 성경학자 제임스 스트롱(James Strong)이 '
                '성경에 등장하는 모든 히브리어·헬라어 단어에 고유 번호를 부여한 분류 체계입니다.\n\n'
                '• 히브리어(구약): H1 ~ H8674\n'
                '• 헬라어(신약): G1 ~ G5624\n\n'
                '이 번호를 통해 같은 원어에서 파생된 단어들을 성경 전체에서 추적할 수 있습니다.\n\n'
                '하단의 이동버튼 (±10/±100/±1000)으로 빠르게 원하는 번호대로 이동할 수 있습니다.',
          ),
          SizedBox(height: 16),
          _SectionCard(
            number: '4',
            title: '데이터 출처',
            content:
                '본 앱의 스트롱코드 사전 데이터는 베들레헴 성경(HebGrkKo.dct)의 자료를 기반으로 작성되었습니다.',
          ),
          SizedBox(height: 16),
          _SectionCard(
            number: '5',
            title: '개발 정보',
            content: '',
            child: _DevInfoTable(),
          ),
          SizedBox(height: 32),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String number;
  final String title;
  final String content;
  final Widget? child;

  const _SectionCard({
    required this.number,
    required this.title,
    required this.content,
    this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: const BoxDecoration(
                    color: Color.fromARGB(255, 255, 53, 53),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      number,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF333333),
                  ),
                ),
              ],
            ),
            if (content.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                content,
                style: const TextStyle(
                  fontSize: 14,
                  height: 1.6,
                  color: Color(0xFF555555),
                ),
              ),
            ],
            if (child != null) ...[const SizedBox(height: 12), child!],
          ],
        ),
      ),
    );
  }
}

class _DevInfoTable extends StatelessWidget {
  const _DevInfoTable();

  @override
  Widget build(BuildContext context) {
    const rows = [
      ('프로그래밍 언어', 'Flutter (Dart)'),
      ('데이터베이스', 'SQLite (sqflite)'),
      ('지원 플랫폼', 'Android, Windows'),
    ];

    return Table(
      columnWidths: const {0: IntrinsicColumnWidth(), 1: FlexColumnWidth()},
      children:
          rows.map((row) {
            return TableRow(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 5),
                  child: Text(
                    row.$1,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF444444),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    vertical: 5,
                    horizontal: 12,
                  ),
                  child: Text(
                    row.$2,
                    style: const TextStyle(
                      fontSize: 14,
                      color: Color(0xFF555555),
                    ),
                  ),
                ),
              ],
            );
          }).toList(),
    );
  }
}
