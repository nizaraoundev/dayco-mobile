import 'package:get/get.dart';
import '../../../../core/services/language_service.dart';

class LanguageController extends GetxController {
  late LanguageService languageService;
  final RxString selectedLanguage = ''.obs;
  final RxBool isLoading = false.obs;

  @override
  void onInit() {
    super.onInit();
    languageService = Get.find<LanguageService>();
    selectedLanguage.value = languageService.getCurrentLanguage();
  }

  void selectLanguage(String languageCode) {
    selectedLanguage.value = languageCode;
  }

  Future<void> saveLanguageAndContinue() async {
    try {
      isLoading.value = true;
      await languageService.setLanguage(selectedLanguage.value);
      // Navigation will be handled by the screen
    } catch (e) {
      // Error handling will be done by the screen
      rethrow;
    } finally {
      isLoading.value = false;
    }
  }
}
