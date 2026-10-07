import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:get/get.dart';

import '../../../../core/services/language_service.dart';
import '../../../../core/shared/widget/buttons/custom_elevated_button.dart';
import '../../../../core/shared/widget/text/custom_text.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/text_styles.dart';
import '../../../../routes/app_routes.dart';

class LanguageSelectionScreen extends StatefulWidget {
  const LanguageSelectionScreen({super.key});

  @override
  State<LanguageSelectionScreen> createState() =>
      _LanguageSelectionScreenState();
}

class _LanguageSelectionScreenState extends State<LanguageSelectionScreen> {
  late LanguageService languageService;
  String selectedLanguage = LanguageService.defaultLanguage;
  bool isLoading = false;

  @override
  void initState() {
    super.initState();
    languageService = Get.find<LanguageService>();
    selectedLanguage = languageService.getCurrentLanguage();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ColorManager.backgroundColor,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: ColorManager.backgroundColor,
        centerTitle: true,
        title: customText(
          text: _getLocalizedText('selectLanguage'),
          textStyle: AppTextStyles.appBarTitle.copyWith(
            color: ColorManager.textPrimary,
          ),
        ),
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            children: [
              const Gap(20),

              // Welcome message
              customText(
                text: _getLocalizedText('welcomeSelectLanguage'),
                textStyle: AppTextStyles.headlineLarge.copyWith(
                  color: ColorManager.textPrimary,
                ),
                textAlign: TextAlign.center,
              ),

              const Gap(10),

              customText(
                text: _getLocalizedText('choosePreferredLanguage'),
                textStyle: AppTextStyles.bodyLarge.copyWith(
                  color: ColorManager.textSecondary,
                ),
                textAlign: TextAlign.center,
              ),

              const Gap(40),

              // Language options
              Expanded(
                child: ListView.builder(
                  itemCount: languageService.getSupportedLanguages().length,
                  itemBuilder: (context, index) {
                    final languageEntry =
                        languageService.getSupportedLanguages()[index];
                    final languageCode = languageEntry.key;
                    final languageData = languageEntry.value;

                    return Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: selectedLanguage == languageCode
                              ? ColorManager.primaryColor
                              : ColorManager.dividerColor,
                          width: selectedLanguage == languageCode ? 2 : 1,
                        ),
                        color: selectedLanguage == languageCode
                            ? ColorManager.primaryColor.withOpacity(0.1)
                            : ColorManager.cardColor,
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.all(16),
                        leading: Text(
                          languageData['flag']!,
                          style: const TextStyle(fontSize: 32),
                        ),
                        title: customText(
                          text: languageData['nativeName']!,
                          textStyle: AppTextStyles.titleMedium.copyWith(
                            color: ColorManager.textPrimary,
                            fontWeight: selectedLanguage == languageCode
                                ? FontWeight.bold
                                : FontWeight.normal,
                          ),
                        ),
                        subtitle: customText(
                          text: languageData['name']!,
                          textStyle: AppTextStyles.bodyMedium.copyWith(
                            color: ColorManager.textSecondary,
                          ),
                        ),
                        trailing: selectedLanguage == languageCode
                            ? Icon(
                                Icons.check_circle,
                                color: ColorManager.primaryColor,
                                size: 24,
                              )
                            : Icon(
                                Icons.radio_button_unchecked,
                                color: ColorManager.textSecondary,
                                size: 24,
                              ),
                        onTap: () {
                          setState(() {
                            selectedLanguage = languageCode;
                          });
                        },
                      ),
                    );
                  },
                ),
              ),

              const Gap(20),

              // Continue button
              Center(
                child: isLoading
                    ? const CircularProgressIndicator()
                    : customElevatedButton(
                        text: _getLocalizedText('continue'),
                        onPressed: _saveLanguageAndContinue,
                        textStyle: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                        borderRadius: 20,
                        width: Get.width * 0.8,
                        height: Get.height * 0.07,
                        color: ColorManager.primaryColor,
                      ),
              ),

              const Gap(20),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _saveLanguageAndContinue() async {
    try {
      setState(() {
        isLoading = true;
      });

      // Save selected language
      await languageService.setLanguage(selectedLanguage);

      // Show success message
      Get.snackbar(
        _getLocalizedText('success'),
        _getLocalizedText('languageSaved'),
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: ColorManager.successColor,
        colorText: Colors.white,
        duration: const Duration(seconds: 2),
      );

      // Navigate to home screen
      Get.offAllNamed(AppRoutes.driverDashboard);
    } catch (e) {
      Get.snackbar(
        _getLocalizedText('error'),
        _getLocalizedText('languageSaveError'),
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: ColorManager.errorColor,
        colorText: Colors.white,
      );
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  String _getLocalizedText(String key) {
    // Simple localization based on selected language
    // In a production app, you would use proper localization files
    final localizations = {
      'fr': {
        'selectLanguage': 'Sélectionner la langue',
        'welcomeSelectLanguage': 'Bienvenue !',
        'choosePreferredLanguage':
            'Choisissez votre langue préférée pour une meilleure expérience.',
        'continue': 'Continuer',
        'success': 'Succès',
        'languageSaved': 'Langue sauvegardée avec succès !',
        'error': 'Erreur',
        'languageSaveError': 'Erreur lors de la sauvegarde de la langue.',
      },
      'ar': {
        'selectLanguage': 'اختيار اللغة',
        'welcomeSelectLanguage': 'مرحباً !',
        'choosePreferredLanguage': 'اختر لغتك المفضلة لتجربة أفضل.',
        'continue': 'متابعة',
        'success': 'نجح',
        'languageSaved': 'تم حفظ اللغة بنجاح !',
        'error': 'خطأ',
        'languageSaveError': 'خطأ في حفظ اللغة.',
      },
      'en': {
        'selectLanguage': 'Select Language',
        'welcomeSelectLanguage': 'Welcome!',
        'choosePreferredLanguage':
            'Choose your preferred language for a better experience.',
        'continue': 'Continue',
        'success': 'Success',
        'languageSaved': 'Language saved successfully!',
        'error': 'Error',
        'languageSaveError': 'Error saving language.',
      },
    };

    return localizations[selectedLanguage]?[key] ??
        localizations['fr']?[key] ??
        key;
  }
}
