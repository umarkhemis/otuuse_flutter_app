import 'package:dio/dio.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/api_exception.dart';
import 'wallet_models.dart';

class WalletRepository {
  WalletRepository(this._apiClient);

  final ApiClient _apiClient;

  Future<int> getBalance() async {
    try {
      final response = await _apiClient.dio.get('/payments/wallet/balance');
      return (response.data as Map<String, dynamic>)['balance_ugx'] as int;
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  /// Calls PesaPal and returns the redirect URL the passenger opens.
  Future<String> initiateTopup(int amountUgx) async {
    try {
      final response = await _apiClient.dio.post(
        '/payments/topup/initiate',
        data: {'amount_ugx': amountUgx},
      );
      final data = response.data as Map<String, dynamic>;
      return data['redirect_url'] as String;
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  Future<List<WalletTransaction>> getTransactions() async {
    try {
      final response = await _apiClient.dio.get('/payments/transactions');
      final list = response.data as List<dynamic>;
      return list
          .map((e) =>
              WalletTransaction.fromJson(e as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }
}
