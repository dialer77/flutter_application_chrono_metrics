import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_application_chrono_metrics/commons/enum_defines.dart';
import 'package:flutter_application_chrono_metrics/datas/data_reaction/testdata_reaction.dart';
import 'package:flutter_application_chrono_metrics/datas/data_time_estimation_auditory/testdata_time_estimation_auditory.dart';
import 'package:flutter_application_chrono_metrics/datas/data_time_estimation_auditory/testresult_time_estimation_auditory.dart';
import 'package:flutter_application_chrono_metrics/datas/data_time_estimation_visual/testdata_time_estimation_visual.dart';
import 'package:flutter_application_chrono_metrics/datas/data_time_estimation_visual/testresult_time_estimation_visual.dart';
import 'package:flutter_application_chrono_metrics/datas/data_time_generation/testdata_time_generation.dart';
import 'package:flutter_application_chrono_metrics/datas/data_time_generation/testresult_time_generation.dart';
import '../datas/user_infomation.dart';
import '../datas/data_reaction/testresult_reaction.dart';
import 'package:intl/intl.dart';

class UserStateProvider extends ChangeNotifier {
  UserInfomation? userInfo; // nullable로 선언

  // userInfo getter
  UserInfomation? get getUserInfo => userInfo;

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
  List<String> loadTestResultList(AppTestType appTestType, UserInfomation? userInfo) {
    UserInfomation loadUserInfo = userInfo ?? getUserInfo!;
    String path = '';
    switch (appTestType) {
      case AppTestType.reaction:
        path = '${Directory.current.path}\\Data\\Reaction\\${loadUserInfo.userNumber}_${loadUserInfo.name}';
        break;
      case AppTestType.timeGeneration:
        path = '${Directory.current.path}\\Data\\TimeGeneration\\${loadUserInfo.userNumber}_${loadUserInfo.name}';
        break;
      case AppTestType.timeEstimationVisual:
        path = '${Directory.current.path}\\Data\\TimeEstimationVisual\\${loadUserInfo.userNumber}_${loadUserInfo.name}';
        break;
      case AppTestType.timeEstimationAuditory:
        path = '${Directory.current.path}\\Data\\TimeEstimationAuditory\\${loadUserInfo.userNumber}_${loadUserInfo.name}';
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
        final fileName = folder.path.split(Platform.pathSeparator).last;
        final resultSplit = fileName.split('_');
        if (resultSplit[0] != 'result') {
          continue;
        }
        csvFiles.add(folder.path.split(Platform.pathSeparator).last);
      }
    }
    return csvFiles.reversed.toList();
  }

  Future<void> saveTestResultReaction({
    required String studentId,
    required String name,
    required TestResultReaction testResultReaction,
    String? audioFilePath, // 음성 파일 경로 추가
  }) async {
    try {
      // 기본 경로 설정
      String basePath = '${Directory.current.path}\\Data\\Reaction';

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

      // 고정된 파일명 사용 (사용자별 하나의 파일)
      File file = File('$userFolderPath/results.csv');
      bool fileExists = await file.exists();

      StringBuffer sb = StringBuffer();

      // 파일이 존재하지 않으면 UTF-8 BOM과 헤더 추가
      if (!fileExists) {
        // UTF-8 BOM 추가
        sb.write('\uFEFF');
        sb.writeln('테스트일시,횟수,자극타입,생성시간(ms),사용자반응시간(ms),음성파일경로');
      }

      // 현재 테스트 시간을 형식화
      String testDateTime = DateFormat('yyyy-MM-dd HH:mm:ss').format(testResultReaction.startTime);

      // 시각 자극 결과 추가
      int count = 1;
      for (var data in testResultReaction.visualTestData) {
        sb.writeln('$testDateTime,$count,시각,${data.targetMilliseconds},${data.resultMilliseconds},${audioFilePath ?? ""}');
        count++;
      }

      // 청각 자극 결과 추가
      count = 1;
      for (var data in testResultReaction.auditoryTestData) {
        sb.writeln('$testDateTime,$count,청각,${data.targetMilliseconds},${data.resultMilliseconds},${audioFilePath ?? ""}');
        count++;
      }

      // 파일이 이미 존재하면 데이터 추가, 아니면 새로 생성
      if (fileExists) {
        await file.writeAsString(sb.toString(), encoding: utf8, mode: FileMode.append);
      } else {
        await file.writeAsString(sb.toString(), encoding: utf8);
      }
    } catch (e) {
      print('테스트 결과 저장 중 오류 발생: $e');
      // 에러를 상위로 전파
    }
  }

  TestResultTimeGeneration loadTestResultTimeGeneration(String filePath, UserInfomation userInfo, bool isPracticeMode) {
    // path 의 파일 명칭 추출

    if (isPracticeMode) {
      var practiceResultTimeGeneration = TestResultTimeGeneration(
        userInfo: userInfo,
      );

      // 파일이 없으면 그냥 반환
      if (!File(filePath).existsSync()) {
        return practiceResultTimeGeneration;
      }

      // filePath 에서 파일 읽기
      String content = File(filePath).readAsStringSync();
      List<String> lines = content.split('\n');
      lines.removeAt(0);

      final DateFormat formatter = DateFormat('yyyy-MM-dd HH:mm:ss');
      for (var line in lines) {
        if (line.isEmpty || line == "") {
          continue;
        }
        final contentSplit = line.split(',');
        practiceResultTimeGeneration.addTestData(TestDataTimeGeneration(
          targetTime: int.parse(contentSplit[1]),
          elapsedTime: int.parse(contentSplit[2]),
          testTime: formatter.parse(contentSplit[3]),
        ));
      }

      return practiceResultTimeGeneration;
    } else {
      String fileName = filePath.split('\\').last;
      // 파일이 없으면 그냥 반환
      TestResultTimeGeneration testResultTimeGeneration = TestResultTimeGeneration(
        userInfo: userInfo,
      );
      if (!File(filePath).existsSync()) {
        return testResultTimeGeneration;
      }

      final resultSplit = fileName.split('_');
      final String dateStr = resultSplit[1];
      final DateTime resultTime = DateTime.parse('${dateStr.substring(0, 4)}-' // year
          '${dateStr.substring(4, 6)}-' // month
          '${dateStr.substring(6, 8)} ' // day
          '${dateStr.substring(8, 10)}:' // hour
          '${dateStr.substring(10, 12)}:' // minute
          '${dateStr.substring(12, 14)}' // second
          );

      testResultTimeGeneration.testTime = resultTime;

      String content = File(filePath).readAsStringSync();
      List<String> lines = content.split('\n');
      lines.removeAt(0);

      for (var line in lines) {
        if (line.isEmpty || line == "") {
          continue;
        }
        final contentSplit = line.split(',');
        testResultTimeGeneration.addTestData(TestDataTimeGeneration(
          targetTime: int.parse(contentSplit[1]),
          elapsedTime: int.parse(contentSplit[2]),
        ));
      }
      return testResultTimeGeneration;
    }
  }

  void saveTestResultTimeGeneration({
    required String studentId,
    required String name,
    required TestResultTimeGeneration testResultTimeGeneration,
    required bool isPracticeMode,
  }) async {
    try {
      // 기본 경로 설정
      String basePath = '${Directory.current.path}\\Data\\TimeGeneration';

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

      late File file;
      StringBuffer sb = StringBuffer();
      // UTF-8 BOM 추가
      sb.write('\uFEFF');
      if (isPracticeMode) {
        String fileName = 'practice_result.csv';
        file = File('$userFolderPath/$fileName');

        sb.writeln('횟수, 생성시간(ms), 사용자추정시간(ms), 테스트시간');
        int count = 1;

        for (var data in testResultTimeGeneration.testDataList) {
          sb.writeln('$count,${data.targetTime},${data.elapsedTime},${DateFormat('yyyy-MM-dd HH:mm:ss').format(data.testTime)}');
          count++;
        }
      } else {
        String timestamp = DateFormat('yyyyMMddHHmmss').format(testResultTimeGeneration.testTime);
        file = File('$userFolderPath/result_$timestamp.csv');

        sb.writeln('횟수, 생성시간(ms), 사용자추정시간(ms)');
        int count = 1;
        int taskCount = testResultTimeGeneration.taskCount;
        for (var data in testResultTimeGeneration.testDataList) {
          sb.writeln('${((count / taskCount) + 1).toStringAsFixed(0)}-${((count % taskCount) + 1).toStringAsFixed(0)},${data.targetTime},${data.elapsedTime}');
          count++;
        }
      }
      // UTF-8로 인코딩하여 파일 저장
      await file.writeAsString(sb.toString(), encoding: utf8);
    } catch (e) {
      // 에러를 상위로 전파
    }
  }

  TestResultTimeEstimationVisual loadTestResultTimeEstimationVisual(String filePath, UserInfomation userInfo) {
    // path 의 파일 명칭 추출

    String fileName = filePath.split('\\').last;
    // 파일이 없으면 그냥 반환
    TestResultTimeEstimationVisual testResultTimeEstimationVisual = TestResultTimeEstimationVisual(
      userInfo: userInfo,
    );
    if (!File(filePath).existsSync()) {
      return testResultTimeEstimationVisual;
    }

    final resultSplit = fileName.split('_');
    final String dateStr = resultSplit[1];
    final DateTime resultTime = DateTime.parse('${dateStr.substring(0, 4)}-' // year
        '${dateStr.substring(4, 6)}-' // month
        '${dateStr.substring(6, 8)} ' // day
        '${dateStr.substring(8, 10)}:' // hour
        '${dateStr.substring(10, 12)}:' // minute
        '${dateStr.substring(12, 14)}' // second
        );

    testResultTimeEstimationVisual.testTime = resultTime;

    String content = File(filePath).readAsStringSync();
    List<String> lines = content.split('\n');
    lines.removeAt(0);

    for (var line in lines) {
      if (line.isEmpty || line == "") {
        continue;
      }
      final contentSplit = line.split(',');
      testResultTimeEstimationVisual.addTestData(TestDataTimeEstimationVisual(
        targetTime: int.parse(contentSplit[1]),
        elapsedTime: int.parse(contentSplit[2]),
      ));
    }
    return testResultTimeEstimationVisual;
  }

  void saveTestResultTimeEstimationVisual({
    required String studentId,
    required String name,
    required TestResultTimeEstimationVisual testResultTimeEstimationVisual,
  }) async {
    try {
      // 기본 경로 설정
      String basePath = '${Directory.current.path}\\Data\\TimeEstimationVisual';

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

      late File file;
      StringBuffer sb = StringBuffer();
      // UTF-8 BOM 추가
      sb.write('\uFEFF');

      String timestamp = DateFormat('yyyyMMddHHmmss').format(testResultTimeEstimationVisual.testTime);
      file = File('$userFolderPath/result_$timestamp.csv');

      sb.writeln('횟수, 생성시간(ms), 사용자추정시간(ms)');
      int count = 0;
      int taskCount = testResultTimeEstimationVisual.taskCount;
      for (var data in testResultTimeEstimationVisual.testDataList) {
        int round = ((count / taskCount) + 1).toInt();
        int task = ((count % taskCount) + 1).toInt();

        sb.writeln('$round-$task,${data.targetTime},${data.elapsedTime}');
        count++;
      }

      // UTF-8로 인코딩하여 파일 저장
      await file.writeAsString(sb.toString(), encoding: utf8);
    } catch (e) {
      // 에러를 상위로 전파
    }
  }

  TestResultTimeEstimationAuditory loadTestResultTimeEstimationAuditory(String filePath, UserInfomation userInfo) {
    // path 의 파일 명칭 추출

    String fileName = filePath.split('\\').last;
    // 파일이 없으면 그냥 반환
    TestResultTimeEstimationAuditory testResultTimeEstimationAuditory = TestResultTimeEstimationAuditory(
      userInfo: userInfo,
    );
    if (!File(filePath).existsSync()) {
      return testResultTimeEstimationAuditory;
    }

    final resultSplit = fileName.split('_');
    final String dateStr = resultSplit[1];
    final DateTime resultTime = DateTime.parse('${dateStr.substring(0, 4)}-' // year
        '${dateStr.substring(4, 6)}-' // month
        '${dateStr.substring(6, 8)} ' // day
        '${dateStr.substring(8, 10)}:' // hour
        '${dateStr.substring(10, 12)}:' // minute
        '${dateStr.substring(12, 14)}' // second
        );

    testResultTimeEstimationAuditory.testTime = resultTime;

    String content = File(filePath).readAsStringSync();
    List<String> lines = content.split('\n');
    lines.removeAt(0);

    for (var line in lines) {
      if (line.isEmpty || line == "") {
        continue;
      }
      final contentSplit = line.split(',');
      testResultTimeEstimationAuditory.addTestData(TestDataTimeEstimationAuditory(
        targetTime: int.parse(contentSplit[1]),
        elapsedTime: int.parse(contentSplit[2]),
      ));
    }
    return testResultTimeEstimationAuditory;
  }

  void saveTestResultTimeEstimationAuditory({
    required String studentId,
    required String name,
    required TestResultTimeEstimationAuditory testResultTimeEstimationAuditory,
  }) async {
    try {
      // 기본 경로 설정
      String basePath = '${Directory.current.path}\\Data\\TimeEstimationAuditory';

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

      late File file;
      StringBuffer sb = StringBuffer();
      // UTF-8 BOM 추가
      sb.write('\uFEFF');

      String timestamp = DateFormat('yyyyMMddHHmmss').format(testResultTimeEstimationAuditory.testTime);
      file = File('$userFolderPath/result_$timestamp.csv');

      sb.writeln('횟수, 생성시간(ms), 사용자추정시간(ms)');
      int count = 0;
      int taskCount = testResultTimeEstimationAuditory.taskCount;
      for (var data in testResultTimeEstimationAuditory.testDataList) {
        int round = ((count / taskCount) + 1).toInt();
        int task = ((count % taskCount) + 1).toInt();

        sb.writeln('$round-$task,${data.targetTime},${data.elapsedTime}');
        count++;
      }

      // UTF-8로 인코딩하여 파일 저장
      await file.writeAsString(sb.toString(), encoding: utf8);
    } catch (e) {
      // 에러를 상위로 전파
    }
  }

  /// 반응 테스트의 결과 파일에서 테스트 결과 목록을 로드합니다.
  /// 각 테스트 세션을 날짜별로 그룹화하여 반환합니다.
  Map<String, List<Map<String, dynamic>>> loadReactionResultsForDrawer(UserInfomation? userInfo) {
    UserInfomation loadUserInfo = userInfo ?? getUserInfo!;

    // 결과 파일 경로
    String userFolderPath = '${Directory.current.path}\\Data\\Reaction\\${loadUserInfo.userNumber}_${loadUserInfo.name}';
    String resultsFilePath = '$userFolderPath\\results.csv';

    // 결과 파일이 없으면 빈 맵 반환
    if (!File(resultsFilePath).existsSync()) {
      return {};
    }

    try {
      // 파일 읽기
      String content = File(resultsFilePath).readAsStringSync();
      List<String> lines = content.split('\n');

      // 헤더 제거 (첫 번째 줄)
      if (lines.isNotEmpty && lines[0].contains('테스트일시')) {
        lines.removeAt(0);
      }

      // 날짜별로 그룹화할 맵
      Map<String, List<Map<String, dynamic>>> resultsByDate = {};

      for (var line in lines) {
        if (line.isEmpty) continue;

        List<String> values = line.split(',');
        if (values.length < 5) continue; // 최소 필요 필드 검사

        String testDateTime = values[0].trim();
        String testDate = testDateTime.split(' ')[0]; // 날짜 부분만 추출
        int count = int.tryParse(values[1]) ?? 0;
        String stimulusType = values[2].trim();
        int targetTime = int.tryParse(values[3]) ?? 0;
        int responseTime = int.tryParse(values[4]) ?? 0;
        String audioFilePath = values.length > 5 ? values[5].trim() : '';

        // 테스트 결과 정보 맵 생성
        Map<String, dynamic> resultInfo = {
          'testDateTime': testDateTime,
          'count': count,
          'stimulusType': stimulusType,
          'targetTime': targetTime,
          'responseTime': responseTime,
          'audioFilePath': audioFilePath
        };

        // 날짜별로 결과 추가
        if (!resultsByDate.containsKey(testDate)) {
          resultsByDate[testDate] = [];
        }
        resultsByDate[testDate]!.add(resultInfo);
      }

      return resultsByDate;
    } catch (e) {
      print('결과 파일 읽기 오류: $e');
      return {};
    }
  }
}
