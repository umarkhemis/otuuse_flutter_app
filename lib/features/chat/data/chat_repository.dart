import 'package:dio/dio.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/api_exception.dart';
import 'chat_models.dart';

class ChatRepository {
  ChatRepository(this._apiClient);
  final ApiClient _apiClient;

  Future<ChatApiResponse> sendMessage(String message) async {
    try {
      final response = await _apiClient.dio.post('/chat/message', data: {'message': message});
      return ChatApiResponse.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  Future<RideStatusResponse> getRideStatus(String rideId) async {
    try {
      final response = await _apiClient.dio.get('/chat/ride-status/$rideId');
      return RideStatusResponse.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  Future<DeliveryStatusResponse> getDeliveryStatus(String deliveryId) async {
    try {
      final response = await _apiClient.dio.get('/chat/delivery-status/$deliveryId');
      return DeliveryStatusResponse.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  /// Uploads a photo of the delivery item and returns the public URL.
  Future<String> uploadDeliveryPhoto(
    String deliveryId,
    List<int> bytes,
    String filename,
  ) async {
    try {
      final formData = FormData.fromMap({
        'file': MultipartFile.fromBytes(
          bytes,
          filename: filename,
        ),
      });
      final response = await _apiClient.dio.post(
        '/chat/delivery/$deliveryId/photo',
        data: formData,
        options: Options(contentType: 'multipart/form-data'),
      );
      return response.data['url'] as String;
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

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
}
