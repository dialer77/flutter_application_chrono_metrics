import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_application_chrono_metrics/commons/common_util.dart';
import 'package:flutter_application_chrono_metrics/commons/enum_defines.dart';
import 'package:flutter_application_chrono_metrics/datas/data_reaction/testresult_reaction.dart';
import 'package:flutter_application_chrono_metrics/datas/data_time_estimation_auditory/testresult_time_estimation_auditory.dart';
import 'package:flutter_application_chrono_metrics/datas/data_time_estimation_visual/testresult_time_estimation_visual.dart';
import 'package:flutter_application_chrono_metrics/datas/data_time_generation/testresult_time_generation.dart';
import 'package:flutter_application_chrono_metrics/datas/user_infomation.dart';
import 'package:flutter_application_chrono_metrics/providers/user_state_provider.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

class TestResultPage extends StatefulWidget {
  const TestResultPage({super.key});

  @override
  State<TestResultPage> createState() => _TestResultPageState();
}

class _TestResultPageState extends State<TestResultPage> {
  AppTestType _selectedTestType = AppTestType.timeEstimationAuditory;
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _userNumberController = TextEditingController();
  List<String> testResultList = [];
  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await CommonUtil.showUserInfoDialog(
        context: context,
        nameController: _nameController,
        userNumberController: _userNumberController,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: LayoutBuilder(
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
                  child: headerWidget(),
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
                            child: Column(
                              children: [
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    // Reaction 버튼
                                    Expanded(
                                      child: InkWell(
                                        onTap: () {
                                          setState(() {
                                            _selectedTestType = AppTestType.reaction;
                                            final userInfo = Provider.of<UserStateProvider>(context, listen: false).getUserInfo;
                                            testResultList = Provider.of<UserStateProvider>(context, listen: false).loadTestResultList(AppTestType.reaction, userInfo);
                                          });
                                        },
                                        child: Container(
                                          margin: const EdgeInsets.symmetric(horizontal: 2),
                                          padding: const EdgeInsets.symmetric(vertical: 10),
                                          decoration: BoxDecoration(
                                            border: Border.all(
                                              color: Colors.grey,
                                              width: 1,
                                            ),
                                            color: _selectedTestType == AppTestType.reaction ? Colors.blue.withOpacity(0.2) : Colors.transparent,
                                          ),
                                          child: Text(
                                            '동작 반응성 속도 측정',
                                            textAlign: TextAlign.center,
                                            style: TextStyle(
                                              fontWeight: _selectedTestType == AppTestType.reaction ? FontWeight.bold : FontWeight.normal,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),

                                    // Time Generation 버튼
                                    Expanded(
                                      child: InkWell(
                                        onTap: () {
                                          setState(() {
                                            _selectedTestType = AppTestType.timeGeneration;
                                            final userInfo = Provider.of<UserStateProvider>(context, listen: false).getUserInfo;
                                            testResultList = Provider.of<UserStateProvider>(context, listen: false).loadTestResultList(AppTestType.timeGeneration, userInfo);
                                          });
                                        },
                                        child: Container(
                                          margin: const EdgeInsets.symmetric(horizontal: 2),
                                          padding: const EdgeInsets.symmetric(vertical: 10),
                                          decoration: BoxDecoration(
                                            border: Border.all(
                                              color: Colors.grey,
                                              width: 1,
                                            ),
                                            color: _selectedTestType == AppTestType.timeGeneration ? Colors.blue.withOpacity(0.2) : Colors.transparent,
                                          ),
                                          child: Text(
                                            '시간 생성',
                                            textAlign: TextAlign.center,
                                            style: TextStyle(
                                              fontWeight: _selectedTestType == AppTestType.timeGeneration ? FontWeight.bold : FontWeight.normal,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),

                                    // Time Estimation Visual 버튼
                                    Expanded(
                                      child: InkWell(
                                        onTap: () {
                                          setState(() {
                                            _selectedTestType = AppTestType.timeEstimationVisual;
                                            final userInfo = Provider.of<UserStateProvider>(context, listen: false).getUserInfo;
                                            testResultList = Provider.of<UserStateProvider>(context, listen: false).loadTestResultList(AppTestType.timeEstimationVisual, userInfo);
                                          });
                                        },
                                        child: Container(
                                          margin: const EdgeInsets.symmetric(horizontal: 2),
                                          padding: const EdgeInsets.symmetric(vertical: 10),
                                          decoration: BoxDecoration(
                                            border: Border.all(
                                              color: Colors.grey,
                                              width: 1,
                                            ),
                                            color: _selectedTestType == AppTestType.timeEstimationVisual ? Colors.blue.withOpacity(0.2) : Colors.transparent,
                                          ),
                                          child: Text(
                                            '시간 추정 - 시각',
                                            textAlign: TextAlign.center,
                                            style: TextStyle(
                                              fontWeight: _selectedTestType == AppTestType.timeEstimationVisual ? FontWeight.bold : FontWeight.normal,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),

                                    // Time Estimation Auditory 버튼
                                    Expanded(
                                      child: InkWell(
                                        onTap: () {
                                          setState(() {
                                            _selectedTestType = AppTestType.timeEstimationAuditory;
                                            final userInfo = Provider.of<UserStateProvider>(context, listen: false).getUserInfo;
                                            testResultList = Provider.of<UserStateProvider>(context, listen: false).loadTestResultList(AppTestType.timeEstimationAuditory, userInfo);
                                          });
                                        },
                                        child: Container(
                                          margin: const EdgeInsets.symmetric(horizontal: 2),
                                          padding: const EdgeInsets.symmetric(vertical: 10),
                                          decoration: BoxDecoration(
                                            border: Border.all(
                                              color: Colors.grey,
                                              width: 1,
                                            ),
                                            color: _selectedTestType == AppTestType.timeEstimationAuditory ? Colors.blue.withOpacity(0.2) : Colors.transparent,
                                          ),
                                          child: Text(
                                            '시간 추정 - 청각',
                                            textAlign: TextAlign.center,
                                            style: TextStyle(
                                              fontWeight: _selectedTestType == AppTestType.timeEstimationAuditory ? FontWeight.bold : FontWeight.normal,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                SizedBox(
                                  width: constraints.maxWidth,
                                  height: constraints.maxHeight * 0.7,
                                  child: _buildSelectedTestContent(),
                                ),
                              ],
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
    );
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
        const Icon(
          Icons.note,
          size: 50,
          color: Colors.blue,
        ),
        SizedBox(
          width: MediaQuery.of(context).size.width * 0.01,
        ),
        const Text(
          '반응 기록',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildSelectedTestContent() {
    switch (_selectedTestType) {
      case AppTestType.reaction:
        return _buildReactionContent();
      case AppTestType.timeGeneration:
        return _buildTimeGenerationContent();
      case AppTestType.timeEstimationVisual:
        return _buildTimeEstimationVisualContent();
      case AppTestType.timeEstimationAuditory:
        return _buildTimeEstimationAuditoryContent();
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildReactionContent() {
    final userInfo = Provider.of<UserStateProvider>(context).getUserInfo;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(8),
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '이름 : ${userInfo?.name} 학번 : ${userInfo?.userNumber}',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const Divider(),
            reactionResult(
              '${Directory.current.path}/Data/Reaction/${userInfo?.userNumber}_${userInfo?.name}',
              userInfo,
            ),
          ],
        ),
      ),
    );
  }

  Widget reactionResult(String path, UserInfomation? userInfo) {
    return Column(
      children: Provider.of<UserStateProvider>(context, listen: false).loadTestResultList(AppTestType.reaction, userInfo).map((result) {
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

  Widget _buildTimeGenerationContent() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Flexible(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '연습 과제',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const Divider(),
                  practiceResult(),
                ],
              ),
            ),
          ),
          Flexible(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  const Text(
                    '본 실험 과제',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const Divider(),
                  testResult(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget practiceResult() {
    final userInfo = Provider.of<UserStateProvider>(context).getUserInfo;
    final practiceResultTimeGeneration = Provider.of<UserStateProvider>(context, listen: false).loadTestResultTimeGeneration(
      '${Directory.current.path}/Data/TimeGeneration/${userInfo?.userNumber}_${userInfo?.name}/practice_result.csv',
      userInfo!,
      true,
    );
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
                  width: MediaQuery.of(context).size.width * 0.06,
                  child: const Text('생성시간 : '),
                ),
                SizedBox(
                    width: MediaQuery.of(context).size.width * 0.06,
                    child: Text(
                      '${result.targetTime}ms',
                    )),
                SizedBox(
                  width: MediaQuery.of(context).size.width * 0.06,
                  child: const Text('추정시간 : '),
                ),
                SizedBox(
                    width: MediaQuery.of(context).size.width * 0.06,
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
                  width: MediaQuery.of(context).size.width * 0.06,
                  child: Text('${(index ~/ testResult.taskCount + 1).toStringAsFixed(0)} - ${((index % testResult.taskCount).toInt() + 1).toStringAsFixed(0)}'),
                ),
                SizedBox(
                  width: MediaQuery.of(context).size.width * 0.06,
                  child: const Text('생성시간 : '),
                ),
                SizedBox(
                  width: MediaQuery.of(context).size.width * 0.06,
                  child: Text('${data.targetTime}ms'),
                ),
                SizedBox(
                  width: MediaQuery.of(context).size.width * 0.06,
                  child: const Text('추정시간 : '),
                ),
                SizedBox(
                  width: MediaQuery.of(context).size.width * 0.06,
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

  Widget _buildTimeEstimationVisualContent() {
    final userInfo = Provider.of<UserStateProvider>(context).getUserInfo;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(8),
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '이름 : ${userInfo?.name} 학번 : ${userInfo?.userNumber}',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const Divider(),
            testResultViewTimeEstimationVisual(),
          ],
        ),
      ),
    );
  }

  Widget testResultViewTimeEstimationVisual() {
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
                        resultItemTimeEstimationVisual(testResult),
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

  Widget resultItemTimeEstimationVisual(TestResultTimeEstimationVisual testResult) {
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

  Widget _buildTimeEstimationAuditoryContent() {
    final userInfo = Provider.of<UserStateProvider>(context).getUserInfo;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(8),
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '이름 : ${userInfo?.name} 학번 : ${userInfo?.userNumber}',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const Divider(),
            testResultViewTimeEstimationVisual(),
          ],
        ),
      ),
    );
  }

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
                        resultItemTimeEstimationAuditory(testResult),
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

  Widget resultItemTimeEstimationAuditory(TestResultTimeEstimationAuditory testResult) {
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
}
