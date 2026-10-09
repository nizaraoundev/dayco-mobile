import 'package:get/get.dart';

class AppRoutes {
  // Navigation helper methods
  void goTo(String routeName) {
    Get.toNamed(routeName);
  }

  void goToEnd(String routeName) {
    Get.offAllNamed(routeName);
  }

  // Auth Routes
  static const String splash = '/splash';
  static const String onboarding = '/onboarding';
  static const String login = '/login';
  static const String driverRegistration = '/driver-registration';
  static const String forgotPassword = '/forgot-password';
  static const String verifyOtp = '/verify-otp';
  static const String resetPassword = '/reset-password';

  // Driver Registration & Document Verification Routes
  static const String documentUpload = '/document-upload';
  static const String documentVerification = '/document-verification';
  static const String verificationStatus = '/verification-status';

  // Main Driver App Routes
  static const String driverDashboard = '/driver-dashboard';
  static const String driverProfile = '/driver-profile';

  // Driver Job Routes
  static const String rideRequests = '/ride-requests';
  static const String activeRide = '/active-ride';
  static const String rideHistory = '/ride-history';
  static const String completedRides = '/completed-rides';
  static const String rideDetails = '/ride-details';
  static const String earnings = '/earnings';

  // Driver Status Routes
  static const String driverStatus = '/driver-status';
  static const String goOnline = '/go-online';
  static const String goOffline = '/go-offline';

  // Driver Wallet Routes
  static const String driverWallet = '/driver-wallet';
  static const String earningsHistory = '/earnings-history';
  static const String withdrawEarnings = '/withdraw-earnings';
  static const String paymentSettings = '/payment-settings';

  // Driver Documents Routes
  static const String myDocuments = '/my-documents';
  static const String updateDocuments = '/update-documents';
  static const String documentStatus = '/document-status';

  // Support Routes
  static const String support = '/support';
  static const String helpCenter = '/help-center';
  static const String contactUs = '/contact-us';
  static const String faq = '/faq';
  static const String reportIssue = '/report-issue';

  // Settings Routes
  static const String settings = '/settings';
  static const String notifications = '/notifications';
  static const String privacy = '/privacy';
  static const String privacyandpolicy = '/privacy-policy';
  static const String termsAndConditions = '/terms-and-conditions';
  static const String aboutUs = '/about-us';

  // Commercial Routes (B2B Sales App)
  static const String commercialDashboard = '/commercial-dashboard';
  static const String commercialMap = '/commercial-map';

  /// Post-login initialization. Reached only with a valid session, and always
  /// entered with `offAllNamed` so the login screen is not left on the stack.
  static const String initializing = '/initializing';
  static const String clients = '/clients';
  static const String clientDetail = '/client-detail';
  static const String products = '/products';
  static const String productDetail = '/product-detail';
  static const String orders = '/orders';
  static const String orderDetail = '/order-detail';
  static const String newOrder = '/new-order';
  static const String visits = '/visits';
  static const String visitDetail = '/visit-detail';
  static const String route = '/route';
}
