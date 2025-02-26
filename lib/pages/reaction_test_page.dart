import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_application_chrono_metrics/commons/common_util.dart';
import 'package:flutter_application_chrono_metrics/commons/enum_defines.dart';
import 'package:flutter_application_chrono_metrics/commons/widgets/record_drawer.dart';
import 'package:flutter_application_chrono_metrics/datas/data_reaction/testdata_reaction.dart';
import 'package:flutter_application_chrono_metrics/datas/data_reaction/testresult_reaction.dart';
import 'package:flutter_application_chrono_metrics/datas/user_infomation.dart';
import 'package:flutter_application_chrono_metrics/pages/page_layout_base.dart';
import 'package:flutter_application_chrono_metrics/providers/user_state_provider.dart';
import 'package:just_audio/just_audio.dart';
import 'dart:async';
import 'dart:math';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'dart:io';

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

  List<String> testResultList = [];

  // 클래스 상단에 컨트롤러 선언
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await CommonUtil.showUserInfoDialog(
        context: context,
        nameController: _nameController,
        userNumberController: _userNumberController,
      );
      FocusScope.of(context).requestFocus(focusNode);
      testResultReaction = TestResultReaction(
        userInfo: Provider.of<UserStateProvider>(context, listen: false).getUserInfo!,
        startTime: DateTime.now(),
      );
      testResultList = Provider.of<UserStateProvider>(context, listen: false).loadTestResultList(AppTestType.reaction, Provider.of<UserStateProvider>(context, listen: false).getUserInfo);
    });
    _initAudio();
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
        testResultReaction = TestResultReaction(
          userInfo: Provider.of<UserStateProvider>(context, listen: false).getUserInfo!,
          startTime: DateTime.now(),
        );
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
        if (isAudioMode) {
          testResultReaction.addAuditoryTestData(TestDataReaction(
            targetMilliseconds: targetMilliseconds,
            resultMilliseconds: reactionTime,
          ));
        } else {
          testResultReaction.addVisualTestData(TestDataReaction(
            targetMilliseconds: targetMilliseconds,
            resultMilliseconds: reactionTime,
          ));
        }
        testState = TestState.idle;
      });

      currentRound++;
      if (currentRound >= maxRounds) {
        if (isAudioMode) {
          Provider.of<UserStateProvider>(context, listen: false).saveTestResultReaction(
            studentId: _userNumberController.text,
            name: _nameController.text,
            testResultReaction: testResultReaction,
          );
          testResultList = Provider.of<UserStateProvider>(context, listen: false).loadTestResultList(AppTestType.reaction, Provider.of<UserStateProvider>(context, listen: false).getUserInfo);
        }
        setState(() {
          testState = TestState.finished;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return KeyboardListener(
      focusNode: focusNode,
      onKeyEvent: (KeyEvent event) {
        if (event is KeyDownEvent) {
          if (event.logicalKey == LogicalKeyboardKey.space) {
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
            Icon(
              isAudioMode ? Icons.volume_up : Icons.visibility,
              size: 50,
              color: isAudioMode ? Colors.blue : Colors.purple,
            ),
            SizedBox(
              width: MediaQuery.of(context).size.width * 0.01,
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
        bodyWidget: Container(
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
                    size: MediaQuery.of(context).size.height * 0.3,
                    color: Colors.red,
                  )
                : testGuideText(24, Colors.blue),
          ),
        ),
        footerWidget: Center(
          child: Text(
            '$currentRound/$maxRounds 라운드',
            style: TextStyle(
              color: isAudioMode ? Colors.blue : Colors.purple,
              fontSize: 18,
            ),
          ),
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

  RecordDrawer getRecordDrawer() {
    final userInfo = Provider.of<UserStateProvider>(context).getUserInfo;
    String path = '${Directory.current.path}/Data/Reaction/${userInfo?.userNumber}_${userInfo?.name}';
    return RecordDrawer(
      path: path,
      record: reactionResult(path, userInfo),
      title: '반응 속도 기록',
    );
  }

  Widget reactionResult(String path, UserInfomation? userInfo) {
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
            physics: const ClampingScrollPhysics(),
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
                            final testResultReaction = Provider.of<UserStateProvider>(context, listen: false).loadTestResultReaction('$path/$result', userInfo!);

                            var list = [
                              reactionResultItem(testResultReaction),
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
          ),
        ),
      ),
    );
  }

  Widget reactionResultItem(TestResultReaction testResultReaction) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('시각 측정 결과'),
        ...testResultReaction.visualTestData.map(
          (data) => Row(
            children: [
              SizedBox(
                width: MediaQuery.of(context).size.width * 0.08,
                child: const Text('목표 시간 : '),
              ),
              SizedBox(
                width: MediaQuery.of(context).size.width * 0.1,
                child: Text('${data.targetMilliseconds}ms'),
              ),
              SizedBox(
                width: MediaQuery.of(context).size.width * 0.08,
                child: const Text('측정 시간 : '),
              ),
              SizedBox(
                width: MediaQuery.of(context).size.width * 0.1,
                child: Text('${data.resultMilliseconds + data.targetMilliseconds}ms'),
              ),
            ],
          ),
        ),
        const Text('청각 측정 결과'),
        ...testResultReaction.auditoryTestData.map(
          (data) => Row(
            children: [
              SizedBox(
                width: MediaQuery.of(context).size.width * 0.08,
                child: const Text('목표 시간 : '),
              ),
              SizedBox(
                width: MediaQuery.of(context).size.width * 0.1,
                child: Text('${data.targetMilliseconds}ms'),
              ),
              SizedBox(
                width: MediaQuery.of(context).size.width * 0.08,
                child: const Text('측정 시간 : '),
              ),
              SizedBox(
                width: MediaQuery.of(context).size.width * 0.1,
                child: Text('${data.resultMilliseconds + data.targetMilliseconds}ms'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
