import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/data/auth_session.dart';
import '../../features/auth/providers/auth_provider.dart';
import '../../features/auth/screens/login_screen.dart';
import '../../features/auth/screens/otp_screen.dart';
import '../../features/chat/screens/chat_screen.dart';
import '../../features/driver/screens/driver_home_screen.dart';
import 'splash_screen.dart';

class _RouterRefreshNotifier extends ChangeNotifier {
  _RouterRefreshNotifier(Ref ref) {
    ref.listen(authProvider, (_, __) => notifyListeners());
  }
}

final routerProvider = Provider<GoRouter>((ref) {
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

        // Admin accounts don't belong in the public app - it doesn't even
        // contain the admin screens (those live in a separate, privately
        // hosted build). If one somehow lands here, log them out.
        if (role == UserRole.admin) {
          if (state.matchedLocation != '/admin-blocked') {
            Future.microtask(() => ref.read(authProvider.notifier).logout());
            return '/admin-blocked';
          }
          return null;
        }

        final correctHome =
            role == UserRole.driver ? '/driver/home' : '/rides/home';
        if (state.matchedLocation != correctHome) {
          return correctHome;
        }
      }

      return null;
    },
    routes: [
      GoRoute(path: '/', builder: (context, state) => const SplashScreen()),
      GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
      GoRoute(
        path: '/verify-otp',
        builder: (context, state) {
          final phoneNumber = state.extra as String?;
          if (phoneNumber == null) return const LoginScreen();
          return OtpScreen(phoneNumber: phoneNumber);
        },
      ),
      GoRoute(path: '/rides/home', builder: (context, state) => const ChatScreen()),
      GoRoute(path: '/driver/home', builder: (context, state) => const DriverHomeScreen()),
      GoRoute(
        path: '/admin-blocked',
        builder: (context, state) => const _AdminBlockedScreen(),
      ),
    ],
  );
});

class _AdminBlockedScreen extends StatelessWidget {
  const _AdminBlockedScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.lock_outline,
                  size: 48, color: Theme.of(context).colorScheme.error),
              const SizedBox(height: 16),
              const Text(
                'Admin accounts use the admin portal, not this app.',
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
