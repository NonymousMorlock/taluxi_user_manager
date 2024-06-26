import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:mockito/mockito.dart';

// TODOComplete mocks.
class MockFirebaseAuth extends Mock implements FirebaseAuth {
  MockFirebaseAuth({signedIn = false}) {
    if (signedIn) {
      signInWithCredential(
        const AuthCredential(
          providerId: 'providerId',
          signInMethod: 'signInMethod',
        ),
      );
    }
  }
  final stateChangedStreamController = StreamController<User>();
  static User? _currentUser;
  static bool mustThrowsException = false;
  static String errorCode = '';
  static List<String> signInMethds = <String>[];

  @override
  User? get currentUser {
    return _currentUser;
  }

  @override
  Future<UserCredential> signInWithCredential(AuthCredential credential) {
    return _fakeSignIn();
  }

  @override
  Future<List<String>> fetchSignInMethodsForEmail(String email) async =>
      signInMethds;

  @override
  Future<UserCredential> createUserWithEmailAndPassword({
    required String email,
    required String password,
  }) {
    return _fakeSignIn();
  }

  @override
  Future<UserCredential> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) {
    return _fakeSignIn();
  }

  @override
  Future<UserCredential> signInWithCustomToken(String token) async {
    return _fakeSignIn();
  }

  @override
  Future<UserCredential> signInAnonymously() {
    return _fakeSignIn(isAnonymous: true);
  }

  @override
  Future<void> signOut() async {
    _currentUser = null;
    stateChangedStreamController.add(_currentUser!);
  }

  Future<UserCredential> _fakeSignIn({bool isAnonymous = false}) {
    if (mustThrowsException) {
      throw FirebaseAuthException(message: 'null', code: errorCode);
    }
    final userCredential = MockUserCredential(isAnonymous: isAnonymous);
    _currentUser = userCredential.user;
    stateChangedStreamController.add(_currentUser!);
    return Future.value(userCredential);
  }

  @override
  Stream<User> authStateChanges() => stateChangedStreamController.stream;
}

class MockUserCredential extends Mock implements UserCredential {
  MockUserCredential({required bool isAnonymous}) : _isAnonymous = isAnonymous;
  final bool _isAnonymous;

  @override
  User get user => MockUser(isAnonymous: _isAnonymous);
}

class MockUser extends Mock implements User {
  MockUser({required bool isAnonymous}) : _isAnonymous = isAnonymous;
  final bool _isAnonymous;

  // !Most be static .
  static String? _displayName = 'Sita Bérété';
  static String _photoURL = 'url-to-photo.jpg';

  @override
  Future<void> updateProfile({
    String? displayName,
    String? photoURL,
  }) async {
    _displayName = displayName;
    _photoURL = photoURL ?? _photoURL;
  }

  @override
  Future<void> reload() async {
    MockFirebaseAuth._currentUser = this;
  }

  @override
  String? get displayName => _displayName;

  @override
  String get uid => 'aabbcc';

  @override
  String get email => 'sita@somedomain.com';

  @override
  String get photoURL => MockUser._photoURL;

  @override
  bool get isAnonymous => _isAnonymous;

  @override
  Future<String> getIdToken([bool forceRefresh = false]) async {
    return Future.value('fake_token');
  }
}
