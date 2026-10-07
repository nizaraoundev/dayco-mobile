import 'package:flutter/material.dart';
import 'package:feather_icons/feather_icons.dart';
import '../../../theme/app_theme.dart';
import '../text/custom_text.dart';

class SettingsListTile extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget icon;
  final VoidCallback? onTap;
  final Color? titleColor;
  final Widget? trailing;
  final bool showArrow;
  final EdgeInsets? margin;
  final EdgeInsets? padding;

  const SettingsListTile({
    super.key,
    required this.title,
    this.subtitle,
    required this.icon,
    this.onTap,
    this.titleColor,
    this.trailing,
    this.showArrow = true,
    this.margin,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin ?? const EdgeInsets.symmetric(horizontal: 15, vertical: 5),
      decoration: BoxDecoration(
        color: ColorManager.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: ColorManager.lightGrey2.withOpacity(0.5),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ListTile(
        contentPadding:
            padding ?? const EdgeInsets.symmetric(horizontal: 20, vertical: 5),
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: ColorManager.primaryColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: icon,
        ),
        title: CustomText(
          txt: title,
          color: titleColor ?? ColorManager.black,
          size: 16,
          fontweight: FontWeight.w500,
          fontfamily: 'Cairo',
        ),
        subtitle: subtitle != null
            ? CustomText(
                txt: subtitle!,
                color: ColorManager.textSecondary,
                size: 12,
                fontfamily: 'Cairo',
              )
            : null,
        trailing: trailing ??
            (showArrow
                ? const Icon(
                    FeatherIcons.chevronRight,
                    color: ColorManager.textSecondary,
                    size: 20,
                  )
                : null),
        onTap: onTap,
      ),
    );
  }
}
