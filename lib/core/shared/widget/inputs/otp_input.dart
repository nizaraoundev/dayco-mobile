import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../theme/app_theme.dart';

class OtpInput extends StatelessWidget {
  final TextEditingController controller;
  final bool autoFocus;
  final void Function(String)? onChanged;

  const OtpInput({
    super.key,
    required this.controller,
    this.autoFocus = false,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      autofocus: autoFocus,
      textAlign: TextAlign.center,
      keyboardType: TextInputType.number,
      controller: controller,
      maxLength: 1,
      cursorColor: ColorManager.primaryColor,
      style: TextStyle(
        color: ColorManager.textPrimary,
        fontSize: 24,
        fontWeight: FontWeight.bold,
      ),
      onChanged: onChanged,
      inputFormatters: [
        FilteringTextInputFormatter.digitsOnly,
      ],
      decoration: InputDecoration(
        counterText: "",
        filled: true,
        fillColor: ColorManager.surfaceColor,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(
            color: ColorManager.primaryColor,
            width: 2.0,
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(
            color: ColorManager.dividerColor,
            width: 1.0,
          ),
        ),
      ),
    );
  }
}
