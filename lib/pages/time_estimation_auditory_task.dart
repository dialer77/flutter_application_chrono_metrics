import 'dart:io';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_application_chrono_metrics/commons/common_util.dart';
import 'package:flutter_application_chrono_metrics/commons/enum_defines.dart';
import 'package:flutter_application_chrono_metrics/commons/widgets/record_drawer.dart';
import 'package:flutter_application_chrono_metrics/datas/data_time_estimation_auditory/testdata_time_estimation_auditory.dart';
import 'package:flutter_application_chrono_metrics/datas/data_time_estimation_auditory/testresult_time_estimation_auditory.dart';
import 'package:flutter_application_chrono_metrics/datas/user_infomation.dart';
import 'package:flutter_application_chrono_metrics/metronome_widget.dart';
import 'package:flutter_application_chrono_metrics/pages/page_layout_base.dart';
import 'package:flutter_application_chrono_metrics/providers/user_state_provider.dart';
import 'package:intl/intl.dart';
import 'package:just_audio/just_audio.dart';
import 'package:provider/provider.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter_application_chrono_metrics/commons/audio_recording_manager.dart';

class TimeEstimationAuditoryTaskPage extends StatefulWidget {
  const TimeEstimationAuditoryTaskPage({super.key});

  @override
  State<TimeEstimationAuditoryTaskPage> createState() => _TimeEstimationAuditoryTaskPageState();
}

class _TimeEstimationAuditoryTaskPageState extends State<TimeEstimationAuditoryTaskPage> with SingleTickerProviderStateMixin {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _userNumberController = TextEditingController();
  final MetronomeController _metronomeController = MetronomeController();
  final TextEditingController _estimatedTimeController = TextEditingController();

  int targetSeconds = 0;
  final List<int> taskTimeList = [3, 6, 12, 30];
  int taskCount = 1;
  final maxTaskCount = 4;
  int currentRound = 1;
  final int maxRounds = 2;

  FocusNode focusNode = FocusNode();
  bool isPracticeMode = true;
  bool isStarted = false;

  // 녹음 관련 변수 추가
  bool _isRecording = false;
  String? _currentRecordingPath;

  List<String> testResultList = [];
  TestResultTimeEstimationAuditory testResult = TestResultTimeEstimationAuditory(userInfo: UserInfomation(name: '', userNumber: ''));

  final AudioPlayer _startAudioPlayer = AudioPlayer();
  final AudioPlayer _movementAudioPlayer = AudioPlayer();
  final AudioPlayer _finishAudioPlayer = AudioPlayer();
  bool _isPlayingSound = false;
  Timer? _finishTimer;

  // 테스트 세션마다 사용할 변수들
  String? _sessionAudioPath;
  final List<String> _audioSequence = [];

  // 새로운 상태 변수 추가
  Duration _currentPlayTime = Duration.zero;
  Timer? _displayTimer;

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
      testResult = TestResultTimeEstimationAuditory(userInfo: userInfo!);
      testResult.setTaskCount(maxTaskCount);

      testResultList = Provider.of<UserStateProvider>(context, listen: false).loadTestResultList(AppTestType.timeEstimationAuditory, userInfo);
      taskTimeList.shuffle();

      _loadAudioAssets();
    });
  }

  // 녹음 시작 메서드
  Future<void> _startRecording() async {
    if (_isRecording) return;

    final userInfo = Provider.of<UserStateProvider>(context, listen: false).getUserInfo;
    if (userInfo == null) return;

    final dateTime = DateTime.now();
    final dateStr = DateFormat('yyyyMMddHHmmss').format(dateTime);

    // 파일 경로 직접 생성
    final directory = Directory('${Directory.current.path}\\Data\\TimeEstimationAuditory\\${userInfo.userNumber}_${userInfo.name}\\recordings');
    if (!directory.existsSync()) {
      directory.createSync(recursive: true);
    }

    final filePath = '${directory.path}/TEA_${userInfo.userNumber}_${userInfo.name}_$dateStr.m4a';

    // 생성된 파일 경로로 녹음 시작
    final success = await AudioRecordingManager().startRecording(filePath);

    if (success && mounted) {
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

    if (success && mounted) {
      setState(() {
        _isRecording = false;
      });

      // 테스트 결과에 녹음 파일 경로 설정
      testResult.setAudioFilePath(filePath);
      print('녹음 파일 저장됨: $filePath');
    }
  }

  void _loadAudioAssets() async {
    await _startAudioPlayer.setAsset('assets/start.mp3');
    await _movementAudioPlayer.setAsset('assets/longMove_30.wav');
    await _finishAudioPlayer.setAsset('assets/finish.mp3');
  }

  @override
  void dispose() {
    _startAudioPlayer.dispose();
    _movementAudioPlayer.dispose();
    _finishAudioPlayer.dispose();
    _finishTimer?.cancel();

    // 녹음 중인 경우 중지 - 비동기 작업이지만 dispose에서는 await 할 수 없으므로
    // 페이지 나가기 전에 처리했는지 확인하는 것이 중요
    if (_isRecording) {
      // 비동기 작업이지만 dispose에서는 기다릴 수 없음
      // 따라서 _stopRecording() 내부에서 mounted 확인이 중요
      _stopRecording();
    }

    _displayTimer?.cancel();
    super.dispose();
  }

  void _startTask() {
    setState(() {
      targetSeconds = taskTimeList[taskCount - 1];
      _isPlayingSound = true;
    });

    // 본 테스트 모드이고 첫 라운드의 첫 번째 과제일 때만 녹음 시작
    if (!isPracticeMode && currentRound == 1 && taskCount == 1 && !_isRecording) {
      _startRecording();
    }

    _prepareAudioSession();

    _startAudioPlayer.setAsset('assets/start.mp3');
    _startAudioPlayer.setVolume(1.0);
    _startAudioPlayer.play();

    // 시작 오디오 파일 기록
    _audioSequence.add('start.mp3');

    StreamSubscription<PlayerState>? subscription;
    subscription = _startAudioPlayer.playerStateStream.listen((state) {
      if (state.processingState == ProcessingState.completed) {
        subscription?.cancel();
        _playMovementSound();
      }
    });
  }

  void _playMovementSound() {
    if (!_isPlayingSound) return;

    _movementAudioPlayer.setAsset('assets/longMove_30.wav');
    _movementAudioPlayer.setVolume(1.0);

    // 움직임 오디오 파일 기록
    _audioSequence.add('longMove_30.wav');

    // 현재 재생 시작 시간 기록
    final startTime = DateTime.now();

    // 목표 종료 시간 계산
    final targetEndTime = startTime.add(Duration(seconds: targetSeconds));

    // 디스플레이 타이머 시작
    _displayTimer?.cancel();
    setState(() => _currentPlayTime = Duration.zero);
    _displayTimer = Timer.periodic(const Duration(milliseconds: 100), (timer) {
      if (mounted) {
        setState(() {
          _currentPlayTime = DateTime.now().difference(startTime);
        });
      }
    });

    _movementAudioPlayer.play();

    // 플레이어 상태 감시
    StreamSubscription<Duration>? positionSubscription;

    // 재생 위치 모니터링
    positionSubscription = _movementAudioPlayer.positionStream.listen((position) {
      final now = DateTime.now();

      // 목표 시간에 도달했는지 확인
      if (now.isAfter(targetEndTime) && _isPlayingSound) {
        _movementAudioPlayer.stop();
        positionSubscription?.cancel();

        // 종료 소리 재생
        _playFinishSound();
      }
    });
  }

  void _playFinishSound() {
    if (!_isPlayingSound) return;

    // 디스플레이 타이머 정지
    _displayTimer?.cancel();
    _displayTimer = null;

    _finishAudioPlayer.setAsset('assets/finish.mp3');
    _finishAudioPlayer.setVolume(1.0);
    _finishAudioPlayer.play();

    // 종료 오디오 파일 기록
    _audioSequence.add('finish.mp3');

    _finishAudioPlayer.playerStateStream.listen((state) {
      if (state.processingState == ProcessingState.completed) {
        if (_isPlayingSound && mounted) {
          setState(() {
            _isPlayingSound = false;
          });
          _endTask();
        }
      }
    });
  }

  // 새 오디오 세션 준비
  Future<void> _prepareAudioSession() async {
    try {
      _audioSequence.clear();

      final userInfo = Provider.of<UserStateProvider>(context, listen: false).getUserInfo;
      final Directory appDocDir = await getApplicationDocumentsDirectory();
      final String recordingPath = '${appDocDir.path}\\Data\\TimeEstimationAuditory\\${userInfo?.userNumber}_${userInfo?.name}';

      await Directory(recordingPath).create(recursive: true);

      final String timestamp = DateTime.now().millisecondsSinceEpoch.toString();
      _sessionAudioPath = '$recordingPath\\session_task${taskCount}_round${currentRound}_$timestamp.wav';

      print('Audio session prepared: $_sessionAudioPath');
    } catch (e) {
      print('Error preparing audio session: $e');
    }
  }

  void _endTask() {
    _isPlayingSound = false;
    _finishTimer?.cancel();
    _finishTimer = null;

    _showEstimatedTimeDialog();
  }

  void _showEstimatedTimeDialog() {
    _estimatedTimeController.clear();
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('시간 추정'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('소리가 들린 시간은 몇 초인가요?'),
              const SizedBox(height: 10),
              TextField(
                controller: _estimatedTimeController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: '소리가 들린 시간 (초)',
                  border: OutlineInputBorder(),
                ),
                autofocus: true,
                onSubmitted: (_) => _submitEstimatedTime(context),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => _submitEstimatedTime(context),
              child: const Text('확인'),
            ),
          ],
        );
      },
    );
  }

  void _submitEstimatedTime(BuildContext context) {
    if (_estimatedTimeController.text.isEmpty) {
      return;
    }

    double estimatedTime = double.tryParse(_estimatedTimeController.text.replaceAll(',', '.')) ?? 0;

    testResult.addTestData(TestDataTimeEstimationAuditory(
      targetTime: targetSeconds,
      elapsedTime: estimatedTime.toInt(),
    ));

    Navigator.of(context).pop();

    setState(() {
      if (taskCount < maxTaskCount) {
        taskCount++;
      } else {
        taskCount = 1;
        if (currentRound < maxRounds) {
          currentRound++;
          taskTimeList.shuffle();
        } else {
          // 모든 테스트가 완료되면 먼저 결과 저장
          if (!isPracticeMode) {
            // 녹음 중지 및 결과 저장 처리
            if (_isRecording) {
              _stopRecording();
            }
            _saveTestResults();

            // 결과 저장 후 완료 다이얼로그 표시
            showDialog(
              context: context,
              barrierDismissible: false,
              builder: (BuildContext context) {
                return Dialog(
                  child: Container(
                    width: MediaQuery.of(context).size.width * 0.5,
                    height: MediaQuery.of(context).size.height * 0.5,
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text(
                          '검사 완료',
                          style: TextStyle(
                            fontSize: 48,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 30),
                        const Text(
                          '검사가 완료되었습니다.\n수고하셨습니다.',
                          style: TextStyle(fontSize: 36),
                          textAlign: TextAlign.center,
                        ),
                        const Spacer(),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
                            textStyle: const TextStyle(fontSize: 20),
                          ),
                          onPressed: () {
                            Navigator.of(context).pop();
                            final userInfo = Provider.of<UserStateProvider>(context, listen: false).getUserInfo;
                            testResult = TestResultTimeEstimationAuditory(userInfo: userInfo!);
                            testResult.setTaskCount(maxTaskCount);
                          },
                          child: const Text('확인'),
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
          }
          currentRound = 1;
        }
      }
      isStarted = false;
    });
  }

  void _saveTestResults() {
    final userInfo = Provider.of<UserStateProvider>(context, listen: false).getUserInfo;
    testResult.setTestTime(DateTime.now());
    final userStateProvider = Provider.of<UserStateProvider>(context, listen: false);
    userStateProvider.saveTestResultTimeEstimationAuditory(
      studentId: userInfo?.userNumber ?? '',
      name: userInfo?.name ?? '',
      testResultTimeEstimationAuditory: testResult,
    );
    testResultList = Provider.of<UserStateProvider>(context, listen: false).loadTestResultList(AppTestType.timeEstimationAuditory, userInfo);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          '모든 테스트가 완료되었습니다. 결과가 저장되었습니다.',
          style: CommonUtil.snackBarTextStyle,
        ),
      ),
    );
  }

  void onSpacePressed() {
    FocusScope.of(context).requestFocus(focusNode);
    if (!isStarted) {
      setState(() {
        isStarted = true;
      });
      if (isPracticeMode) {
        _metronomeController.start();
      } else {
        _startTask();
      }
    } else {
      if (isPracticeMode) {
        setState(() {
          isStarted = false;
          _isPlayingSound = false;
        });
        _metronomeController.stop();
      }
    }
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
          headerWidget: headerWidget(),
          bodyWidget: bodyWidget(),
          footerWidget: footerWidget(),
        ),
      ),
    );
  }

  RecordDrawer getRecordDrawer() {
    final userInfo = Provider.of<UserStateProvider>(context).getUserInfo;
    String path = '${Directory.current.path}\\Data\\TimeEstimationAuditory\\${userInfo?.userNumber}_${userInfo?.name}';
    return RecordDrawer(
      path: path,
      record: Scrollbar(
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
              child: testResultView(),
            ),
          ),
        ),
      ),
      title: '시간 추정 과제 - 청각적 양식',
    );
  }

  final ScrollController _scrollController = ScrollController();
  Widget testResultView() {
    final userInfo = Provider.of<UserStateProvider>(context).getUserInfo;
    String path = '${Directory.current.path}\\Data\\TimeEstimationAuditory\\${userInfo?.userNumber}_${userInfo?.name}';
    return Container(
      width: MediaQuery.of(context).size.width * 0.9,
      padding: const EdgeInsets.only(left: 16, right: 16),
      child: Column(
        children: testResultList.map((result) {
          final resultSplit = result.split('_');

          final String dateStr = resultSplit[1];
          final DateTime resultTime = DateTime.parse('${dateStr.substring(0, 4)}-'
              '${dateStr.substring(4, 6)}-'
              '${dateStr.substring(6, 8)} '
              '${dateStr.substring(8, 10)}:'
              '${dateStr.substring(10, 12)}:'
              '${dateStr.substring(12, 14)}');

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
                      final testResult = Provider.of<UserStateProvider>(context, listen: false).loadTestResultTimeEstimationAuditory(
                        '$path\\$result',
                        userInfo!,
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

  Widget resultItem(TestResultTimeEstimationAuditory testResult) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 오디오 파일이 있으면 재생 버튼 표시
        if (testResult.audioFilePath != null)
          Container(
            margin: const EdgeInsets.only(bottom: 10),
            child: Row(
              children: [
                const Text('녹음: ', style: TextStyle(fontWeight: FontWeight.bold)),
                TextButton.icon(
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
        ...testResult.testDataList.asMap().entries.map(
          (entry) {
            final index = entry.key;
            final data = entry.value;

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
                  child: Text('${data.targetTime}초'),
                ),
                SizedBox(
                  width: MediaQuery.of(context).size.width * 0.1,
                  child: const Text('사용자추정시간 : '),
                ),
                SizedBox(
                  width: MediaQuery.of(context).size.width * 0.1,
                  child: Text('${data.elapsedTime}초'),
                ),
              ],
            );

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

  void toggleMode() {
    if (!isStarted) {
      // 모드 전환시 녹음 중인 경우 중지
      if (_isRecording) {
        _stopRecording();
      }

      setState(() {
        isPracticeMode = !isPracticeMode;
      });
    }
  }

  Widget headerWidget() {
    return Row(
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
          '시간 추정 과제 - 청각적 양식 / ${isPracticeMode ? '연습 시행' : '본 실험 시행'}',
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
    );
  }

  Widget bodyWidget() {
    return Container(
      width: MediaQuery.of(context).size.width,
      height: MediaQuery.of(context).size.height * 0.6,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isPracticeMode ? Colors.blue : Colors.purple,
          width: 2,
        ),
      ),
      child: isPracticeMode
          ? MetronomeWidget(
              width: MediaQuery.of(context).size.width * 0.25,
              height: MediaQuery.of(context).size.height * 0.6,
              controller: _metronomeController,
              initialBpm: 60,
              isAuditoryMode: true,
            )
          : testBodyWidget(),
    );
  }

  Widget testBodyWidget() {
    if (isStarted == false) {
      return Column(
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
          Text(
            '시작하려면 스페이스를 눌러주세요',
            style: TextStyle(
              color: isPracticeMode ? Colors.blue : Colors.purple,
              fontSize: 24,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      );
    } else {
      // 재생 중일 때의 UI
      return Container();
    }
  }

  Widget footerWidget() {
    if (isPracticeMode) {
      return Container(
        padding: const EdgeInsets.all(0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton(
              onPressed: () {
                if (!focusNode.hasFocus) {
                  onSpacePressed();
                } else {
                  FocusScope.of(context).requestFocus(focusNode);
                  onSpacePressed();
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                  side: BorderSide(
                    color: isPracticeMode ? Colors.blue : Colors.purple,
                    width: 2,
                  ),
                ),
              ),
              child: Text(
                isStarted ? '정지 (Space)' : '시작 (Space)',
                style: TextStyle(fontSize: 15, color: isPracticeMode ? Colors.blue : Colors.purple),
              ),
            ),
          ],
        ),
      );
    } else {
      return Center(
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
      );
    }
  }
}
