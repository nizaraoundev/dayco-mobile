import 'package:dayco_mobile/routes/app_routes.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../features/auth/presentation/pages/login.dart';
import '../features/auth/presentation/bindings/auth_binding.dart';
import '../core/di/service_locator.dart';
import '../features/auth/domain/repositories/auth_repository.dart';

// Commercial feature imports
import '../features/commercial/presentation/pages/commercial_dashboard_page.dart';
import '../features/commercial/presentation/pages/commercial_map_page.dart';
import '../features/commercial/presentation/pages/clients_page.dart';
import '../features/commercial/presentation/pages/products_page.dart';
import '../features/commercial/presentation/pages/orders_page.dart';
import '../features/commercial/bindings/commercial_binding.dart';
import '../features/startup/presentation/pages/initialization_route.dart';

class AppPages {
  AppPages._();

  static const initial = AppRoutes.driverDashboard;

  // GetX routes for GetMaterialApp with enhanced transitions and curves
  static final routes = [
    GetPage(
      name: AppRoutes.splash,
      page: () => const SplashPage(),
      transition: Transition.fade,
      transitionDuration: const Duration(milliseconds: 800),
      curve: Curves.easeInOut,
    ),
    GetPage(
      name: AppRoutes.onboarding,
      page: () => const OnboardingPage(),
      transition: Transition.rightToLeft,
      transitionDuration: const Duration(milliseconds: 500),
      curve: Curves.fastOutSlowIn,
    ),
    GetPage(
      name: AppRoutes.login,
      page: () => const LoginPage(),
      binding: AuthBinding(),
      transition: Transition.rightToLeft,
      transitionDuration: const Duration(milliseconds: 400),
      curve: Curves.easeInOut,
    ),

    // ============== COMMERCIAL ROUTES (B2B Sales App) ==============
    GetPage(
      name: AppRoutes.commercialDashboard,
      page: () => const CommercialDashboardPage(),
      binding: InitialCommercialBinding(),
      transition: Transition.fadeIn,
      transitionDuration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    ),
    GetPage(
      name: AppRoutes.initializing,
      page: () => const InitializationRoute(),
      // Fades rather than slides: this is a continuation of signing in, not a
      // push onto a navigation stack.
      transition: Transition.fadeIn,
      transitionDuration: const Duration(milliseconds: 250),
      curve: Curves.easeInOut,
    ),
    GetPage(
      name: AppRoutes.commercialMap,
      page: () => const CommercialMapPage(),
      transition: Transition.rightToLeft,
      transitionDuration: const Duration(milliseconds: 350),
      curve: Curves.easeInOut,
    ),
    GetPage(
      name: AppRoutes.clients,
      page: () => const ClientsPage(),
      binding: CommercialBinding(),
      transition: Transition.rightToLeft,
      transitionDuration: const Duration(milliseconds: 350),
      curve: Curves.easeInOut,
    ),
    GetPage(
      name: AppRoutes.products,
      page: () => const ProductsPage(),
      binding: ProductsBinding(),
      transition: Transition.rightToLeft,
      transitionDuration: const Duration(milliseconds: 350),
      curve: Curves.easeInOut,
    ),
    GetPage(
      name: AppRoutes.orders,
      page: () => const OrdersPage(),
      binding: OrdersBinding(),
      transition: Transition.rightToLeft,
      transitionDuration: const Duration(milliseconds: 350),
      curve: Curves.easeInOut,
    ),

    // ============== END COMMERCIAL ROUTES ==============
    GetPage(
      name: AppRoutes.driverProfile,
      page: () => const DriverProfilePage(),
      transition: Transition.zoom,
      transitionDuration: const Duration(milliseconds: 400),
      curve: Curves.elasticOut,
    ),
    GetPage(
      name: AppRoutes.rideRequests,
      page: () => const RideRequestsPage(),
      transition: Transition.rightToLeft,
      transitionDuration: const Duration(milliseconds: 350),
      curve: Curves.decelerate,
    ),
    GetPage(
      name: AppRoutes.activeRide,
      page: () => const ActiveRidePage(),
      transition: Transition.fadeIn,
      transitionDuration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    ),

    GetPage(
      name: AppRoutes.rideDetails,
      page: () => const RideDetailsPage(),
      transition: Transition.downToUp,
      transitionDuration: const Duration(milliseconds: 400),
      curve: Curves.easeOutBack,
    ),

    GetPage(
      name: AppRoutes.withdrawEarnings,
      page: () => const WithdrawEarningsPage(),
      transition: Transition.downToUp,
      transitionDuration: const Duration(milliseconds: 350),
      curve: Curves.easeOutBack,
    ),
    GetPage(
      name: AppRoutes.paymentSettings,
      page: () => const PaymentSettingsPage(),
      transition: Transition.rightToLeft,
      transitionDuration: const Duration(milliseconds: 350),
      curve: Curves.decelerate,
    ),
    GetPage(
      name: AppRoutes.myDocuments,
      page: () => const MyDocumentsPage(),
      transition: Transition.rightToLeft,
      transitionDuration: const Duration(milliseconds: 400),
      curve: Curves.easeInOut,
    ),
    GetPage(
      name: AppRoutes.updateDocuments,
      page: () => const UpdateDocumentsPage(),
      transition: Transition.upToDown,
      transitionDuration: const Duration(milliseconds: 500),
      curve: Curves.easeOutCubic,
    ),

    GetPage(
      name: AppRoutes.helpCenter,
      page: () => const HelpCenterPage(),
      transition: Transition.rightToLeft,
      transitionDuration: const Duration(milliseconds: 350),
      curve: Curves.decelerate,
    ),
    GetPage(
      name: AppRoutes.contactUs,
      page: () => const ContactUsPage(),
      transition: Transition.rightToLeft,
      transitionDuration: const Duration(milliseconds: 350),
      curve: Curves.decelerate,
    ),
    GetPage(
      name: AppRoutes.faq,
      page: () => const FaqPage(),
      transition: Transition.rightToLeft,
      transitionDuration: const Duration(milliseconds: 350),
      curve: Curves.decelerate,
    ),
    GetPage(
      name: AppRoutes.reportIssue,
      page: () => const ReportIssuePage(),
      transition: Transition.downToUp,
      transitionDuration: const Duration(milliseconds: 400),
      curve: Curves.easeOutCubic,
    ),
    GetPage(
      name: AppRoutes.settings,
      page: () => const SettingsPage(),
      transition: Transition.zoom,
      transitionDuration: const Duration(milliseconds: 400),
      curve: Curves.elasticOut,
    ),
    GetPage(
      name: AppRoutes.notifications,
      page: () => const NotificationsPage(),
      transition: Transition.downToUp,
      transitionDuration: const Duration(milliseconds: 350),
      curve: Curves.easeOutCubic,
    ),
    GetPage(
      name: AppRoutes.privacy,
      page: () => const PrivacyPage(),
      transition: Transition.rightToLeft,
      transitionDuration: const Duration(milliseconds: 350),
      curve: Curves.decelerate,
    ),
    GetPage(
      name: AppRoutes.termsAndConditions,
      page: () => const TermsAndConditionsPage(),
      transition: Transition.rightToLeft,
      transitionDuration: const Duration(milliseconds: 350),
      curve: Curves.decelerate,
    ),
    GetPage(
      name: AppRoutes.aboutUs,
      page: () => const AboutUsPage(),
      transition: Transition.rightToLeft,
      transitionDuration: const Duration(milliseconds: 350),
      curve: Curves.decelerate,
    ),
  ];
}

class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage> {
  @override
  void initState() {
    super.initState();
    _navigateFromSplash();
  }

  Future<void> _navigateFromSplash() async {
    // Building the dependency graph here rather than before `runApp` keeps the
    // first frame cheap: the branding is already on screen while the secure
    // storage is read and the session restored. Nothing else can reach the
    // locator first, because this is the initial route and it does not navigate
    // until these have completed.
    await configureDependencies();

    // The 700ms `Future.delayed` that used to be here was pure dead time: it
    // delayed every cold start to make the splash visible. Routing now happens
    // as soon as the stored session has been checked.
    final restored = await locator<AuthRepository>().restoreSession();

    if (!mounted) return;

    // A restored session goes through initialization too, so a restart reaches
    // the map with its data already loaded — the same path as a fresh sign-in,
    // rather than a second code path that can drift from it.
    Get.offAllNamed(
      restored != null ? AppRoutes.initializing : AppRoutes.login,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: const [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            
          ],
        ),
      ),
    );
  }
}

class OnboardingPage extends StatelessWidget {
  const OnboardingPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Text('Onboarding Page - Replace with actual implementation'),
      ),
    );
  }
}

class ForgotPasswordPage extends StatelessWidget {
  const ForgotPasswordPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Text(
          'Forgot Password Page - Replace with actual implementation',
        ),
      ),
    );
  }
}

class VerifyOtpPage extends StatelessWidget {
  const VerifyOtpPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Text('Verify OTP Page - Replace with actual implementation'),
      ),
    );
  }
}

class ResetPasswordPage extends StatelessWidget {
  const ResetPasswordPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Text('Reset Password Page - Replace with actual implementation'),
      ),
    );
  }
}

class DashboardPage extends StatelessWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Text('Dashboard Page - Replace with actual implementation'),
      ),
    );
  }
}

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Text('Profile Page - Replace with actual implementation'),
      ),
    );
  }
}

class RideRequestPage extends StatelessWidget {
  const RideRequestPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Text('Ride Request Page - Replace with actual implementation'),
      ),
    );
  }
}

class RideTrackingPage extends StatelessWidget {
  const RideTrackingPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Text('Ride Tracking Page - Replace with actual implementation'),
      ),
    );
  }
}

class RideDetailsPage extends StatelessWidget {
  const RideDetailsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Text('Ride Details Page - Replace with actual implementation'),
      ),
    );
  }
}

class BusinessPortalPage extends StatelessWidget {
  const BusinessPortalPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Text(
          'Business Portal Page - Replace with actual implementation',
        ),
      ),
    );
  }
}

class BusinessDashboardPage extends StatelessWidget {
  const BusinessDashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Text(
          'Business Dashboard Page - Replace with actual implementation',
        ),
      ),
    );
  }
}

class BusinessProfilePage extends StatelessWidget {
  const BusinessProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Text(
          'Business Profile Page - Replace with actual implementation',
        ),
      ),
    );
  }
}

class BusinessSettingsPage extends StatelessWidget {
  const BusinessSettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Text(
          'Business Settings Page - Replace with actual implementation',
        ),
      ),
    );
  }
}

class WalletPage extends StatelessWidget {
  const WalletPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Text('Wallet Page - Replace with actual implementation'),
      ),
    );
  }
}

class WalletHistoryPage extends StatelessWidget {
  const WalletHistoryPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Text('Wallet History Page - Replace with actual implementation'),
      ),
    );
  }
}

class AddMoneyPage extends StatelessWidget {
  const AddMoneyPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Text('Add Money Page - Replace with actual implementation'),
      ),
    );
  }
}

class WithdrawMoneyPage extends StatelessWidget {
  const WithdrawMoneyPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Text('Withdraw Money Page - Replace with actual implementation'),
      ),
    );
  }
}

class PaymentMethodsPage extends StatelessWidget {
  const PaymentMethodsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Text(
          'Payment Methods Page - Replace with actual implementation',
        ),
      ),
    );
  }
}

class HelpCenterPage extends StatelessWidget {
  const HelpCenterPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Text('Help Center Page - Replace with actual implementation'),
      ),
    );
  }
}

class ContactUsPage extends StatelessWidget {
  const ContactUsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Text('Contact Us Page - Replace with actual implementation'),
      ),
    );
  }
}

class FaqPage extends StatelessWidget {
  const FaqPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Text('FAQ Page - Replace with actual implementation'),
      ),
    );
  }
}

class ReportIssuePage extends StatelessWidget {
  const ReportIssuePage({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Text('Report Issue Page - Replace with actual implementation'),
      ),
    );
  }
}

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Text('Settings Page - Replace with actual implementation'),
      ),
    );
  }
}

class NotificationsPage extends StatelessWidget {
  const NotificationsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Text('Notifications Page - Replace with actual implementation'),
      ),
    );
  }
}

class PrivacyPage extends StatelessWidget {
  const PrivacyPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Text('Privacy Page - Replace with actual implementation'),
      ),
    );
  }
}

class TermsAndConditionsPage extends StatelessWidget {
  const TermsAndConditionsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Text(
          'Terms and Conditions Page - Replace with actual implementation',
        ),
      ),
    );
  }
}

class AboutUsPage extends StatelessWidget {
  const AboutUsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Text('About Us Page - Replace with actual implementation'),
      ),
    );
  }
}

class DriverProfilePage extends StatelessWidget {
  const DriverProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Text('Driver Profile Page - Replace with actual implementation'),
      ),
    );
  }
}

class CompletedRidesPage extends StatelessWidget {
  const CompletedRidesPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Text(
          'Completed Rides Page - Replace with actual implementation',
        ),
      ),
    );
  }
}

class ActiveRidePage extends StatelessWidget {
  const ActiveRidePage({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Text('Active Ride Page - Replace with actual implementation'),
      ),
    );
  }
}

class RideRequestsPage extends StatelessWidget {
  const RideRequestsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Text('Ride Requests Page - Replace with actual implementation'),
      ),
    );
  }
}

class MyDocumentsPage extends StatelessWidget {
  const MyDocumentsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Text('My Documents Page - Replace with actual implementation'),
      ),
    );
  }
}

class DriverWalletPage extends StatelessWidget {
  const DriverWalletPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Text('Driver Wallet Page - Replace with actual implementation'),
      ),
    );
  }
}

class WithdrawEarningsPage extends StatelessWidget {
  const WithdrawEarningsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Text(
          'Withdraw Earnings Page - Replace with actual implementation',
        ),
      ),
    );
  }
}

class PaymentSettingsPage extends StatelessWidget {
  const PaymentSettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Text(
          'Payment Settings Page - Replace with actual implementation',
        ),
      ),
    );
  }
}

class UpdateDocumentsPage extends StatelessWidget {
  const UpdateDocumentsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Text(
          'Update Documents Page - Replace with actual implementation',
        ),
      ),
    );
  }
}
