import 'package:flutter/material.dart';

class IconSpacebar extends StatelessWidget {
  final double fontSize;
  final Color color;

  const IconSpacebar({
    super.key,
    required this.fontSize,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: fontSize * 0.8, vertical: fontSize * 0.06),
      decoration: BoxDecoration(
        border: Border.all(color: color, width: 2),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text('Space', style: TextStyle(color: color, fontSize: fontSize * 0.5)),
    );
  }
}
