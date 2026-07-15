import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/providers/auth_provider.dart';
import '../data/admin_models.dart';
import '../data/admin_repository.dart';

class AdminState {
  const AdminState({
    this.stats,
    this.drivers = const [],
    this.deliveries = const [],
    this.isLoadingStats = false,
    this.isLoadingDrivers = false,
    this.isLoadingDeliveries = false,
    this.isOnboarding = false,
    this.isReplying = false,
    this.lastOnboardResult,
    this.pendingActionDriverId,
    this.errorMessage,
  });

  final DashboardStats? stats;
  final List<DriverListItem> drivers;
  final List<DeliveryListItem> deliveries;
  final bool isLoadingStats;
  final bool isLoadingDrivers;
  final bool isLoadingDeliveries;
  final bool isOnboarding;
  final bool isReplying;
  final OnboardResult? lastOnboardResult;
  final String? pendingActionDriverId;
  final String? errorMessage;

  AdminState copyWith({
    DashboardStats? stats,
    List<DriverListItem>? drivers,
    List<DeliveryListItem>? deliveries,
    bool? isLoadingStats,
    bool? isLoadingDrivers,
    bool? isLoadingDeliveries,
    bool? isOnboarding,
    bool? isReplying,
    OnboardResult? lastOnboardResult,
    bool clearOnboardResult = false,
    String? pendingActionDriverId,
    bool clearPendingAction = false,
    String? errorMessage,
    bool clearError = false,
  }) {
    return AdminState(
      stats: stats ?? this.stats,
      drivers: drivers ?? this.drivers,
      deliveries: deliveries ?? this.deliveries,
      isLoadingStats: isLoadingStats ?? this.isLoadingStats,
      isLoadingDrivers: isLoadingDrivers ?? this.isLoadingDrivers,
      isLoadingDeliveries: isLoadingDeliveries ?? this.isLoadingDeliveries,
      isOnboarding: isOnboarding ?? this.isOnboarding,
      isReplying: isReplying ?? this.isReplying,
      lastOnboardResult: clearOnboardResult
          ? null
          : (lastOnboardResult ?? this.lastOnboardResult),
      pendingActionDriverId: clearPendingAction
          ? null
          : (pendingActionDriverId ?? this.pendingActionDriverId),
      errorMessage:
          clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

class AdminNotifier extends Notifier<AdminState> {
  @override
  AdminState build() {
    Future.microtask(() {
      loadDashboard();
      loadDrivers();
      loadDeliveries();
    });
    return const AdminState(
      isLoadingStats: true,
      isLoadingDrivers: true,
      isLoadingDeliveries: true,
    );
  }

  AdminRepository get _repo =>
      AdminRepository(ref.read(apiClientProvider));

  Future<void> loadDashboard() async {
    state = state.copyWith(isLoadingStats: true, clearError: true);
    try {
      final stats = await _repo.getDashboard();
      state = state.copyWith(stats: stats, isLoadingStats: false);
    } catch (e) {
      state = state.copyWith(isLoadingStats: false, errorMessage: e.toString());
    }
  }

  Future<void> loadDrivers() async {
    state = state.copyWith(isLoadingDrivers: true, clearError: true);
    try {
      final drivers = await _repo.listDrivers();
      state = state.copyWith(drivers: drivers, isLoadingDrivers: false);
    } catch (e) {
      state =
          state.copyWith(isLoadingDrivers: false, errorMessage: e.toString());
    }
  }

  Future<void> loadDeliveries() async {
    state = state.copyWith(isLoadingDeliveries: true, clearError: true);
    try {
      final deliveries = await _repo.listDeliveries();
      state = state.copyWith(
          deliveries: deliveries, isLoadingDeliveries: false);
    } catch (e) {
      state = state.copyWith(
          isLoadingDeliveries: false, errorMessage: e.toString());
    }
  }

  /// Returns true on success. UI shows snackbar based on result.
  Future<bool> replyToDelivery(
      String deliveryId, String message, String? newStatus) async {
    state = state.copyWith(isReplying: true, clearError: true);
    try {
      await _repo.replyToDelivery(deliveryId, message, newStatus);
      state = state.copyWith(isReplying: false);
      await loadDeliveries(); // refresh list
      return true;
    } catch (e) {
      state =
          state.copyWith(isReplying: false, errorMessage: e.toString());
      return false;
    }
  }

  Future<OnboardResult?> onboardDriver({
    required String phoneNumber,
    required String name,
    required String initialPin,
    required int subscriptionMonths,
    String? plateNumber,
  }) async {
    state = state.copyWith(isOnboarding: true, clearError: true);
    try {
      final result = await _repo.onboardDriver(
        phoneNumber: phoneNumber,
        name: name,
        initialPin: initialPin,
        subscriptionMonths: subscriptionMonths,
        plateNumber: plateNumber,
      );
      state = state.copyWith(isOnboarding: false, lastOnboardResult: result);
      await loadDrivers();
      return result;
    } catch (e) {
      state =
          state.copyWith(isOnboarding: false, errorMessage: e.toString());
      return null;
    }
  }

  Future<void> suspendDriver(String driverId) async {
    state = state.copyWith(pendingActionDriverId: driverId);
    try {
      await _repo.suspendDriver(driverId);
      await loadDrivers();
    } catch (e) {
      state = state.copyWith(errorMessage: e.toString());
    } finally {
      state = state.copyWith(clearPendingAction: true);
    }
  }

  Future<void> reinstateDriver(String driverId) async {
    state = state.copyWith(pendingActionDriverId: driverId);
    try {
      await _repo.reinstateDriver(driverId);
      await loadDrivers();
    } catch (e) {
      state = state.copyWith(errorMessage: e.toString());
    } finally {
      state = state.copyWith(clearPendingAction: true);
    }
  }

  Future<void> renewSubscription(String driverId, int months) async {
    state = state.copyWith(pendingActionDriverId: driverId);
    try {
      await _repo.renewSubscription(driverId, months);
      await loadDrivers();
    } catch (e) {
      state = state.copyWith(errorMessage: e.toString());
    } finally {
      state = state.copyWith(clearPendingAction: true);
    }
  }
}

final adminProvider =
    NotifierProvider<AdminNotifier, AdminState>(AdminNotifier.new);
  Future<void> uploadDeliveryPhoto(
    String deliveryId,
    List<int> bytes,
    String filename,
  ) async {
    try {
      await _repo.uploadDeliveryPhoto(deliveryId, bytes, filename);
    } catch (e) {
      // Non-fatal - log and continue
    }
  }

}
