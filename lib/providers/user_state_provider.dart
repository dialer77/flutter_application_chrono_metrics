import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_application_chrono_metrics/commons/enum_defines.dart';
import 'package:flutter_application_chrono_metrics/datas/testdata_reaction.dart';
import '../datas/user_infomation.dart';
import '../datas/testresult_reaction.dart';
import 'package:intl/intl.dart';

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

  TestResultReaction loadTestResultReaction(String filePath, UserInfomation userInfo) {
    // path 의 파일 명칭 추출
    String fileName = filePath.split('/').last;

    final resultSplit = fileName.split('_');
    final String dateStr = resultSplit[1];
    final DateTime resultTime = DateTime.parse('${dateStr.substring(0, 4)}-' // year
        '${dateStr.substring(4, 6)}-' // month
        '${dateStr.substring(6, 8)} ' // day
        '${dateStr.substring(8, 10)}:' // hour
        '${dateStr.substring(10, 12)}:' // minute
        '${dateStr.substring(12, 14)}' // second
        );

    TestResultReaction testResultReaction = TestResultReaction(
      startTime: resultTime,
      userInfo: userInfo,
    );

    // 파일 읽기
    String content = File(filePath).readAsStringSync();
    List<String> lines = content.split('\n');
    lines.removeAt(0);

    for (var line in lines) {
      final contentSplit = line.split(',');
      final type = contentSplit[0].split('_')[0];

      if (type == '시각') {
        testResultReaction.visualTestData.add(TestDataReaction(
          targetMilliseconds: int.parse(contentSplit[1]),
          resultMilliseconds: int.parse(contentSplit[2]),
        ));
      } else if (type == '청각') {
        testResultReaction.auditoryTestData.add(TestDataReaction(
          targetMilliseconds: int.parse(contentSplit[1]),
          resultMilliseconds: int.parse(contentSplit[2]),
        ));
      }
    }

    return testResultReaction;
  }

  // load test result reaction
  List<String> loadTestResultListReaction(AppTestType appTestType, UserInfomation? userInfo) {
    UserInfomation loadUserInfo = userInfo ?? getUserInfo!;
    String path = '';
    switch (appTestType) {
      case AppTestType.reaction:
        path = '${Directory.current.path}/Data/Reaction/${loadUserInfo.userNumber}_${loadUserInfo.name}';
        break;
      case AppTestType.timegeneration:
        path = '${Directory.current.path}/Data/TimeGeneration/${loadUserInfo.userNumber}_${loadUserInfo.name}';
        break;
    }

    if (!Directory(path).existsSync()) {
      return [];
    }

    Directory dir = Directory(path);
    List<FileSystemEntity> folders = dir.listSync();

    // csv 파일 목록 읽어서 반환
    List<String> csvFiles = [];
    for (var folder in folders) {
      if (folder is File && folder.path.endsWith('.csv')) {
        csvFiles.add(folder.path.split(Platform.pathSeparator).last);
      }
    }
    return csvFiles.reversed.toList();
  }

  Future<void> saveTestResultReaction({
    required String studentId,
    required String name,
    required TestResultReaction testResultReaction,
  }) async {
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
      String timestamp = DateFormat('yyyyMMddHHmmss').format(testResultReaction.startTime);
      File file = File('$userFolderPath/result_$timestamp.csv');

      StringBuffer sb = StringBuffer();
      // UTF-8 BOM 추가
      sb.write('\uFEFF');
      sb.writeln('횟수, 생성시간(ms), 사용자추정시간(ms)');
      int count = 1;
      for (var data in testResultReaction.visualTestData) {
        sb.writeln('시각_$count, ${data.targetMilliseconds}, ${data.resultMilliseconds}');
        count++;
      }

      count = 1;
      for (var data in testResultReaction.auditoryTestData) {
        sb.writeln('청각_$count, ${data.targetMilliseconds}, ${data.resultMilliseconds}');
        count++;
      }

      // UTF-8로 인코딩하여 파일 저장
      await file.writeAsString(sb.toString(), encoding: utf8);
    } catch (e) {
      // 에러를 상위로 전파
    }
  }
}
