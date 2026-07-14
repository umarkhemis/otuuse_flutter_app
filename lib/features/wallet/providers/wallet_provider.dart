import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/providers/auth_provider.dart';
import '../data/wallet_models.dart';
import '../data/wallet_repository.dart';

class WalletState {
  const WalletState({
    this.balanceUgx,
    this.isLoadingBalance = false,
    this.isInitiatingTopup = false,
    this.transactions = const [],
    this.isLoadingTransactions = false,
    this.errorMessage,
  });

  final int? balanceUgx;
  final bool isLoadingBalance;
  final bool isInitiatingTopup;
  final List<WalletTransaction> transactions;
  final bool isLoadingTransactions;
  final String? errorMessage;

  WalletState copyWith({
    int? balanceUgx,
    bool? isLoadingBalance,
    bool? isInitiatingTopup,
    List<WalletTransaction>? transactions,
    bool? isLoadingTransactions,
    String? errorMessage,
    bool clearError = false,
  }) {
    return WalletState(
      balanceUgx: balanceUgx ?? this.balanceUgx,
      isLoadingBalance: isLoadingBalance ?? this.isLoadingBalance,
      isInitiatingTopup: isInitiatingTopup ?? this.isInitiatingTopup,
      transactions: transactions ?? this.transactions,
      isLoadingTransactions:
          isLoadingTransactions ?? this.isLoadingTransactions,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

class WalletNotifier extends Notifier<WalletState> {
  @override
  WalletState build() {
    // Load balance as soon as the provider is created.
    Future.microtask(refreshBalance);
    return const WalletState(isLoadingBalance: true);
  }

  WalletRepository get _repo =>
      WalletRepository(ref.read(apiClientProvider));

  Future<void> refreshBalance() async {
    state = state.copyWith(isLoadingBalance: true, clearError: true);
    try {
      final balance = await _repo.getBalance();
      state = state.copyWith(balanceUgx: balance, isLoadingBalance: false);
    } catch (e) {
      state = state.copyWith(
          isLoadingBalance: false, errorMessage: e.toString());
    }
  }

  Future<void> loadTransactions() async {
    state = state.copyWith(isLoadingTransactions: true);
    try {
      final txns = await _repo.getTransactions();
      state =
          state.copyWith(transactions: txns, isLoadingTransactions: false);
    } catch (e) {
      state = state.copyWith(
          isLoadingTransactions: false, errorMessage: e.toString());
    }
  }

  /// Returns the PesaPal redirect URL on success, null on failure.
  Future<String?> initiateTopup(int amountUgx) async {
    state = state.copyWith(isInitiatingTopup: true, clearError: true);
    try {
      final url = await _repo.initiateTopup(amountUgx);
      state = state.copyWith(isInitiatingTopup: false);
      return url;
    } catch (e) {
      state = state.copyWith(
          isInitiatingTopup: false, errorMessage: e.toString());
      return null;
    }
  }
}

final walletProvider =
    NotifierProvider<WalletNotifier, WalletState>(WalletNotifier.new);
