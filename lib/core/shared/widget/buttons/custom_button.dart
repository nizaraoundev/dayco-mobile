import 'package:flutter/material.dart';

class CustomIconButton extends StatelessWidget {
  final Widget icon;
  final VoidCallback onPressed;
  final Color? color;
  final ButtonStyle? style;
  final String? tooltip;
  final double? iconSize;
  final AlignmentGeometry? alignment;
  final VisualDensity? visualDensity;
  final bool autofocus;
  final EdgeInsetsGeometry? padding;

  const CustomIconButton({
    super.key,
    required this.icon,
    required this.onPressed,
    this.color,
    this.style,
    this.tooltip,
    this.iconSize,
    this.alignment,
    this.visualDensity,
    this.autofocus = false,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onPressed,
      icon: icon,
      color: color,
      style: style,
      tooltip: tooltip,
      iconSize: iconSize,
      alignment: alignment ?? Alignment.center,
      visualDensity: visualDensity,
      autofocus: autofocus,
      padding: padding ?? const EdgeInsets.all(8.0),
    );
  }
}
