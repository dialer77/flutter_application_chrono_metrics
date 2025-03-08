import 'package:flutter/material.dart';
import 'dart:async';
import 'package:just_audio/just_audio.dart';

class MetronomeWidget extends StatefulWidget {
  /// 초기 BPM 값
  final int initialBpm;

  /// 메트로놈 위젯의 높이
  final double height;

  /// 메트로놈 위젯의 너비
  final double width;

  /// 메트로놈 색상 테마
  final Color primaryColor;

  /// 메트로놈 막대 색상
  final Color stickColor;

  /// 메트로놈 베이스 색상
  final Color baseColor;

  /// 메트로놈 상단 원 색상
  final Color knobColor;

  /// 커스텀 클릭 사운드 경로 (null이면 기본 사운드 사용)
  final String? customSoundPath;

  /// 메트로놈 컨트롤러
  final MetronomeController? controller;

  final bool isAuditoryMode;

  const MetronomeWidget({
    super.key,
    this.initialBpm = 60,
    this.height = 300,
    this.width = 200,
    this.primaryColor = Colors.blue,
    this.stickColor = const Color(0xFF5D4037),
    this.baseColor = const Color(0xFFD7CCC8),
    this.knobColor = Colors.red,
    this.customSoundPath,
    this.controller,
    this.isAuditoryMode = false,
  });

  @override
  _MetronomeWidgetState createState() => _MetronomeWidgetState();
}

class _MetronomeWidgetState extends State<MetronomeWidget> with SingleTickerProviderStateMixin {
  late int bpm;
  bool isPlaying = false;
  Timer? _timer;
  final AudioPlayer _audioPlayer = AudioPlayer();
  // 청각 모드용 추가 오디오 플레이어
  final AudioPlayer _startAudioPlayer = AudioPlayer();
  final AudioPlayer _movementAudioPlayer = AudioPlayer();
  final AudioPlayer _completionAudioPlayer = AudioPlayer();
  late AnimationController _animationController;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    bpm = widget.initialBpm;

    _animationController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );

    _animation = Tween<double>(begin: -0.25, end: 0.25).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeInOut,
      ),
    );

    _loadSound();

    // 컨트롤러가 있으면 연결
    widget.controller?._state = this;
  }

  Future<void> _loadSound() async {
    try {
      if (widget.isAuditoryMode) {
        // 청각 모드용 사운드 로드
        await _startAudioPlayer.setAsset('assets/start.mp3');
        await _movementAudioPlayer.setAsset('assets/movement.wav');
        await _completionAudioPlayer.setAsset('assets/finish.mp3');
      } else if (widget.customSoundPath != null) {
        await _audioPlayer.setAsset('assets/${widget.customSoundPath}');
      } else {
        await _audioPlayer.setAsset('assets/beep.mp3');
      }
    } catch (e) {
      debugPrint('메트로놈 사운드 로드 실패: $e');
    }
  }

  void _startMetronome() {
    if (isPlaying) return;

    setState(() {
      isPlaying = true;
    });

    // 청각 모드일 경우 사이클 시작
    if (widget.isAuditoryMode) {
      _startAuditoryModeCycle();
    } else {
      _startMetronomeTimer();
    }
  }

  void _startMetronomeTimer() {
    // BPM에 따른 간격 계산 (밀리초)
    int interval = (60 / bpm * 1000).round();

    // 일반 모드: 타이머로 지속적인 메트로놈 동작
    _timer = Timer.periodic(Duration(milliseconds: interval), (timer) {
      _playClick();
      _animationController.forward().then((_) {
        _animationController.reverse();
      });
    });
  }

  // 청각 모드에서 사이클 시작
  void _startAuditoryModeCycle() {
    if (!isPlaying) return;

    // 시작 사운드 재생 후 움직임 실행
    _playStartSound().then((_) {
      if (!isPlaying) return; // 재생 중간에 정지된 경우

      // 움직임 소리 재생하고 애니메이션 실행
      _playMovementSound();
      _animationController.forward().then((_) {
        return _animationController.reverse();
      }).then((_) {
        if (!isPlaying) return; // 재생 중간에 정지된 경우

        // 완료 소리 재생 후 잠시 대기한 다음 사이클 반복
        _playCompletionSound().then((_) {
          if (!isPlaying) return;

          // 1초 후 다시 사이클 시작
          Future.delayed(const Duration(seconds: 1), () {
            if (isPlaying) {
              _startAuditoryModeCycle();
            }
          });
        });
      });
    });
  }

  void _stopMetronome() {
    if (!isPlaying) return;

    setState(() {
      isPlaying = false;
    });

    _timer?.cancel();
    _timer = null;
    _animationController.reset();
  }

  void _playClick() async {
    try {
      await _audioPlayer.seek(Duration.zero);
      await _audioPlayer.play();
    } catch (e) {
      debugPrint('메트로놈 사운드 재생 실패: $e');
    }
  }

  // 청각 모드용 사운드 재생 함수들
  Future<void> _playStartSound() async {
    try {
      await _startAudioPlayer.seek(Duration.zero);
      await _startAudioPlayer.play();
      // 시작 사운드가 끝날 때까지 대기
      await Future.delayed(_startAudioPlayer.duration ?? Duration.zero);
    } catch (e) {
      debugPrint('시작 사운드 재생 실패: $e');
    }
  }

  void _playMovementSound() async {
    try {
      await _movementAudioPlayer.seek(Duration.zero);
      await _movementAudioPlayer.play();
    } catch (e) {
      debugPrint('이동 사운드 재생 실패: $e');
    }
  }

  Future<void> _playCompletionSound() async {
    try {
      await _completionAudioPlayer.seek(Duration.zero);
      await _completionAudioPlayer.play();
      // 완료 사운드가 끝날 때까지 대기
      await Future.delayed(_completionAudioPlayer.duration ?? Duration.zero);
    } catch (e) {
      debugPrint('완료 사운드 재생 실패: $e');
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _audioPlayer.dispose();
    // 청각 모드용 플레이어 정리
    _startAudioPlayer.dispose();
    _movementAudioPlayer.dispose();
    _completionAudioPlayer.dispose();
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: widget.width,
      height: widget.height,
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16.0),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            spreadRadius: 1,
          ),
        ],
      ),
      child: SizedBox(
        height: widget.height * 0.7,
        width: widget.width * 0.9,
        child: AnimatedBuilder(
          animation: _animation,
          builder: (context, child) {
            return Stack(
              alignment: Alignment.center,
              children: [
                // 메트로놈 피라미드 바디
                CustomPaint(
                  size: Size(widget.width * 0.9, widget.height * 0.7),
                  painter: PyramidMetronomePainter(
                    baseColor: widget.baseColor,
                    primaryColor: widget.primaryColor,
                  ),
                ),

                // 메트로놈 막대 - 중앙을 통과하여 아래까지 이어짐
                Center(
                  child: Transform.rotate(
                    angle: _animation.value,
                    // 회전 중심점을 피라미드 중간으로 설정
                    origin: Offset(0, widget.height * 0.3),
                    alignment: Alignment.center,
                    child: Container(
                      // 막대 길이를 충분히 길게 설정하여 전체 피라미드를 가로지르도록 함
                      height: widget.height * 0.7,
                      width: 3,
                      decoration: BoxDecoration(
                        color: widget.stickColor,
                        borderRadius: BorderRadius.circular(2),
                      ),
                      alignment: Alignment.topCenter,
                      child: Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          color: widget.knobColor,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                  ),
                ),

                // 청각 모드일 때 좌측에 시작음 재생 버튼 추가
                if (widget.isAuditoryMode)
                  Positioned(
                    top: 10,
                    left: widget.width * 0.5, // 가로 길이의 1/5 위치
                    child: Column(
                      children: [
                        InkWell(
                          onTap: _playStartSound,
                          child: Container(
                            padding: const EdgeInsets.all(8.0),
                            decoration: BoxDecoration(
                              color: widget.primaryColor.withOpacity(0.8),
                              borderRadius: BorderRadius.circular(8.0),
                            ),
                            child: const Icon(
                              Icons.play_circle_outline,
                              color: Colors.white,
                              size: 45,
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '시작음',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: widget.primaryColor,
                          ),
                        ),
                      ],
                    ),
                  ),

                // 청각 모드일 때 우측에 종료음 재생 버튼 추가
                if (widget.isAuditoryMode)
                  Positioned(
                    top: 10,
                    right: widget.width * 0.5, // 가로 길이의 1/5 위치 (오른쪽에서)
                    child: Column(
                      children: [
                        InkWell(
                          onTap: _playCompletionSound,
                          child: Container(
                            padding: const EdgeInsets.all(8.0),
                            decoration: BoxDecoration(
                              color: widget.primaryColor.withOpacity(0.8),
                              borderRadius: BorderRadius.circular(8.0),
                            ),
                            child: const Icon(
                              Icons.play_circle_outline,
                              color: Colors.white,
                              size: 45,
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '종료음',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: widget.primaryColor,
                          ),
                        ),
                      ],
                    ),
                  ),

                // 청각 모드일 때 왼쪽에 텍스트 내용 인터페이스 추가

                Positioned(
                  top: widget.height * 0.3, // 상단에서 약 25% 위치
                  left: 0,
                  child: Container(
                    width: MediaQuery.of(context).size.width * 0.325, // 적절한 너비
                    padding: const EdgeInsets.all(10.0),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.9),
                      borderRadius: BorderRadius.circular(10.0),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 4,
                          spreadRadius: 1,
                        ),
                      ],
                      border: Border.all(
                        color: widget.primaryColor.withOpacity(0.3),
                        width: 1.5,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                          decoration: BoxDecoration(
                            color: widget.primaryColor.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(4.0),
                          ),
                          child: Text(
                            '안내 사항',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: widget.primaryColor,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          widget.isAuditoryMode
                              ? '지금부터 소리가 나는 동안 시간을 세어볼게요\n'
                                  '이 두 개의 알림음 사이에 들리는 소리의 시간을 재어볼게요.\n'
                                  '이건 추가 움직이는 1초의 소리를 의미합니다.\n'
                                  '박자에 맞춰 1초의 소리를 기억해주세요.\n'
                                  '충분히 연습하셨으면 스페이스바를 눌러주세요.\n'
                                  '한 번 연습해보실께요.'
                              : '지금부터 화면에 띵 소리와 함께 추가 양쪽으로 움직일 거예요\n'
                                  '한번 움직일 때 1초입니다. 박자에 맞춰 기억해주세요\n'
                                  '충분히 연습하셨으면 스페이스바를 눌러주세요.\n'
                                  '한 번 연습해보실께요.',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.black87,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // 하단 중앙에 텍스트 추가
                Positioned(
                  bottom: 10, // 하단에서의 간격
                  left: 10,
                  right: 10,
                  child: Container(
                    padding: const EdgeInsets.all(8.0),
                    child: Text(
                      '충분히 연습하셨으면 본 검사를 진행하겠습니다.\n'
                      'Tab 키를 눌러 본 검사모드로 전환해주세요.',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: widget.primaryColor,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

// 피라미드형 메트로놈을 그리는 CustomPainter
class PyramidMetronomePainter extends CustomPainter {
  final Color baseColor;
  final Color primaryColor;

  PyramidMetronomePainter({
    required this.baseColor,
    required this.primaryColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final double width = size.width;
    final double height = size.height;

    // 나무 질감 효과를 위한 그라데이션
    final Paint woodPaint = Paint()
      ..shader = LinearGradient(
        colors: [
          baseColor,
          baseColor.withRed((baseColor.red - 20).clamp(0, 255)),
        ],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ).createShader(Rect.fromLTWH(0, 0, width, height));

    // 피라미드 바디 그리기
    final Path pyramidPath = Path();
    pyramidPath.moveTo(width * 0.5, 0); // 상단 중앙
    pyramidPath.lineTo(width * 0.15, height); // 왼쪽 하단 (더 넓게)
    pyramidPath.lineTo(width * 0.85, height); // 오른쪽 하단 (더 넓게)
    pyramidPath.close();

    // 나무 질감 효과 추가
    canvas.drawPath(pyramidPath, woodPaint);

    // 피라미드 테두리
    final Paint borderPaint = Paint()
      ..color = Colors.brown.shade700
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    canvas.drawPath(pyramidPath, borderPaint);

    // 상단 나무 마감
    final Paint topWoodPaint = Paint()..color = Colors.brown.shade300;

    final Path topPath = Path();
    topPath.moveTo(width * 0.4, 0);
    topPath.lineTo(width * 0.6, 0);
    topPath.lineTo(width * 0.55, height * 0.05);
    topPath.lineTo(width * 0.45, height * 0.05);
    topPath.close();

    canvas.drawPath(topPath, topWoodPaint);

    // 중앙 눈금 패널 (온도계 스타일)
    final Paint panelPaint = Paint()..color = Colors.black87;

    final Rect panelRect = Rect.fromLTRB(
      width * 0.45,
      height * 0.15,
      width * 0.55,
      height * 0.85,
    );

    canvas.drawRect(panelRect, panelPaint);

    // 눈금 그리기
    final Paint scalePaint = Paint()
      ..color = Colors.white
      ..strokeWidth = 1;

    final double scaleHeight = height * 0.7;
    final double startY = height * 0.15;
    const int numMarks = 15; // 눈금 수

    for (int i = 0; i <= numMarks; i++) {
      final double y = startY + (scaleHeight / numMarks) * i;
      final double lineWidth = i % 5 == 0 ? width * 0.05 : width * 0.03;

      canvas.drawLine(
        Offset(width * 0.5 - lineWidth / 2, y),
        Offset(width * 0.5 + lineWidth / 2, y),
        scalePaint,
      );

      // 주요 눈금에 숫자 표시
      if (i % 5 == 0 && i > 0 && i < numMarks) {
        final TextPainter textPainter = TextPainter(
          text: TextSpan(
            text: '${40 + i * 10}',
            style: const TextStyle(color: Colors.white, fontSize: 9),
          ),
          textDirection: TextDirection.ltr,
        );

        textPainter.layout();
        textPainter.paint(
          canvas,
          Offset(width * 0.5 + width * 0.06, y - 4),
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// 메트로놈 컨트롤러 - 외부에서 메트로놈을 제어하기 위한 클래스
class MetronomeController {
  _MetronomeWidgetState? _state;

  /// 메트로놈 시작
  void start() {
    _state?._startMetronome();
  }

  /// 메트로놈 정지
  void stop() {
    _state?._stopMetronome();
  }

  /// 현재 재생 상태 확인
  bool get isPlaying => _state?.isPlaying ?? false;

  /// 현재 BPM 값 가져오기
  int? get currentBpm => _state?.bpm;

  /// BPM 값 설정하기
  set setBpm(int newBpm) {
    if (_state != null) {
      final bool wasPlaying = _state!.isPlaying;
      if (wasPlaying) {
        _state!._stopMetronome();
      }

      _state!.setState(() {
        _state!.bpm = newBpm.clamp(30, 300);
      });

      if (wasPlaying) {
        _state!._startMetronome();
      }
    }
  }
}
