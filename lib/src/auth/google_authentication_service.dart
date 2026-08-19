import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

import 'auth_user.dart';
import 'account_roles.dart';
import 'authentication_service.dart';

/// Firebase Authentication backed by Google Sign-In.
///
/// Web uses Firebase's popup flow. Android and iOS use the native Google
/// Sign-In SDK and exchange its ID token for a Firebase credential.
class GoogleAuthenticationService
    implements AuthenticationService, EmailPasswordAuthenticationService {
  GoogleAuthenticationService({
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

  @override
  AuthUser? get currentUser => _currentUser;

  @override
  Stream<AuthUser?> get authStateChanges => _firebaseAuth
      .idTokenChanges()
      .asyncMap(_mapUser)
      .map((user) => _currentUser = user);

  @override
  Future<void> initialize() async {
    _currentUser = await _mapUser(_firebaseAuth.currentUser);
    if (!kIsWeb) {
      _nativeInitialization ??= _googleSignIn.initialize(
        clientId: clientId,
        serverClientId: serverClientId,
      );
      await _nativeInitialization;
    }
  }

  @override
  Future<AuthUser?> signInWithGoogle() async {
    final UserCredential credential;
    if (kIsWeb) {
      credential = await _firebaseAuth.signInWithPopup(GoogleAuthProvider());
    } else {
      await initialize();
      final GoogleSignInAccount googleUser;
      try {
        googleUser = await _googleSignIn.authenticate();
      } on GoogleSignInException catch (error) {
        if (_isCancellation(error.code)) return null;
        rethrow;
      }

      final idToken = googleUser.authentication.idToken;
      if (idToken == null) {
        throw StateError('Google Sign-In did not return an ID token.');
      }
      credential = await _firebaseAuth.signInWithCredential(
        GoogleAuthProvider.credential(idToken: idToken),
      );
    }

    return _currentUser = await _mapUser(credential.user);
  }

  @override
  Future<AuthUser?> signInWithEmailPassword({
    required String email,
    required String password,
  }) async {
    final credential = await _firebaseAuth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    return _currentUser = await _mapUser(credential.user);
  }

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
      displayName: user.displayName,
      photoUrl: user.photoURL,
    );
  }
}
