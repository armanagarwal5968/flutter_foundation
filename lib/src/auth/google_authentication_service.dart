import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../telemetry/performance_timing.dart';
import 'auth_user.dart';
import 'account_roles.dart';
import 'authentication_service.dart';

/// Firebase Authentication backed by Google, Apple, and email/password.
///
/// Web uses Firebase's full-page redirect for Google: popups can open behind
/// the browser on desktop, and popup state can be lost when Safari is opened
/// from apps such as WhatsApp. Android and iOS use the native Google Sign-In
/// SDK and exchange its ID token for a Firebase credential.
///
/// Every sign-in path is timed step by step through [PerformanceTiming].
class FirebaseAuthenticationService
    implements AuthenticationService, EmailPasswordAuthenticationService {
  FirebaseAuthenticationService({
    FirebaseAuth? firebaseAuth,
    GoogleSignIn? googleSignIn,
    this.clientId,
    this.serverClientId,
  }) : _firebaseAuth = firebaseAuth ?? FirebaseAuth.instance,
       _googleSignIn = googleSignIn ?? GoogleSignIn.instance;

  final FirebaseAuth _firebaseAuth;
  final GoogleSignIn _googleSignIn;
  final String? clientId;
  final String? serverClientId;

  static Future<void>? _nativeInitialization;
  AuthUser? _currentUser;
  late final Stream<AuthUser?> _sharedAuthStateChanges =
      _firebaseAuth
          .idTokenChanges()
          .asyncMap(_mapUser)
          .map((user) => _currentUser = user)
          .asBroadcastStream();

  @override
  AuthUser? get currentUser => _currentUser;

  @override
  Stream<AuthUser?> get authStateChanges => _sharedAuthStateChanges;

  @override
  Future<void> initialize() => PerformanceTiming.instance.measure(
    'auth_initialize',
    (timing) async {
      if (kIsWeb) {
        // Firebase JS SDK 12.17.0 can close its IndexedDB persistence while an
        // OAuth popup hides the opener tab. Local persistence uses
        // localStorage instead and still keeps the user signed in across
        // browser restarts.
        await _firebaseAuth.setPersistence(Persistence.LOCAL);
        timing.step('set_persistence');
      }
      timing.setAttribute(
        'restored_user',
        _firebaseAuth.currentUser == null ? 'no' : 'yes',
      );
      _currentUser = await _mapUser(_firebaseAuth.currentUser);
      timing.step('load_claims');
      if (!kIsWeb) {
        _nativeInitialization ??= _googleSignIn.initialize(
          clientId: clientId,
          serverClientId: serverClientId,
        );
        await _nativeInitialization;
        timing.step('google_sdk_init');
      }
    },
  );

  @override
  Future<AuthUser?> signInWithGoogle() async {
    final timing = PerformanceTiming.instance.start('sign_in_google');
    try {
      final UserCredential credential;
      if (kIsWeb) {
        if (shouldUseGoogleRedirect(
          isWeb: kIsWeb,
          platform: defaultTargetPlatform,
        )) {
          timing.setAttribute('flow', 'redirect');
          await _firebaseAuth.signInWithRedirect(GoogleAuthProvider());
          timing.step('redirect_start');
          // The browser leaves this page. Firebase restores the signed-in user
          // through authStateChanges when the redirect returns; that part is
          // timed by auth_initialize and post_login_load.
          timing.stop();
          return null;
        }
        timing.setAttribute('flow', 'popup');
        credential = await _firebaseAuth.signInWithPopup(GoogleAuthProvider());
        timing.step('google_popup');
      } else {
        timing.setAttribute('flow', 'native');
        await initialize();
        timing.step('sdk_ready');
        final GoogleSignInAccount googleUser;
        try {
          googleUser = await _googleSignIn.authenticate();
        } on GoogleSignInException catch (error) {
          if (_isCancellation(error.code)) {
            timing.step('google_account_picker');
            timing.stop(outcome: 'cancelled');
            return null;
          }
          rethrow;
        }
        timing.step('google_account_picker');

        final idToken = googleUser.authentication.idToken;
        if (idToken == null) {
          throw StateError('Google Sign-In did not return an ID token.');
        }
        credential = await _firebaseAuth.signInWithCredential(
          GoogleAuthProvider.credential(idToken: idToken),
        );
        timing.step('firebase_credential');
      }

      final user = _currentUser = await _mapUser(credential.user);
      timing.step('load_claims');
      timing.stop();
      return user;
    } on Object {
      timing.stop(outcome: 'error');
      rethrow;
    }
  }

  @override
  Future<AuthUser?> signInWithApple() =>
      PerformanceTiming.instance.measure('sign_in_apple', (timing) async {
        final provider =
            AppleAuthProvider()
              ..addScope('email')
              ..addScope('name');
        final UserCredential credential;
        if (kIsWeb) {
          timing.setAttribute('flow', 'popup');
          credential = await _firebaseAuth.signInWithPopup(provider);
        } else {
          timing.setAttribute('flow', 'native');
          credential = await _firebaseAuth.signInWithProvider(provider);
        }
        timing.step('apple_provider');
        final user = _currentUser = await _mapUser(credential.user);
        timing.step('load_claims');
        return user;
      });

  @override
  Future<AuthUser?> signInWithEmailPassword({
    required String email,
    required String password,
  }) => PerformanceTiming.instance.measure('sign_in_email_password', (
    timing,
  ) async {
    final credential = await _firebaseAuth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    timing.step('firebase_sign_in');
    final user = _currentUser = await _mapUser(credential.user);
    timing.step('load_claims');
    return user;
  });

  @override
  Future<void> signOut() async {
    await _firebaseAuth.signOut();
    _currentUser = null;
    if (!kIsWeb) {
      await initialize();
      await _googleSignIn.signOut();
    }
  }

  static bool _isCancellation(GoogleSignInExceptionCode code) =>
      code == GoogleSignInExceptionCode.canceled ||
      code == GoogleSignInExceptionCode.interrupted;

  static Future<AuthUser?> _mapUser(User? user) async {
    if (user == null) return null;
    final token = await user.getIdTokenResult();
    return AuthUser(
      id: user.uid,
      email: user.email,
      roles: parseAccountRoles(token.claims),
      accountType:
          token.claims?['accountType'] == AccountType.demo
              ? AccountType.demo
              : AccountType.standard,
      displayName: user.displayName,
      photoUrl: user.photoURL,
    );
  }
}

/// Web always uses the full-page redirect. On desktop browsers the OAuth popup
/// can open behind the app window, leaving users on "Signing in..." until they
/// find it.
@visibleForTesting
bool shouldUseGoogleRedirect({
  required bool isWeb,
  required TargetPlatform platform,
}) => isWeb;

/// Backward-compatible name retained for existing foundation consumers.
@Deprecated('Use FirebaseAuthenticationService instead.')
typedef GoogleAuthenticationService = FirebaseAuthenticationService;
