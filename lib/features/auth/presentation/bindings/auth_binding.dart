import 'package:get/get.dart';

import '../controllers/auth_controller.dart';

class AuthBinding extends Bindings {
  @override
  void dependencies() {
    // Use put with permanent: true to prevent disposal
    // This ensures the controller stays alive across all auth pages
    Get.put<AuthController>(
      AuthController(),
      permanent: true,
      tag: 'auth_controller',
    );
  }
}
