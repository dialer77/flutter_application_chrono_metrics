import 'dart:io';
import 'dart:convert';
import 'dart:async'; // Timer 추가

class AudioRecordingClient {
  Socket? _socket;
  bool _isConnected = false;
  final String _serverPath;
  final String _serverProcessName;
  Timer? _connectionCheckTimer; // 연결 상태 주기적 확인용 타이머
  String _lastConnectedHost = '';
  int _lastConnectedPort = 0;
  int _reconnectAttempts = 0; // 재연결 시도 횟수
  final int _maxReconnectAttempts = 5; // 최대 재연결 시도 횟수

  AudioRecordingClient({String serverPath = 'lib/CSharp/AudioRecordingServer.exe', String serverProcessName = 'AudioRecordingServer'})
      : _serverPath = serverPath,
        _serverProcessName = serverProcessName;

  /// 서버 프로세스가 실행 중인지 확인
  Future<bool> isServerRunning() async {
    try {
      if (Platform.isWindows) {
        // Windows에서 tasklist 명령어로 프로세스 확인
        ProcessResult result = await Process.run('tasklist', ['/FI', 'IMAGENAME eq $_serverProcessName.exe', '/FO', 'CSV']);
        String output = result.stdout.toString();
        // 출력에 프로세스 이름이 포함되어 있으면 실행 중
        return output.contains(_serverProcessName);
      } else {
        // 다른 플랫폼(Linux, macOS 등)에서 ps 명령어로 확인
        ProcessResult result = await Process.run('ps', ['-e']);
        String output = result.stdout.toString();
        return output.contains(_serverProcessName);
      }
    } catch (e) {
      print('프로세스 확인 중 오류: $e');
      return false;
    }
  }

  /// 서버 프로그램 실행
  Future<bool> startServer() async {
    try {
      // 현재 실행 경로를 기준으로 서버 경로 구성
      final currentDir = Directory.current.path;
      final serverFullPath = '$currentDir/$_serverPath';

      File serverFile = File(serverFullPath);
      if (!await serverFile.exists()) {
        print('서버 실행 파일이 존재하지 않습니다: $serverFullPath');
        return false;
      }

      print('서버 실행 시도: ${serverFile.absolute.path}');

      // 서버 디렉토리 확인
      final serverDir = serverFile.parent;
      print('서버 디렉토리: ${serverDir.path}');

      // Process.run으로 변경하여 실행 (Process.start 대신)
      final result = await Process.run(
        serverFile.absolute.path,
        [],
        runInShell: true,
        workingDirectory: serverDir.path,
      );

      print('서버 실행 결과: 종료 코드 ${result.exitCode}');
      print('서버 표준 출력: ${result.stdout}');

      if (result.stderr.toString().isNotEmpty) {
        print('서버 오류 출력: ${result.stderr}');
      }

      // Process.start로 백그라운드 실행 (실행 파일만 지정)
      final process = await Process.start(
        serverFile.absolute.path,
        [],
        runInShell: true,
        workingDirectory: serverDir.path,
      );

      process.stdout.transform(utf8.decoder).listen((data) {
        print('서버 출력: $data');
      });

      process.stderr.transform(utf8.decoder).listen((data) {
        print('서버 오류: $data');
      });

      // 서버 시작 대기
      await Future.delayed(const Duration(seconds: 3));

      // 실행 후 서버 프로세스 확인
      bool isRunning = await isServerRunning();
      print('서버 실행 상태 확인: $isRunning');

      return isRunning;
    } catch (e) {
      print('서버 실행 중 오류: $e');
      print('오류 스택 트레이스: ${StackTrace.current}');
      return false;
    }
  }

  /// 서버 연결 초기화 (프로세스 체크, 필요시 시작, 연결)
  Future<bool> initialize(String host, int port) async {
    try {
      // 서버 실행 여부 확인
      bool isRunning = await isServerRunning();

      // 서버가 실행 중이 아니면 시작
      if (!isRunning) {
        print('음성 녹음 서버가 실행 중이 아닙니다. 서버를 시작합니다...');
        bool started = await startServer();
        if (!started) {
          print('서버 시작 실패');
          return false;
        }
        print('음성 녹음 서버 시작 완료');
      } else {
        print('음성 녹음 서버가 이미 실행 중입니다');
      }

      // 서버에 연결
      bool connected = await connect(host, port);

      if (connected) {
        _lastConnectedHost = host;
        _lastConnectedPort = port;
        _reconnectAttempts = 0;

        // 연결 상태 주기적 확인 타이머 시작
        _startConnectionCheckTimer();
      }

      return connected;
    } catch (e) {
      print('초기화 중 오류: $e');
      return false;
    }
  }

  // 연결 상태 주기적 확인 타이머 설정
  void _startConnectionCheckTimer() {
    _connectionCheckTimer?.cancel();
    _connectionCheckTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      if (!_isConnected) {
        print('연결이 끊어졌습니다. 재연결을 시도합니다...');
        reconnect();
      }
    });
  }

  /// 서버 재연결 시도
  Future<bool> reconnect() async {
    if (_isConnected) return true;
    if (_lastConnectedHost.isEmpty || _lastConnectedPort == 0) return false;

    if (_reconnectAttempts >= _maxReconnectAttempts) {
      print('최대 재연결 시도 횟수($_maxReconnectAttempts)를 초과했습니다.');
      return false;
    }

    _reconnectAttempts++;
    print('재연결 시도 $_reconnectAttempts/$_maxReconnectAttempts...');

    // 서버 프로세스 확인 및 필요시 재시작
    bool isRunning = await isServerRunning();
    if (!isRunning) {
      print('서버가 종료되었습니다. 서버를 재시작합니다...');
      bool started = await startServer();
      if (!started) {
        print('서버 재시작 실패');
        return false;
      }
      await Future.delayed(const Duration(seconds: 2)); // 서버 시작 대기
    }

    // 재연결 시도
    bool connected = await connect(_lastConnectedHost, _lastConnectedPort);
    if (connected) {
      _reconnectAttempts = 0;
      print('서버에 성공적으로 재연결되었습니다.');
    }

    return connected;
  }

  Future<bool> connect(String host, int port) async {
    try {
      // 이미 연결되어 있으면 기존 연결 종료
      if (_isConnected) {
        _socket?.close();
        _socket = null;
        _isConnected = false;
      }

      _socket = await Socket.connect(host, port);
      _isConnected = true;

      // 서버 응답 수신 리스너
      _socket!.listen(
        (List<int> data) {
          String response = utf8.decode(data);
          print('서버 응답: $response');
        },
        onError: (error) {
          print('소켓 에러: $error');
          _isConnected = false;
          _socket = null;
        },
        onDone: () {
          print('서버 연결 종료');
          _isConnected = false;
          _socket = null;
        },
      );

      print('음성 녹음 서버에 연결되었습니다');
      return true;
    } catch (e) {
      print('연결 실패: $e');
      return false;
    }
  }

  /// 명령 전송 전 연결 상태 확인 및 필요시 재연결
  Future<bool> _ensureConnected() async {
    if (_isConnected) return true;
    return await reconnect();
  }

  Future<bool> startRecording(String filePath) async {
    // 연결 상태 확인 및 필요시 재연결
    if (!await _ensureConnected()) {
      print('서버에 연결할 수 없습니다');
      return false;
    }

    try {
      _socket!.write('START_RECORDING:$filePath');
      print('녹음 시작 명령 전송: $filePath');
      return true;
    } catch (e) {
      print('명령 전송 실패: $e');
      return false;
    }
  }

  Future<bool> stopRecording(String filePath) async {
    // 연결 상태 확인 및 필요시 재연결
    if (!await _ensureConnected()) {
      print('서버에 연결할 수 없습니다');
      return false;
    }

    try {
      _socket!.write('STOP_RECORDING:$filePath');
      print('녹음 중지 명령 전송: $filePath');
      return true;
    } catch (e) {
      print('명령 전송 실패: $e');
      return false;
    }
  }

  Future<bool> getStatus() async {
    // 연결 상태 확인 및 필요시 재연결
    if (!await _ensureConnected()) {
      print('서버에 연결할 수 없습니다');
      return false;
    }

    try {
      _socket!.write('GET_STATUS');
      return true;
    } catch (e) {
      print('명령 전송 실패: $e');
      return false;
    }
  }

  void disconnect() {
    _connectionCheckTimer?.cancel();
    _connectionCheckTimer = null;

    if (_isConnected) {
      _socket?.close();
      _socket = null;
      _isConnected = false;
      print('서버 연결 종료');
    }
  }

  bool get isConnected => _isConnected;
}
