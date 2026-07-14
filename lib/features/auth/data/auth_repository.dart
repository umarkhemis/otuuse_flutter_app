import 'package:dio/dio.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/api_exception.dart';
import '../../../core/storage/token_storage.dart';
import 'auth_session.dart';

class AuthRepository {
  AuthRepository(this._apiClient, this._tokenStorage);

  final ApiClient _apiClient;
  final TokenStorage _tokenStorage;

  Future<void> requestOtp({
    required String phoneNumber,
    required String name,
    required String role,
  }) async {
    try {
      await _apiClient.dio.post('/auth/request-otp', data: {
        'phone_number': phoneNumber,
        'name': name,
        'role': role,
      });
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  /// [pin] is only meaningful for admin accounts - the backend requires it
  /// there and ignores it for passenger/driver. Leaving it null is correct
  /// for the regular consumer app login flow.
  Future<AuthSession> verifyOtp({
    required String phoneNumber,
    required String otp,
    String? pin,
  }) async {
    try {
      final response = await _apiClient.dio.post('/auth/verify-otp', data: {
        'phone_number': phoneNumber,
        'otp': otp,
        'pin': pin,
      });
      final data = response.data;
      final roleStr = data['role'] as String;
      await _tokenStorage.saveTokens(
        accessToken: data['access_token'] as String,
        refreshToken: data['refresh_token'] as String,
        userId: data['user_id'] as String,
        role: roleStr,
      );
      return AuthSession(
        userId: data['user_id'] as String,
        role: AuthSession.roleFromString(roleStr),
      );
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  Future<void> logout() async {
    final refreshToken = await _tokenStorage.getRefreshToken();
    if (refreshToken != null) {
      try {
        await _apiClient.dio.post('/auth/logout',
            data: {'refresh_token': refreshToken});
      } catch (_) {}
    }
    await _tokenStorage.clear();
  }

  Future<AuthSession?> restoreSession() async {
    final accessToken = await _tokenStorage.getAccessToken();
    final role = await _tokenStorage.getRole();
    final userId = await _tokenStorage.getUserId();
    if (accessToken == null || role == null || userId == null) return null;
    return AuthSession(
      userId: userId,
      role: AuthSession.roleFromString(role),
    );
  }
}
