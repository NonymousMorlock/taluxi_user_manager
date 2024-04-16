import 'package:mockito/mockito.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MockSharedPreferences extends Mock implements SharedPreferences {
  static Map<String, dynamic> data = <String, dynamic>{};
  static bool enabled = false;
  static bool throwException = false;
  static bool writingDataMustFail = false;
  static int thrownExceptionCount = 0;

  @override
  Future<bool> clear() {
    data.clear();
    return Future.value(true);
  }

  @override
  dynamic get(String key) {
    if (!enabled) return null;
    if (throwException) {
      thrownExceptionCount++;
      throw Exception();
    }
    return data[key];
  }

  @override
  String getString(String key) => get(key) as String;

  @override
  int getInt(String key) => get(key) as int;

  @override
  Future<bool> setString(String key, String value) async {
    if (!enabled) return false;
    if (throwException) {
      thrownExceptionCount++;
      throw Exception();
    } else if (writingDataMustFail) return Future.value(false);
    data[key] = value;
    return Future.value(true);
  }

  @override
  Future<bool> setInt(String key, int value) async {
    if (!enabled) return false;
    if (throwException) {
      thrownExceptionCount++;
      throw Exception();
    } else if (writingDataMustFail) return Future.value(false);
    data[key] = value;
    return Future.value(true);
  }

  // void setMockData(Map<String, dynamic> data) => data = data;
}
