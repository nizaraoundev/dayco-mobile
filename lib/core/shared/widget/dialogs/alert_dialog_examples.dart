import 'package:flutter/material.dart';
import 'alert_dialog.dart';

/// Example usage of CustomAlertDialog widget
///
/// This file demonstrates different ways to use the alert dialog widget
class AlertDialogExamples {
  /// Success alert dialog
  static void showSuccessDialog({
    required String title,
    required String message,
    VoidCallback? onConfirm,
  }) {
    showCustomAlertDialog(
      title: title,
      message: message,
      type: AlertDialogType.success,
      confirmText: 'Super!',
      onConfirm: onConfirm,
    );
  }

  /// Error alert dialog
  static void showErrorDialog({
    required String title,
    required String message,
    VoidCallback? onConfirm,
  }) {
    showCustomAlertDialog(
      title: title,
      message: message,
      type: AlertDialogType.error,
      confirmText: 'Réessayer',
      onConfirm: onConfirm,
    );
  }

  /// Warning alert dialog
  static void showWarningDialog({
    required String title,
    required String message,
    VoidCallback? onConfirm,
    VoidCallback? onCancel,
  }) {
    showCustomAlertDialog(
      title: title,
      message: message,
      type: AlertDialogType.warning,
      confirmText: 'Continuer',
      cancelText: 'Annuler',
      onConfirm: onConfirm,
      onCancel: onCancel,
    );
  }

  /// Info alert dialog
  static void showInfoDialog({
    required String title,
    required String message,
    VoidCallback? onConfirm,
  }) {
    showCustomAlertDialog(
      title: title,
      message: message,
      type: AlertDialogType.info,
      confirmText: 'Compris',
      onConfirm: onConfirm,
    );
  }

  /// Confirmation dialog with two buttons
  static void showConfirmationDialog({
    required String title,
    required String message,
    VoidCallback? onConfirm,
    VoidCallback? onCancel,
    String confirmText = 'Confirmer',
    String cancelText = 'Annuler',
  }) {
    showCustomAlertDialog(
      title: title,
      message: message,
      type: AlertDialogType.info,
      confirmText: confirmText,
      cancelText: cancelText,
      onConfirm: onConfirm,
      onCancel: onCancel,
    );
  }

  /// Custom alert dialog with custom icon and color
  static void showCustomDialog({
    required String title,
    required String message,
    required Widget customIcon,
    required Color customColor,
    VoidCallback? onConfirm,
    String confirmText = 'OK',
  }) {
    showCustomAlertDialog(
      title: title,
      message: message,
      type: AlertDialogType.custom,
      confirmText: confirmText,
      customIcon: customIcon,
      customColor: customColor,
      onConfirm: onConfirm,
    );
  }

  /// Logout confirmation dialog
  static void showLogoutDialog({
    required VoidCallback onLogout,
  }) {
    showCustomAlertDialog(
      title: 'Déconnexion',
      message: 'Êtes-vous sûr de vouloir vous déconnecter?',
      type: AlertDialogType.warning,
      confirmText: 'Se déconnecter',
      cancelText: 'Annuler',
      onConfirm: onLogout,
    );
  }

  /// Delete confirmation dialog
  static void showDeleteDialog({
    required String itemName,
    required VoidCallback onDelete,
  }) {
    showCustomAlertDialog(
      title: 'Supprimer $itemName',
      message:
          'Cette action est irréversible. Êtes-vous sûr de vouloir continuer?',
      type: AlertDialogType.error,
      confirmText: 'Supprimer',
      cancelText: 'Annuler',
      onConfirm: onDelete,
    );
  }

  /// Network error dialog
  static void showNetworkErrorDialog({
    VoidCallback? onRetry,
  }) {
    showCustomAlertDialog(
      title: 'Erreur de connexion',
      message: 'Vérifiez votre connexion internet et réessayez.',
      type: AlertDialogType.error,
      confirmText: 'Réessayer',
      cancelText: 'Annuler',
      onConfirm: onRetry,
    );
  }

  /// Permission denied dialog
  static void showPermissionDialog({
    required String permission,
    VoidCallback? onOpenSettings,
  }) {
    showCustomAlertDialog(
      title: 'Permission requise',
      message:
          'L\'accès à $permission est nécessaire pour cette fonctionnalité.',
      type: AlertDialogType.warning,
      confirmText: 'Paramètres',
      cancelText: 'Plus tard',
      onConfirm: onOpenSettings,
    );
  }
}
