import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/admin/screens/admin_home_screen.dart';
import '../../features/admin_auth/screens/admin_login_screen.dart';
import '../../features/admin_auth/screens/admin_otp_screen.dart';
import '../../features/auth/data/auth_session.dart';
import '../../features/auth/providers/auth_provider.dart';
import 'splash_screen.dart';

class _RouterRefreshNotifier extends ChangeNotifier {
  _RouterRefreshNotifier(Ref ref) {
    ref.listen(authProvider, (_, __) => notifyListeners());
  }
}

final adminRouterProvider = Provider<GoRouter>((ref) {
  final refreshNotifier = _RouterRefreshNotifier(ref);

  return GoRouter(
    initialLocation: '/',
    refreshListenable: refreshNotifier,
    redirect: (context, state) {
      final authState = ref.read(authProvider);
      final isAuthRoute = state.matchedLocation == '/login' ||
          state.matchedLocation == '/verify-otp';

      if (authState.status == AuthStatus.unknown) {
        return state.matchedLocation == '/' ? null : '/';
      }

      if (authState.status == AuthStatus.unauthenticated) {
        return isAuthRoute ? null : '/login';
      }

      if (authState.status == AuthStatus.authenticated) {
        final role = authState.session?.role;
        // This portal is admin-only. A passenger/driver account should
        // never end up here, but if one does, log them out immediately.
        if (role != UserRole.admin) {
          if (state.matchedLocation != '/login') {
            Future.microtask(() => ref.read(authProvider.notifier).logout());
          }
          return '/login';
        }
        if (state.matchedLocation != '/admin/home') {
          return '/admin/home';
        }
      }

      return null;
    },
    routes: [
      GoRoute(path: '/', builder: (context, state) => const SplashScreen()),
      GoRoute(path: '/login', builder: (context, state) => const AdminLoginScreen()),
      GoRoute(
        path: '/verify-otp',
        builder: (context, state) {
          final phoneNumber = state.extra as String?;
          if (phoneNumber == null) return const AdminLoginScreen();
          return AdminOtpScreen(phoneNumber: phoneNumber);
        },
      ),
      GoRoute(path: '/admin/home', builder: (context, state) => const AdminHomeScreen()),
    ],
  );
});
