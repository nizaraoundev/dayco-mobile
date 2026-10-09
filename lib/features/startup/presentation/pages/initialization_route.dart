import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get/get.dart';

import '../../../../core/di/service_locator.dart';
import '../../../../core/services/location_service.dart';
import '../../../../routes/app_routes.dart';
import '../../../auth/domain/repositories/auth_repository.dart';
import '../../../cartography/presentation/marker_icon_cache.dart';
import '../../../clients/domain/repositories/clients_repository.dart';
import '../cubit/app_initialization_cubit.dart';
import 'initialization_page.dart';

/// Hosts [InitializationPage]: builds the cubit from the service locator,
/// starts it once, and owns the navigation that follows.
///
/// Navigation lives here rather than in the cubit so the cubit stays a pure,
/// testable state machine — the previous controllers called `Get.offAllNamed`
/// from inside business logic, which is why none of them could be tested
/// without a `GetMaterialApp`.
class InitializationRoute extends StatelessWidget {
  const InitializationRoute({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider<AppInitializationCubit>(
      create: (_) => AppInitializationCubit(
        authRepository: locator<AuthRepository>(),
        clientsRepository: locator<ClientsRepository>(),
        locationService: const GeolocatorLocationService(),
        markerIconCache: locator<MarkerIconCache>(),
      )..start(),
      child: PopScope(
        // The session is already established; backing out of initialization
        // would strand the user on an empty stack or back at the login screen.
        canPop: false,
        child: InitializationPage(
          // `offAllNamed` clears the stack, so the hardware back button cannot
          // return to the login screen or to this screen after it completes.
          onReady: () => Get.offAllNamed(AppRoutes.commercialMap),
          onReauthenticationRequired: () => Get.offAllNamed(AppRoutes.login),
        ),
      ),
    );
  }
}
