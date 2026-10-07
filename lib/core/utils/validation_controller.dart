import 'package:get/get.dart';
import 'localization_helper.dart';

class ValidationController extends GetxController {
  @override
  void onInit() {
    super.onInit();
    _initializeLocalization();
  }

  Future<void> _initializeLocalization() async {
    await LocalizationHelper.loadLocalization();
  }

  // Method to reload localization when language changes
  Future<void> reloadLocalization() async {
    await LocalizationHelper.loadLocalization();
  }
}
