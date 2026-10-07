import 'package:flutter/material.dart';

ElevatedButton customElevatedButton({
  required String text,
  required VoidCallback onPressed,
  required TextStyle textStyle,
  required double borderRadius,
  required double width,
  required double height,
  required Color color,
  Color? shadowColor,
  double elevation = 3.0,
}) {
  return ElevatedButton(
    onPressed: onPressed,
    style: ElevatedButton.styleFrom(
      backgroundColor: color,
      shadowColor: shadowColor,
      elevation: elevation,
      minimumSize: Size(width, height),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(borderRadius),
      ),
    ),
    child: Text(
      text,
      style: textStyle,
    ),
  );
}
