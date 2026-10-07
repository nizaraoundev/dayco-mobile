import 'package:flutter/material.dart';

/// Filter chip for map
class MapFilterChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color? color;
  final bool isSelected;
  final VoidCallback onTap;

  const MapFilterChip({
    super.key,
    required this.label,
    required this.icon,
    this.color,
    this.isSelected = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final chipColor = color ?? Colors.grey[700]!;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? chipColor.withOpacity(0.15) : Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isSelected ? chipColor : Colors.grey[300]!,
              width: isSelected ? 1.5 : 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 16,
                color: isSelected ? chipColor : Colors.grey[600],
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  color: isSelected ? chipColor : Colors.grey[700],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
