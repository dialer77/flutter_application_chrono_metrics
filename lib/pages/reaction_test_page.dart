import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_application_chrono_metrics/commons/common_util.dart';
import 'package:flutter_application_chrono_metrics/commons/enum_defines.dart';
import 'package:flutter_application_chrono_metrics/datas/testdata_reaction.dart';
import 'package:flutter_application_chrono_metrics/datas/testresult_reaction.dart';
import 'package:flutter_application_chrono_metrics/datas/user_infomation.dart';
import 'package:flutter_application_chrono_metrics/providers/user_state_provider.dart';
import 'package:just_audio/just_audio.dart';
import 'dart:async';
import 'dart:math';
import 'package:provider/provider.dart';

class ReactionTestPage extends StatefulWidget {
  const ReactionTestPage({super.key});

  @override
  State<ReactionTestPage> createState() => _ReactionTestPageState();
}

class _ReactionTestPageState extends State<ReactionTestPage> {
  TestState testState = TestState.idle;
  bool isAudioMode = false;
  DateTime? startTime;
  int targetMilliseconds = 0;
  final Random random = Random();
  FocusNode focusNode = FocusNode();
  int currentRound = 0;
  final int maxRounds = 1;
  late AudioPlayer player;
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _userNumberController = TextEditingController();

  late TestResultReaction testResultReaction;

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
    });
    _initAudio();
    testResultReaction = TestResultReaction(
      userInfo: Provider.of<UserStateProvider>(context, listen: false).getUserInfo!,
      startTime: DateTime.now(),
    );
  }

  Future<void> _initAudio() async {
    player = AudioPlayer();
    final audioSource = AudioSource.asset('assets/beep.mp3');
    await player.setAudioSource(audioSource);
    await player.setVolume(1.0);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _userNumberController.dispose();
    player.dispose();
    focusNode.dispose();
    super.dispose();
  }

  void startTest() {
    setState(() {
      testState = TestState.ready;
    });

    targetMilliseconds = 1500 + random.nextInt(3500);
    Future.delayed(Duration(milliseconds: targetMilliseconds), () async {
      if (!mounted || testState != TestState.ready) return;

      setState(() {
        testState = TestState.testing;
        startTime = DateTime.now();
      });

      if (isAudioMode) {
        try {
          await player.seek(Duration.zero);
          await player.play();
        } catch (e) {
          if (mounted) {
            setState(() {
              testState = TestState.idle;
            });
          }
        }
      }
    });
  }

  void resetTest() {
    setState(() {
      currentRound = 0;
      testState = TestState.idle;
    });
  }

  void onSpacePressed() {
    if (testState == TestState.finished) {
      if (isAudioMode) {
        resetTest();
        isAudioMode = false;
      } else {
        resetTest();
        isAudioMode = true;
      }
      return;
    }

    if (testState == TestState.idle) {
      startTest();
    } else if (testState == TestState.ready) {
      setState(() {
        testState = TestState.idle;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('너무 일찍 눌렀습니다! 다시 시도하세요.')),
      );
    } else if (testState == TestState.testing) {
      final endTime = DateTime.now();
      final reactionTime = endTime.difference(startTime!).inMilliseconds;
      setState(() {
        Provider.of<UserStateProvider>(context, listen: false).getTestResultReaction?.addAuditoryTestData(TestDataReaction(
              targetMilliseconds: targetMilliseconds,
              resultMilliseconds: reactionTime,
            ));
        testState = TestState.idle;
      });

      currentRound++;
      if (currentRound >= maxRounds) {
        Provider.of<UserStateProvider>(context, listen: false).saveTestResultReaction(
          studentId: _userNumberController.text,
          name: _nameController.text,
        );
        setState(() {
          testState = TestState.finished;
        });
      }
    }
  }

  String getAverageTime() {
    final testResult = Provider.of<UserStateProvider>(context, listen: false).getTestResultReaction;

    if (testResult == null) return '아직 기록이 없습니다';
    final avg = testResult.auditoryAverageTime();
    return '평균 반응 속도: ${avg.toStringAsFixed(1)}ms';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      endDrawer: getReactionRecordDrawer(),
      endDrawerEnableOpenDragGesture: false, // 드래그로 드로어 열기 비활성화
      body: KeyboardListener(
        focusNode: focusNode,
        onKeyEvent: (KeyEvent event) {
          if (event is KeyDownEvent) {
            if (event.logicalKey == LogicalKeyboardKey.space) {
              onSpacePressed();
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
                            Icon(
                              isAudioMode ? Icons.volume_up : Icons.visibility,
                              size: 50,
                              color: isAudioMode ? Colors.blue : Colors.purple,
                            ),
                            SizedBox(
                              width: constraints.maxWidth * 0.01,
                            ),
                            Text(
                              '동작 반응성 속도 측정 - ${isAudioMode ? '청각 모드' : '시각 모드'}',
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
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(
                                        color: isAudioMode ? Colors.blue : Colors.purple,
                                        width: 2,
                                      ),
                                    ),
                                    child: Center(
                                      child: testState == TestState.testing && isAudioMode == false
                                          ? Icon(
                                              Icons.star,
                                              size: constraints.maxHeight * 0.3,
                                              color: Colors.red,
                                            )
                                          : testGuideText(24, Colors.blue),
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
                        child: Center(
                          child: Text(
                            '$currentRound/$maxRounds 라운드',
                            style: TextStyle(
                              color: isAudioMode ? Colors.blue : Colors.purple,
                              fontSize: 18,
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

  Text testGuideText(double fontSize, Color color) {
    TextStyle textStyle = TextStyle(
      color: color,
      fontSize: fontSize,
      fontWeight: FontWeight.bold,
    );

    switch (testState) {
      case TestState.finished:
        if (isAudioMode) {
          return Text('테스트 완료!\n스페이스바를 눌러 재시작', textAlign: TextAlign.center, style: textStyle);
        } else {
          return Text('시각 모드 테스트 완료!\n스페이스바를 눌러 청각 측정 진행', textAlign: TextAlign.center, style: textStyle);
        }
      case TestState.idle:
        return Text('준비되었습니다!\n스페이스바를 눌러 테스트 시작해주세요', textAlign: TextAlign.center, style: textStyle);
      default:
        return Text('', textAlign: TextAlign.center, style: textStyle);
    }
  }

  Drawer getReactionRecordDrawer() {
    final userInfo = Provider.of<UserStateProvider>(context).getUserInfo;

    return Drawer(
      width: MediaQuery.of(context).size.width * 0.6,
      child: LayoutBuilder(
        builder: (context, constraints) {
          return ListView(
            padding: EdgeInsets.zero,
            children: [
              Container(
                height: constraints.maxHeight * 0.1,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.inversePrimary,
                ),
                padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
                alignment: Alignment.centerLeft,
                child: Text(
                  '반응 속도 기록',
                  style: TextStyle(
                    fontSize: constraints.maxHeight * 0.03,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              // 유저 정보 섹션 추가
              Container(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text('이름: ${userInfo?.name ?? "미입력"}'),
                        Text('학번: ${userInfo?.userNumber ?? "미입력"}'),
                      ],
                    ),
                  ],
                ),
              ),
              const Divider(),
              ListTile(
                title: Text(getAverageTime()),
              ),
              const Divider(),
              // 각 라운드별 기록 표시
            ],
          );
        },
      ),
    );
  }
}
