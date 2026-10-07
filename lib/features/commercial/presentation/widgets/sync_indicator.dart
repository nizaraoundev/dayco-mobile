import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';

/// Sync status indicator widget
class SyncIndicator extends StatelessWidget {
  final bool isOnline;
  final bool isSyncing;
  final int pendingCount;
  final VoidCallback? onTap;

  const SyncIndicator({
    super.key,
    required this.isOnline,
    required this.isSyncing,
    required this.pendingCount,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: _getBackgroundColor().withOpacity(0.2),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isSyncing)
              SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation(_getIconColor()),
                ),
              )
            else
              Icon(_getIcon(), size: 14, color: _getIconColor()),
            const SizedBox(width: 6),
            Text(
              _getText(),
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: _getIconColor(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _getBackgroundColor() {
    if (!isOnline) return Colors.grey;
    if (isSyncing) return ColorManager.primaryColor;
    if (pendingCount > 0) return Colors.orange;
    return ColorManager.secondaryVariant;
  }

  Color _getIconColor() {
    if (!isOnline) return Colors.white;
    if (isSyncing) return Colors.white;
    if (pendingCount > 0) return Colors.white;
    return Colors.white;
  }

  IconData _getIcon() {
    if (!isOnline) return Icons.cloud_off;
    if (pendingCount > 0) return Icons.cloud_upload;
    return Icons.cloud_done;
  }

  String _getText() {
    if (!isOnline) return 'Hors ligne';
    if (isSyncing) return 'Sync...';
    if (pendingCount > 0) return '$pendingCount';
    return 'Sync';
  }
}
