using System;
using System.IO;
using System.Net;
using System.Net.Sockets;
using System.Text;
using System.Threading;
using NAudio.Wave;

class AudioRecordingServer
{
    private static WasapiLoopbackCapture loopbackCapture;
    private static WaveInEvent microphoneCapture;
    private static WaveFileWriter systemAudioWriter;
    private static WaveFileWriter microphoneWriter;
    private static string tempSystemAudioFile;
    private static string tempMicrophoneFile;
    private static string currentFilePath;
    private static bool isRecording = false;

    static void Main()
    {
        TcpListener server = null;
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
                Thread clientThread = new Thread(new ParameterizedThreadStart(HandleClient));
                clientThread.Start(client);
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

        isRecording = true;

        // 시스템 오디오 설정
        systemAudioWriter = new WaveFileWriter(tempSystemAudioFile, loopbackCapture.WaveFormat);
        loopbackCapture.DataAvailable += (s, e) =>
        {
            if (systemAudioWriter != null && isRecording)
            {
                try
                {
                    systemAudioWriter.Write(e.Buffer, 0, e.BytesRecorded);
                }
                catch (Exception ex)
                {
                    Console.WriteLine($"시스템 오디오 처리 중 오류: {ex.Message}");
                }
            }
        };

        // 마이크 오디오 설정
        microphoneWriter = new WaveFileWriter(tempMicrophoneFile, microphoneCapture.WaveFormat);
        microphoneCapture.DataAvailable += (s, e) =>
        {
            if (microphoneWriter != null && isRecording)
            {
                try
                {
                    microphoneWriter.Write(e.Buffer, 0, e.BytesRecorded);
                }
                catch (Exception ex)
                {
                    Console.WriteLine($"마이크 오디오 처리 중 오류: {ex.Message}");
                }
            }
        };

        // 녹음 시작
        loopbackCapture.StartRecording();
        microphoneCapture.StartRecording();

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

        // 파일 라이터 정리
        if (systemAudioWriter != null)
        {
            systemAudioWriter.Dispose();
            systemAudioWriter = null;
        }

        if (microphoneWriter != null)
        {
            microphoneWriter.Dispose();
            microphoneWriter = null;
        }

        // 최종 파일 경로 결정
        string targetFilePath = finalFilePath ?? currentFilePath ??
            $"recording_{DateTime.Now.ToString("yyyyMMdd_HHmmss")}.wav";

        try
        {
            // 두 오디오 파일을 하나로 결합
            if (File.Exists(tempSystemAudioFile) && File.Exists(tempMicrophoneFile))
            {
                // 대상 디렉토리가 없으면 생성
                string directory = Path.GetDirectoryName(targetFilePath);
                if (!string.IsNullOrEmpty(directory) && !Directory.Exists(directory))
                {
                    Directory.CreateDirectory(directory);
                }

                // 두 파일을 혼합하여 최종 파일 생성
                MixAudioFiles(tempSystemAudioFile, tempMicrophoneFile, targetFilePath);

                // 개별 파일 저장 경로 생성
                string fileNameWithoutExt = Path.GetFileNameWithoutExtension(targetFilePath);
                string fileExt = Path.GetExtension(targetFilePath);
                string filePath = Path.GetDirectoryName(targetFilePath);

                string systemAudioFilePath = Path.Combine(filePath, fileNameWithoutExt + "_system" + fileExt);
                string microphoneFilePath = Path.Combine(filePath, fileNameWithoutExt + "_mic" + fileExt);

                // 개별 파일 저장 (임시 파일을 최종 위치로 복사)
                File.Copy(tempSystemAudioFile, systemAudioFilePath, true);
                File.Copy(tempMicrophoneFile, microphoneFilePath, true);

                Console.WriteLine($"시스템 오디오 저장됨: {systemAudioFilePath}");
                Console.WriteLine($"마이크 오디오 저장됨: {microphoneFilePath}");

                // 임시 파일 삭제
                File.Delete(tempSystemAudioFile);
                File.Delete(tempMicrophoneFile);
                Directory.Delete(Path.GetDirectoryName(tempSystemAudioFile), true);

                Console.WriteLine($"녹음 완료: {targetFilePath}");
            }
        }
        catch (Exception ex)
        {
            Console.WriteLine($"파일 처리 중 오류 발생: {ex.Message}");
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

    static void HandleClient(object obj)
    {
        TcpClient client = (TcpClient)obj;
        NetworkStream stream = client.GetStream();

        byte[] buffer = new byte[1024];
        int bytesRead;

        try
        {
            // 클라이언트로부터 데이터 수신
            while ((bytesRead = stream.Read(buffer, 0, buffer.Length)) != 0)
            {
                string data = Encoding.ASCII.GetString(buffer, 0, bytesRead);
                Console.WriteLine("수신한 명령: {0}", data);

                // 명령 처리
                string response = ProcessCommand(data);

                // 응답 전송
                byte[] responseBytes = Encoding.ASCII.GetBytes(response);
                stream.Write(responseBytes, 0, responseBytes.Length);
            }
        }
        catch (Exception e)
        {
            Console.WriteLine("Exception: {0}", e);
        }
        finally
        {
            client.Close();
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

        return "UNKNOWN_COMMAND";
    }
}
