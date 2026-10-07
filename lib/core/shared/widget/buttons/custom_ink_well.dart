import 'package:flutter/material.dart';

class CustomInkWell extends StatelessWidget {
  final Widget widget;
  final VoidCallback ontap;
  final double radius;
  final Color? splashColor;

  const CustomInkWell({
    super.key,
    required this.widget,
    required this.ontap,
    this.radius = 10,
    this.splashColor,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: ontap,
      borderRadius: BorderRadius.circular(radius),
      splashColor: splashColor,
      child: widget,
    );
  }
}
