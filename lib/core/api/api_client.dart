import 'dart:async';

import 'package:dio/dio.dart';

import '../config/app_config.dart';
import '../storage/token_storage.dart';

/// Wraps Dio with two pieces of behaviour every authenticated request needs:
///
/// 1. Attach the stored access token to every outgoing request.
/// 2. On a 401, transparently refresh the token pair (matching the
///    rotate-on-use refresh endpoint on the backend) and retry the original
///    request once - the caller never sees the 401 at all unless the
///    refresh itself fails, which means the session is genuinely over.
///
/// [onAuthFailure] fires when a refresh attempt fails (expired/revoked
/// refresh token) - wire this to log the user out and send them back to
/// the login screen.
class ApiClient {
  ApiClient(this._tokenStorage, {void Function()? onAuthFailure}) : _onAuthFailure = onAuthFailure {
    _dio = Dio(
      BaseOptions(
        baseUrl: AppConfig.apiBaseUrl,
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 15),
      ),
    );
    _dio.interceptors.add(_buildAuthInterceptor());
  }

  late final Dio _dio;
  final TokenStorage _tokenStorage;
  final void Function()? _onAuthFailure;

  // If several requests hit a 401 at the same moment (e.g. a screen that
  // fires off three API calls at once right as the token expires), we only
  // want one actual refresh call. The rest wait on this same future instead
  // of each independently hitting /auth/refresh - the backend rotates the
  // refresh token on every use, so a second concurrent call would just
  // invalidate the first one's brand new token.
  Completer<bool>? _refreshCompleter;

  Dio get dio => _dio;

  InterceptorsWrapper _buildAuthInterceptor() {
    return InterceptorsWrapper(
      onRequest: (options, handler) async {
        final token = await _tokenStorage.getAccessToken();
        if (token != null) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        handler.next(options);
      },
      onError: (error, handler) async {
        final isUnauthorized = error.response?.statusCode == 401;
        final isRefreshCallItself = error.requestOptions.path.contains('/auth/refresh');

        if (!isUnauthorized || isRefreshCallItself) {
          handler.next(error);
          return;
        }

        final refreshed = await _refreshTokens();
        if (!refreshed) {
          await _tokenStorage.clear();
          _onAuthFailure?.call();
          handler.next(error);
          return;
        }

        try {
          final newToken = await _tokenStorage.getAccessToken();
          final retryOptions = error.requestOptions;
          retryOptions.headers['Authorization'] = 'Bearer $newToken';
          final response = await _dio.fetch(retryOptions);
          handler.resolve(response);
        } on DioException catch (retryError) {
          handler.next(retryError);
        }
      },
    );
  }

  Future<bool> _refreshTokens() {
    if (_refreshCompleter != null) {
      return _refreshCompleter!.future;
    }

    final completer = Completer<bool>();
    _refreshCompleter = completer;

    () async {
      try {
        final refreshToken = await _tokenStorage.getRefreshToken();
        if (refreshToken == null) {
          completer.complete(false);
          return;
        }

        // A fresh, bare Dio instance for this one call - routing it through
        // the normal _dio would re-enter this same interceptor.
        final plainDio = Dio(BaseOptions(baseUrl: AppConfig.apiBaseUrl));
        final response = await plainDio.post('/auth/refresh', data: {
          'refresh_token': refreshToken,
        });

        await _tokenStorage.saveTokens(
          accessToken: response.data['access_token'] as String,
          refreshToken: response.data['refresh_token'] as String,
          role: response.data['role'] as String,
          userId: response.data['user_id'] as String,
        );

        completer.complete(true);
      } catch (_) {
        completer.complete(false);
      } finally {
        _refreshCompleter = null;
      }
    }();

    return completer.future;
  }
}
