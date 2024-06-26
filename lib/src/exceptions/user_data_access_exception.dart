class UserDataAccessException implements Exception {
  const UserDataAccessException({
    this.exceptionType = UserDataAccessExceptionType.unknown,
    this.message =
        "Une Erreur est survenue lors de la récupération de vos données. Si l'erreur persiste, réessayez plus tard.",
  });
  const UserDataAccessException.unknown() : this();
  final UserDataAccessExceptionType exceptionType;
  final String message;
}

enum UserDataAccessExceptionType { unknown }
