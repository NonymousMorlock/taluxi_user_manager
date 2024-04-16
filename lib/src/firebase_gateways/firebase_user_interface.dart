import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:user_manager/src/entities/user.dart';
import 'package:user_manager/src/firebase_gateways/firebase_user_data_repository.dart';
import 'package:user_manager/src/repositories/user_data_repository.dart';
import 'package:user_manager/src/utils/helpers.dart';

// TODO: Refactor (keys and ride count handling).
class FirebaseUserInterface implements User {
  FirebaseUserInterface({
    required this.firebaseUser,
    required UserDataRepository userDataRepository,
  }) {
    _userDataRepository = userDataRepository;
    refreshAdditionalData();
    _formattedName = _getFormatedName();
  }
  final fb.User firebaseUser;
  String? _trophies;
  String? _trophiesCount;
  String? _rideCount;
  late UserDataRepository _userDataRepository;
  String? _formattedName;
  Map<String, dynamic>? _rideCountHistory;

  @override
  String? get email => firebaseUser.email;
  @override
  String? get phoneNumber => firebaseUser.phoneNumber;
  @override
  String? get photoUrl => firebaseUser.photoURL;
  @override
  String? get rideCount => _rideCount;
  @override
  String? get trophies => _trophies;
  @override
  String get uid => firebaseUser.uid;
  @override
  String? get userName => firebaseUser.displayName;
  @override
  String? get formatedName => _formattedName;
  @override
  String? get trophiesCount => _trophiesCount;
  @override
  Map<String, dynamic>? get rideCountHistory => _rideCountHistory;
  // @override
  // Map<String, dynamic> get reviews => _reviews;

  String? _getFormatedName() {
    if (userName == null) return null;
    final names = userName!.split(' ');
    final firstNameCapitalized =
        '${names[0][0].toUpperCase()}${names[0].substring(1)}';
    if (names.length >= 3) return '$firstNameCapitalized ${names[1]}';
    return firstNameCapitalized;
  }

  @override
  Future<void> refreshAdditionalData() async {
    // TODO: Refactoring.
    // TODO : Test: Ui most correctly display 'Erreur' (without overflow) when a error occur
    final errorData = {
      FirebaseUserDataRepository.totalRideCountKey: 'Erreur',
      FirebaseUserDataRepository.trophiesKey: 'Erreur',
    };
    final additionalData = await _userDataRepository
        .getAdditionalData(uid)
        .catchError((e) => errorData);
    _trophies = additionalData[FirebaseUserDataRepository.trophiesKey];
    _rideCount =
        additionalData[FirebaseUserDataRepository.totalRideCountKey].toString();
    if (_trophies == null) {
      _trophiesCount = 0.toString();
    } else if (_trophies != 'Erreur') {
      _trophiesCount = trophies!.split('').length.toString();
    } else {
      _trophiesCount = 'Erreur';
    }
    _rideCountHistory = _getUserInterfaceFriendlyHistory();
  }

  Map<String, dynamic> _getUserInterfaceFriendlyHistory() {
    try {
      final rideCountHistory = _userDataRepository.getRideCountHistory();
      _replaceWithUserFriendlyKey(
        originalData: rideCountHistory,
        keyMatcher: _getThe3LastDaysUserFriendlyHistoryKey(),
      );
      return rideCountHistory;
    } catch (_) {
      // TODO: implement rapport
      return {'Erreur': ''};
    }
  }

  void _replaceWithUserFriendlyKey({
    required Map<String, dynamic> originalData,
    required Map<String, String> keyMatcher,
  }) {
    keyMatcher.forEach((originalKey, userFriendlyKey) {
      if (originalData.containsKey(originalKey)) {
        originalData[userFriendlyKey] = originalData[originalKey];
        originalData.remove(originalKey);
      } else {
        originalData[userFriendlyKey] = 0;
      }
    });
  }

  Map<String, String> _getThe3LastDaysUserFriendlyHistoryKey() {
    final now = DateTime.now();
    return {
      generateKeyFromDateTime(now): "Aujourd'hui",
      generateKeyFromDateTime(now.subtract(const Duration(days: 1))): 'Hier',
      generateKeyFromDateTime(now.subtract(const Duration(days: 2))):
          'Avant-hier',
    };
  }
}
