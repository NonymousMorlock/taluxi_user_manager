import 'package:firebase_core/firebase_core.dart';

export 'src/authentication_provider.dart';
export 'src/entities/user.dart';
export 'src/exceptions/authentication_exception.dart';
export 'src/exceptions/user_data_access_exception.dart';
export 'src/repositories/user_data_repository.dart';

/// Initialize all [user_manager] services and dependencies.
Future<FirebaseApp> initializeBackEndServices() async {
  return Firebase.initializeApp();
}
