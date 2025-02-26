import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_application_chrono_metrics/commons/common_util.dart';
import 'package:flutter_application_chrono_metrics/commons/enum_defines.dart';
import 'package:flutter_application_chrono_metrics/datas/data_reaction/testresult_reaction.dart';
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
            const Text(
              '연습 과제',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
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

  Widget _buildTimeGenerationContent() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Time Generation Test Results',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 16),
          Text('Target time: XX seconds'),
          Text('Generated time: XX seconds'),
          Text('Accuracy: XX%'),
        ],
      ),
    );
  }

  Widget _buildTimeEstimationVisualContent() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Visual Time Estimation Test Results',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 16),
          Text('Target duration: XX seconds'),
          Text('Estimated duration: XX seconds'),
          Text('Estimation error: XX%'),
        ],
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

  Widget _buildTimeEstimationAuditoryContent() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Auditory Time Estimation Test Results',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 16),
          Text('Target duration: XX seconds'),
          Text('Estimated duration: XX seconds'),
          Text('Estimation error: XX%'),
        ],
      ),
    );
  }
}
