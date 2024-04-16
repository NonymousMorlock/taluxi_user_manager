import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:flutter/foundation.dart';
import 'package:flutter_facebook_auth/flutter_facebook_auth.dart';
import 'package:user_manager/src/authentication_provider.dart';
import 'package:user_manager/src/entities/user.dart';
import 'package:user_manager/src/exceptions/authentication_exception.dart';
import 'package:user_manager/src/exceptions/user_data_access_exception.dart';
import 'package:user_manager/src/firebase_gateways/firebase_user_interface.dart';
import 'package:user_manager/src/repositories/user_data_repository.dart';

class FirebaseAuthProvider
    with ChangeNotifier
    implements AuthenticationProvider {
  factory FirebaseAuthProvider() => _singleton;

  FirebaseAuthProvider._internal()
      : _userDataRepository = UserDataRepository.instance,
        _firebaseAuth = firebase_auth.FirebaseAuth.instance {
    _firebaseAuth.authStateChanges().listen(_onAuthStateChanged);
    _authStateStreamController.onListen =
        () => _authStateStreamController.sink.add(_currentAuthState);
    FacebookAuth.instance.logOut();
  }

  @visibleForTesting
  FirebaseAuthProvider.forTest(this._userDataRepository, this._firebaseAuth) {
    _firebaseAuth.authStateChanges().listen(_onAuthStateChanged);
    _authStateStreamController.onListen =
        () => _authStateStreamController.sink.add(_currentAuthState);
  }

  late firebase_auth.FirebaseAuth _firebaseAuth;
  AuthState _currentAuthState = AuthState.uninitialized;
  final _authStateStreamController = StreamController<AuthState>.broadcast();
  late final UserDataRepository _userDataRepository;
  User? _user;
  static final _singleton = FirebaseAuthProvider._internal();
  @visibleForTesting
  int wrongPasswordCounter = 0;
  @visibleForTesting
  String? lastTryedEmail;

  @override
  AuthState get authState => _currentAuthState;

  @override
  User? get user => _user;

  @override
  Stream<AuthState> get authBinaryState => _authStateStreamController.stream;

  @override
  void dispose() {
    _authStateStreamController.close();
    super.dispose();
  }

  Future<void> _onAuthStateChanged(firebase_auth.User? firebaseUser) async {
    // TODO: refactoring
    try {
      if (firebaseUser == null) {
        _user = null;
        _switchState(AuthState.unauthenticated);
      } else {
        if (authState == AuthState.registering) {
          // fetch user profile data that was updated while registering.
          await firebaseUser.reload();
          firebaseUser = _firebaseAuth.currentUser;
        }
        _user = FirebaseUserInterface(
          firebaseUser: firebaseUser!,
          userDataRepository: _userDataRepository,
        );
        _switchState(AuthState.authenticated);
        wrongPasswordCounter = 0;
      }
    } catch (e) {
      //TODO: rapport error.
      if (_firebaseAuth.currentUser != null &&
          authState != AuthState.authenticated) {
        _switchState(AuthState.authenticated);
      }
    }
  }

  @override
  Future<void> signInWithFacebook() async {
    try {
      // TODOtest signInWithFacebook
      _switchState(AuthState.authenticating);
      final result = await FacebookAuth.instance.login(
        loginBehavior: defaultTargetPlatform == TargetPlatform.android
            ? LoginBehavior.dialogOnly
            : LoginBehavior.nativeWithFallback,
      );
      if (result.status == LoginStatus.success) {
        final facebookOAuthCredential =
            firebase_auth.FacebookAuthProvider.credential(
          result.accessToken!.token,
        );
        final userCredential =
            await _firebaseAuth.signInWithCredential(facebookOAuthCredential);
        if (userCredential.additionalUserInfo!.isNewUser) {
          await _userDataRepository
              .initAdditionalData(userCredential.user!.uid);
        }
      }
    } catch (e) {
      throw await _handleException(e, facebook: true);
    }
  }

  @override
  Future<void> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    try {
      _switchState(AuthState.authenticating);
      await _firebaseAuth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
    } on firebase_auth.FirebaseAuthException catch (e) {
      throw await _handleException(
        firebase_auth.FirebaseAuthException(
          email: email,
          message: e.message,
          code: e.code,
        ),
      );
    } catch (e) {
      throw await _handleException(e);
    }
  }

  @override
  Future<void> registerUser({
    required String firstName,
    required String lastName,
    required String email,
    required String password,
  }) async {
    try {
      _switchState(AuthState.registering);
      final userCredential = await _firebaseAuth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      if (userCredential.user == null) {
        throw const AuthenticationException.unknown();
      }
      await _userDataRepository.initAdditionalData(userCredential.user!.uid);
      await userCredential.user!.updateDisplayName('$firstName $lastName');
    } catch (e) {
      throw await _handleException(e);
    }
  }

  @override
  Future<void> sendPasswordResetEmail(String email) async {
    try {
      //TODO: tests sendPasswordResetEmail.
      await _firebaseAuth.sendPasswordResetEmail(email: email);
    } catch (e) {
      throw await _handleException(e);
    }
  }

  @override
  Future<void> signOut() async {
    try {
      await _firebaseAuth.signOut();
    } catch (e) {
      throw await _handleException(e);
    }
  }

  void _switchState(AuthState targetState) {
    if (_currentAuthState == targetState) return;
    _currentAuthState = targetState;
    if (targetState == AuthState.authenticated ||
        targetState == AuthState.unauthenticated) {
      _authStateStreamController.sink.add(targetState);
    }
    notifyListeners();
  }

  Future<Exception> _handleException(
    dynamic exception, {
    bool facebook = false,
  }) async {
    if (_firebaseAuth.currentUser == null) {
      _switchState(AuthState.unauthenticated);
    }
    if (exception is firebase_auth.FirebaseAuthException) {
      debugPrint('\n\n------$exception-----\n\n');
      return _convertFirebaseAuthException(exception);
    }
    if (exception is UserDataAccessException) {
      return exception; // <==> rethrow
    }
    if (facebook) {
      return const AuthenticationException.facebookLoginFailed();
    }
    // TODO: implement error rapport systéme.
    return const AuthenticationException.unknown();
  }

  Future<AuthenticationException> _convertFirebaseAuthException(
    firebase_auth.FirebaseAuthException exception,
  ) async {
    switch (exception.code) {
      case 'account-exists-with-different-credential':
        return const AuthenticationException
            .accountExistsWithDifferentCredential();
      case 'invalid-credential':
        return const AuthenticationException.invalidCredential();
      case 'invalid-verification-code':
        return const AuthenticationException.invalidVerificationCode();
      case 'email-already-in-use':
        return const AuthenticationException.emailAlreadyUsed();
      case 'weak-password':
        return const AuthenticationException.weakPassword();
      case 'invalid-email':
        return const AuthenticationException.invalidEmail();
      case 'user-disabled':
        return const AuthenticationException.userDisabled();
      case 'user-not-found':
        return const AuthenticationException.userNotFound();
      case 'wrong-password':
        if (lastTryedEmail != exception.email) {
          wrongPasswordCounter = 0;
          lastTryedEmail = exception.email;
        }
        if (++wrongPasswordCounter >= 3) {
          return _handleManyWrongPassword(exception);
        }
        return const AuthenticationException.wrongPassword();
      case 'too-many-requests':
        return const AuthenticationException.tooManyRequests();
      default:
        return const AuthenticationException.unknown();
    }
  }

  Future<AuthenticationException> _handleManyWrongPassword(
    firebase_auth.FirebaseAuthException exception,
  ) async {
    // If the wrong password counter exceeds a certain limit, return a
    // generic error
    if (++wrongPasswordCounter >= 3) {
      return const AuthenticationException(
        exceptionType: AuthenticationExceptionType.wrongPassword,
        message:
            'Failed login attempts exceeded. If you forgot your password, '
                'please use the "Forgot Password" option.',
      );
    }
    // If the wrong password counter is less than the limit,
    // return the wrong password error
    return const AuthenticationException.wrongPassword();
  }
}
