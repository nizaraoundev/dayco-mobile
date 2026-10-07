import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:get/get.dart';
import '../../../theme/app_theme.dart';
import '../text/custom_text.dart';
import '../inputs/text_input.dart';

class DialogService {
  static Future<void> showEditProfileDialog({
    required String currentName,
    required String currentEmail,
    required String currentPhone,
    required Function(String name, String email, String phone) onSave,
  }) {
    final nameController = TextEditingController(text: currentName);
    final emailController = TextEditingController(text: currentEmail);
    final phoneController = TextEditingController(text: currentPhone);

    return showDialog(
      context: Get.context!,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        title: const CustomText(
          txt: 'Edit Profile',
          fontweight: FontWeight.bold,
          size: 18,
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CustomTextFormField(
                formcontroller: nameController,
                texthint: 'Full Name',
                inputType: TextInputType.name,
                validator: (value) =>
                    value?.isEmpty == true ? 'Required' : null,
                icon: const Icon(Icons.person),
                height: 50,
              ),
              const Gap(15),
              CustomTextFormField(
                formcontroller: emailController,
                texthint: 'Email',
                inputType: TextInputType.emailAddress,
                validator: (value) =>
                    value?.isEmpty == true ? 'Required' : null,
                icon: const Icon(Icons.email),
                height: 50,
              ),
              const Gap(15),
              CustomTextFormField(
                formcontroller: phoneController,
                texthint: 'Phone Number',
                inputType: TextInputType.phone,
                validator: (value) =>
                    value?.isEmpty == true ? 'Required' : null,
                icon: const Icon(Icons.phone),
                height: 50,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const CustomText(
                txt: 'Cancel', color: ColorManager.textSecondary),
          ),
          ElevatedButton(
            onPressed: () {
              onSave(nameController.text, emailController.text,
                  phoneController.text);
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: ColorManager.primaryColor,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            child: const CustomText(txt: 'Save', color: ColorManager.white),
          ),
        ],
      ),
    );
  }

  static Future<void> showChangePasswordDialog({
    required Function(String current, String newPassword) onChangePassword,
  }) {
    final currentPasswordController = TextEditingController();
    final newPasswordController = TextEditingController();
    final confirmPasswordController = TextEditingController();

    return showDialog(
      context: Get.context!,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        title: const CustomText(
          txt: 'Change Password',
          fontweight: FontWeight.bold,
          size: 18,
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CustomTextFormField(
                formcontroller: currentPasswordController,
                texthint: 'Current Password',
                inputType: TextInputType.text,
                obscureText: true,
                validator: (value) =>
                    value?.isEmpty == true ? 'Required' : null,
                icon: const Icon(Icons.lock),
                height: 50,
              ),
              const Gap(15),
              CustomTextFormField(
                formcontroller: newPasswordController,
                texthint: 'New Password',
                inputType: TextInputType.text,
                obscureText: true,
                validator: (value) =>
                    value?.isEmpty == true ? 'Required' : null,
                icon: const Icon(Icons.lock_outline),
                height: 50,
              ),
              const Gap(15),
              CustomTextFormField(
                formcontroller: confirmPasswordController,
                texthint: 'Confirm New Password',
                inputType: TextInputType.text,
                obscureText: true,
                validator: (value) =>
                    value?.isEmpty == true ? 'Required' : null,
                icon: const Icon(Icons.lock_outline),
                height: 50,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const CustomText(
                txt: 'Cancel', color: ColorManager.textSecondary),
          ),
          ElevatedButton(
            onPressed: () {
              if (newPasswordController.text ==
                  confirmPasswordController.text) {
                onChangePassword(
                    currentPasswordController.text, newPasswordController.text);
                Navigator.pop(context);
              } else {
                Get.snackbar(
                  'Error',
                  'Passwords do not match',
                  snackPosition: SnackPosition.BOTTOM,
                  backgroundColor: ColorManager.errorColor,
                  colorText: ColorManager.white,
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: ColorManager.primaryColor,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            child: const CustomText(txt: 'Change', color: ColorManager.white),
          ),
        ],
      ),
    );
  }

  static Future<void> showLanguageDialog({
    required String currentLanguage,
    required Function(String language) onLanguageChanged,
  }) {
    final languages = ['English', 'العربية', 'Français'];
    String selectedLanguage = currentLanguage;

    return showDialog(
      context: Get.context!,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        title: const CustomText(
          txt: 'Select Language',
          fontweight: FontWeight.bold,
          size: 18,
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: languages.map((language) {
            return RadioListTile<String>(
              title: CustomText(txt: language, size: 16),
              value: language,
              groupValue: selectedLanguage,
              onChanged: (value) {
                onLanguageChanged(value!);
                Navigator.pop(context);
              },
              activeColor: ColorManager.primaryColor,
            );
          }).toList(),
        ),
      ),
    );
  }

  static Future<void> showConfirmationDialog({
    required String title,
    required String message,
    required VoidCallback onConfirm,
    String confirmText = 'Confirm',
    String cancelText = 'Cancel',
    Color? confirmColor,
  }) {
    return showDialog(
      context: Get.context!,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        title: CustomText(
          txt: title,
          fontweight: FontWeight.bold,
          size: 18,
          color: confirmColor,
        ),
        content: CustomText(
          txt: message,
          size: 14,
          spacing: 1.2,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child:
                CustomText(txt: cancelText, color: ColorManager.textSecondary),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              onConfirm();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: confirmColor ?? ColorManager.primaryColor,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            child: CustomText(txt: confirmText, color: ColorManager.white),
          ),
        ],
      ),
    );
  }
}
