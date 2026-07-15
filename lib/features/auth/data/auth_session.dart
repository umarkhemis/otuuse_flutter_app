enum UserRole { passenger, driver, admin }

class AuthSession {
  const AuthSession({
    required this.userId,
    required this.role,
    this.name = '',
  });

  final String userId;
  final UserRole role;
  final String name;

  static UserRole roleFromString(String role) {
    switch (role.toLowerCase()) {
      case 'driver':
        return UserRole.driver;
      case 'admin':
        return UserRole.admin;
      default:
        return UserRole.passenger;
    }
  }
}
