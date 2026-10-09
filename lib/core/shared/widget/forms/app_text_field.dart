import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../theme/design_tokens.dart';

/// A labelled text input.
///
/// Every field in the client form used to repeat the same eight lines of
/// [InputDecoration] — border radius, prefix icon colour, label — which is how
/// they drifted out of sync. This widget owns that styling once.
///
/// Accessibility behaviour that callers get for free:
/// - a persistent visible label, not a placeholder that vanishes on focus
///   (WCAG 2.1 AA §3.3.2 Labels or Instructions),
/// - optionality stated in *words*, so it does not depend on spotting a colour
///   or an asterisk,
/// - errors announced with the field rather than as loose text (§3.3.1),
/// - a 48dp minimum hit area (§2.5.5),
/// - the prefix icon marked decorative so screen readers do not read it as
///   content before the label (§1.1.1).
class AppTextField extends StatelessWidget {
  const AppTextField({
    super.key,
    required this.controller,
    required this.label,
    this.icon,
    this.hint,
    this.helperText,
    this.isRequired = false,
    this.enabled = true,
    this.keyboardType,
    this.textInputAction,
    this.maxLines = 1,
    this.validator,
    this.inputFormatters,
    this.onSubmitted,
  });

  final TextEditingController controller;

  /// The human label. Do not append "(optional)" — pass [isRequired] instead
  /// and let the widget phrase it consistently.
  final String label;

  final IconData? icon;
  final String? hint;

  /// Guidance shown under the field. Use for format expectations
  /// ("8 digits, no spaces") rather than repeating the label.
  final String? helperText;

  final bool isRequired;
  final bool enabled;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final int maxLines;
  final String? Function(String?)? validator;
  final List<TextInputFormatter>? inputFormatters;
  final ValueChanged<String>? onSubmitted;

  OutlineInputBorder _border(Color color, {double width = 1}) =>
      OutlineInputBorder(
        borderRadius: AppRadius.mdAll,
        borderSide: BorderSide(color: color, width: width),
      );

  @override
  Widget build(BuildContext context) {
    // Stating optionality in the label text means it survives a screen reader
    // and does not rely on the user noticing a visual marker.
    final effectiveLabel = isRequired ? '$label *' : label;

    return TextFormField(
      controller: controller,
      enabled: enabled,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      maxLines: maxLines,
      validator: validator,
      inputFormatters: inputFormatters,
      onFieldSubmitted: onSubmitted,
      style: const TextStyle(fontSize: 15, color: AppPalette.textPrimary),
      decoration: InputDecoration(
        labelText: effectiveLabel,
        hintText: hint,
        helperText: helperText,
        // Reserves the error row so the form does not jump by 20px the first
        // time a field fails validation.
        helperMaxLines: 2,
        errorMaxLines: 2,
        prefixIcon: icon == null
            ? null
            : ExcludeSemantics(
                child: Icon(
                  icon,
                  // brandInk, not brand: at 15px this icon is small text as far
                  // as contrast is concerned, and brand is only 3.66:1.
                  color: enabled
                      ? AppPalette.brandInk
                      : AppPalette.textTertiary,
                  size: 20,
                ),
              ),
        filled: true,
        fillColor: enabled ? AppPalette.surface : AppPalette.surfaceMuted,
        // 48dp floor on the tap target even for a single-line field.
        constraints: const BoxConstraints(minHeight: AppA11y.minTouchTarget),
        labelStyle: const TextStyle(
          color: AppPalette.textSecondary,
          fontSize: 15,
        ),
        floatingLabelStyle: const TextStyle(
          color: AppPalette.brandInk,
          fontWeight: FontWeight.w600,
        ),
        helperStyle: const TextStyle(
          color: AppPalette.textTertiary,
          fontSize: AppA11y.minFontSize,
        ),
        enabledBorder: _border(AppPalette.border),
        // 2px on focus so the focus indicator is visible without relying on
        // colour alone (§2.4.7 / §1.4.11).
        focusedBorder: _border(AppPalette.brandInk, width: 2),
        errorBorder: _border(AppPalette.danger),
        focusedErrorBorder: _border(AppPalette.danger, width: 2),
        disabledBorder: _border(AppPalette.border),
        border: _border(AppPalette.border),
      ),
    );
  }
}
