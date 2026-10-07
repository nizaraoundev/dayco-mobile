// Validators
import 'package:get/get.dart';
import 'localization_helper.dart';

Future<String?> validInput(String val, String type) async {
  // Ensure localization is loaded
  await LocalizationHelper.loadLocalization();

  if (type == "username") {
    if (!GetUtils.isUsername(val)) {
      return LocalizationHelper.translate("invalidUsername");
    }
  }
  if (type == "email") {
    if (!GetUtils.isEmail(val)) {
      return LocalizationHelper.translate("invalidEmail");
    }
  }

  // if (type == "phone") {
  //   if (!GetUtils.isTunisiaNumber(val)) {
  //     return LocalizationHelper.translate("invalidPhone");
  //   }
  // }
  if (type == "NumericOnly") {
    if (!GetUtils.isNumericOnly(val)) {
      return LocalizationHelper.translate("weakPassword");
    }
  }
  if (type == "DateTime") {
    if (!GetUtils.isDateTime(val)) {
      return LocalizationHelper.translate("invalidDate");
    }
  }
  if (val.isEmpty) {
    return LocalizationHelper.translate("fieldEmpty");
  }

  return null; // Return null if validation passes
}

// Synchronous version - requires localization to be pre-loaded
String? validInputSync(String val, String type) {
  if (type == "username") {
    if (!GetUtils.isUsername(val)) {
      return LocalizationHelper.translate("invalidUsername");
    }
  }
  if (type == "email") {
    if (!GetUtils.isEmail(val)) {
      return LocalizationHelper.translate("invalidEmail");
    }
  }

  // if (type == "phone") {
  //   if (!GetUtils.isTunisiaNumber(val)) {
  //     return LocalizationHelper.translate("invalidPhone");
  //   }
  // }
  if (type == "NumericOnly") {
    if (!GetUtils.isNumericOnly(val)) {
      return LocalizationHelper.translate("weakPassword");
    }
  }
  if (type == "DateTime") {
    if (!GetUtils.isDateTime(val)) {
      return LocalizationHelper.translate("invalidDate");
    }
  }
  if (val.isEmpty) {
    return LocalizationHelper.translate("fieldEmpty");
  }

  return null;
}
