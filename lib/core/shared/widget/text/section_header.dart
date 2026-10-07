import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../theme/app_theme.dart';
import '../text/custom_text.dart';

class SectionHeader extends StatelessWidget {
  final String title;
  final EdgeInsets? padding;
  final Color? textColor;
  final double? fontSize;
  final FontWeight? fontWeight;

  const SectionHeader({
    super.key,
    required this.title,
    this.padding,
    this.textColor,
    this.fontSize,
    this.fontWeight,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding ?? const EdgeInsets.all(15.0),
      child: CustomText(
        txt: title,
        color: textColor ?? ColorManager.black,
        size: fontSize ?? Get.width / 17,
        fontweight: fontWeight ?? FontWeight.bold,
        spacing: 1,
        fontfamily: 'Cairo',
      ),
    );
  }
}
