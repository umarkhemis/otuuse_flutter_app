import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/providers/auth_provider.dart';
import '../data/admin_models.dart';
import '../data/admin_repository.dart';

class AdminState {
  const AdminState({
    this.stats,
    this.drivers = const [],
    this.rides = const [],
    this.isLoadingStats = false,
    this.isLoadingDrivers = false,
    this.isLoadingRides = false,
    this.isOnboarding = false,
    this.lastOnboardResult,
    this.pendingActionDriverId,
    this.errorMessage,
  });

  final DashboardStats? stats;
  final List<DriverListItem> drivers;
  final List<RecentRide> rides;
  final bool isLoadingStats;
  final bool isLoadingDrivers;
  final bool isLoadingRides;
  final bool isOnboarding;
  final OnboardResult? lastOnboardResult;

  /// Which driver ID is currently being suspended/reinstated.
  final String? pendingActionDriverId;
  final String? errorMessage;

  AdminState copyWith({
    DashboardStats? stats,
    List<DriverListItem>? drivers,
    List<RecentRide>? rides,
    bool? isLoadingStats,
    bool? isLoadingDrivers,
    bool? isLoadingRides,
    bool? isOnboarding,
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
      rides: rides ?? this.rides,
      isLoadingStats: isLoadingStats ?? this.isLoadingStats,
      isLoadingDrivers: isLoadingDrivers ?? this.isLoadingDrivers,
      isLoadingRides: isLoadingRides ?? this.isLoadingRides,
      isOnboarding: isOnboarding ?? this.isOnboarding,
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
    });
    return const AdminState(isLoadingStats: true, isLoadingDrivers: true);
  }

  AdminRepository get _repo =>
      AdminRepository(ref.read(apiClientProvider));

  Future<void> loadDashboard() async {
    state = state.copyWith(isLoadingStats: true, clearError: true);
    try {
      final stats = await _repo.getDashboard();
      state = state.copyWith(stats: stats, isLoadingStats: false);
    } catch (e) {
      state = state.copyWith(
          isLoadingStats: false, errorMessage: e.toString());
    }
  }

  Future<void> loadDrivers() async {
    state = state.copyWith(isLoadingDrivers: true, clearError: true);
    try {
      final drivers = await _repo.listDrivers();
      state = state.copyWith(drivers: drivers, isLoadingDrivers: false);
    } catch (e) {
      state = state.copyWith(
          isLoadingDrivers: false, errorMessage: e.toString());
    }
  }

  Future<void> loadRides() async {
    if (state.rides.isNotEmpty) return; // only load once per session
    state = state.copyWith(isLoadingRides: true);
    try {
      final rides = await _repo.listRides();
      state = state.copyWith(rides: rides, isLoadingRides: false);
    } catch (e) {
      state = state.copyWith(
          isLoadingRides: false, errorMessage: e.toString());
    }
  }

  /// Returns the invite code on success, null on failure.
  Future<OnboardResult?> onboardDriver({
    required String phoneNumber,
    required String name,
    required String initialPin,
    required int subscriptionMonths,
  }) async {
    state = state.copyWith(isOnboarding: true, clearError: true);
    try {
      final result = await _repo.onboardDriver(
        phoneNumber: phoneNumber,
        name: name,
        initialPin: initialPin,
        subscriptionMonths: subscriptionMonths,
      );
      state = state.copyWith(
          isOnboarding: false, lastOnboardResult: result);
      await loadDrivers(); // refresh list
      return result;
    } catch (e) {
      state = state.copyWith(
          isOnboarding: false, errorMessage: e.toString());
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
