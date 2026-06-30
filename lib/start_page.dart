import 'package:flutter/material.dart';
import 'main.dart';

class StartPage extends StatelessWidget {
  const StartPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('스트롱코드성경')),
      body: Center(
        // Center 위젯의 자식으로 Column을 추가하여 위젯들을 세로로 배치합니다.
        child: Column(
          // Column의 자식들을 수직 중앙에 정렬합니다.
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            // 'The Bible' 텍스트를 추가하고 스타일을 적용합니다.
            Image.asset(
              'assets/images/top_image.png', // 이미지 경로
              width: 306, // 너비 조절
              height: 350, // 높이 조절
            ),

            // 텍스트와 버튼 사이에 간격을 줍니다.
            const SizedBox(height: 20),
            // 기존의 '시작하기' 버튼입니다.
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color.fromARGB(
                  255,
                  255,
                  0,
                  0,
                ), // 원하는 색상2
                foregroundColor: const Color.fromARGB(
                  255,
                  255,
                  255,
                  255,
                ), // 텍스트 색상2
              ),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const BibleHomePage(),
                  ),
                );
              },
              child: const Text('시작하기'),
            ),
            const SizedBox(height: 40),
            Image.asset(
              'assets/images/top_image3.png', // 이미지 경로
              width: 180, // 너비 조절
              height: 47, // 높이 조절
            ),
          ],
        ),
      ),
    );
  }
}
