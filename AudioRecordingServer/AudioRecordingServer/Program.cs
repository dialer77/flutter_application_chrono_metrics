using System;
using System.IO;
using System.Net;
using System.Net.Sockets;
using System.Text;
using System.Threading;
using NAudio.Wave;
using System.Timers;

class AudioRecordingServer
{
    private static WasapiLoopbackCapture? loopbackCapture;
    private static WaveInEvent? microphoneCapture;
    private static WaveFileWriter? systemAudioWriter;
    private static WaveFileWriter? microphoneWriter;
    private static string? tempSystemAudioFile;
    private static string? tempMicrophoneFile;
    private static string? currentFilePath;
    private static bool isRecording = false;
    private static DateTime recordingStartTime;
    private static readonly object systemWriterLock = new object();
    private static readonly object microphoneWriterLock = new object();
    private static System.Timers.Timer silenceTimer;

    // 이벤트 핸들러 참조 저장
    private static EventHandler<WaveInEventArgs> loopbackDataAvailableHandler;
    private static EventHandler<WaveInEventArgs> microphoneDataAvailableHandler;
    private static EventHandler<StoppedEventArgs> loopbackRecordingStoppedHandler;
    private static EventHandler<StoppedEventArgs> microphoneRecordingStoppedHandler;

    // 클래스 변수 추가
    private static bool isFirstDataReceived = false;
    private static DateTime recordingActualStartTime;
    private static int initialBufferSize = 16000; // 약 0.1초 분량의 초기 버퍼 크기 (추정치)

    static void Main(string[] args)
    {
        Console.OutputEncoding = Encoding.UTF8; // 콘솔 출력 인코딩 설정
        Console.InputEncoding = Encoding.UTF8;  // 콘솔 입력 인코딩 설정

        TcpListener? server = null;
        try
        {
            // 로컬 IP와 포트 설정
            IPAddress localAddr = IPAddress.Parse("127.0.0.1");
            int port = 8888;

            // TCP 리스너 생성
            server = new TcpListener(localAddr, port);

            // 리스닝 시작
            server.Start();

            Console.WriteLine("음성 녹화 서버가 시작되었습니다.");
            Console.WriteLine("클라이언트 연결 대기 중...");

            // 오디오 디바이스 초기화
            InitializeAudioDevices();

            while (true)
            {
                // 클라이언트 연결 수락
                TcpClient client = server.AcceptTcpClient();
                Console.WriteLine("클라이언트가 연결되었습니다.");

                // 클라이언트 처리를 위한 쓰레드 생성
                Thread clientThread = new Thread(() => HandleClient(client));
                clientThread.Start();
            }
        }
        catch (Exception e)
        {
            Console.WriteLine("Exception: {0}", e);
        }
        finally
        {
            StopRecording();
            server?.Stop();
        }
    }

    static void InitializeAudioDevices()
    {
        // 시스템 오디오 캡처 초기화 (스피커 출력)
        loopbackCapture = new WasapiLoopbackCapture();

        // 마이크 캡처 초기화
        microphoneCapture = new WaveInEvent();
        microphoneCapture.DeviceNumber = 0; // 기본 마이크

        Console.WriteLine("오디오 디바이스가 초기화되었습니다.");
    }

    static void StartRecording(string filePath = null)
    {
        if (isRecording)
        {
            StopRecording();
        }

        // 임시 파일 경로 생성
        string tempDir = Path.Combine(Path.GetTempPath(), "AudioRecording_" + DateTime.Now.ToString("yyyyMMdd_HHmmss"));
        Directory.CreateDirectory(tempDir);

        tempSystemAudioFile = Path.Combine(tempDir, "system_audio.wav");
        tempMicrophoneFile = Path.Combine(tempDir, "microphone.wav");
        currentFilePath = filePath;

        recordingStartTime = DateTime.Now;

        // 기존 이벤트 핸들러 제거
        if (loopbackDataAvailableHandler != null)
            loopbackCapture.DataAvailable -= loopbackDataAvailableHandler;
        if (microphoneDataAvailableHandler != null)
            microphoneCapture.DataAvailable -= microphoneDataAvailableHandler;
        if (loopbackRecordingStoppedHandler != null)
            loopbackCapture.RecordingStopped -= loopbackRecordingStoppedHandler;
        if (microphoneRecordingStoppedHandler != null)
            microphoneCapture.RecordingStopped -= microphoneRecordingStoppedHandler;

        // 디바이스 재초기화
        loopbackCapture.Dispose();
        microphoneCapture.Dispose();
        loopbackCapture = new WasapiLoopbackCapture();
        microphoneCapture = new WaveInEvent();
        microphoneCapture.DeviceNumber = 0; // 기본 마이크

        isRecording = true;

        // 시스템 오디오 설정
        systemAudioWriter = new WaveFileWriter(tempSystemAudioFile, loopbackCapture.WaveFormat);

        // 이벤트 핸들러 수정
        loopbackDataAvailableHandler = (s, e) =>
        {
            if (systemAudioWriter != null && isRecording)
            {
                try
                {
                    lock (systemWriterLock)
                    {
                        // 첫 데이터 수신 시 시간 기록
                        if (!isFirstDataReceived && e.BytesRecorded > 0)
                        {
                            isFirstDataReceived = true;
                            recordingActualStartTime = DateTime.Now;
                            TimeSpan delay = recordingActualStartTime - recordingStartTime;
                            Console.WriteLine($"첫 오디오 데이터 수신됨. 녹음 시작 후 {delay.TotalMilliseconds}ms 지연");

                            // 초기 빈 버퍼 계산 - 실제 지연 시간에 맞게 조정
                            // 초기 빈 버퍼 생성 (필요한 경우)
                            if (delay.TotalMilliseconds > 10) // 10ms 이상 지연이 있는 경우만
                            {
                                int bytesPerMs = loopbackCapture.WaveFormat.AverageBytesPerSecond / 1000;
                                int initialBytes = (int)(delay.TotalMilliseconds * bytesPerMs);

                                // 초기 빈 버퍼 생성
                                byte[] initialBuffer = new byte[initialBytes];
                                for (int i = 0; i < initialBytes; i++)
                                {
                                    initialBuffer[i] = 0; // 무음으로 채움
                                }

                                // 초기 버퍼 쓰기
                                systemAudioWriter.Write(initialBuffer, 0, initialBuffer.Length);
                                Console.WriteLine($"초기 무음 버퍼 추가: {initialBytes} 바이트");
                            }
                        }

                        // 일반 데이터 쓰기
                        systemAudioWriter.Write(e.Buffer, 0, e.BytesRecorded == 0 ? initialBufferSize : e.BytesRecorded);
                    }
                }
                catch (Exception ex)
                {
                    Console.WriteLine($"시스템 오디오 처리 중 오류: {ex.Message}");
                }
            }
        };
        loopbackCapture.DataAvailable += loopbackDataAvailableHandler;

        // 마이크 오디오 설정
        microphoneWriter = new WaveFileWriter(tempMicrophoneFile, microphoneCapture.WaveFormat);
        microphoneDataAvailableHandler = (s, e) =>
        {
            if (microphoneWriter != null && isRecording)
            {
                try
                {
                    lock (microphoneWriterLock)
                    {
                        microphoneWriter.Write(e.Buffer, 0, e.BytesRecorded);
                    }
                }
                catch (Exception ex)
                {
                    Console.WriteLine($"마이크 오디오 처리 중 오류: {ex.Message}");
                }
            }
        };
        microphoneCapture.DataAvailable += microphoneDataAvailableHandler;

        // 녹음이 끝날 때 이벤트 처리
        loopbackRecordingStoppedHandler = (s, e) =>
        {
            Console.WriteLine("시스템 오디오 녹음이 중지되었습니다.");
        };
        loopbackCapture.RecordingStopped += loopbackRecordingStoppedHandler;

        microphoneRecordingStoppedHandler = (s, e) =>
        {
            Console.WriteLine("마이크 오디오 녹음이 중지되었습니다.");
        };
        microphoneCapture.RecordingStopped += microphoneRecordingStoppedHandler;

        // 녹음 시작
        try
        {
            loopbackCapture.StartRecording();
            Console.WriteLine("시스템 오디오 녹음이 시작되었습니다.");
        }
        catch (Exception ex)
        {
            Console.WriteLine($"시스템 오디오 녹음 시작 중 오류: {ex.Message}");
        }

        try
        {
            microphoneCapture.StartRecording();
            Console.WriteLine("마이크 오디오 녹음이 시작되었습니다.");
        }
        catch (Exception ex)
        {
            Console.WriteLine($"마이크 오디오 녹음 시작 중 오류: {ex.Message}");
        }

        Console.WriteLine($"녹음 시작됨 (시스템: {tempSystemAudioFile}, 마이크: {tempMicrophoneFile})");
    }

    static void StopRecording(string finalFilePath = null)
    {
        if (!isRecording)
            return;

        isRecording = false;

        // 캡처 중지
        loopbackCapture?.StopRecording();
        microphoneCapture?.StopRecording();

        // 잠시 대기 (모든 이벤트가 처리될 수 있도록)
        Thread.Sleep(500);

        // 파일 라이터 정리
        lock (systemWriterLock)
        {
            if (systemAudioWriter != null)
            {
                systemAudioWriter.Dispose();
                systemAudioWriter = null;
            }
        }

        lock (microphoneWriterLock)
        {
            if (microphoneWriter != null)
            {
                microphoneWriter.Dispose();
                microphoneWriter = null;
            }
        }

        // 최종 파일 경로 결정
        string targetFilePath = finalFilePath ?? currentFilePath ??
            $"recording_{DateTime.Now.ToString("yyyyMMdd_HHmmss")}.wav";

        try
        {
            // 한글 경로 처리를 위한 수정
            try
            {
                // 경로 유효성 검사
                if (!IsValidPath(targetFilePath))
                {
                    Console.WriteLine($"경고: 유효하지 않은 대상 파일 경로. 기본 경로로 대체됩니다.");
                    string timestamp = DateTime.Now.ToString("yyyyMMdd_HHmmss");
                    targetFilePath = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.MyDocuments),
                                               $"AudioRecording_{timestamp}.wav");
                    Console.WriteLine($"수정된 대상 경로: {targetFilePath}");
                }

                // 대상 디렉토리가 없으면 생성
                string directory = Path.GetDirectoryName(targetFilePath);
                if (!string.IsNullOrEmpty(directory) && !Directory.Exists(directory))
                {
                    Directory.CreateDirectory(directory);
                    Console.WriteLine($"대상 디렉토리 생성됨: {directory}");
                }
            }
            catch (Exception ex)
            {
                Console.WriteLine($"대상 경로 처리 중 오류: {ex.Message}");
                string timestamp = DateTime.Now.ToString("yyyyMMdd_HHmmss");
                targetFilePath = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.MyDocuments),
                                           $"AudioRecording_{timestamp}.wav");
                Console.WriteLine($"대체 대상 경로: {targetFilePath}");
            }

            // 개별 파일 저장 경로 생성
            string fileNameWithoutExt = Path.GetFileNameWithoutExtension(targetFilePath);
            string fileExt = Path.GetExtension(targetFilePath);
            string filePath = Path.GetDirectoryName(targetFilePath);

            string systemAudioFilePath = Path.Combine(filePath, fileNameWithoutExt + "_system" + fileExt);
            string microphoneFilePath = Path.Combine(filePath, fileNameWithoutExt + "_mic" + fileExt);

            // 파일 복사 및 저장
            bool systemAudioSaved = false;

            if (File.Exists(tempSystemAudioFile))
            {
                FileInfo info = new FileInfo(tempSystemAudioFile);
                if (info.Length > 0)
                {
                    File.Copy(tempSystemAudioFile, systemAudioFilePath, true);
                    File.Copy(tempSystemAudioFile, targetFilePath, true);
                    Console.WriteLine($"시스템 오디오 저장됨: {systemAudioFilePath} (크기: {info.Length} 바이트)");
                    systemAudioSaved = true;
                }
                else
                {
                    Console.WriteLine("시스템 오디오 파일이 비어 있습니다.");
                }
            }

            if (File.Exists(tempMicrophoneFile))
            {
                FileInfo info = new FileInfo(tempMicrophoneFile);
                if (info.Length > 0)
                {
                    File.Copy(tempMicrophoneFile, microphoneFilePath, true);
                    Console.WriteLine($"마이크 오디오 저장됨: {microphoneFilePath} (크기: {info.Length} 바이트)");

                    // 시스템 오디오가 없으면 마이크 오디오를 기본 파일로 사용
                    if (!systemAudioSaved)
                    {
                        File.Copy(tempMicrophoneFile, targetFilePath, true);
                        Console.WriteLine($"기본 오디오 파일로 마이크 오디오 사용됨: {targetFilePath}");
                    }
                }
                else
                {
                    Console.WriteLine("마이크 오디오 파일이 비어 있습니다.");
                }
            }

            // 시스템 오디오와 마이크 오디오 모두 저장되지 않았다면, 빈 오디오 파일 생성
            if (!File.Exists(targetFilePath))
            {
                using (var writer = new WaveFileWriter(targetFilePath, new WaveFormat(44100, 16, 2)))
                {
                    // 1초 분량의 무음 데이터 생성
                    byte[] silenceBuffer = new byte[44100 * 2 * 2]; // 1초, 스테레오, 16비트
                    writer.Write(silenceBuffer, 0, silenceBuffer.Length);
                }
                Console.WriteLine($"빈 오디오 파일 생성됨: {targetFilePath}");
            }

            // 임시 파일 정리
            try
            {
                if (File.Exists(tempSystemAudioFile))
                    File.Delete(tempSystemAudioFile);
                if (File.Exists(tempMicrophoneFile))
                    File.Delete(tempMicrophoneFile);

                string tempDir = Path.GetDirectoryName(tempSystemAudioFile);
                if (Directory.Exists(tempDir))
                    Directory.Delete(tempDir, true);
            }
            catch (Exception ex)
            {
                Console.WriteLine($"임시 파일 정리 중 오류: {ex.Message}");
            }

            Console.WriteLine($"녹음 완료: {targetFilePath}");
        }
        catch (Exception ex)
        {
            Console.WriteLine($"파일 처리 중 오류 발생: {ex.Message}");

            // 오류 발생 시 백업 저장
            try
            {
                string timestamp = DateTime.Now.ToString("yyyyMMdd_HHmmss");
                string backupPath = Path.Combine(
                    Environment.GetFolderPath(Environment.SpecialFolder.MyDocuments),
                    $"AudioRecording_Backup_{timestamp}.wav");

                if (File.Exists(tempSystemAudioFile))
                {
                    File.Copy(tempSystemAudioFile, backupPath, true);
                    Console.WriteLine($"백업 파일 저장됨: {backupPath}");
                }
            }
            catch (Exception backupEx)
            {
                Console.WriteLine($"백업 저장 중 오류: {backupEx.Message}");
            }
        }

        Console.WriteLine("녹음 중지됨");
    }

    static void MixAudioFiles(string systemAudioFile, string microphoneFile, string outputFile)
    {
        // 먼저 각 파일의 WaveFormat 정보 가져오기
        WaveFormat systemFormat = null;
        WaveFormat micFormat = null;

        using (var reader = new WaveFileReader(systemAudioFile))
        {
            systemFormat = reader.WaveFormat;
        }

        using (var reader = new WaveFileReader(microphoneFile))
        {
            micFormat = reader.WaveFormat;
        }

        Console.WriteLine($"시스템 오디오 형식: {systemFormat}");
        Console.WriteLine($"마이크 오디오 형식: {micFormat}");

        // 대상 형식 정의 (일반적으로 표준 44.1kHz, 16비트, 스테레오 사용)
        WaveFormat targetFormat = new WaveFormat(44100, 16, 2);

        Console.WriteLine($"대상 형식: {targetFormat}");

        // 임시 변환 파일 경로
        string tempConvertedSystemFile = Path.Combine(Path.GetDirectoryName(systemAudioFile), "converted_system.wav");
        string tempConvertedMicFile = Path.Combine(Path.GetDirectoryName(microphoneFile), "converted_mic.wav");

        try
        {
            // 시스템 오디오 변환
            ConvertWaveFile(systemAudioFile, tempConvertedSystemFile, targetFormat);

            // 마이크 오디오 변환
            ConvertWaveFile(microphoneFile, tempConvertedMicFile, targetFormat);

            // 이제 동일한 형식으로 변환된 파일을 믹싱
            using (var systemReader = new AudioFileReader(tempConvertedSystemFile))
            using (var micReader = new AudioFileReader(tempConvertedMicFile))
            {
                // 볼륨 조정 (필요시)
                systemReader.Volume = 1.0f;
                micReader.Volume = 1.0f;

                // 두 소스를 함께 믹스
                using (var mixer = new WaveMixerStream32())
                {
                    mixer.AutoStop = true;
                    mixer.AddInputStream(systemReader);
                    mixer.AddInputStream(micReader);

                    // 출력 파일에 쓰기
                    WaveFileWriter.CreateWaveFile(outputFile, mixer);
                }
            }

            // 임시 변환 파일 삭제
            File.Delete(tempConvertedSystemFile);
            File.Delete(tempConvertedMicFile);

            Console.WriteLine($"오디오 믹스 완료: {outputFile}");
        }
        catch (Exception ex)
        {
            Console.WriteLine($"오디오 믹싱 중 오류 발생: {ex.Message}");

            // 오류 발생 시 기본 파일 복사
            try
            {
                // 기본적으로 시스템 오디오만 사용
                File.Copy(systemAudioFile, outputFile, true);
                Console.WriteLine($"믹싱 실패로 인해 시스템 오디오만 저장: {outputFile}");
            }
            catch
            {
                Console.WriteLine("파일 복사 중 오류 발생");
            }
        }
    }

    static void ConvertWaveFile(string inputFile, string outputFile, WaveFormat targetFormat)
    {
        using (var reader = new WaveFileReader(inputFile))
        {
            // 현재 형식과 대상 형식이 같으면 그대로 복사
            if (reader.WaveFormat.Equals(targetFormat))
            {
                File.Copy(inputFile, outputFile, true);
                return;
            }

            try
            {
                // MediaFoundationResampler로 변환
                using (var resampler = new MediaFoundationResampler(reader, targetFormat))
                {
                    resampler.ResamplerQuality = 60; // 최고 품질
                    WaveFileWriter.CreateWaveFile(outputFile, resampler);
                }
            }
            catch (Exception ex)
            {
                Console.WriteLine($"MediaFoundationResampler 오류: {ex.Message}");

                // ACM resampler로 대체 시도
                try
                {
                    using (var resampler = new WaveFormatConversionStream(targetFormat, reader))
                    {
                        WaveFileWriter.CreateWaveFile(outputFile, resampler);
                    }
                }
                catch
                {
                    // 모든 변환 방법이 실패하면 원본 파일 복사
                    File.Copy(inputFile, outputFile, true);
                    Console.WriteLine("변환 실패, 원본 형식 사용");
                }
            }
        }

        Console.WriteLine($"파일 변환 완료: {outputFile}");
    }

    static void HandleClient(TcpClient client)
    {
        NetworkStream stream = client.GetStream();
        byte[] buffer = new byte[4096]; // 충분한 버퍼 크기 확보
        int bytesRead;

        try
        {
            // 연결된 클라이언트 정보 출력
            Console.WriteLine($"클라이언트 연결됨: {((IPEndPoint)client.Client.RemoteEndPoint).Address}");

            while (client.Connected)
            {
                bytesRead = 0;
                try
                {
                    // 데이터 수신 대기
                    bytesRead = stream.Read(buffer, 0, buffer.Length);
                }
                catch (IOException)
                {
                    // 연결이 끊어진 경우
                    break;
                }

                if (bytesRead == 0)
                {
                    // 연결이 끊어진 경우
                    break;
                }

                // UTF-8 인코딩으로 데이터 해석 (한글 지원)
                string command = Encoding.UTF8.GetString(buffer, 0, bytesRead).Trim();
                Console.WriteLine($"수신된 명령: {command}");

                // 명령 처리
                string response = ProcessCommand(command);

                // UTF-8 인코딩으로 응답 전송 (한글 지원)
                byte[] responseBytes = Encoding.UTF8.GetBytes(response);
                try
                {
                    stream.Write(responseBytes, 0, responseBytes.Length);
                    Console.WriteLine($"응답 전송: {response}");
                }
                catch (IOException)
                {
                    // 전송 중 오류 발생
                    break;
                }
            }
        }
        catch (Exception ex)
        {
            Console.WriteLine($"클라이언트 처리 중 예외 발생: {ex.Message}");
        }
        finally
        {
            // 연결 종료 및 리소스 정리
            client.Close();
            Console.WriteLine("클라이언트 연결 종료");

            // 녹음 중이었다면 중지
            if (isRecording)
            {
                StopRecording();
            }
        }
    }

    static string ProcessCommand(string command)
    {
        // 명령 파싱 및 처리
        if (command.StartsWith("START_RECORDING"))
        {
            // 명령과 경로를 분리 (첫 번째 콜론만 구분자로 사용)
            string filePath = null;
            int colonIndex = command.IndexOf(':');
            if (colonIndex > 0 && colonIndex < command.Length - 1)
            {
                filePath = command.Substring(colonIndex + 1);

                // 한글 경로 처리를 위한 수정
                try
                {
                    // 경로에 디렉토리가 없으면, 만들어줌
                    string directory = Path.GetDirectoryName(filePath);
                    if (!string.IsNullOrEmpty(directory) && !Directory.Exists(directory))
                    {
                        Directory.CreateDirectory(directory);
                        Console.WriteLine($"디렉토리 생성됨: {directory}");
                    }

                    // 경로 확인
                    Console.WriteLine($"녹음 파일 경로: {filePath}");

                    // 잘못된 경로인지 검증
                    if (!IsValidPath(filePath))
                    {
                        Console.WriteLine($"경고: 유효하지 않은 파일 경로. 기본 경로로 대체됩니다.");
                        string timestamp = DateTime.Now.ToString("yyyyMMdd_HHmmss");
                        filePath = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.MyDocuments),
                                               $"AudioRecording_{timestamp}.wav");
                        Console.WriteLine($"수정된 경로: {filePath}");
                    }
                }
                catch (Exception ex)
                {
                    Console.WriteLine($"경로 처리 중 오류: {ex.Message}");
                    string timestamp = DateTime.Now.ToString("yyyyMMdd_HHmmss");
                    filePath = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.MyDocuments),
                                           $"AudioRecording_{timestamp}.wav");
                    Console.WriteLine($"대체 경로: {filePath}");
                }
            }

            // 녹음 시작
            StartRecording(filePath);

            return "RECORDING_STARTED";
        }
        else if (command.StartsWith("STOP_RECORDING"))
        {
            // 명령과 경로를 분리 (첫 번째 콜론만 구분자로 사용)
            string finalFilePath = null;
            int colonIndex = command.IndexOf(':');
            if (colonIndex > 0 && colonIndex < command.Length - 1)
            {
                finalFilePath = command.Substring(colonIndex + 1);
            }

            // 녹음 중지
            StopRecording(finalFilePath);

            return "RECORDING_STOPPED";
        }
        else if (command.Equals("EXIT") || command.Equals("QUIT"))
        {
            // 녹음 중이라면 중지
            if (isRecording)
            {
                StopRecording();
            }

            // 리소스 정리
            loopbackCapture?.Dispose();
            microphoneCapture?.Dispose();

            Console.WriteLine("서버를 종료합니다...");
            Environment.Exit(0);
            return "SERVER_STOPPING";
        }

        return "UNKNOWN_COMMAND";
    }

    // 한글 경로 유효성 검사 함수 추가
    static bool IsValidPath(string path)
    {
        try
        {
            // Path.GetFullPath에서 예외가 발생하지 않으면 유효한 경로로 간주
            string fullPath = Path.GetFullPath(path);

            // 경로 길이 체크 (Windows 260자 제한)
            if (fullPath.Length > 240) // 조금 여유 둠
            {
                Console.WriteLine("경로가 너무 깁니다.");
                return false;
            }

            // 경로에 사용할 수 없는 문자가 있는지 확인
            char[] invalidChars = Path.GetInvalidPathChars();
            if (path.IndexOfAny(invalidChars) >= 0)
            {
                Console.WriteLine("경로에 사용할 수 없는 문자가 포함되어 있습니다.");
                return false;
            }

            return true;
        }
        catch
        {
            return false;
        }
    }
}
