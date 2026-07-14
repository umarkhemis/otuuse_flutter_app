enum UserRole { passenger, driver, admin }

class AuthSession {
  const AuthSession({
    required this.userId,
    required this.role,
  });

  final String userId;
  final UserRole role;

  static UserRole roleFromString(String role) {
    switch (role) {
      case 'driver':
        return UserRole.driver;
      case 'admin':
        return UserRole.admin;
      default:
        return UserRole.passenger;
    }
  }
}
