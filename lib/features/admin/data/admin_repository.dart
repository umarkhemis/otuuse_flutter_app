import 'package:dio/dio.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/api_exception.dart';
import 'admin_models.dart';

class AdminRepository {
  AdminRepository(this._apiClient);

  final ApiClient _apiClient;

  Future<DashboardStats> getDashboard() async {
    try {
      final r = await _apiClient.dio.get('/admin/dashboard');
      return DashboardStats.fromJson(r.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  Future<List<DriverListItem>> listDrivers() async {
    try {
      final r = await _apiClient.dio
          .get('/admin/drivers', queryParameters: {'limit': 100});
      final list = r.data as List<dynamic>;
      return list
          .map((e) =>
              DriverListItem.fromJson(e as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  Future<OnboardResult> onboardDriver({
    required String phoneNumber,
    required String name,
    required String initialPin,
    required int subscriptionMonths,
  }) async {
    try {
      final r = await _apiClient.dio.post('/admin/drivers/onboard', data: {
        'phone_number': phoneNumber,
        'name': name,
        'initial_pin': initialPin,
        'subscription_months': subscriptionMonths,
      });
      return OnboardResult.fromJson(r.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  Future<void> suspendDriver(String driverId) async {
    try {
      await _apiClient.dio.patch('/admin/drivers/$driverId/suspend');
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  Future<void> reinstateDriver(String driverId) async {
    try {
      await _apiClient.dio.patch('/admin/drivers/$driverId/reinstate');
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  Future<void> renewSubscription(String driverId, int months) async {
    try {
      await _apiClient.dio.post(
        '/admin/drivers/$driverId/renew-subscription',
        queryParameters: {'months': months},
      );
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  Future<List<RecentRide>> listRides({int limit = 30}) async {
    try {
      final r = await _apiClient.dio
          .get('/admin/rides', queryParameters: {'limit': limit});
      final list = r.data as List<dynamic>;
      return list
          .map((e) => RecentRide.fromJson(e as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }
}
