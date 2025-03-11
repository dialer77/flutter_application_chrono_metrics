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
import 'package:flutter_application_chrono_metrics/commons/audio_recording_manager.dart';

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

  // 녹음 관련 변수 추가
  bool _isRecording = false;
  String? _currentRecordingPath;

  int targetSeconds = 0;
  int? elapsedMilliseconds;
  final List<int> taskTimeList = [3, 5, 7, 9, 12];
  int taskCount = 1;
  final maxTaskCount = 5;

  int currentRound = 1;
  final int maxRounds = 2;

  TestResultTimeGeneration testResultTimeGeneration = TestResultTimeGeneration(userInfo: UserInfomation(userNumber: '', name: ''));
  TestResultTimeGeneration practiceResultTimeGeneration = TestResultTimeGeneration(userInfo: UserInfomation(userNumber: '', name: ''));

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      // 오디오 녹음 매니저 초기화
      await AudioRecordingManager().initialize();

      await CommonUtil.showUserInfoDialog(
        context: context,
        nameController: _nameController,
        userNumberController: _userNumberController,
      );
      FocusScope.of(context).requestFocus(focusNode);

      final userInfo = Provider.of<UserStateProvider>(context, listen: false).getUserInfo;
      practiceResultTimeGeneration = Provider.of<UserStateProvider>(context, listen: false).loadTestResultTimeGeneration(
        '${Directory.current.path}\\Data\\TimeGeneration\\${userInfo?.userNumber}_${userInfo?.name}\\practice_result.csv',
        userInfo!,
        true,
      );
    });

    taskTimeList.shuffle();
    testResultList = Provider.of<UserStateProvider>(context, listen: false).loadTestResultList(AppTestType.timeGeneration, Provider.of<UserStateProvider>(context, listen: false).getUserInfo);
  }

  @override
  void dispose() {
    focusNode.dispose();
    super.dispose();
  }

  // 녹음 시작 메서드
  Future<void> _startRecording() async {
    if (_isRecording) return;

    final userInfo = Provider.of<UserStateProvider>(context, listen: false).getUserInfo;
    if (userInfo == null) return;

    final dateTime = DateTime.now();
    final dateStr = DateFormat('yyyyMMddHHmmss').format(dateTime);

    // 파일 경로 직접 생성
    final directory = Directory('${Directory.current.path}\\Data\\TimeGeneration\\${userInfo.userNumber}_${userInfo.name}\\recordings');
    if (!directory.existsSync()) {
      directory.createSync(recursive: true);
    }

    final filePath = '${directory.path}/TG_${userInfo.userNumber}_${userInfo.name}_$dateStr.m4a';

    // 생성된 파일 경로로 녹음 시작
    final success = await AudioRecordingManager().startRecording(filePath);

    if (success) {
      setState(() {
        _isRecording = true;
        _currentRecordingPath = filePath;
      });
    }
  }

  // 녹음 중지 메서드
  Future<void> _stopRecording() async {
    if (!_isRecording || _currentRecordingPath == null) return;

    // 현재 녹음 중인 파일 경로 저장
    final filePath = _currentRecordingPath!;

    // 파일 경로를 매개변수로 전달하여 녹음 중지
    final success = await AudioRecordingManager().stopRecording(filePath);

    if (success) {
      setState(() {
        _isRecording = false;
      });

      // 테스트 결과에 녹음 파일 경로 설정
      testResultTimeGeneration.setAudioFilePath(filePath);
      print('녹음 파일 저장됨: $filePath');
    }
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
    // 연습 모드가 아니고 첫 테스트 라운드의 첫 번째 과제일 때만 녹음 시작
    if (!isPracticeMode && currentRound == 1 && taskCount == 1 && elapsedMilliseconds == null) {
      _startRecording();
    }

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

    // 타겟 표시 후 측정 시작을 순차적으로 처리
    _handleTimingSequence();
  }

  // 타겟 표시 후 측정 시작을 순차적으로 처리
  Future<void> _handleTimingSequence() async {
    // 2초 후에 + 표시로 변경
    await Future.delayed(const Duration(milliseconds: 2000), () {
      if (mounted && isStarted) {
        setState(() {
          isShowingTarget = false;
        });
      }
    });

    // 추가 2초 딜레이
    await Future.delayed(const Duration(seconds: 2));

    // 첫 번째 딜레이와 추가 딜레이가 완료된 후에만 실행
    if (!isShowingTarget && !isMeasuring && mounted) {
      setState(() {
        isMeasuring = true;
        startTime = DateTime.now();
      });
    }
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
          // 테스트 완료 시 녹음 중지 및 녹음 파일 경로 저장
          if (_isRecording) {
            _stopRecording();
          }

          testResultTimeGeneration.setTestTime(DateTime.now());
          testResultTimeGeneration.setTaskCount(maxTaskCount);

          // 녹음 파일 경로 설정
          if (_currentRecordingPath != null) {
            testResultTimeGeneration.setAudioFilePath(_currentRecordingPath!);
          }

          final userInfo = Provider.of<UserStateProvider>(context, listen: false).getUserInfo;
          Provider.of<UserStateProvider>(context, listen: false).saveTestResultTimeGeneration(
            studentId: userInfo?.userNumber ?? '',
            name: userInfo?.name ?? '',
            testResultTimeGeneration: testResultTimeGeneration,
            isPracticeMode: false,
          );

          testResultList = Provider.of<UserStateProvider>(context, listen: false).loadTestResultList(AppTestType.timeGeneration, Provider.of<UserStateProvider>(context, listen: false).getUserInfo);
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
    } else if (isMeasuring) {
      endTest();
    }
  }

  TextStyle getDisplayStyle() {
    if (isStarted) {
      return const TextStyle(
        fontSize: 150,
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
    return Focus(
      onKeyEvent: (FocusNode node, KeyEvent event) {
        if (event is KeyDownEvent && event.logicalKey == LogicalKeyboardKey.tab) {
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: KeyboardListener(
        focusNode: focusNode,
        onKeyEvent: (KeyEvent event) {
          if (event is KeyDownEvent) {
            if (event.logicalKey == LogicalKeyboardKey.tab) {
              toggleMode();
            } else if (event.logicalKey == LogicalKeyboardKey.space) {
              onSpacePressed();
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
                tooltip: '${isPracticeMode ? "본실험" : "연습"} 모드로 전환 (Tab키)',
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
              const Spacer(),
              // 녹음 상태 표시
              if (_isRecording)
                const Row(
                  children: [
                    Icon(
                      Icons.mic,
                      color: Colors.red,
                      size: 20,
                    ),
                    SizedBox(width: 5),
                    Text(
                      "녹음 중",
                      style: TextStyle(color: Colors.red),
                    ),
                    SizedBox(width: 10),
                  ],
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
                            return getDisplayTestWidget();
                          } else {
                            if (isMeasuring) {
                              return Icon(
                                Icons.circle,
                                size: MediaQuery.of(context).size.height * 0.4,
                                color: Colors.black,
                              );
                            } else {
                              return Text(
                                '준비',
                                style: getDisplayStyle(),
                              );
                            }
                          }
                        }()),
                        if (isStarted == false) ...[
                          const SizedBox(height: 20),
                          Text(
                            isPracticeMode ? '추가적인 연습을 진행시에는 스페이스바를 눌러 다시 시작해주세요.' : '스페이스바를 눌러 다음 검사를 시작해주세요.',
                            style: TextStyle(
                              fontSize: isPracticeMode ? 20 : 48,
                              color: isPracticeMode ? Colors.grey : Colors.black,
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
                            fontSize: 48,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 10),
                        testGuideText(),
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
      ),
    );
  }

  Widget getDisplayTestWidget() {
    if (!isStarted) {
      // 화면을 두 부분으로 나누어 표시
      String upperText = '경과 시간: ${elapsedMilliseconds}ms\n'
          '목표 시간: ${targetSeconds * 1000}ms';

      String lowerText = '충분히 연습하셨으면 본 검사를 진행하겠습니다.\n'
          'Tab 키를 눌러 본 검사모드로 전환해주세요';

      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (isPracticeMode) ...[
            Text(
              upperText,
              style: getDisplayStyle(), // 기존 스타일 적용
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20), // 두 텍스트 사이 간격
            Text(
              lowerText,
              style: const TextStyle(
                fontSize: 24, // 원하는 스타일로 변경
                color: Colors.blue,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ],
      );
    } else if (isStarted) {
      String displayText = '';
      if (isShowingTarget) {
        displayText = '$targetSeconds초';
      } else {
        displayText = isMeasuring ? '●' : '+'; // 측정 중일 때는 검정 원, 아니면 +
      }

      return Text(
        displayText,
        style: getDisplayStyle(), // 스타일 적용
        textAlign: TextAlign.center,
      );
    } else {
      String displayText = isPracticeMode ? '연습 모드' : '본실험 모드';

      return Text(
        displayText,
        style: getDisplayStyle(), // 스타일 적용
        textAlign: TextAlign.center,
      );
    }
  }

  Widget testGuideText() {
    TextStyle textStyle = TextStyle(
      color: isPracticeMode ? Colors.blue : Colors.purple,
      fontSize: 28,
    );
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        RichText(
          textAlign: TextAlign.left,
          text: TextSpan(
            style: textStyle,
            children: [
              const TextSpan(
                text: '지금부터는 마음 속으로 시간을 세어보실 건데요.\n',
              ),
              const TextSpan(
                text: '\'1초\'',
                style: TextStyle(color: Colors.black),
              ),
              const TextSpan(
                text: ' 또는 ',
              ),
              const TextSpan(
                text: '\'2초\'',
                style: TextStyle(color: Colors.black),
              ),
              const TextSpan(
                text: ' 이렇게 마음 속으로 셀 시간이 나타납니다.\n'
                    '그런 후,\n',
              ),
              const TextSpan(
                text: '\'준비\'',
                style: TextStyle(color: Colors.black),
              ),
              const TextSpan(
                text: '를 응시하고 있다가 ',
              ),
              const WidgetSpan(
                alignment: PlaceholderAlignment.middle,
                child: Icon(Icons.circle, size: 24, color: Colors.black),
              ),
              TextSpan(
                text: '이 나타나면\n'
                    '해당 시간이 지난 후에 스페이스바를\n'
                    '${isPracticeMode ? "눌러주시면 됩니다. 한 번 연습해보실께요." : "눌러주시면 됩니다.\n이제 본 검사를 시작하겠습니다."}',
              ),
            ],
          ),
        ),
      ],
    );
  }

  RecordDrawer getRecordDrawer() {
    final userInfo = Provider.of<UserStateProvider>(context).getUserInfo;
    String path = '${Directory.current.path}\\Data\\TimeGeneration\\${userInfo?.userNumber}_${userInfo?.name}';
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
                  width: MediaQuery.of(context).size.width * 0.08,
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
    String path = '${Directory.current.path}\\Data\\TimeGeneration\\${userInfo?.userNumber}_${userInfo?.name}';
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
                        '$path\\$result',
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
        // 오디오 파일이 있는 경우 재생 버튼 표시
        if (testResult.audioFilePath != null && testResult.audioFilePath!.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 16.0),
            child: Row(
              children: [
                const Icon(Icons.mic, color: Colors.green, size: 16),
                const SizedBox(width: 8),
                Text("녹음 파일: ${testResult.audioFilePath!.split('/').last}"),
                const SizedBox(width: 16),
                OutlinedButton.icon(
                  icon: const Icon(Icons.play_arrow),
                  label: const Text('녹음 재생'),
                  onPressed: () {
                    // 오디오 파일 재생 로직
                    print('오디오 파일 재생: ${testResult.audioFilePath}');
                  },
                ),
              ],
            ),
          ),

        // 기존 결과 표시 로직
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
