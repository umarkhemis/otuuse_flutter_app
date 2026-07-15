import 'package:dio/dio.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/api_exception.dart';
import 'chat_models.dart';

class ChatRepository {
  ChatRepository(this._apiClient);

  final ApiClient _apiClient;

  Future<ChatApiResponse> sendMessage(String message) async {
    try {
      final response = await _apiClient.dio.post('/chat/message', data: {
        'message': message,
      });
      return ChatApiResponse.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  /// Poll this every 4 seconds after a ride is dispatched.
  /// Returns status + driver details once the driver accepts.
  Future<RideStatusResponse> getRideStatus(String rideId) async {
    try {
      final response = await _apiClient.dio.get('/chat/ride-status/$rideId');
      return RideStatusResponse.fromJson(
          response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  /// Called after driver accepts and passenger taps Confirm on the fare card.
  /// [rideId] is required in the new driver-first flow.
  /// [confirmed] false = passenger cancelled the confirmed ride.
  Future<ConfirmRideResult> confirmRide(String rideId, bool confirmed) async {
    try {
      final response = await _apiClient.dio.post('/chat/confirm-ride', data: {
        'confirmed': confirmed,
        'ride_id': rideId,
      });
      final data = response.data as Map<String, dynamic>;
      return ConfirmRideResult(
        rideId: data['ride_id'] as String?,
        message: data['message'] as String,
      );
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  Future<DeliveryStatusResponse> getDeliveryStatus(String deliveryId) async {
    try {
      final response =
          await _apiClient.dio.get('/chat/delivery-status/$deliveryId');
      return DeliveryStatusResponse.fromJson(
          response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

}
