import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_application_chrono_metrics/commons/common_util.dart';
import 'package:flutter_application_chrono_metrics/commons/enum_defines.dart';
import 'package:flutter_application_chrono_metrics/commons/widgets/icon_spacebar.dart';
import 'package:flutter_application_chrono_metrics/commons/widgets/record_drawer.dart';
import 'package:flutter_application_chrono_metrics/datas/data_reaction/testdata_reaction.dart';
import 'package:flutter_application_chrono_metrics/datas/data_reaction/testresult_reaction.dart';
import 'package:flutter_application_chrono_metrics/datas/user_infomation.dart';
import 'package:flutter_application_chrono_metrics/pages/page_layout_base.dart';
import 'package:flutter_application_chrono_metrics/providers/user_state_provider.dart';
import 'package:flutter_application_chrono_metrics/commons/audio_recording_manager.dart';
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
  final int maxRounds = 5;
  late AudioPlayer player;
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _userNumberController = TextEditingController();
  bool _isRecording = false; // 음성 녹음 상태
  String? _currentRecordingPath; // 현재 녹음 파일 경로

  late TestResultReaction testResultReaction;

  List<String> testResultList = [];

  // 클래스 상단에 컨트롤러 선언
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      // 메인 메뉴에서 설정한 사용자 정보 가져오기
      final userInfo = Provider.of<UserStateProvider>(context, listen: false).getUserInfo;
      if (userInfo != null) {
        // 이미 저장된 사용자 정보가 있으면 컨트롤러에 설정
        _nameController.text = userInfo.name;
        _userNumberController.text = userInfo.userNumber;
      }

      // 음성 녹음 매니저 초기화
      await AudioRecordingManager().initialize();

      // 사용자 정보 입력 대화상자 표시 (이미 입력된 정보가 있으면 자동 채워짐)
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
    // 녹음 중인 경우 중지
    _stopRecording();
    super.dispose();
  }

  // 음성 녹음 시작
  Future<void> _startRecording() async {
    if (_isRecording) return;

    final userInfo = Provider.of<UserStateProvider>(context, listen: false).getUserInfo;
    if (userInfo == null) return;

    final dateTime = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
    final mode = isAudioMode ? 'auditory' : 'visual';

    // 테스트 결과 파일과 동일한 경로 구조 사용
    final String baseDirectory = '${Directory.current.path}/Data/Reaction';
    final String userPath = '$baseDirectory/${userInfo.userNumber}_${userInfo.name}';
    final String recordingDirectory = '$userPath/Audio';

    // 디렉토리가 없으면 생성
    final directory = Directory(recordingDirectory);
    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }

    // 녹음 파일명 생성 (타임스탬프 포함)
    final String audioFilename = '${userInfo.userNumber}_${userInfo.name}_${dateTime}_$mode.mp3';
    final String filePath = '$recordingDirectory/$audioFilename';

    _currentRecordingPath = filePath;

    // 녹음 시작
    final success = await AudioRecordingManager().startRecording(filePath);
    if (success) {
      setState(() {
        _isRecording = true;
      });
      print('음성 녹음 시작: $filePath');
    }
  }

  // 음성 녹음 중지
  Future<void> _stopRecording() async {
    if (!_isRecording || _currentRecordingPath == null) return;

    final success = await AudioRecordingManager().stopRecording(_currentRecordingPath!);
    if (success) {
      setState(() {
        _isRecording = false;
      });
      print('음성 녹음 중지: $_currentRecordingPath');
    }
  }

  void startTest() {
    // 테스트 시작 시 녹음 시작
    _startRecording();

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
    // 테스트 리셋 시 기존 녹음 중지
    _stopRecording();

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
          // 사용자 정보 가져와서 저장
          final userInfo = Provider.of<UserStateProvider>(context, listen: false).getUserInfo!;

          // 테스트 결과 저장 - 음성 파일 경로 전달
          Provider.of<UserStateProvider>(context, listen: false).saveTestResultReaction(
            studentId: userInfo.userNumber,
            name: userInfo.name,
            testResultReaction: testResultReaction,
            audioFilePath: _currentRecordingPath,
          );

          testResultList = Provider.of<UserStateProvider>(context, listen: false).loadTestResultList(AppTestType.reaction, Provider.of<UserStateProvider>(context, listen: false).getUserInfo);

          // 모든 테스트 완료 시 녹음 중지 (테스트 결과 저장 시점)
          _stopRecording();
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
            Expanded(
              child: Text(
                '동작 반응성 속도 측정 - ${isAudioMode ? '청각 모드' : '시각 모드'}',
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            // 녹음 상태 표시 아이콘
            if (_isRecording)
              const Padding(
                padding: EdgeInsets.only(right: 16.0),
                child: Row(
                  children: [
                    Icon(Icons.mic, color: Colors.red),
                    SizedBox(width: 4),
                    Text('녹음 중', style: TextStyle(color: Colors.red)),
                  ],
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

  Widget testGuideText(double fontSize, Color color) {
    TextStyle textStyle = TextStyle(
      color: color,
      fontSize: fontSize,
      fontWeight: FontWeight.bold,
    );

    switch (testState) {
      case TestState.finished:
        if (isAudioMode) {
          return Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('테스트 완료!\n[초기 메뉴화면]으로 돌아가시겠습니까?', textAlign: TextAlign.center, style: textStyle),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                ),
                child: const Text('← 돌아가기',
                    style: TextStyle(
                      fontSize: 18,
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    )),
              ),
            ],
          );
        } else {
          return Text('시각 모드 테스트 완료!\n스페이스바를 눌러 청각 측정 진행', textAlign: TextAlign.center, style: textStyle);
        }
      case TestState.idle:
        return Center(
          child: SizedBox(
            width: MediaQuery.of(context).size.width * 0.5, // Adjust width as needed
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('준비가 되셨나요?!', style: textStyle),
                Row(
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: [
                    if (isAudioMode) ...[
                      Text('띵 소리가 들리자마자 스페이스바', style: textStyle),
                    ] else ...[
                      Text('별', style: textStyle),
                      Icon(Icons.star, color: Colors.red, size: fontSize * 1.2),
                      Text('이 보이자마자 스페이스바', style: textStyle),
                    ],
                    IconSpacebar(fontSize: fontSize, color: color),
                    Text('를 누르세요.', style: textStyle),
                  ],
                ),
                SizedBox(height: fontSize),
                Row(
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: [
                    Text('자, 시작하려면 스페이스바', style: textStyle),
                    IconSpacebar(fontSize: fontSize, color: color),
                    Text('를 누르세요', style: textStyle),
                  ],
                ),
              ],
            ),
          ),
        );
      default:
        return Text('', textAlign: TextAlign.center, style: textStyle);
    }
  }

  RecordDrawer getRecordDrawer() {
    final userInfo = Provider.of<UserStateProvider>(context).getUserInfo;
    String path = '${Directory.current.path}/Data/Reaction/${userInfo?.userNumber}_${userInfo?.name}';
    return RecordDrawer(
      path: path,
      record: reactionResultFromFile(userInfo),
      title: '반응 속도 기록',
    );
  }

  Widget reactionResultFromFile(UserInfomation? userInfo) {
    // 결과 파일에서 데이터 로드
    final resultsByDate = Provider.of<UserStateProvider>(context, listen: false).loadReactionResultsForDrawer(userInfo);

    if (resultsByDate.isEmpty) {
      return const Center(
        child: Text('저장된 테스트 결과가 없습니다.'),
      );
    }

    return Scrollbar(
      thumbVisibility: true,
      controller: _scrollController,
      child: MouseRegion(
        cursor: SystemMouseCursors.grab,
        child: GestureDetector(
          onPanUpdate: (details) {
            _scrollController.jumpTo(
              (_scrollController.offset - details.delta.dy).clamp(
                0.0,
                _scrollController.position.maxScrollExtent,
              ),
            );
          },
          child: SingleChildScrollView(
            controller: _scrollController,
            physics: const ClampingScrollPhysics(),
            child: Column(
              children: resultsByDate.entries.map((entry) {
                // 날짜를 키로 사용
                String date = entry.key;
                List<Map<String, dynamic>> results = entry.value;

                // 날짜별 그룹화된 테스트 결과 표시
                return ExpansionTile(
                  title: Text('테스트 날짜: $date'),
                  children: [
                    ...results
                        .fold<Map<String, List<Map<String, dynamic>>>>({}, // 초기 빈 맵
                            (map, result) {
                          // 시간별로 그룹화
                          String key = result['testDateTime'];
                          if (!map.containsKey(key)) {
                            map[key] = [];
                          }
                          map[key]!.add(result);
                          return map;
                        })
                        .entries
                        .map((timeEntry) {
                          // 특정 시간의 테스트 세션
                          String testTime = timeEntry.key;
                          List<Map<String, dynamic>> sessionResults = timeEntry.value;

                          // 오디오 파일 경로 (모든 결과가 동일한 오디오 파일을 가리킴)
                          String audioPath = sessionResults.first['audioFilePath'];

                          return ExpansionTile(
                            title: Text('세션 시간: ${testTime.split(' ')[1]}'),
                            subtitle: audioPath.isNotEmpty ? const Text('녹음 파일 있음', style: TextStyle(color: Colors.green)) : null,
                            children: [
                              SizedBox(
                                width: MediaQuery.of(context).size.width * 0.9,
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      // 시각 자극 결과
                                      const Text('시각 측정 결과', style: TextStyle(fontWeight: FontWeight.bold)),
                                      ...sessionResults.where((result) => result['stimulusType'] == '시각').map((result) => reactionResultRow(result)),

                                      const SizedBox(height: 16),

                                      // 청각 자극 결과
                                      const Text('청각 측정 결과', style: TextStyle(fontWeight: FontWeight.bold)),
                                      ...sessionResults.where((result) => result['stimulusType'] == '청각').map((result) => reactionResultRow(result)),

                                      // 오디오 파일 링크 (있는 경우)
                                      if (audioPath.isNotEmpty)
                                        Padding(
                                          padding: const EdgeInsets.only(top: 16.0),
                                          child: OutlinedButton.icon(
                                            icon: const Icon(Icons.play_arrow),
                                            label: const Text('녹음 재생'),
                                            onPressed: () {
                                              // 오디오 파일 재생 로직
                                              // 여기에 오디오 재생 기능을 추가할 수 있습니다
                                              print('오디오 파일 재생: $audioPath');
                                            },
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          );
                        }),
                  ],
                );
              }).toList(),
            ),
          ),
        ),
      ),
    );
  }

  Widget reactionResultRow(Map<String, dynamic> result) {
    return Row(
      children: [
        SizedBox(
          width: MediaQuery.of(context).size.width * 0.08,
          child: Text('${result['count']}회차'),
        ),
        SizedBox(
          width: MediaQuery.of(context).size.width * 0.08,
          child: const Text('목표 시간:'),
        ),
        SizedBox(
          width: MediaQuery.of(context).size.width * 0.1,
          child: Text('${result['targetTime']}ms'),
        ),
        SizedBox(
          width: MediaQuery.of(context).size.width * 0.08,
          child: const Text('반응 시간:'),
        ),
        SizedBox(
          width: MediaQuery.of(context).size.width * 0.1,
          child: Text('${result['responseTime']}ms'),
        ),
      ],
    );
  }
}
