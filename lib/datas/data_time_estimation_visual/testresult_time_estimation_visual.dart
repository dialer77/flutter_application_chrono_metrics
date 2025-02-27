import 'package:flutter_application_chrono_metrics/datas/data_time_estimation_visual/testdata_time_estimation_visual.dart';
import 'package:flutter_application_chrono_metrics/datas/user_infomation.dart';

class TestResultTimeEstimationVisual {
  final List<TestDataTimeEstimationVisual> _testDataList = [];
  DateTime testTime = DateTime.now();
  UserInfomation userInfo;
  int taskCount = 4;
  String? _audioFilePath;

  TestResultTimeEstimationVisual({
    required this.userInfo,
  });

  void addTestData(TestDataTimeEstimationVisual testData) {
    _testDataList.add(testData);
  }

  List<TestDataTimeEstimationVisual> get testDataList => _testDataList;

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
