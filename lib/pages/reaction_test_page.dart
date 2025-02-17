import 'package:flutter/material.dart';
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
  DateTime? startTime;
  List<int> reactionTimes = [];
  final Random random = Random();

  void startTest() {
    setState(() {
      isWaiting = false;
      isReady = true;
      isTesting = false;
    });

    // 1.5초에서 5초 사이의 랜덤한 시간 후에 테스트 시작
    Future.delayed(Duration(milliseconds: 1500 + random.nextInt(3500)), () {
      if (mounted && isReady) {
        setState(() {
          isReady = false;
          isTesting = true;
          startTime = DateTime.now();
        });
      }
    });
  }

  void onTap() {
    if (isWaiting) {
      startTest();
    } else if (isReady) {
      // 너무 일찍 클릭한 경우
      setState(() {
        isWaiting = true;
        isReady = false;
        isTesting = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('너무 일찍 클릭했습니다! 다시 시도하세요.')),
      );
    } else if (isTesting) {
      // 반응 시간 측정
      final endTime = DateTime.now();
      final reactionTime = endTime.difference(startTime!).inMilliseconds;
      setState(() {
        reactionTimes.add(reactionTime);
        isWaiting = true;
        isTesting = false;
      });
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
        title: const Text('반응 속도 테스트'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            GestureDetector(
              onTap: onTap,
              child: Container(
                width: 300,
                height: 300,
                decoration: BoxDecoration(
                  color: isWaiting
                      ? Colors.blue
                      : isReady
                          ? Colors.red
                          : Colors.green,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Center(
                  child: Text(
                    isWaiting
                        ? '클릭하여 시작'
                        : isReady
                            ? '기다리세요...'
                            : '클릭하세요!',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
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
            ],
          ],
        ),
      ),
    );
  }
}
