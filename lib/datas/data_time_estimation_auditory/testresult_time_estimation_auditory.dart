import 'package:flutter_application_chrono_metrics/datas/data_time_estimation_auditory/testdata_time_estimation_auditory.dart';
import 'package:flutter_application_chrono_metrics/datas/user_infomation.dart';

class TestResultTimeEstimationAuditory {
  final List<TestDataTimeEstimationAuditory> _testDataList = [];
  DateTime testTime = DateTime.now();
  UserInfomation userInfo;
  int taskCount = 4;
  String? _audioFilePath; // 오디오 파일 경로 추가

  TestResultTimeEstimationAuditory({
    required this.userInfo,
  });

  void addTestData(TestDataTimeEstimationAuditory testData) {
    _testDataList.add(testData);
  }

  List<TestDataTimeEstimationAuditory> get testDataList => _testDataList;

  void setTestTime(DateTime testTime) {
    this.testTime = testTime;
  }

  void setTaskCount(int taskCount) {
    this.taskCount = taskCount;
  }

  // 오디오 파일 경로 getter
  String? get audioFilePath => _audioFilePath;

  // 오디오 파일 경로 setter
  void setAudioFilePath(String path) {
    _audioFilePath = path;
  }
}
