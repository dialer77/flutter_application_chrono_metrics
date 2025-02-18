import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'dart:math';

class TimeGenerationPage extends StatefulWidget {
  const TimeGenerationPage({super.key});

  @override
  State<TimeGenerationPage> createState() => _TimeGenerationPageState();
}

class _TimeGenerationPageState extends State<TimeGenerationPage> {
  FocusNode focusNode = FocusNode();
  bool isPracticeMode = true;
  bool isStarted = false;
  DateTime? startTime;
  int? targetSeconds;
  int? elapsedMilliseconds;
  final Random random = Random();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      FocusScope.of(context).requestFocus(focusNode);
    });
  }

  @override
  void dispose() {
    focusNode.dispose();
    super.dispose();
  }

  void toggleMode() {
    if (!isStarted) {
      setState(() {
        isPracticeMode = !isPracticeMode;
        elapsedMilliseconds = null;
      });
    }
  }

  void startTest() {
    setState(() {
      isStarted = true;
      startTime = DateTime.now();
      elapsedMilliseconds = null;
      if (isPracticeMode) {
        targetSeconds = random.nextInt(5) + 1; // 1~5초 랜덤
      }
    });
  }

  void endTest() {
    if (isStarted) {
      final endTime = DateTime.now();
      setState(() {
        isStarted = false;
        elapsedMilliseconds = endTime.difference(startTime!).inMilliseconds;
        startTime = null;
      });
    }
  }

  void onSpacePressed() {
    if (isStarted) {
      endTest();
    } else {
      startTest();
    }
  }

  String getDisplayText() {
    if (!isStarted && elapsedMilliseconds != null) {
      return '경과 시간: ${elapsedMilliseconds}ms\n목표 시간: ${targetSeconds! * 1000}ms';
    } else if (isStarted) {
      return isPracticeMode ? '$targetSeconds초' : '+';
    } else {
      return isPracticeMode ? '연습 모드' : '본실험 모드';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          '시간 생성 과제',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: KeyboardListener(
        focusNode: focusNode,
        onKeyEvent: (KeyEvent event) {
          if (event is KeyDownEvent) {
            if (event.logicalKey == LogicalKeyboardKey.keyM) {
              toggleMode();
            } else if (event.logicalKey == LogicalKeyboardKey.space) {
              onSpacePressed(); // 스페이스바 이벤트 처리를 별도 메서드로 분리
            }
          }
        },
        child: LayoutBuilder(
          builder: (context, constraints) {
            return Padding(
              padding: EdgeInsets.only(
                left: constraints.maxWidth * 0.05,
                right: constraints.maxWidth * 0.05,
                bottom: constraints.maxHeight * 0.05,
              ),
              child: Column(
                children: [
                  SizedBox(
                    height: constraints.maxHeight * 0.1,
                    child: Row(
                      children: [
                        IconButton(
                          onPressed: isStarted ? null : toggleMode,
                          icon: Icon(
                            isPracticeMode ? Icons.school : Icons.science,
                            size: 50,
                            color: isPracticeMode ? Colors.blue : Colors.purple,
                          ),
                          tooltip: '${isPracticeMode ? "본실험" : "연습"} 모드로 전환 (M키)',
                        ),
                        SizedBox(
                          width: constraints.maxWidth * 0.01,
                        ),
                        Text(
                          isPracticeMode ? '연습 모드' : '본실험 모드',
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          height: constraints.maxHeight * 0.6,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: isPracticeMode ? Colors.blue : Colors.purple,
                              width: 2,
                            ),
                          ),
                          child: Center(
                            child: isStarted || elapsedMilliseconds != null
                                ? Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(
                                        getDisplayText(),
                                        style: const TextStyle(
                                          fontSize: 48,
                                          fontWeight: FontWeight.bold,
                                        ),
                                        textAlign: TextAlign.center,
                                      ),
                                      if (elapsedMilliseconds != null) ...[
                                        const SizedBox(height: 20),
                                        const Text(
                                          '스페이스바를 눌러 다시 시작',
                                          style: TextStyle(
                                            fontSize: 16,
                                            color: Colors.grey,
                                          ),
                                        ),
                                      ],
                                    ],
                                  )
                                : Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        isPracticeMode ? Icons.school : Icons.science,
                                        size: 50,
                                        color: isPracticeMode ? Colors.blue : Colors.purple,
                                      ),
                                      const SizedBox(height: 20),
                                      Text(
                                        isPracticeMode ? '연습 모드' : '본실험 모드',
                                        style: TextStyle(
                                          color: isPracticeMode ? Colors.blue : Colors.purple,
                                          fontSize: 24,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const SizedBox(height: 10),
                                      Text(
                                        '시작하려면 스페이스를 눌러주세요',
                                        style: TextStyle(
                                          color: isPracticeMode ? Colors.blue : Colors.purple,
                                          fontSize: 16,
                                        ),
                                        textAlign: TextAlign.center,
                                      ),
                                    ],
                                  ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(
                    height: constraints.maxHeight * 0.05,
                  ),
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isPracticeMode ? Colors.blue : Colors.purple,
                          width: 2,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
