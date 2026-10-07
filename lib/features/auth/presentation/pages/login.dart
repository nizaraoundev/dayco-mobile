import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:get/get.dart';
import '../../../../core/assets/images.dart';
import '../../../../core/services/language_service.dart';
import '../../../../core/shared/widget/buttons/custom_elevated_button.dart';
import '../../../../core/shared/widget/text/custom_text.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../localization/ui_translations.dart';
import '../controllers/auth_controller.dart';

class LoginPage extends StatelessWidget {
  const LoginPage({super.key});

  String _tr(String key) => UiTranslations.t(key);

  @override
  Widget build(BuildContext context) {
    // Ensure controller is available, create if not exists
    AuthController controller;
    try {
      controller = Get.find<AuthController>(tag: 'auth_controller');
    } catch (e) {
      controller = Get.put(
        AuthController(),
        permanent: true,
        tag: 'auth_controller',
      );
    }

    final languageService = Get.find<LanguageService>();

    return Scaffold(
      backgroundColor: ColorManager.backgroundColor,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Form(
              key: controller.loginFormKey,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Obx(
                    () => Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          _tr('language'),
                          style: TextStyle(
                            color: ColorManager.textSecondary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(width: 10),
                        _buildLanguageChip(
                          flag: '🇫🇷',
                          label: _tr('french'),
                          selected:
                              languageService.currentLanguage.value == 'fr',
                          onTap: () => languageService.setLanguage('fr'),
                        ),
                        const SizedBox(width: 8),
                        _buildLanguageChip(
                          flag: '🇹🇳',
                          label: _tr('arabic'),
                          selected:
                              languageService.currentLanguage.value == 'ar',
                          onTap: () => languageService.setLanguage('ar'),
                        ),
                      ],
                    ),
                  ),
                  const Gap(24),

                  // Logo
                  Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: ColorManager.primaryColor.withOpacity(0.2),
                          spreadRadius: 2,
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Center(
                      child: Image.asset(AppImages.logo, width: 90, height: 90),
                    ),
                  ),
                  const Gap(40),

                  // Welcome text
                  customText(
                    text: _tr('welcome'),
                    textStyle: const TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                  ),
                  const Gap(8),
                  customText(
                    text: _tr('connectContinue'),
                    textStyle: const TextStyle(
                      fontSize: 16,
                      color: Colors.black,
                    ),
                  ),
                  const Gap(40),

                  // Email input
                  TextFormField(
                    controller: controller.emailLoginController,
                    keyboardType: TextInputType.text,
                    style: const TextStyle(color: Colors.black),
                    decoration: InputDecoration(
                      labelText: _tr('email'),
                      hintText: _tr('emailHint'),
                      labelStyle: const TextStyle(color: Colors.black),
                      hintStyle: const TextStyle(color: Colors.black54),
                      prefixIcon: Icon(
                        Icons.email_outlined,
                        color: ColorManager.primaryColor,
                      ),
                      filled: true,
                      fillColor: ColorManager.surfaceColor.withOpacity(0.5),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: ColorManager.primaryColor,
                          width: 2,
                        ),
                      ),
                      errorBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: ColorManager.errorColor,
                          width: 2,
                        ),
                      ),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return _tr('emailRequired');
                      }
                      if (!GetUtils.isEmail(value)) {
                        return _tr('invalidEmail');
                      }
                      return null;
                    },
                  ),
                  const Gap(20),

                  // Password input
                  Obx(
                    () => TextFormField(
                      controller: controller.passwordLoginController,
                      obscureText: !controller.isPasswordVisible.value,
                      style: const TextStyle(color: Colors.black),
                      decoration: InputDecoration(
                        labelText: _tr('password'),
                        hintText: '••••••••',
                        labelStyle: const TextStyle(color: Colors.black),
                        hintStyle: const TextStyle(color: Colors.black54),
                        prefixIcon: Icon(
                          Icons.lock_outline,
                          color: ColorManager.primaryColor,
                        ),
                        // suffixIcon: IconButton(
                        //   icon: Icon(
                        //     controller.isPasswordVisible.value
                        //         ? Icons.visibility_outlined
                        //         : Icons.visibility_off_outlined,
                        //     color: ColorManager.textSecondary,
                        //   ),
                        // ),
                        filled: true,
                        fillColor: ColorManager.surfaceColor.withOpacity(0.5),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: ColorManager.primaryColor,
                            width: 2,
                          ),
                        ),
                        errorBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: ColorManager.errorColor,
                            width: 2,
                          ),
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return _tr('passwordRequired');
                        }
                        if (value.length < 6) {
                          return _tr('passwordMin');
                        }
                        return null;
                      },
                    ),
                  ),
                  const Gap(30),

                  // Login Button
                  Obx(
                    () => controller.isLoginLoading.value
                        ? const CircularProgressIndicator()
                        : customElevatedButton(
                            text: _tr('signIn'),
                            onPressed: controller.login,
                            textStyle: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: ColorManager.textOnPrimary,
                            ),
                            borderRadius: 12,
                            width: double.infinity,
                            height: 55,
                            color: ColorManager.primaryColor,
                          ),
                  ),
                  const Gap(20),

                  // Quick test login
            
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLanguageChip({
    required String flag,
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: selected
              ? ColorManager.primaryColor.withOpacity(0.15)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? ColorManager.primaryColor : Colors.black26,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(flag),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: Colors.black,
                fontWeight: selected ? FontWeight.bold : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
