import 'package:dio/dio.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/api_exception.dart';

class RatingRepository {
  RatingRepository(this._apiClient);
  final ApiClient _apiClient;

  /// [ratingFor] must be 'driver' or 'passenger'.
  Future<void> submitRating({
    required String rideId,
    required int rating,
    required String ratingFor,
    String? review,
  }) async {
    try {
      await _apiClient.dio.post('/rides/$rideId/rate', data: {
        'rating': rating,
        'rating_for': ratingFor,
        if (review != null && review.trim().isNotEmpty) 'review': review.trim(),
      });
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }
}
