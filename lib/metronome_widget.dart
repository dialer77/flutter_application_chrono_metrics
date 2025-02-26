import 'package:flutter/material.dart';
import 'dart:async';
import 'package:audioplayers/audioplayers.dart';

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

  const MetronomeWidget({
    Key? key,
    this.initialBpm = 60,
    this.height = 600,
    this.width = 200,
    this.primaryColor = Colors.blue,
    this.stickColor = const Color(0xFF5D4037),
    this.baseColor = const Color(0xFFD7CCC8),
    this.knobColor = Colors.red,
    this.customSoundPath,
  }) : super(key: key);

  @override
  _MetronomeWidgetState createState() => _MetronomeWidgetState();
}

class _MetronomeWidgetState extends State<MetronomeWidget> with SingleTickerProviderStateMixin {
  late int bpm;
  bool isPlaying = false;
  Timer? _timer;
  final AudioPlayer _audioPlayer = AudioPlayer();
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
  }

  Future<void> _loadSound() async {
    if (widget.customSoundPath != null) {
      await _audioPlayer.setSource(AssetSource(widget.customSoundPath!));
    } else {
      await _audioPlayer.setSource(AssetSource('sounds/click.mp3'));
    }
  }

  void _startMetronome() {
    if (isPlaying) return;

    setState(() {
      isPlaying = true;
    });

    // BPM에 따른 간격 계산 (밀리초)
    int interval = (60 / bpm * 1000).round();

    _timer = Timer.periodic(Duration(milliseconds: interval), (timer) {
      _playClick();
      _animationController.forward().then((_) {
        _animationController.reverse();
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
    await _audioPlayer.stop();
    await _audioPlayer.resume();
  }

  void _increaseBPM() {
    if (bpm < 300) {
      setState(() {
        bpm += 1;
      });
      if (isPlaying) {
        _stopMetronome();
        _startMetronome();
      }
    }
  }

  void _decreaseBPM() {
    if (bpm > 30) {
      setState(() {
        bpm -= 1;
      });
      if (isPlaying) {
        _stopMetronome();
        _startMetronome();
      }
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _audioPlayer.dispose();
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
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          // 메트로놈 애니메이션
          Container(
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
                  ],
                );
              },
            ),
          ),
          const SizedBox(height: 10),
          // BPM 표시
          Text(
            'BPM: $bpm',
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          // BPM 조절 버튼
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildCircleButton(
                icon: Icons.remove,
                onPressed: _decreaseBPM,
                color: widget.primaryColor,
              ),
              const SizedBox(width: 16),
              _buildCircleButton(
                icon: isPlaying ? Icons.stop : Icons.play_arrow,
                onPressed: isPlaying ? _stopMetronome : _startMetronome,
                color: isPlaying ? Colors.red : Colors.green,
                size: 50,
              ),
              const SizedBox(width: 16),
              _buildCircleButton(
                icon: Icons.add,
                onPressed: _increaseBPM,
                color: widget.primaryColor,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCircleButton({
    required IconData icon,
    required VoidCallback onPressed,
    required Color color,
    double size = 40,
  }) {
    return SizedBox(
      width: size,
      height: size,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          shape: const CircleBorder(),
          padding: EdgeInsets.zero,
          backgroundColor: color,
          foregroundColor: Colors.white,
        ),
        child: Icon(icon),
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
    final int numMarks = 15; // 눈금 수

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
            style: TextStyle(color: Colors.white, fontSize: 9),
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
