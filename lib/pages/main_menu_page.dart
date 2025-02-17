import 'package:flutter/material.dart';
import 'reaction_test_page.dart';

class MainMenuPage extends StatefulWidget {
  const MainMenuPage({super.key, required this.title});

  final String title;

  @override
  State<MainMenuPage> createState() => _MainMenuPageState();
}

class _MainMenuPageState extends State<MainMenuPage> {
  final List<(String, Widget?)> menuItems = [
    ('동작 반응성 속도 측정', const ReactionTestPage()),
    ('시간 생성', null),
    ('시간 추정 - 시각 자극', null),
    ('시간 추정 - 청각 자극', null),
    ('반응 기록', null),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: LayoutBuilder(
        builder: (context, constraints) {
          return Container(
            padding: EdgeInsets.only(
              top: constraints.maxHeight * 0.12,
              bottom: constraints.maxHeight * 0.2,
              left: constraints.maxWidth * 0.1,
              right: constraints.maxWidth * 0.1,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: menuItems
                  .map((item) => _buildButton(
                        item.$1,
                        constraints.maxHeight * 0.1,
                        constraints.maxWidth * 0.6,
                        item.$2,
                      ))
                  .toList(),
            ),
          );
        },
      ),
    );
  }

  Widget _buildButton(String text, double height, double width, Widget? page) {
    return ElevatedButton(
      onPressed: page != null
          ? () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => page),
              );
            }
          : null,
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: BorderSide(color: page != null ? Colors.blue : Colors.grey),
        ),
        fixedSize: Size(width, height),
        alignment: Alignment.centerLeft,
        padding: EdgeInsets.only(left: width * 0.05),
      ),
      child: Text(
        text,
        style: TextStyle(color: page != null ? Colors.blue : Colors.grey, fontSize: height * 0.3),
      ),
    );
  }
}
