import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_application_chrono_metrics/commons/common_util.dart';
import 'package:flutter_application_chrono_metrics/commons/enum_defines.dart';
import 'package:flutter_application_chrono_metrics/commons/widgets/record_drawer.dart';
import 'package:flutter_application_chrono_metrics/datas/data_time_estimation_visual/testdata_time_estimation_visual.dart';
import 'package:flutter_application_chrono_metrics/datas/data_time_estimation_visual/testresult_time_estimation_visual.dart';
import 'package:flutter_application_chrono_metrics/datas/user_infomation.dart';
import 'package:flutter_application_chrono_metrics/metronome_widget.dart';
import 'package:flutter_application_chrono_metrics/pages/page_layout_base.dart';
import 'package:flutter_application_chrono_metrics/providers/user_state_provider.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:flutter_application_chrono_metrics/commons/audio_recording_manager.dart';

class TimeEstimationVisualTaskPage extends StatefulWidget {
  const TimeEstimationVisualTaskPage({super.key});

  @override
  State<TimeEstimationVisualTaskPage> createState() => _TimeEstimationVisualTaskPageState();
}

class _TimeEstimationVisualTaskPageState extends State<TimeEstimationVisualTaskPage> with SingleTickerProviderStateMixin {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _userNumberController = TextEditingController();
  final MetronomeController _metronomeController = MetronomeController();
  final TextEditingController _estimatedTimeController = TextEditingController();

  late AnimationController _animationController;
  late Animation<double> _animation;

  int targetSeconds = 0;
  final List<int> taskTimeList = [3, 6, 12, 30];
  int taskCount = 1;
  final maxTaskCount = 4;
  int currentRound = 1;
  final int maxRounds = 5;

  FocusNode focusNode = FocusNode();
  bool isPracticeMode = true;
  bool isStarted = false;

  // 녹음 관련 변수 추가
  bool _isRecording = false;
  String? _currentRecordingPath;

  List<String> testResultList = [];
  TestResultTimeEstimationVisual testResult = TestResultTimeEstimationVisual(userInfo: UserInfomation(name: '', userNumber: ''));

  @override
  void initState() {
    super.initState();

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 5),
    );

    _animation = Tween<double>(begin: 0.0, end: 1.0).animate(_animationController)
      ..addListener(() {
        setState(() {});
      })
      ..addStatusListener((status) {
        if (status == AnimationStatus.completed) {
          _endTask();
        }
      });

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
      testResult = TestResultTimeEstimationVisual(userInfo: userInfo!);
      testResult.setTaskCount(maxTaskCount);

      testResultList = Provider.of<UserStateProvider>(context, listen: false).loadTestResultList(AppTestType.timeEstimationVisual, userInfo);
      taskTimeList.shuffle();
    });
  }

  @override
  void dispose() {
    // 애니메이션 컨트롤러 dispose 전에 멈추기
    _animationController.stop();
    _animationController.dispose();

    // 녹음 중인 경우 중지 - 비동기 작업이지만 dispose에서는 await 할 수 없으므로
    // 페이지 나가기 전에 처리했는지 확인하는 것이 중요
    if (_isRecording) {
      // 비동기 작업이지만 dispose에서는 기다릴 수 없음
      // 따라서 _stopRecording() 내부에서 mounted 확인이 중요
      _stopRecording();
    }

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
    final directory = Directory('${Directory.current.path}/Data/TimeEstimationVisual/${userInfo.userNumber}_${userInfo.name}/recordings');
    if (!directory.existsSync()) {
      directory.createSync(recursive: true);
    }

    final filePath = '${directory.path}/TEV_${userInfo.userNumber}_${userInfo.name}_$dateStr.m4a';

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

  void _startTask() {
    targetSeconds = taskTimeList[taskCount - 1];

    _animationController.duration = Duration(seconds: targetSeconds);

    // 본 테스트 모드이고 첫 라운드의 첫 번째 과제일 때만 녹음 시작
    if (!isPracticeMode && currentRound == 1 && taskCount == 1 && !_isRecording) {
      _startRecording();
    }

    _animationController.forward(from: 0.0);
  }

  void _endTask() {
    _animationController.stop();

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
              const Text('사각형이 이동한 시간을 초 단위로 추정해주세요.'),
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

    testResult.addTestData(TestDataTimeEstimationVisual(
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

          // 모든 테스트가 완료되면 녹음 중지 및 결과 저장
          if (!isPracticeMode && _isRecording) {
            _stopRecording();
          }

          _saveTestResults();
          final userInfo = Provider.of<UserStateProvider>(context, listen: false).getUserInfo;
          testResult = TestResultTimeEstimationVisual(userInfo: userInfo!);
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
    userStateProvider.saveTestResultTimeEstimationVisual(
      studentId: userInfo?.userNumber ?? '',
      name: userInfo?.name ?? '',
      testResultTimeEstimationVisual: testResult,
    );
    testResultList = Provider.of<UserStateProvider>(context, listen: false).loadTestResultList(AppTestType.timeEstimationVisual, userInfo);
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
    String path = '${Directory.current.path}/Data/TimeEstimationVisual/${userInfo?.userNumber}_${userInfo?.name}';
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

              child: testResultView(),
            ),
          ),
        ),
      ),
      title: '시각 추정 과제 - 시각적 양식',
    );
  }

  final ScrollController _scrollController = ScrollController();
  Widget testResultView() {
    final userInfo = Provider.of<UserStateProvider>(context).getUserInfo;
    String path = '${Directory.current.path}/Data/TimeEstimationVisual/${userInfo?.userNumber}_${userInfo?.name}';
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
                      final testResult = Provider.of<UserStateProvider>(context, listen: false).loadTestResultTimeEstimationVisual(
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

  Widget resultItem(TestResultTimeEstimationVisual testResult) {
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
            color: isPracticeMode ? Colors.blue : Colors.purple,
          ),
          tooltip: '${isPracticeMode ? "본실험" : "연습"} 모드로 전환 (Tab키)',
        ),
        SizedBox(
          width: MediaQuery.of(context).size.width * 0.01,
        ),
        Text(
          '시각 추정 과제 - ${isPracticeMode ? '연습' : '본실험'}',
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
      return Stack(
        children: [
          Positioned(
            left: _animation.value * MediaQuery.of(context).size.width * 0.9,
            top: MediaQuery.of(context).size.height * 0.3,
            child: Container(
              width: MediaQuery.of(context).size.width * 0.1,
              height: MediaQuery.of(context).size.height * 0.1,
              decoration: BoxDecoration(
                color: Colors.purple,
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ],
      );
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
