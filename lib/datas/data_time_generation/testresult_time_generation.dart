import 'package:flutter_application_chrono_metrics/datas/data_time_generation/testdata_time_generation.dart';
import 'package:flutter_application_chrono_metrics/datas/user_infomation.dart';

class TestResultTimeGeneration {
  final List<TestDataTimeGeneration> _testDataList = [];
  bool isPracticeMode = false;
  DateTime testTime = DateTime.now();
  UserInfomation userInfo;

  TestResultTimeGeneration({
    required this.userInfo,
  });

  void addTestData(TestDataTimeGeneration testData) {
    _testDataList.add(testData);
  }

  List<TestDataTimeGeneration> get testDataList => _testDataList;

  void setTestTime(DateTime testTime) {
    this.testTime = testTime;
  }
}
