import 'package:flutter/material.dart';

class CustomText extends StatelessWidget {
  final String txt;
  final Color color;
  final double size;
  final FontWeight fontweight;
  final double spacing;
  final TextAlign textAlign;
  final int? maxLines;
  final TextOverflow? overflow;

  const CustomText({
    super.key,
    required this.txt,
    required this.color,
    required this.size,
    required this.fontweight,
    required this.spacing,
    this.textAlign = TextAlign.start,
    this.maxLines,
    this.overflow,
  });

  @override
  Widget build(BuildContext context) {
    return Text(
      txt,
      style: TextStyle(
        color: color,
        fontSize: size,
        fontWeight: fontweight,
        letterSpacing: spacing,
      ),
      textAlign: textAlign,
      maxLines: maxLines,
      overflow: overflow,
    );
  }
}
