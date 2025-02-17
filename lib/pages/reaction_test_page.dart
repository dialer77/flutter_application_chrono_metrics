import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:audioplayers/audioplayers.dart';
import 'dart:async';
import 'dart:math';

class ReactionTestPage extends StatefulWidget {
  const ReactionTestPage({super.key});

  @override
  State<ReactionTestPage> createState() => _ReactionTestPageState();
}

class _ReactionTestPageState extends State<ReactionTestPage> {
  bool isWaiting = true;
  bool isReady = false;
  bool isTesting = false;
  bool isFinished = false;
  bool isAudioMode = false;
  DateTime? startTime;
  List<int> reactionTimes = [];
  final Random random = Random();
  FocusNode focusNode = FocusNode();
  final int maxRounds = 5;
  final AudioPlayer audioPlayer = AudioPlayer();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      FocusScope.of(context).requestFocus(focusNode);
    });
    _initAudio();
  }

  Future<void> _initAudio() async {
    await audioPlayer.setSource(AssetSource('beep.mp3')); // 실제 파일 이름으로 수정해주세요
    await audioPlayer.setVolume(1.0);
  }

  @override
  void dispose() {
    focusNode.dispose();
    audioPlayer.dispose();
    super.dispose();
  }

  void startTest() {
    if (reactionTimes.length >= maxRounds) {
      setState(() {
        isFinished = true;
      });
      return;
    }

    setState(() {
      isWaiting = false;
      isReady = true;
      isTesting = false;
    });

    Future.delayed(Duration(milliseconds: 1500 + random.nextInt(3500)), () {
      if (mounted && isReady) {
        setState(() {
          isReady = false;
          isTesting = true;
          startTime = DateTime.now();
        });
        if (isAudioMode) {
          audioPlayer.resume(); // 비프음 재생
        }
      }
    });
  }

  void resetTest() {
    setState(() {
      isWaiting = true;
      isReady = false;
      isTesting = false;
      isFinished = false;
      reactionTimes = [];
    });
  }

  void toggleMode() {
    if (!isWaiting) return; // 테스트 중에는 모드 변경 불가
    setState(() {
      isAudioMode = !isAudioMode;
      reactionTimes = []; // 모드 변경시 기록 초기화
    });
  }

  void onSpacePressed() {
    if (isFinished) {
      resetTest();
      return;
    }

    if (isWaiting) {
      startTest();
    } else if (isReady) {
      setState(() {
        isWaiting = true;
        isReady = false;
        isTesting = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('너무 일찍 눌렀습니다! 다시 시도하세요.')),
      );
    } else if (isTesting) {
      final endTime = DateTime.now();
      final reactionTime = endTime.difference(startTime!).inMilliseconds;
      setState(() {
        reactionTimes.add(reactionTime);
        isWaiting = true;
        isTesting = false;
      });

      if (reactionTimes.length >= maxRounds) {
        setState(() {
          isFinished = true;
        });
      }
    }
  }

  String getAverageTime() {
    if (reactionTimes.isEmpty) return '아직 기록이 없습니다';
    final avg = reactionTimes.reduce((a, b) => a + b) / reactionTimes.length;
    return '평균 반응 속도: ${avg.toStringAsFixed(1)}ms';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(isAudioMode ? '청각 반응 속도 테스트 (M)' : '시각 반응 속도 테스트 (M)'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          IconButton(
            icon: Icon(isAudioMode ? Icons.volume_up : Icons.visibility),
            onPressed: toggleMode,
            tooltip: '${isAudioMode ? "시각" : "청각"} 모드로 전환 (M키)',
          ),
        ],
      ),
      body: KeyboardListener(
        focusNode: focusNode,
        onKeyEvent: (KeyEvent event) {
          if (event is KeyDownEvent) {
            if (event.logicalKey == LogicalKeyboardKey.space) {
              onSpacePressed();
            } else if (event.logicalKey == LogicalKeyboardKey.keyM) {
              toggleMode();
            }
          }
        },
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 300,
                height: 300,
                decoration: BoxDecoration(
                  color: isAudioMode
                      ? Colors.blue
                      : isFinished
                          ? Colors.purple
                          : isWaiting
                              ? Colors.blue
                              : isReady
                                  ? Colors.red
                                  : Colors.green,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        isFinished
                            ? '테스트 완료!\n스페이스바를 눌러 재시작'
                            : isAudioMode
                                ? isWaiting
                                    ? '스페이스바를 눌러 테스트 시작'
                                    : '비프음을 기다리세요...\n비프음이 들리면 스페이스바를 누르세요!'
                                : isWaiting
                                    ? '스페이스바를 눌러 시작\n초록색으로 변하면 스페이스바를 누르세요'
                                    : isReady
                                        ? '기다리세요...'
                                        : '스페이스바를 누르세요!',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        '${reactionTimes.length}/$maxRounds 라운드',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 40),
              Text(
                getAverageTime(),
                style: const TextStyle(fontSize: 20),
              ),
              if (reactionTimes.isNotEmpty) ...[
                const SizedBox(height: 20),
                Text(
                  '마지막 기록: ${reactionTimes.last}ms',
                  style: const TextStyle(fontSize: 20),
                ),
                const SizedBox(height: 20),
                ...reactionTimes.asMap().entries.map(
                      (entry) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Text(
                          '${entry.key + 1}번째 시도: ${entry.value}ms',
                          style: const TextStyle(fontSize: 16),
                        ),
                      ),
                    ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
