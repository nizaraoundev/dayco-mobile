import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:get/get.dart';
import '../../../../core/assets/images.dart';
import '../../../../core/services/language_service.dart';
import '../../../../core/shared/widget/buttons/custom_elevated_button.dart';
import '../../../../core/shared/widget/text/custom_text.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/app_gradients.dart';
import '../../../../core/theme/dayco_colors.dart';
import '../../../../localization/ui_translations.dart';
import '../controllers/auth_controller.dart';

/// Screens whose shortest side is at least this wide are treated as tablets.
const double _kTabletBreakpoint = 600;

/// The logo asset is a 1000x1000 square with wide transparent margins, so it is
/// always drawn cover-cropped at this ratio to show the artwork larger.
const double _kLogoAspectRatio = 280 / 150;

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
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isLandscape = constraints.maxWidth > constraints.maxHeight;
          final isTablet =
              MediaQuery.sizeOf(context).shortestSide >= _kTabletBreakpoint;

          return Stack(
            children: [
              // Soft page backdrop: white fading into a tint of the logo blue,
              // with large logo-coloured shapes behind the content.
              Positioned.fill(
                child: DecoratedBox(
                  decoration:
                      BoxDecoration(gradient: context.dayco.pageGradient),
                  child: const CustomPaint(
                    painter: _BackdropPainter(
                      color: ColorManager.primaryColor,
                      intensity: 0.30,
                    ),
                  ),
                ),
              ),
              if (isLandscape)
                _buildLandscapeLayout(controller, languageService, isTablet)
              else
                _buildPortraitLayout(controller, languageService, isTablet),
            ],
          );
        },
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Layouts
  // ---------------------------------------------------------------------------

  /// Phones and tablets held upright: everything in one centred column.
  Widget _buildPortraitLayout(
    AuthController controller,
    LanguageService languageService,
    bool isTablet,
  ) {
    return SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(
            horizontal: isTablet ? 40 : 24,
            vertical: 24,
          ),
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: isTablet ? 520 : 480),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildLogo(width: isTablet ? 340 : 260, onDarkPanel: false),
                Gap(isTablet ? 32 : 24),
                _buildWelcome(onDarkPanel: false, isTablet: isTablet),
                Gap(isTablet ? 48 : 40),
                _buildForm(
                  controller,
                  languageService,
                  isTablet: isTablet,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Landscape: branding on one side, the form on the other.
  ///
  /// The brand side is a full-bleed gradient of the logo blue, rounded and
  /// shadowed on its inner edge to separate it from the form side.
  Widget _buildLandscapeLayout(
    AuthController controller,
    LanguageService languageService,
    bool isTablet,
  ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(flex: 5, child: _buildBrandPanel(isTablet: isTablet)),
        Expanded(
          flex: 6,
          child: SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: EdgeInsets.symmetric(
                  horizontal: isTablet ? 56 : 32,
                  vertical: 24,
                ),
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: isTablet ? 460 : 400),
                  child: _buildForm(
                    controller,
                    languageService,
                    isTablet: isTablet,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// The blue branding panel shown beside the form in landscape.
  Widget _buildBrandPanel({required bool isTablet}) {
    const radius = BorderRadius.horizontal(right: Radius.circular(48));

    return DecoratedBox(
      decoration: const BoxDecoration(
        // The pair this panel used to spell out is the house gradient; it now
        // comes from the one definition, so a change there reaches the panel.
        gradient: AppGradients.brandWide,
        borderRadius: radius,
        boxShadow: [
          BoxShadow(
            color: Color(0x33008DD2),
            blurRadius: 24,
            offset: Offset(6, 0),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: radius,
        child: CustomPaint(
          // On the blue panel the decorative shapes are drawn in white.
          painter: const _BackdropPainter(color: Colors.white, intensity: 1),
          child: SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: EdgeInsets.symmetric(
                  horizontal: isTablet ? 40 : 24,
                  vertical: 24,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildLogo(
                      width: isTablet ? 320 : 220,
                      onDarkPanel: true,
                    ),
                    Gap(isTablet ? 32 : 20),
                    _buildWelcome(onDarkPanel: true, isTablet: isTablet),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Pieces
  // ---------------------------------------------------------------------------

  /// The logo. On the blue panel it sits on a white plate so the blue artwork
  /// stays readable; on the light background it needs no plate at all.
  Widget _buildLogo({required double width, required bool onDarkPanel}) {
    final image = Image.asset(
      AppImages.logo,
      width: width,
      height: width / _kLogoAspectRatio,
      fit: BoxFit.cover,
    );

    if (!onDarkPanel) return image;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: width * 0.09,
        vertical: width * 0.06,
      ),
      decoration: BoxDecoration(
        color: ColorManager.white,
        borderRadius: BorderRadius.circular(28),
      ),
      child: image,
    );
  }

  Widget _buildWelcome({required bool onDarkPanel, required bool isTablet}) {
    final titleColor = onDarkPanel ? ColorManager.white : Colors.black;
    final subtitleColor =
        onDarkPanel ? ColorManager.white.withOpacity(0.85) : Colors.black;

    return Column(
      children: [
        customText(
          text: _tr('welcome'),
          textStyle: TextStyle(
            fontSize: isTablet ? 40 : 30,
            fontWeight: FontWeight.bold,
            color: titleColor,
          ),
        ),
        const Gap(8),
        customText(
          text: _tr('connectContinue'),
          textStyle: TextStyle(
            fontSize: isTablet ? 18 : 15,
            color: subtitleColor,
          ),
        ),
      ],
    );
  }

  /// Email, password, sign in button and the language switcher.
  Widget _buildForm(
    AuthController controller,
    LanguageService languageService, {
    required bool isTablet,
  }) {
    return Form(
      key: controller.loginFormKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Email input
          TextFormField(
            controller: controller.emailLoginController,
            focusNode: controller.emailLoginFocusNode,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            autocorrect: false,
            textCapitalization: TextCapitalization.none,
            autofillHints: const [AutofillHints.email],
            onFieldSubmitted: (_) =>
                controller.passwordLoginFocusNode.requestFocus(),
            style: TextStyle(
              color: Colors.black,
              fontSize: isTablet ? 17 : 15,
            ),
            decoration: _inputDecoration(
              label: _tr('email'),
              hint: _tr('emailHint'),
              prefixIcon: Icons.email_outlined,
              isTablet: isTablet,
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
              focusNode: controller.passwordLoginFocusNode,
              obscureText: !controller.isPasswordVisible.value,
              keyboardType: TextInputType.visiblePassword,
              textInputAction: TextInputAction.done,
              autocorrect: false,
              enableSuggestions: false,
              autofillHints: const [AutofillHints.password],
              onFieldSubmitted: (_) => controller.login(),
              style: TextStyle(
                color: Colors.black,
                fontSize: isTablet ? 17 : 15,
              ),
              decoration: _inputDecoration(
                label: _tr('password'),
                hint: '••••••••',
                prefixIcon: Icons.lock_outline,
                isTablet: isTablet,
                suffixIcon: IconButton(
                  onPressed: controller.togglePasswordVisibility,
                  icon: Icon(
                    controller.isPasswordVisible.value
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                    color: ColorManager.textSecondary,
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
                      fontSize: isTablet ? 18 : 16,
                      fontWeight: FontWeight.w600,
                      color: ColorManager.textOnPrimary,
                    ),
                    borderRadius: 12,
                    width: double.infinity,
                    height: isTablet ? 62 : 55,
                    color: ColorManager.primaryColor,
                  ),
          ),
          const Gap(28),

          // Language selection
          Obx(
            () => _buildLanguageSelector(
              current: languageService.currentLanguage.value,
              onSelect: languageService.setLanguage,
              isTablet: isTablet,
            ),
          ),
        ],
      ),
    );
  }

  InputDecoration _inputDecoration({
    required String label,
    required String hint,
    required IconData prefixIcon,
    required bool isTablet,
    Widget? suffixIcon,
  }) {
    // Without a colour the field gets a hairline outline, so it stays defined
    // against the tinted background instead of melting into it.
    OutlineInputBorder border({Color? color}) => OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: color == null
          ? const BorderSide(color: Color(0x33626D77))
          : BorderSide(color: color, width: 2),
    );

    return InputDecoration(
      labelText: label,
      hintText: hint,
      labelStyle: const TextStyle(color: Colors.black),
      hintStyle: const TextStyle(color: Colors.black54),
      prefixIcon: Icon(prefixIcon, color: ColorManager.primaryColor),
      suffixIcon: suffixIcon,
      contentPadding: EdgeInsets.symmetric(
        horizontal: 16,
        vertical: isTablet ? 22 : 16,
      ),
      filled: true,
      // Kept opaque so the fields stay readable over the background shapes.
      fillColor: ColorManager.white,
      border: border(),
      enabledBorder: border(),
      focusedBorder: border(color: ColorManager.primaryColor),
      errorBorder: border(color: ColorManager.errorColor),
      focusedErrorBorder: border(color: ColorManager.errorColor),
    );
  }

  Widget _buildLanguageSelector({
    required String current,
    required ValueChanged<String> onSelect,
    required bool isTablet,
  }) {
    return Column(
      children: [
        Text(
          _tr('language'),
          style: TextStyle(
            fontSize: isTablet ? 14 : 13,
            color: ColorManager.textSecondary,
            fontWeight: FontWeight.w600,
          ),
        ),
        const Gap(10),
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: ColorManager.white,
            borderRadius: BorderRadius.circular(30),
            border: Border.all(color: Colors.black12),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildLanguageOption(
                flag: '\u{1F1EB}\u{1F1F7}',
                label: _tr('french'),
                selected: current == 'fr',
                onTap: () => onSelect('fr'),
                isTablet: isTablet,
              ),
              const Gap(4),
              _buildLanguageOption(
                flag: '\u{1F1F9}\u{1F1F3}',
                label: _tr('arabic'),
                selected: current == 'ar',
                onTap: () => onSelect('ar'),
                isTablet: isTablet,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildLanguageOption({
    required String flag,
    required String label,
    required bool selected,
    required VoidCallback onTap,
    required bool isTablet,
  }) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(26),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(26),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: EdgeInsets.symmetric(
            horizontal: isTablet ? 22 : 18,
            vertical: isTablet ? 12 : 10,
          ),
          decoration: BoxDecoration(
            color: selected ? ColorManager.primaryColor : Colors.transparent,
            borderRadius: BorderRadius.circular(26),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(flag, style: TextStyle(fontSize: isTablet ? 18 : 16)),
              const Gap(8),
              Text(
                label,
                style: TextStyle(
                  fontSize: isTablet ? 15 : 14,
                  color: selected ? ColorManager.textOnPrimary : Colors.black87,
                  fontWeight: selected ? FontWeight.bold : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

}

/// Draws the large soft shapes that sit behind the login content.
///
/// The same painter is used on both backgrounds: [color] is the logo blue over
/// the light page, and white over the blue branding panel.
class _BackdropPainter extends CustomPainter {
  const _BackdropPainter({required this.color, required this.intensity});

  final Color color;

  /// Multiplier applied to every shape's opacity, so the same composition can
  /// be loud on the branding panel and barely-there on the light page.
  final double intensity;

  @override
  void paint(Canvas canvas, Size size) {
    void blob(
      double dx,
      double dy,
      double radius,
      double opacity, {
      double? strokeWidth,
    }) {
      final paint = Paint()
        ..color = color.withOpacity((opacity * intensity).clamp(0.0, 1.0))
        ..style = strokeWidth == null ? PaintingStyle.fill : PaintingStyle.stroke
        ..strokeWidth = strokeWidth ?? 0;
      canvas.drawCircle(
        Offset(dx * size.width, dy * size.height),
        radius * size.width,
        paint,
      );
    }

    blob(-0.12, -0.06, 0.45, 0.16);
    blob(1.04, 0.16, 0.26, 0.14);
    blob(1.00, 0.18, 0.40, 0.10, strokeWidth: size.width * 0.012);
    blob(0.82, 0.94, 0.34, 0.12);
    blob(0.14, 0.74, 0.08, 0.18);
    blob(0.28, 1.05, 0.24, 0.09);
  }

  @override
  bool shouldRepaint(covariant _BackdropPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.intensity != intensity;
}
