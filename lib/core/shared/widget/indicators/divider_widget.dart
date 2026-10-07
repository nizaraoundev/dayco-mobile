import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../theme/app_theme.dart';

class DividerWidget extends StatelessWidget {
  const DividerWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Divider(
        thickness: 1,
        color: ColorManager.textSecondary.withOpacity(0.5),
        indent: Get.width * 0.02,
        endIndent: Get.width * 0.02,
      ),
    );
  }
}
