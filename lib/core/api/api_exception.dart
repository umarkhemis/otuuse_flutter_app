import 'package:dio/dio.dart';

/// A friendly, UI-ready exception. The backend returns errors as
/// `{"detail": "..."}` (FastAPI's HTTPException convention), so we unwrap
/// that here once instead of repeating the same parsing in every screen.
class ApiException implements Exception {
  ApiException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  factory ApiException.fromDioException(DioException e) {
    final data = e.response?.data;

    if (data is Map && data['detail'] != null) {
      return ApiException(data['detail'].toString(), statusCode: e.response?.statusCode);
    }

    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return ApiException('Connection timed out. Check your internet connection.');
      case DioExceptionType.connectionError:
        return ApiException(
          'Could not reach the server. Check that the backend is running and reachable.',
        );
      default:
        return ApiException('Something went wrong. Please try again.', statusCode: e.response?.statusCode);
    }
  }

  @override
  String toString() => message;
}
