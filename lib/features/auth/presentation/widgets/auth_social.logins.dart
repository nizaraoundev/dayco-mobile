import 'package:flutter/material.dart';
import 'package:get/get.dart';

class auth_social_logins extends StatelessWidget {
  final String logo;

  const auth_social_logins({super.key, required this.logo});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: Get.height * 0.06,
      width: Get.width * 0.12,
      decoration: BoxDecoration(
        color: const Color.fromARGB(255, 255, 255, 255),
        border: Border.all(color: Colors.black12),
        borderRadius: BorderRadius.circular(30),
      ),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
        Image.asset(
          logo,
          filterQuality: FilterQuality.high,
          width: 25,
          height: 25,
        ),
      ]),
    );
  }
}
