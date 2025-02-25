import 'package:flutter_application_chrono_metrics/datas/user_infomation.dart';
import 'package:flutter_application_chrono_metrics/datas/data_reaction/testdata_reaction.dart';

class TestResultReaction {
  UserInfomation userInfo;
  DateTime startTime;
  List<TestDataReaction> visualTestData = [];
  List<TestDataReaction> auditoryTestData = [];

  TestResultReaction({
    required this.userInfo,
    required this.startTime,
  });

  void addVisualTestData(TestDataReaction testData) {
    visualTestData.add(testData);
  }

  void addAuditoryTestData(TestDataReaction testData) {
    auditoryTestData.add(testData);
  }

  // 청각 평균 반응 시간
  double auditoryAverageTime() {
    return auditoryTestData.map((e) => e.resultMilliseconds).reduce((a, b) => a + b) / auditoryTestData.length;
  }

  // 시각 평균 반응 시간
  double visualAverageTime() {
    return visualTestData.map((e) => e.resultMilliseconds).reduce((a, b) => a + b) / visualTestData.length;
  }
}
