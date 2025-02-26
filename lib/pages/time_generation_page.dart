import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_application_chrono_metrics/commons/common_util.dart';
import 'package:flutter_application_chrono_metrics/commons/enum_defines.dart';
import 'package:flutter_application_chrono_metrics/datas/data_time_generation/testdata_time_generation.dart';
import 'package:flutter_application_chrono_metrics/datas/data_time_generation/testresult_time_generation.dart';
import 'package:flutter_application_chrono_metrics/datas/user_infomation.dart';
import 'package:flutter_application_chrono_metrics/pages/page_layout_base.dart';
import 'dart:async';
import 'dart:math';

import 'package:flutter_application_chrono_metrics/providers/user_state_provider.dart';
import 'package:intl/intl.dart';
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

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _userNumberController = TextEditingController();

  int targetSeconds = 0;
  int? elapsedMilliseconds;
  final List<int> taskTimeList = [3, 5, 7, 9, 12];
  int taskCount = 1;
  final maxTaskCount = 5;

  int currentRound = 1;
  final int maxRounds = 4;

  TestResultTimeGeneration testResultTimeGeneration = TestResultTimeGeneration(userInfo: UserInfomation(userNumber: '', name: ''));
  TestResultTimeGeneration practiceResultTimeGeneration = TestResultTimeGeneration(userInfo: UserInfomation(userNumber: '', name: ''));

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      CommonUtil.showUserInfoDialog(
        context: context,
        nameController: _nameController,
        userNumberController: _userNumberController,
      );
      FocusScope.of(context).requestFocus(focusNode);

      final userInfo = Provider.of<UserStateProvider>(context, listen: false).getUserInfo;
      practiceResultTimeGeneration = Provider.of<UserStateProvider>(context, listen: false).loadTestResultTimeGeneration(
        '${Directory.current.path}/Data/TimeGeneration/${userInfo?.userNumber}_${userInfo?.name}/practice_result.csv',
        userInfo!,
        true,
      );
    });

    taskTimeList.shuffle();
    testResultList = Provider.of<UserStateProvider>(context, listen: false).loadTestResultList(AppTestType.timegeneration, Provider.of<UserStateProvider>(context, listen: false).getUserInfo);
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
      if (currentRound >= maxRounds && taskCount >= maxTaskCount) {
        currentRound = 1;
        taskCount = 1;
        elapsedMilliseconds = null;
        final userInfo = Provider.of<UserStateProvider>(context, listen: false).getUserInfo;
        testResultTimeGeneration = TestResultTimeGeneration(userInfo: userInfo!);
        return;
      }

      isStarted = true;
      isShowingTarget = true;
      if (isPracticeMode) {
        targetSeconds = random.nextInt(5) + 1; // 1~5초 랜덤
      } else {
        if (taskCount >= maxTaskCount) {
          taskTimeList.shuffle();
          taskCount = 1;
          currentRound++;
        } else {
          if (elapsedMilliseconds != null) {
            taskCount++;
          }
        }
        targetSeconds = taskTimeList[taskCount - 1];
      }
    });

    // 2초 후에 + 표시로 변경
    Future.delayed(const Duration(seconds: 1), () {
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
        practiceResultTimeGeneration.addTestData(TestDataTimeGeneration(
          targetTime: targetSeconds * 1000,
          elapsedTime: elapsedMilliseconds ?? 0,
          testTime: endTime,
        ));
        final userInfo = Provider.of<UserStateProvider>(context, listen: false).getUserInfo;
        Provider.of<UserStateProvider>(context, listen: false).saveTestResultTimeGeneration(
          studentId: userInfo?.userNumber ?? '',
          name: userInfo?.name ?? '',
          testResultTimeGeneration: practiceResultTimeGeneration,
          isPracticeMode: true,
        );
      } else {
        testResultTimeGeneration.addTestData(TestDataTimeGeneration(
          targetTime: targetSeconds * 1000,
          elapsedTime: elapsedMilliseconds ?? 0,
        ));

        if (taskCount == maxTaskCount && currentRound == maxRounds) {
          testResultTimeGeneration.setTestTime(DateTime.now());
          testResultTimeGeneration.setTaskCount(maxTaskCount);

          final userInfo = Provider.of<UserStateProvider>(context, listen: false).getUserInfo;
          Provider.of<UserStateProvider>(context, listen: false).saveTestResultTimeGeneration(
            studentId: userInfo?.userNumber ?? '',
            name: userInfo?.name ?? '',
            testResultTimeGeneration: testResultTimeGeneration,
            isPracticeMode: false,
          );

          testResultList = Provider.of<UserStateProvider>(context, listen: false).loadTestResultList(AppTestType.timegeneration, Provider.of<UserStateProvider>(context, listen: false).getUserInfo);
        }
      }
    }
    setState(() {
      isStarted = false;
      isMeasuring = false;

      startTime = null;
    });
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
    return KeyboardListener(
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
      child: PageLayoutBase(
        recordDrawer: getRecordDrawer(),
        headerWidget: Row(
          children: [
            SizedBox(
              width: MediaQuery.of(context).size.width * 0.05,
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
              width: MediaQuery.of(context).size.width * 0.01,
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
        bodyWidget: Container(
          height: MediaQuery.of(context).size.height * 0.6,
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
                      if (!isStarted && taskCount == maxTaskCount) ...[
                        Text(
                          '$currentRound 라운드 종료',
                          style: getDisplayStyle(),
                        ),
                      ],
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
                            size: MediaQuery.of(context).size.height * 0.4,
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
        footerWidget: Visibility(
          visible: isPracticeMode == false,
          child: Center(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '$taskCount/$maxTaskCount 과제',
                  style: TextStyle(
                    color: isPracticeMode ? Colors.blue : Colors.purple,
                    fontSize: MediaQuery.of(context).size.height * 0.03,
                  ),
                ),
                SizedBox(width: MediaQuery.of(context).size.width * 0.05),
                Text(
                  '$currentRound/$maxRounds 라운드',
                  style: TextStyle(
                    color: isPracticeMode ? Colors.blue : Colors.purple,
                    fontSize: MediaQuery.of(context).size.height * 0.03,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  RecordDrawer getRecordDrawer() {
    final userInfo = Provider.of<UserStateProvider>(context).getUserInfo;
    String path = '${Directory.current.path}/Data/TimeGeneration/${userInfo?.userNumber}_${userInfo?.name}';
    return RecordDrawer(
      path: path,
      record: Scrollbar(
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

              child: isPracticeMode ? practiceResult() : testResult(),
            ),
          ),
        ),
      ),
      title: isPracticeMode ? '연습 결과' : '본실험 결과',
    );
  }

  final ScrollController _scrollController = ScrollController();
  Widget practiceResult() {
    return Container(
      width: MediaQuery.of(context).size.width * 0.9,
      padding: const EdgeInsets.only(left: 16, right: 16),
      child: Column(
        children: practiceResultTimeGeneration.testDataList.map((result) {
          return SizedBox(
            height: 30,
            child: Row(
              children: [
                SizedBox(
                    width: MediaQuery.of(context).size.width * 0.15,
                    child: Text(
                      result.testTime.toString(),
                    )),
                SizedBox(
                  width: MediaQuery.of(context).size.width * 0.05,
                  child: const Text('생성시간 : '),
                ),
                SizedBox(
                    width: MediaQuery.of(context).size.width * 0.1,
                    child: Text(
                      '${result.targetTime}ms',
                    )),
                SizedBox(
                  width: MediaQuery.of(context).size.width * 0.1,
                  child: const Text('사용자추정시간 : '),
                ),
                SizedBox(
                    width: MediaQuery.of(context).size.width * 0.1,
                    child: Text(
                      '${result.elapsedTime}ms',
                    )),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  List<String> testResultList = [];
  Widget testResult() {
    final userInfo = Provider.of<UserStateProvider>(context).getUserInfo;
    String path = '${Directory.current.path}/Data/TimeGeneration/${userInfo?.userNumber}_${userInfo?.name}';
    return Container(
      width: MediaQuery.of(context).size.width * 0.9,
      padding: const EdgeInsets.only(left: 16, right: 16),
      child: Column(
        children: testResultList.map((result) {
          final resultSplit = result.split('_');

          final String dateStr = resultSplit[1];
          final DateTime resultTime = DateTime.parse('${dateStr.substring(0, 4)}-' // year
              '${dateStr.substring(4, 6)}-' // month
              '${dateStr.substring(6, 8)} ' // day
              '${dateStr.substring(8, 10)}:' // hour
              '${dateStr.substring(10, 12)}:' // minute
              '${dateStr.substring(12, 14)}' // second
              );

          final String formattedDate = DateFormat('yyyy-MM-dd HH:mm:ss').format(resultTime);
          return ExpansionTile(
            title: Text(formattedDate),
            children: [
              SizedBox(
                width: MediaQuery.of(context).size.width * 0.9,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: (() {
                      final testResult = Provider.of<UserStateProvider>(context, listen: false).loadTestResultTimeGeneration(
                        '$path/$result',
                        userInfo!,
                        false,
                      );

                      var list = [
                        resultItem(testResult),
                      ];
                      return list;
                    })(),
                  ),
                ),
              ),
            ],
          );
        }).toList(),
      ),
    );
  }

  Widget resultItem(TestResultTimeGeneration testResult) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ...testResult.testDataList.asMap().entries.map(
          (entry) {
            final index = entry.key;
            final data = entry.value;

            // 현재 항목의 Row 위젯
            final rowWidget = Row(
              children: [
                SizedBox(
                  width: MediaQuery.of(context).size.width * 0.08,
                  child: Text('${(index ~/ testResult.taskCount + 1).toStringAsFixed(0)} - ${((index % testResult.taskCount).toInt() + 1).toStringAsFixed(0)}'),
                ),
                SizedBox(
                  width: MediaQuery.of(context).size.width * 0.08,
                  child: const Text('생성시간 : '),
                ),
                SizedBox(
                  width: MediaQuery.of(context).size.width * 0.1,
                  child: Text('${data.targetTime}ms'),
                ),
                SizedBox(
                  width: MediaQuery.of(context).size.width * 0.1,
                  child: const Text('사용자추정시간 : '),
                ),
                SizedBox(
                  width: MediaQuery.of(context).size.width * 0.1,
                  child: Text('${data.elapsedTime}ms'),
                ),
              ],
            );

            // 세트의 마지막 항목인 경우 (나머지가 taskCount-1인 경우)
            // 또는 전체 리스트의 마지막 항목인 경우
            if ((index % testResult.taskCount) == testResult.taskCount - 1 && index < testResult.testDataList.length - 1) {
              return Column(
                children: [
                  rowWidget,
                  const Divider(),
                ],
              );
            } else {
              return rowWidget;
            }
          },
        ),
      ],
    );
  }
}
