import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:get/get.dart';
import '../../../theme/app_theme.dart';
import '../buttons/custom_button.dart';
import '../text/custom_text.dart';

class ProfileHeader extends StatelessWidget {
  final String userName;
  final String? userEmail;
  final Widget profileImage;
  final VoidCallback? onBackPressed;
  final VoidCallback? onProfileImageTap;
  final Color? backgroundColor;
  final double? height;

  const ProfileHeader({
    super.key,
    required this.userName,
    this.userEmail,
    required this.profileImage,
    this.onBackPressed,
    this.onProfileImageTap,
    this.backgroundColor,
    this.height,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(top: Get.height * 0.002),
      margin: const EdgeInsets.only(bottom: 30),
      decoration: BoxDecoration(
        color: backgroundColor ?? ColorManager.white,
        borderRadius: const BorderRadius.all(Radius.circular(30)),
        boxShadow: const [
          BoxShadow(
            color: ColorManager.lightGrey2,
            blurRadius: 5,
            offset: Offset(0, 5),
          ),
        ],
      ),
      width: Get.width,
      height: height ?? Get.height / 2.8,
      child: Column(
        children: [
          Gap(Get.height * 0.05),
          if (onBackPressed != null)
            Row(
              children: [
                const Gap(10),
                CustomIconButton(
                  padding: EdgeInsets.all(Get.width / 35),
                  icon: const Icon(Icons.close),
                  onPressed: onBackPressed!,
                  color: ColorManager.black,
                  style: ButtonStyle(
                    elevation: WidgetStateProperty.all(7),
                    shadowColor: WidgetStateProperty.all(ColorManager.black),
                    backgroundColor:
                        WidgetStateProperty.all(ColorManager.white),
                    shape: WidgetStateProperty.all(
                      RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(50),
                      ),
                    ),
                  ),
                  tooltip: "Back",
                  iconSize: Get.width / 20,
                  alignment: Alignment.centerLeft,
                  visualDensity: VisualDensity.adaptivePlatformDensity,
                  autofocus: true,
                ),
              ],
            ),
          GestureDetector(
            onTap: onProfileImageTap,
            child: profileImage,
          ),
          const Gap(10),
          CustomText(
            txt: userName,
            color: ColorManager.blackLight,
            size: 20,
            fontweight: FontWeight.bold,
            spacing: 1,
            fontfamily: 'Cairo',
          ),
          if (userEmail != null) ...[
            const Gap(5),
            CustomText(
              txt: userEmail!,
              color: ColorManager.textSecondary,
              size: 14,
              fontfamily: 'Cairo',
            ),
          ],
        ],
      ),
    );
  }
}
