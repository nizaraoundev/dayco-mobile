import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../theme/app_theme.dart';
import '../buttons/custom_elevated_button.dart';
import '../text/custom_text.dart';

enum AlertDialogType {
  success,
  error,
  warning,
  info,
  custom,
}

Future<void> showCustomAlertDialog({
  required String title,
  required String message,
  AlertDialogType type = AlertDialogType.info,
  String confirmText = 'OK',
  String? cancelText,
  VoidCallback? onConfirm,
  VoidCallback? onCancel,
  bool barrierDismissible = true,
  Widget? customIcon,
  Color? customColor,
}) async {
  return showDialog<void>(
    context: Get.context!,
    barrierDismissible: barrierDismissible,
    builder: (BuildContext context) {
      return CustomAlertDialog(
        title: title,
        message: message,
        type: type,
        confirmText: confirmText,
        cancelText: cancelText,
        onConfirm: onConfirm,
        onCancel: onCancel,
        customIcon: customIcon,
        customColor: customColor,
      );
    },
  );
}

class CustomAlertDialog extends StatelessWidget {
  final String title;
  final String message;
  final AlertDialogType type;
  final String confirmText;
  final String? cancelText;
  final VoidCallback? onConfirm;
  final VoidCallback? onCancel;
  final Widget? customIcon;
  final Color? customColor;

  const CustomAlertDialog({
    super.key,
    required this.title,
    required this.message,
    this.type = AlertDialogType.info,
    this.confirmText = 'OK',
    this.cancelText,
    this.onConfirm,
    this.onCancel,
    this.customIcon,
    this.customColor,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      elevation: 0,
      backgroundColor: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: ColorManager.backgroundColor,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Icon
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: _getIconBackgroundColor().withOpacity(0.1),
                borderRadius: BorderRadius.circular(30),
              ),
              child: Center(
                child: customIcon ??
                    Icon(
                      _getIcon(),
                      size: 30,
                      color: _getIconColor(),
                    ),
              ),
            ),
            const SizedBox(height: 20),

            // Title
            customText(
              text: title,
              textStyle: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: ColorManager.textPrimary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),

            // Message
            customText(
              text: message,
              textStyle: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w400,
                color: ColorManager.textSecondary,
                height: 1.4,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),

            // Buttons
            Row(
              children: [
                if (cancelText != null) ...[
                  Expanded(
                    child: customElevatedButton(
                      text: cancelText!,
                      onPressed: () {
                        Navigator.of(context).pop();
                        if (onCancel != null) onCancel!();
                      },
                      textStyle: TextStyle(
                        color: ColorManager.textSecondary,
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                      borderRadius: 8,
                      width: double.infinity,
                      height: 45,
                      color: ColorManager.surfaceColor,
                      elevation: 0,
                    ),
                  ),
                  const SizedBox(width: 12),
                ],
                Expanded(
                  child: customElevatedButton(
                    text: confirmText,
                    onPressed: () {
                      Navigator.of(context).pop();
                      if (onConfirm != null) onConfirm!();
                    },
                    textStyle: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                    borderRadius: 8,
                    width: double.infinity,
                    height: 45,
                    color: _getButtonColor(),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  IconData _getIcon() {
    if (customIcon != null) return Icons.info;

    switch (type) {
      case AlertDialogType.success:
        return Icons.check_circle;
      case AlertDialogType.error:
        return Icons.error;
      case AlertDialogType.warning:
        return Icons.warning;
      case AlertDialogType.info:
        return Icons.info;
      case AlertDialogType.custom:
        return Icons.info;
    }
  }

  Color _getIconColor() {
    if (customColor != null) return customColor!;

    switch (type) {
      case AlertDialogType.success:
        return ColorManager.successColor;
      case AlertDialogType.error:
        return ColorManager.errorColor;
      case AlertDialogType.warning:
        return ColorManager.warningColor;
      case AlertDialogType.info:
        return ColorManager.primaryColor;
      case AlertDialogType.custom:
        return ColorManager.primaryColor;
    }
  }

  Color _getIconBackgroundColor() {
    return _getIconColor();
  }

  Color _getButtonColor() {
    if (customColor != null) return customColor!;

    switch (type) {
      case AlertDialogType.success:
        return ColorManager.successColor;
      case AlertDialogType.error:
        return ColorManager.errorColor;
      case AlertDialogType.warning:
        return ColorManager.warningColor;
      case AlertDialogType.info:
        return ColorManager.primaryColor;
      case AlertDialogType.custom:
        return ColorManager.primaryColor;
    }
  }
}
