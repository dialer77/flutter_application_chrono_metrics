class TestDataTimeGeneration {
  final int targetTime;
  final int elapsedTime;
  final DateTime testTime;

  TestDataTimeGeneration({
    required this.targetTime,
    required this.elapsedTime,
    DateTime? testTime,
  }) : testTime = testTime ?? DateTime.now();
}
