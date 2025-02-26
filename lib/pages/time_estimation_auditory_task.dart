import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_application_chrono_metrics/commons/common_util.dart';
import 'package:flutter_application_chrono_metrics/commons/enum_defines.dart';
import 'package:flutter_application_chrono_metrics/commons/widgets/record_drawer.dart';
import 'package:flutter_application_chrono_metrics/datas/data_time_estimation_visual/testresult_time_estimation_visual.dart';
import 'package:flutter_application_chrono_metrics/datas/user_infomation.dart';
import 'package:flutter_application_chrono_metrics/metronome_widget.dart';
import 'package:flutter_application_chrono_metrics/pages/page_layout_base.dart';
import 'package:flutter_application_chrono_metrics/providers/user_state_provider.dart';
import 'package:provider/provider.dart';

class TimeEstimationAuditoryTaskPage extends StatefulWidget {
  const TimeEstimationAuditoryTaskPage({super.key});

  @override
  State<TimeEstimationAuditoryTaskPage> createState() => _TimeEstimationAuditoryTaskPageState();
}

class _TimeEstimationAuditoryTaskPageState extends State<TimeEstimationAuditoryTaskPage> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _userNumberController = TextEditingController();
  final MetronomeController _metronomeController = MetronomeController();

  int targetSeconds = 0;
  final List<int> taskTimeList = [3, 6, 12, 30];
  int taskCount = 1;
  final maxTaskCount = 4;
  int currentRound = 1;
  final int maxRounds = 5;

  FocusNode focusNode = FocusNode();
  bool isPracticeMode = true;
  bool isStarted = false;

  List<String> testResultList = [];
  TestResultTimeEstimationVisual testResult = TestResultTimeEstimationVisual(userInfo: UserInfomation(name: '', userNumber: ''));

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
      testResult = TestResultTimeEstimationVisual(userInfo: userInfo!);

      testResultList = Provider.of<UserStateProvider>(context, listen: false).loadTestResultList(AppTestType.timeEstimationVisual, userInfo);
    });
  }

  void _startTask() {}

  void _endTask() {}

  void onSpacePressed() {
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
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return KeyboardListener(
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
    );
  }

  RecordDrawer getRecordDrawer() {
    final userInfo = Provider.of<UserStateProvider>(context).getUserInfo;
    String path = '${Directory.current.path}/Data/TimeEstimationVisual/${userInfo?.userNumber}_${userInfo?.name}';
    return RecordDrawer(
      path: path,
      record: Container(),
      title: '시각 추정 과제 - 청각적 양식',
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
          '시각 추정 과제 - 청각적 양식 / ${isPracticeMode ? '연습 시행' : '본 실험 시행'}',
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
                onSpacePressed();
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
