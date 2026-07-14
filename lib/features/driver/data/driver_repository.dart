import 'package:dio/dio.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/api_exception.dart';
import 'driver_models.dart';

class DriverRepository {
  DriverRepository(this._apiClient);

  final ApiClient _apiClient;

  Future<void> setAvailability(bool online) async {
    try {
      await _apiClient.dio.post('/driver/availability', data: {'online': online});
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  /// Returns null if no active ride.
  Future<ActiveRide?> getActiveRide() async {
    try {
      final response = await _apiClient.dio.get('/driver/ride/active');
      final data = response.data as Map<String, dynamic>;
      final ride = data['ride'];
      if (ride == null) return null;
      return ActiveRide.fromJson(ride as Map<String, dynamic>);
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  /// action: accept | decline | arrived | start | complete
  Future<void> performAction(String rideId, String action) async {
    try {
      await _apiClient.dio.post(
        '/driver/ride/$rideId/action',
        data: {'action': action},
      );
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }
}
