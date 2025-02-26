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

      final userInfo = Provider.of<UserStateProvider>(context, listen: false).getUserInfo;
      testResult = TestResultTimeEstimationAuditory(userInfo: userInfo!);
      testResult.setTaskCount(maxTaskCount);

      testResultList = Provider.of<UserStateProvider>(context, listen: false).loadTestResultList(AppTestType.timeEstimationAuditory, userInfo);
      taskTimeList.shuffle();

      _loadAudioAssets();
    });
  }

  void _loadAudioAssets() async {
    await _startAudioPlayer.setAsset('assets/start.mp3');
    await _movementAudioPlayer.setAsset('assets/longMove.wav');
    await _finishAudioPlayer.setAsset('assets/finish.mp3');
  }

  @override
  void dispose() {
    _startAudioPlayer.dispose();
    _movementAudioPlayer.dispose();
    _finishAudioPlayer.dispose();
    _finishTimer?.cancel();

    super.dispose();
  }

  void _startTask() {
    setState(() {
      targetSeconds = taskTimeList[taskCount - 1];
      _isPlayingSound = true;
    });

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

    _movementAudioPlayer.setAsset('assets/longMove.wav');
    _movementAudioPlayer.setVolume(1.0);

    // 움직임 오디오 파일 기록
    _audioSequence.add('longMove.wav');

    _movementAudioPlayer.playerStateStream.listen((state) {
      if (state.processingState == ProcessingState.completed && _isPlayingSound) {
        _movementAudioPlayer.seek(Duration.zero);
        _movementAudioPlayer.play();

        // 반복 재생 발생할 때마다 기록 (선택 사항)
        _audioSequence.add('longMove.wav');
      }
    });

    _movementAudioPlayer.play();

    _finishTimer = Timer(Duration(seconds: targetSeconds), () {
      _movementAudioPlayer.stop();

      if (_isPlayingSound) {
        _finishAudioPlayer.setAsset('assets/finish.mp3');
        _finishAudioPlayer.setVolume(1.0);
        _finishAudioPlayer.play();

        // 종료 오디오 파일 기록
        _audioSequence.add('finish.mp3');

        _finishAudioPlayer.playerStateStream.listen((state) {
          if (state.processingState == ProcessingState.completed) {
            if (_isPlayingSound) {
              _isPlayingSound = false;
              _endTask();
            }
          }
        });
      }
    });
  }

  // 새 오디오 세션 준비
  Future<void> _prepareAudioSession() async {
    try {
      _audioSequence.clear();

      final userInfo = Provider.of<UserStateProvider>(context, listen: false).getUserInfo;
      final Directory appDocDir = await getApplicationDocumentsDirectory();
      final String recordingPath = '${appDocDir.path}/Data/TimeEstimationAuditory/${userInfo?.userNumber}_${userInfo?.name}';

      await Directory(recordingPath).create(recursive: true);

      final String timestamp = DateTime.now().millisecondsSinceEpoch.toString();
      _sessionAudioPath = '$recordingPath/session_task${taskCount}_round${currentRound}_$timestamp.wav';

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
              const Text('소리가 들린 시간을 초 단위로 추정해주세요.'),
              const SizedBox(height: 10),
              TextField(
                controller: _estimatedTimeController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: '추정한 시간 (초)',
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
          currentRound = 1;
          _saveTestResults();
          final userInfo = Provider.of<UserStateProvider>(context, listen: false).getUserInfo;
          testResult = TestResultTimeEstimationAuditory(userInfo: userInfo!);
          testResult.setTaskCount(maxTaskCount);
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
      const SnackBar(content: Text('모든 테스트가 완료되었습니다. 결과가 저장되었습니다.')),
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
      setState(() {
        isStarted = false;
        _isPlayingSound = false;
      });
      if (isPracticeMode) {
        _metronomeController.stop();
      } else {
        _endTask();
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
    String path = '${Directory.current.path}/Data/TimeEstimationAuditory/${userInfo?.userNumber}_${userInfo?.name}';
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
    String path = '${Directory.current.path}/Data/TimeEstimationAuditory/${userInfo?.userNumber}_${userInfo?.name}';
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
                        '$path/$result',
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
      );
    } else {
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
