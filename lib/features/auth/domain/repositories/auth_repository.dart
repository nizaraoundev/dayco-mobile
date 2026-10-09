import '../../../../core/error/result.dart';
import '../entities/commercial_user.dart';

/// The application's authority on who is signed in.
///
/// Unlike the previous `AuthService`, this is an interface: the cubits depend on
/// it, not on `Dio` or `SharedPreferences`, so they can be unit-tested with a
/// fake. It is also the single source of truth for the connected user — the old
/// code re-read `connected_user_id` from preferences in at least four places,
/// which is how the map and the client list could disagree about who was
/// signed in.
abstract interface class AuthRepository {
  /// The signed-in representative, or `null` when signed out.
  ///
  /// Synchronous because it is read on nearly every screen build; the value is
  /// restored into memory by [restoreSession] during startup.
  CommercialUser? get currentUser;

  /// Emits on sign-in, sign-out and profile refresh. Never closes while the app
  /// is running.
  Stream<CommercialUser?> get userChanges;

  /// Whether a usable, unexpired session exists.
  bool get hasValidSession;

  /// Rehydrates the session from secure storage at startup.
  ///
  /// Returns the restored user, or `null` when there is no session or the stored
  /// token has expired. Expired tokens are cleared as a side effect, so the app
  /// can never start in a half-signed-in state.
  Future<CommercialUser?> restoreSession();

  /// Signs in with `codeClient` + password and loads the full profile.
  ///
  /// Profile loading is part of sign-in rather than a separate step so the app
  /// cannot reach the map with a token but no user — the state the old
  /// `AuthController` produced when `getUserDetails` failed after `login`
  /// succeeded.
  Future<Result<CommercialUser>> signIn({
    required String codeClient,
    required String password,
  });

  /// Re-fetches the connected user's profile.
  Future<Result<CommercialUser>> refreshProfile();

  /// Clears every backend's tokens and the cached profile.
  Future<void> signOut();
}
