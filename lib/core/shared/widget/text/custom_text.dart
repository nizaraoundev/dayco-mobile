import 'package:flutter/material.dart';

Text customText({
  required String text,
  required TextStyle textStyle,
  TextAlign textAlign = TextAlign.start,
  TextDirection? textDirection, // Optional: Automatically detects if null
}) {
  return Text(
    text,
    style: textStyle,
    textAlign: textAlign,
    textDirection: textDirection ?? TextDirection.ltr,
  );
}

class CustomText extends StatelessWidget {
  final String txt;
  final Color? color;
  final double? size;
  final FontWeight? fontweight;
  final double? spacing;
  final String? fontfamily;
  final TextAlign? textAlign;
  final int? maxLines;
  final TextOverflow? overflow;

  const CustomText({
    super.key,
    required this.txt,
    this.color,
    this.size,
    this.fontweight,
    this.spacing,
    this.fontfamily,
    this.textAlign,
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
        fontFamily: fontfamily,
      ),
      textAlign: textAlign,
      maxLines: maxLines,
      overflow: overflow,
    );
  }
}
