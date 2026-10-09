// Auth controller
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../core/services/language_service.dart';
import '../../../../core/utils/app_logger.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../routes/app_routes.dart';
import '../../data/models/login_request.dart';
import '../../data/models/user_model.dart';
import '../../data/services/auth_service.dart';

class AuthController extends GetxController {
  // Auth service
  final AuthService _authService = AuthService();

  // User data
  final Rx<UserModel?> currentUser = Rx<UserModel?>(null);

  // Form keys for form validation
  final GlobalKey<FormState> loginFormKey = GlobalKey<FormState>();
  final GlobalKey<FormState> registerFormKey = GlobalKey<FormState>();
  final GlobalKey<FormState> forgotPasswordFormKey = GlobalKey<FormState>();
  final GlobalKey<FormState> resetPasswordFormKey = GlobalKey<FormState>();

  // Text controllers for login
  final TextEditingController emailLoginController = TextEditingController();
  final TextEditingController passwordLoginController = TextEditingController();

  // Country code for phone number (default to Tunisia)
  final RxString selectedCountryCode = '+216'.obs;

  // Text controllers for registration
  final TextEditingController nameController = TextEditingController();
  final TextEditingController phoneController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController taxiRegistrationController =
      TextEditingController();
  final TextEditingController idNumberController = TextEditingController();
  final RxString selectedCity = ''.obs;
  final TextEditingController passwordRegisterController =
      TextEditingController();
  final TextEditingController confirmPasswordController =
      TextEditingController();

  // Text controllers for forgot password
  final TextEditingController phoneForgotController = TextEditingController();

  // Text controllers for reset password
  final TextEditingController newPasswordController = TextEditingController();
  final TextEditingController confirmNewPasswordController =
      TextEditingController();

  // OTP controllers
  final List<TextEditingController> otpControllers = List.generate(
    4,
    (index) => TextEditingController(),
  );

  // Loading states
  final RxBool isLoginLoading = false.obs;
  final RxBool isRegisterLoading = false.obs;
  final RxBool isForgotPasswordLoading = false.obs;
  final RxBool isResetPasswordLoading = false.obs;
  final RxBool isOtpVerificationLoading = false.obs;

  // Password visibility
  final RxBool isPasswordVisible = false.obs;

  // OTP timer state
  final RxInt otpTimeRemaining = 60.obs;
  final RxBool canResendOtp = false.obs;

  // Track if controller is disposed
  bool _isDisposed = false;
  bool _shouldDispose = false;

  @override
  void onClose() {
    // Only dispose if explicitly requested (e.g., user logs out)
    if (_shouldDispose) {
      _isDisposed = true;
      _disposeAllControllers();
    }
    super.onClose();
  }

  // Private method to actually dispose controllers
  void _disposeAllControllers() {
    try {
      emailLoginController.dispose();
      passwordLoginController.dispose();
      nameController.dispose();
      phoneController.dispose();
      emailController.dispose();
      taxiRegistrationController.dispose();
      idNumberController.dispose();
      passwordRegisterController.dispose();
      confirmPasswordController.dispose();
      phoneForgotController.dispose();
      newPasswordController.dispose();
      confirmNewPasswordController.dispose();
      for (var controller in otpControllers) {
        controller.dispose();
      }
    } catch (e) {
      // Ignore disposal errors
    }
  }

  // Login functionality with real API
  void login() async {
    if (_isDisposed || _shouldDispose) return;
    if (loginFormKey.currentState!.validate()) {
      isLoginLoading.value = true;

      try {
        String codeClient = _safeGetControllerText(emailLoginController);
        String password = _safeGetControllerText(passwordLoginController);

        // Call API
        final loginRequest = LoginRequest(
          codeClient: codeClient,
          password: password,
        );
        // Never log the request body: it contains the password in cleartext,
        // and device logs are readable by `adb logcat` and captured in bug
        // reports. Only the non-secret identifier is recorded.
        AppLogger.debug('Login attempt for codeClient=$codeClient');
        final loginResponse = await _authService.login(loginRequest);

        // Get user details
        final userDetails = await _authService.getUserDetails(
          loginResponse.userId,
        );
        currentUser.value = userDetails;

        isLoginLoading.value = false;

        Get.snackbar(
          'Connexion réussie',
          'Bienvenue ${userDetails.fullName}',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: ColorManager.successColor,
          colorText: ColorManager.textOnPrimary,
          duration: const Duration(seconds: 2),
        );

        // Goes to initialization, not straight to the map: the map's data is
        // loaded there first so it opens ready instead of filling in behind a
        // set of spinners. `offAllNamed` keeps the login screen off the stack.
        Get.offAllNamed(AppRoutes.initializing);
      } catch (e) {
        isLoginLoading.value = false;
        Get.snackbar(
          'Erreur',
          e.toString().replaceAll('Exception: ', ''),
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: ColorManager.errorColor,
          colorText: ColorManager.textOnPrimary,
        );
      }
    }
  }

  // Registration functionality
  void register() {
    if (_isDisposed || _shouldDispose) return;
    if (registerFormKey.currentState!.validate()) {
      isRegisterLoading.value = true;
      // Simulate API call
      Future.delayed(const Duration(seconds: 2), () {
        if (!_isDisposed && !_shouldDispose) {
          isRegisterLoading.value = false;
          // Navigate to OTP verification page
          Get.toNamed(AppRoutes.verifyOtp);
        }
      });
    }
  }

  // Forgot password functionality
  void forgotPassword() {
    if (_isDisposed || _shouldDispose) return;
    if (forgotPasswordFormKey.currentState!.validate()) {
      isForgotPasswordLoading.value = true;
      // Simulate API call
      Future.delayed(const Duration(seconds: 2), () {
        if (!_isDisposed && !_shouldDispose) {
          isForgotPasswordLoading.value = false;
          Get.toNamed(AppRoutes.verifyOtp);
        }
      });
    }
  }

  // Reset password functionality
  void resetPassword() {
    if (_isDisposed || _shouldDispose) return;
    if (resetPasswordFormKey.currentState!.validate()) {
      isResetPasswordLoading.value = true;
      // Simulate API call
      Future.delayed(const Duration(seconds: 2), () {
        if (!_isDisposed && !_shouldDispose) {
          isResetPasswordLoading.value = false;
          // Show success message
          Get.snackbar(
            'Succès',
            'Votre mot de passe a été réinitialisé avec succès',
            snackPosition: SnackPosition.BOTTOM,
            backgroundColor: ColorManager.successColor,
            colorText: ColorManager.textOnPrimary,
            duration: const Duration(seconds: 3),
          );

          // Navigate back to login
          Future.delayed(const Duration(seconds: 1), () {
            Get.offAllNamed(AppRoutes.login);
          });
        }
      });
    }
  }

  // OTP verification
  void verifyOtp() {
    if (_isDisposed || _shouldDispose) return;

    String otp = '';
    try {
      otp = otpControllers
          .map((controller) => _safeGetControllerText(controller))
          .join();
    } catch (e) {
      Get.snackbar(
        'Erreur',
        'Erreur lors de la lecture du code OTP',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: ColorManager.errorColor,
        colorText: ColorManager.textOnPrimary,
      );
      return;
    }

    if (otp.length == 4) {
      isOtpVerificationLoading.value = true;
      // Simulate API verification
      Future.delayed(const Duration(seconds: 2), () {
        if (!_isDisposed && !_shouldDispose) {
          isOtpVerificationLoading.value = false;

          // Check if user has already selected a language
          try {
            final languageService = Get.find<LanguageService>();
            if (languageService.hasSelectedLanguage()) {
              // User has already selected language, go directly to driver dashboard
              Get.offAllNamed(AppRoutes.driverDashboard);
            } else {
              // User hasn't selected language yet, go to document upload for driver verification
              Get.offAllNamed(AppRoutes.documentUpload);
            }
          } catch (e) {
            // LanguageService not found, initialize it and go to document upload
            Get.put(LanguageService(), permanent: true);
            Get.offAllNamed(AppRoutes.documentUpload);
          }
        }
      });
    } else {
      Get.snackbar(
        'Erreur',
        'Veuillez entrer un code valide à 4 chiffres',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: ColorManager.errorColor,
        colorText: ColorManager.textOnPrimary,
      );
    }
  }

  // Start OTP timer
  void startOtpTimer() {
    if (_isDisposed || _shouldDispose) return;
    otpTimeRemaining.value = 60;
    canResendOtp.value = false;
    Future.doWhile(() async {
      await Future.delayed(const Duration(seconds: 1));
      if (_isDisposed || _shouldDispose) return false;
      if (otpTimeRemaining.value > 0) {
        otpTimeRemaining.value--;
        return true;
      } else {
        canResendOtp.value = true;
        return false;
      }
    });
  }

  // Resend OTP
  void resendOtp() {
    if (_isDisposed || _shouldDispose) return;
    if (canResendOtp.value) {
      // Clear current OTP safely
      for (var controller in otpControllers) {
        try {
          if (_isControllerAvailable(controller)) {
            controller.clear();
          }
        } catch (e) {
          // Controller might be disposed, skip it
          continue;
        }
      }

      // Reset timer
      startOtpTimer();

      // Show snackbar
      Get.snackbar(
        'Succès',
        'Un nouveau code a été envoyé',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: ColorManager.successColor,
        colorText: ColorManager.textOnPrimary,
      );
    }
  }

  // Navigation helpers - don't clear controllers during navigation
  void goToLogin() {
    Get.offAllNamed(AppRoutes.login);
  }

  void goToRegister() {
    Get.offAllNamed(AppRoutes.driverRegistration);
  }

  void goToForgotPassword() {
    Get.offAllNamed(AppRoutes.forgotPassword);
  }

  // Method to safely check if controller is available
  bool _isControllerAvailable(TextEditingController controller) {
    if (_isDisposed || _shouldDispose) return false;
    try {
      // Try to access the controller's text property
      controller.text;
      return true;
    } catch (e) {
      return false;
    }
  }

  // Safe method to get text from controller
  String _safeGetControllerText(TextEditingController controller) {
    if (!_isControllerAvailable(controller)) return '';
    try {
      return controller.text;
    } catch (e) {
      return '';
    }
  }

  // Get full phone number with country code
  String getFullPhoneNumber() {
    return '${selectedCountryCode.value}${_safeGetControllerText(emailLoginController)}';
  }

  // Update country code
  void updateCountryCode(String countryCode) {
    selectedCountryCode.value = countryCode;
  }

  // Toggle password visibility
  void togglePasswordVisibility() {
    isPasswordVisible.value = !isPasswordVisible.value;
  }

  // Quick login with fake driver data

  // Show test drivers selection dialog
  void showTestDriversDialog() {
    Get.dialog(
      Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Comptes de test',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: ColorManager.textPrimary,
                ),
              ),
              const SizedBox(height: 20),

              // Commercial Account
              _buildTestAccountCard(
                name: 'Commercial B2B',
                type: 'Agent Commercial',
                phone: '99999999',
                info1: 'Pièces Auto',
                info2: '45 clients',
                info3: 'Zone Tunis',
                color: ColorManager.primaryColor,
                icon: Icons.business_center,
                onTap: () {
                  Get.back();
                  emailLoginController.text = 'commercial@dayco.com';
                  passwordLoginController.text = 'commercial123';
                  login();
                },
              ),

              const SizedBox(height: 12),

              // Ahmed Ben Ali - Premium Driver
              const SizedBox(height: 20),

              TextButton(
                onPressed: () => Get.back(),
                child: Text(
                  'Annuler',
                  style: TextStyle(color: ColorManager.textSecondary),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Helper method to build test account card
  Widget _buildTestAccountCard({
    required String name,
    required String type,
    required String phone,
    required String info1,
    required String info2,
    required String info3,
    required Color color,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          border: Border.all(color: color.withOpacity(0.3)),
          borderRadius: BorderRadius.circular(8),
          color: color.withOpacity(0.1),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              child: Icon(icon, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: ColorManager.textPrimary,
                    ),
                  ),
                  Text(
                    type,
                    style: TextStyle(
                      fontSize: 12,
                      color: color,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Text(
                    '+216 $phone',
                    style: TextStyle(
                      fontSize: 11,
                      color: ColorManager.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  info1,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: ColorManager.textPrimary,
                  ),
                ),
                Text(
                  info2,
                  style: TextStyle(
                    fontSize: 10,
                    color: ColorManager.textSecondary,
                  ),
                ),
                Text(
                  info3,
                  style: TextStyle(
                    fontSize: 10,
                    color: ColorManager.successColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
