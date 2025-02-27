import 'package:flutter_application_chrono_metrics/commons/audio_recording_client.dart';
import 'dart:io';

/// 전역에서 AudioRecordingClient에 접근할 수 있는 싱글톤 매니저 클래스
class AudioRecordingManager {
  // 싱글톤 인스턴스
  static final AudioRecordingManager _instance = AudioRecordingManager._internal();

  // 팩토리 생성자
  factory AudioRecordingManager() {
    return _instance;
  }

  // 내부 생성자
  AudioRecordingManager._internal();

  // AudioRecordingClient 인스턴스
  late AudioRecordingClient _client;

  // 클라이언트 인스턴스가 초기화되었는지 여부
  bool _isInitialized = false;

  // 마지막 초기화 설정 정보 저장
  String _host = '127.0.0.1';
  int _port = 8888;
  String _serverPath = 'Server/AudioRecordingServer.exe';
  String _serverProcessName = 'AudioRecordingServer';

  /// 초기화 - 앱 시작시 호출해야 함
  Future<bool> initialize({
    String serverPath = 'Server/AudioRecordingServer.exe',
    String serverProcessName = 'AudioRecordingServer',
    String host = '127.0.0.1',
    int port = 8888,
  }) async {
    _host = host;
    _port = port;
    _serverPath = serverPath;
    _serverProcessName = serverProcessName;

    if (_isInitialized) {
      // 이미 초기화되어 있지만 연결이 끊어진 경우 재연결 시도
      if (!_client.isConnected) {
        return await _client.reconnect();
      }
      return true;
    }

    _client = AudioRecordingClient(serverPath: serverPath, serverProcessName: serverProcessName);

    bool initialized = await _client.initialize(host, port);
    _isInitialized = initialized;
    return initialized;
  }

  /// 연결 상태 확인 및 필요시 재연결
  Future<bool> ensureConnected() async {
    if (!_isInitialized) {
      return await initialize(serverPath: _serverPath, serverProcessName: _serverProcessName, host: _host, port: _port);
    }

    if (!_client.isConnected) {
      return await _client.reconnect();
    }

    return true;
  }

  /// 클라이언트 인스턴스 가져오기
  AudioRecordingClient get client {
    if (!_isInitialized) {
      print('경고: AudioRecordingManager가 초기화되지 않았습니다. 사용 전에 initialize()를 호출하세요.');
    }
    return _client;
  }

  /// 연결 상태 확인
  bool get isConnected => _isInitialized && _client.isConnected;

  /// 녹음 시작
  Future<bool> startRecording(String filePath) async {
    if (!_isInitialized) {
      print('AudioRecordingManager가 초기화되지 않았습니다.');
      bool initialized = await initialize(serverPath: _serverPath, serverProcessName: _serverProcessName, host: _host, port: _port);
      if (!initialized) return false;
    }

    // 연결 상태 확인 및 필요시 재연결
    if (!await ensureConnected()) {
      return false;
    }

    return _client.startRecording(filePath);
  }

  /// 녹음 중지
  Future<bool> stopRecording(String filePath) async {
    if (!_isInitialized) {
      return false;
    }

    // 연결 상태 확인 및 필요시 재연결
    if (!await ensureConnected()) {
      return false;
    }

    return _client.stopRecording(filePath);
  }

  /// 연결 해제
  void disconnect() {
    if (_isInitialized) {
      _client.disconnect();
    }
  }

  /// 서버 프로세스 종료
  Future<bool> stopServer() async {
    if (!_isInitialized) return false;

    // 먼저 연결 종료
    disconnect();

    try {
      if (Platform.isWindows) {
        // Windows에서 taskkill 명령어로 프로세스 종료
        final result = await Process.run('taskkill', ['/F', '/IM', '$_serverProcessName.exe']);
        print('서버 종료 결과: ${result.stdout}');
        if (result.stderr.toString().isNotEmpty) {
          print('서버 종료 오류: ${result.stderr}');
        }
        return result.exitCode == 0;
      } else {
        // 다른 플랫폼(Linux, macOS 등)에서 killall 명령어로 종료
        final result = await Process.run('killall', [_serverProcessName]);
        return result.exitCode == 0;
      }
    } catch (e) {
      print('서버 종료 중 오류: $e');
      return false;
    }
  }

  /// 앱 종료 시 호출되어야 함
  Future<void> cleanup() async {
    if (_isInitialized) {
      // 연결 해제
      disconnect();
      // 서버 프로세스 종료
      await stopServer();
    }
  }
}
