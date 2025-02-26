import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_application_chrono_metrics/datas/data_time_generation/testdata_time_generation.dart';
import 'package:flutter_application_chrono_metrics/datas/data_time_generation/testresult_time_generation.dart';
import 'dart:async';
import 'dart:math';

import 'package:flutter_application_chrono_metrics/providers/user_state_provider.dart';
import 'package:provider/provider.dart';
import 'package:flutter_application_chrono_metrics/commons/widgets/record_drawer.dart';

class TimeGenerationPage extends StatefulWidget {
  const TimeGenerationPage({super.key});

  @override
  State<TimeGenerationPage> createState() => _TimeGenerationPageState();
}

class _TimeGenerationPageState extends State<TimeGenerationPage> {
  final Random random = Random();
  FocusNode focusNode = FocusNode();

  bool isPracticeMode = true;

  bool isStarted = false;
  bool isShowingTarget = false; // 목표 시간 표시 상태
  bool isMeasuring = false; // 시간 측정 중 상태
  DateTime? startTime;

  int targetSeconds = 0;
  int? elapsedMilliseconds;
  final List<int> taskTimeList = [3, 5, 7, 9, 12];
  int taskCount = 0;
  final maxTaskCount = 5;

  int currentRound = 0;
  final int maxRounds = 4;

  late TestResultTimeGeneration testResultTimeGeneration;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      FocusScope.of(context).requestFocus(focusNode);

      final userInfo = Provider.of<UserStateProvider>(context, listen: false).getUserInfo;
      testResultTimeGeneration = Provider.of<UserStateProvider>(context, listen: false).loadTestResultTimeGeneration(
        '${Directory.current.path}/Data/TimeGeneration/${userInfo?.userNumber}_${userInfo?.name}/practice_result.csv',
        userInfo!,
        true,
      );
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
      isShowingTarget = true;
      if (isPracticeMode) {
        targetSeconds = random.nextInt(5) + 1; // 1~5초 랜덤
      } else {
        if (taskCount >= maxTaskCount) {
          taskCount = 0;
        }
        targetSeconds = taskTimeList[taskCount];
      }
    });

    // 2초 후에 + 표시로 변경
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted && isStarted) {
        setState(() {
          isShowingTarget = false;
        });
      }
    });
  }

  void startMeasuring() {
    setState(() {
      isMeasuring = true;
      startTime = DateTime.now();
    });
  }

  void endTest() {
    if (isMeasuring) {
      final endTime = DateTime.now();
      elapsedMilliseconds = endTime.difference(startTime!).inMilliseconds;
      if (isPracticeMode) {
        testResultTimeGeneration.addTestData(TestDataTimeGeneration(
          targetTime: targetSeconds * 1000,
          elapsedTime: elapsedMilliseconds ?? 0,
          testTime: endTime,
        ));

        final userInfo = Provider.of<UserStateProvider>(context, listen: false).getUserInfo;
        Provider.of<UserStateProvider>(context, listen: false).saveTestResultTimeGeneration(
          studentId: userInfo?.userNumber ?? '',
          name: userInfo?.name ?? '',
          testResultTimeGeneration: testResultTimeGeneration,
          isPracticeMode: true,
        );
      }
      setState(() {
        isStarted = false;
        isMeasuring = false;

        startTime = null;
        if (isPracticeMode == false) {
          taskCount++;
          if (taskCount >= maxTaskCount) {
            currentRound++;
          }
        }
      });
    }
  }

  void onSpacePressed() {
    if (!isStarted) {
      startTest();
    } else if (!isShowingTarget && !isMeasuring) {
      startMeasuring();
    } else if (isMeasuring) {
      endTest();
    }
  }

  String getDisplayText() {
    if (!isStarted) {
      return '경과 시간: ${elapsedMilliseconds}ms\n목표 시간: ${targetSeconds * 1000}ms';
    } else if (isStarted) {
      if (isShowingTarget) {
        return '$targetSeconds초';
      } else {
        return isMeasuring ? '●' : '+'; // 측정 중일 때는 검정 원, 아니면 +
      }
    } else {
      return isPracticeMode ? '연습 모드' : '본실험 모드';
    }
  }

  TextStyle getDisplayStyle() {
    if (isStarted && !isShowingTarget && isMeasuring) {
      return const TextStyle(
        fontSize: 48,
        fontWeight: FontWeight.bold,
        color: Colors.black, // 검정 원일 때는 검정색
      );
    }
    return const TextStyle(
      fontSize: 48,
      fontWeight: FontWeight.bold,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      endDrawer: getRecordDrawer(),
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
        child: Stack(
          children: [
            LayoutBuilder(
              builder: (context, constraints) {
                return Padding(
                  padding: EdgeInsets.only(
                    right: constraints.maxWidth * 0.05,
                    bottom: constraints.maxHeight * 0.1,
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(
                        height: constraints.maxHeight * 0.1,
                        child: Row(
                          children: [
                            SizedBox(
                              width: constraints.maxWidth * 0.05,
                              child: IconButton(
                                icon: const Icon(Icons.arrow_back),
                                onPressed: () => Navigator.of(context).pop(),
                              ),
                            ),
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
                              '시간 생성 과제 - ${isPracticeMode ? '연습' : '본실험'}',
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: Padding(
                          padding: EdgeInsets.only(
                            left: constraints.maxWidth * 0.05,
                          ),
                          child: Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Expanded(
                                  child: Container(
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
                                                (() {
                                                  if (isShowingTarget || !isStarted) {
                                                    return Text(
                                                      getDisplayText(),
                                                      style: getDisplayStyle(), // 스타일 적용
                                                      textAlign: TextAlign.center,
                                                    );
                                                  } else {
                                                    return Icon(
                                                      isMeasuring ? Icons.circle : Icons.add,
                                                      size: constraints.maxHeight * 0.4,
                                                      color: Colors.black,
                                                    );
                                                  }
                                                }()),
                                                if (isStarted == false) ...[
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
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      SizedBox(
                        height: constraints.maxHeight * 0.05,
                        child: Visibility(
                          visible: isPracticeMode == false,
                          child: Center(
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  '${taskCount + 1}/$maxTaskCount 과제',
                                  style: TextStyle(
                                    color: isPracticeMode ? Colors.blue : Colors.purple,
                                    fontSize: constraints.maxHeight * 0.03,
                                  ),
                                ),
                                SizedBox(width: constraints.maxWidth * 0.05),
                                Text(
                                  '$currentRound/$maxRounds 라운드',
                                  style: TextStyle(
                                    color: isPracticeMode ? Colors.blue : Colors.purple,
                                    fontSize: constraints.maxHeight * 0.03,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
            Positioned(
              right: 0,
              top: MediaQuery.of(context).size.height / 2 - 30,
              child: Builder(
                builder: (BuildContext context) {
                  return Container(
                    height: 60,
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.inversePrimary,
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(15),
                        bottomLeft: Radius.circular(15),
                      ),
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.more_vert),
                      iconSize: 24,
                      padding: const EdgeInsets.symmetric(horizontal: 0),
                      constraints: const BoxConstraints(),
                      onPressed: () => Scaffold.of(context).openEndDrawer(),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  RecordDrawer getRecordDrawer() {
    final userInfo = Provider.of<UserStateProvider>(context).getUserInfo;
    String path = '${Directory.current.path}/Data/TimeGeneration/${userInfo?.userNumber}_${userInfo?.name}';
    return RecordDrawer(
      path: path,
      record: isPracticeMode ? practiceResult() : Container(),
      title: isPracticeMode ? '연습 결과' : '본실험 결과',
    );
  }

  final ScrollController _scrollController = ScrollController();
  Widget practiceResult() {
    return Scrollbar(
      thumbVisibility: true,
      controller: _scrollController, // 스크롤바에 컨트롤러 연결
      child: MouseRegion(
        cursor: SystemMouseCursors.grab,
        child: GestureDetector(
          onPanUpdate: (details) {
            // 스크롤 컨트롤러를 통해 스크롤 위치 업데이트
            _scrollController.jumpTo(
              (_scrollController.offset - details.delta.dy).clamp(
                0.0,
                _scrollController.position.maxScrollExtent,
              ),
            );
          },
          child: SingleChildScrollView(
            controller: _scrollController, // SingleChildScrollView에 컨트롤러 연결

            child: Column(
              children: testResultTimeGeneration.testDataList.map((result) {
                StringBuffer sb = StringBuffer();
                sb.writeln('${result.testTime} 생성시간 : ${result.targetTime}ms, 사용자추정시간 : ${result.elapsedTime}ms');

                return Text(sb.toString());
              }).toList(),
            ),
          ),
        ),
      ),
    );
  }
}
