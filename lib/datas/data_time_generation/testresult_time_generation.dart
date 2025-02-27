import 'package:flutter_application_chrono_metrics/datas/data_time_generation/testdata_time_generation.dart';
import 'package:flutter_application_chrono_metrics/datas/user_infomation.dart';

class TestResultTimeGeneration {
  final List<TestDataTimeGeneration> _testDataList = [];
  bool isPracticeMode = false;
  DateTime testTime = DateTime.now();
  UserInfomation userInfo;
  int taskCount = 5;
  String? _audioFilePath;

  TestResultTimeGeneration({
    required this.userInfo,
    DateTime? startTime,
    this.taskCount = 5,
    this.isPracticeMode = false,
  }) {
    if (startTime != null) {
      testTime = startTime;
    }
  }

  void addTestData(TestDataTimeGeneration testData) {
    _testDataList.add(testData);
  }

  List<TestDataTimeGeneration> get testDataList => _testDataList;

  void setTestTime(DateTime testTime) {
    this.testTime = testTime;
  }

  void setTaskCount(int taskCount) {
    this.taskCount = taskCount;
  }

  String? get audioFilePath => _audioFilePath;

  void setAudioFilePath(String path) {
    _audioFilePath = path;
  }
}
