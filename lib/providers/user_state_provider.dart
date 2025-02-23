import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_application_chrono_metrics/datas/testdata_reaction.dart';
import '../datas/user_infomation.dart';
import '../datas/testresult_reaction.dart';

class UserStateProvider extends ChangeNotifier {
  List<int> reactionTimes = [];
  UserInfomation? userInfo; // nullable로 선언

  // userInfo getter
  UserInfomation? get getUserInfo => userInfo;

  // 반응 시간 기록 추가
  void addReactionTime(int reactionTime) {
    reactionTimes.add(reactionTime);
    notifyListeners();
  }

  // 유저 정보 설정
  void setUserInfo(UserInfomation info) {
    userInfo = info;
    notifyListeners();
  }

  TestResultReaction? _testResultReaction;

  TestResultReaction? get getTestResultReaction => _testResultReaction;
  set setTestResultReaction(TestResultReaction? testResultReaction) {
    _testResultReaction = testResultReaction;
    notifyListeners();
  }

  // load test result reaction
  Future<void> loadTestResultReaction() async {
    // 파일 로드 csv 파일 로드

    // 실행폴더 상위의 Data 폴더에 있는 Reaction 폴더의 내용을 불러옴
    String path = '${Directory.current.path}/Data/Reaction';
    Directory dir = Directory(path);

    // 디렉토리 내의 모든 폴더 목록을 가져옴
    List<FileSystemEntity> folders = dir.listSync();

    for (var folder in folders) {
      if (folder is Directory) {
        // 폴더 경로에서 마지막 부분(폴더 이름)만 추출
        String folderName = folder.path.split(Platform.pathSeparator).last;

        // "_"를 기준으로 학번과 이름 분리
        List<String> parts = folderName.split('_');
        if (parts.length == 2) {
          String studentId = parts[0];
          String name = parts[1];

          // TODO: 여기서 추출된 studentId와 name을 활용하여 필요한 처리 수행
          print('학번: $studentId, 이름: $name');
        }
      }
    }
  }

  Future<void> saveTestResultReaction({required String studentId, required String name}) async {
    try {
      // 기본 경로 설정
      String basePath = '${Directory.current.path}/Data/Reaction';

      // Data/Reaction 폴더가 없으면 생성
      Directory baseDir = Directory(basePath);
      if (!await baseDir.exists()) {
        await baseDir.create(recursive: true);
      }

      // 학번_이름 형식의 폴더 경로 생성
      String userFolderPath = '$basePath/${studentId}_$name';
      Directory userDir = Directory(userFolderPath);

      // 사용자 폴더가 없으면 생성
      if (!await userDir.exists()) {
        await userDir.create();
      }

      // 여기에 실제 파일 저장 로직 추가
      // 예시: 타임스탬프를 사용한 파일 이름
      String timestamp = DateTime.now().millisecondsSinceEpoch.toString();
      File file = File('$userFolderPath/result_$timestamp.txt');
      await file.writeAsString('');
    } catch (e) {
      print('Error saving test result: $e');
      rethrow; // 에러를 상위로 전파
    }
  }
}
