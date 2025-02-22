import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:just_audio/just_audio.dart';
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
  late AudioPlayer player;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      FocusScope.of(context).requestFocus(focusNode);
    });
    _initAudio();
  }

  Future<void> _initAudio() async {
    player = AudioPlayer();
    final audioSource = AudioSource.asset('assets/beep.mp3');
    await player.setAudioSource(audioSource);
    await player.setVolume(1.0);
  }

  @override
  void dispose() {
    player.dispose();
    focusNode.dispose();
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

    Future.delayed(Duration(milliseconds: 1500 + random.nextInt(3500)), () async {
      if (!mounted || !isReady) return;

      setState(() {
        isReady = false;
        isTesting = true;
        startTime = DateTime.now();
      });

      if (isAudioMode) {
        try {
          await player.seek(Duration.zero);
          await player.play();
        } catch (e) {
          print('Audio playback error: $e');
          if (mounted) {
            setState(() {
              isWaiting = true;
              isReady = false;
              isTesting = false;
            });
          }
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
        title: const Text('동작 반응성 속도 측정'),
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
        child: LayoutBuilder(
          builder: (context, constraints) {
            return Padding(
              padding: EdgeInsets.only(
                left: constraints.maxWidth * 0.05,
                right: constraints.maxWidth * 0.05,
                bottom: constraints.maxHeight * 0.05,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    height: constraints.maxHeight * 0.1,
                    child: Row(
                      children: [
                        IconButton(
                          onPressed: toggleMode,
                          icon: Icon(
                            isAudioMode ? Icons.volume_up : Icons.visibility,
                            size: 50,
                            color: isAudioMode ? Colors.blue : Colors.purple,
                          ),
                          tooltip: '${isAudioMode ? "청각" : "시각"} 모드로 전환 (M키)',
                        ),
                        SizedBox(
                          width: constraints.maxWidth * 0.01,
                        ),
                        Text(
                          isAudioMode ? '청각 모드' : '시각 모드',
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          height: constraints.maxHeight * 0.6,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: isAudioMode ? Colors.blue : Colors.purple,
                              width: 2,
                            ),
                          ),
                          child: Center(
                            child: isTesting && isAudioMode == false
                                ? Icon(
                                    Icons.star,
                                    size: constraints.maxHeight * 0.3,
                                    color: Colors.red,
                                  )
                                : testGuideText(24, Colors.blue),
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(
                    height: constraints.maxHeight * 0.05,
                    child: Center(
                      child: Text(
                        '${reactionTimes.length}/$maxRounds 라운드',
                        style: TextStyle(
                          color: isAudioMode ? Colors.blue : Colors.purple,
                          fontSize: 18,
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isAudioMode ? Colors.blue : Colors.purple,
                          width: 2,
                        ),
                      ),
                      child: const SingleChildScrollView(
                        child: Row(
                          children: [
                            Text('test'),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Text testGuideText(double fontSize, Color color) {
    TextStyle textStyle = TextStyle(
      color: color,
      fontSize: fontSize,
      fontWeight: FontWeight.bold,
    );

    if (isFinished) {
      return Text('테스트 완료!\n스페이스바를 눌러 재시작', textAlign: TextAlign.center, style: textStyle);
    }

    if (isAudioMode) {
      if (isWaiting) {
        return Text('비프음을 기다리세요...\n비프음이 들리면 스페이스바를 누르세요!', textAlign: TextAlign.center, style: textStyle);
      } else {
        return Text('비프음이 들리면 스페이스바를 누르세요!', textAlign: TextAlign.center, style: textStyle);
      }
    }

    if (isWaiting) {
      return Text('스페이스바를 눌러 테스트 시작', textAlign: TextAlign.center, style: textStyle);
    } else if (isReady) {
      return Text('준비되었습니다!\n스페이스바를 눌러 테스트 시작', textAlign: TextAlign.center, style: textStyle);
    } else if (isTesting) {
      return Text('별이 나오면 스페이스바를 누르세요!', textAlign: TextAlign.center, style: textStyle);
    }

    return Text(
      isFinished
          ? '테스트 완료!\n스페이스바를 눌러 재시작'
          : isAudioMode
              ? isWaiting
                  ? '스페이스바를 눌러 테스트 시작'
                  : '비프음을 기다리세요...\n비프음이 들리면 스페이스바를 누르세요!'
              : isWaiting
                  ? '스페이스바를 눌러 시작\n별이 나오면 스페이스바를 누르세요'
                  : isReady
                      ? ''
                      : '스페이스바를 누르세요!',
      textAlign: TextAlign.center,
      style: const TextStyle(
        color: Colors.blue,
        fontSize: 24,
        fontWeight: FontWeight.bold,
      ),
    );
  }
}
