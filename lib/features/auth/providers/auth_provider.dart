import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/storage/token_storage.dart';
import '../data/auth_repository.dart';
import '../data/auth_session.dart';

enum AuthStatus {
  /// Still checking secure storage for a saved session. The router keeps
  /// the user on the splash screen during this state.
  unknown,
  authenticated,
  unauthenticated,
}

class AuthState {
  const AuthState({this.status = AuthStatus.unknown, this.session});
  final AuthStatus status;
  final AuthSession? session;
}

class AuthNotifier extends Notifier<AuthState> {
  @override
  AuthState build() {
    Future.microtask(_restore);
    return const AuthState();
  }

  Future<void> _restore() async {
    final repository = ref.read(authRepositoryProvider);
    final session = await repository.restoreSession();
    state = AuthState(
      status: session != null
          ? AuthStatus.authenticated
          : AuthStatus.unauthenticated,
      session: session,
    );
  }

  Future<void> requestOtp({
    required String phoneNumber,
    required String name,
    required String role,
  }) {
    return ref.read(authRepositoryProvider).requestOtp(
        phoneNumber: phoneNumber, name: name, role: role);
  }

  /// [pin] is only used by the admin portal build - left null elsewhere.
  Future<void> verifyOtp({
    required String phoneNumber,
    required String otp,
    String? pin,
  }) async {
    final session = await ref
        .read(authRepositoryProvider)
        .verifyOtp(phoneNumber: phoneNumber, otp: otp, pin: pin);
    state = AuthState(status: AuthStatus.authenticated, session: session);
  }

  Future<void> logout() async {
    await ref.read(authRepositoryProvider).logout();
    state = const AuthState(status: AuthStatus.unauthenticated);
  }
}

final tokenStorageProvider = Provider<TokenStorage>((ref) => const TokenStorage());

final apiClientProvider = Provider<ApiClient>((ref) {
  final storage = ref.watch(tokenStorageProvider);
  return ApiClient(
    storage,
    onAuthFailure: () => ref.read(authProvider.notifier).logout(),
  );
});

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  final storage = ref.watch(tokenStorageProvider);
  return AuthRepository(apiClient, storage);
});

final authProvider = NotifierProvider<AuthNotifier, AuthState>(AuthNotifier.new);
