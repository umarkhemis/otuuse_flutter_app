import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/providers/auth_provider.dart';
import '../data/driver_models.dart';
import '../data/driver_repository.dart';

class DriverState {
  const DriverState({
    this.isOnline = false,
    this.isTogglingAvailability = false,
    this.activeRide,
    this.isPerformingAction = false,
    this.errorMessage,
  });

  final bool isOnline;
  final bool isTogglingAvailability;
  final ActiveRide? activeRide;
  final bool isPerformingAction;
  final String? errorMessage;

  DriverState copyWith({
    bool? isOnline,
    bool? isTogglingAvailability,
    ActiveRide? activeRide,
    bool clearActiveRide = false,
    bool? isPerformingAction,
    String? errorMessage,
    bool clearError = false,
  }) {
    return DriverState(
      isOnline: isOnline ?? this.isOnline,
      isTogglingAvailability:
          isTogglingAvailability ?? this.isTogglingAvailability,
      activeRide:
          clearActiveRide ? null : (activeRide ?? this.activeRide),
      isPerformingAction: isPerformingAction ?? this.isPerformingAction,
      errorMessage:
          clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

class DriverNotifier extends Notifier<DriverState> {
  Timer? _pollTimer;

  @override
  DriverState build() {
    ref.onDispose(() => _pollTimer?.cancel());
    return const DriverState();
  }

  DriverRepository get _repo =>
      DriverRepository(ref.read(apiClientProvider));

  Future<void> toggleAvailability() async {
    if (state.isTogglingAvailability) return;
    final goingOnline = !state.isOnline;
    state = state.copyWith(
        isTogglingAvailability: true, clearError: true);
    try {
      await _repo.setAvailability(goingOnline);
      state = state.copyWith(
        isOnline: goingOnline,
        isTogglingAvailability: false,
        clearActiveRide: !goingOnline,
      );
      if (goingOnline) {
        _startPolling();
      } else {
        _stopPolling();
      }
    } catch (e) {
      state = state.copyWith(
        isTogglingAvailability: false,
        errorMessage: e.toString(),
      );
    }
  }

  void _startPolling() {
    _pollTimer?.cancel();
    // Fetch immediately, then every 4 seconds.
    _fetchActiveRide();
    _pollTimer = Timer.periodic(
      const Duration(seconds: 4),
      (_) => _fetchActiveRide(),
    );
  }

  void _stopPolling() {
    _pollTimer?.cancel();
    _pollTimer = null;
  }

  Future<void> _fetchActiveRide() async {
    try {
      final ride = await _repo.getActiveRide();
      state = state.copyWith(
        activeRide: ride,
        clearActiveRide: ride == null,
      );
    } catch (_) {
      // Polling failures are silent so they don't disrupt the driver's view.
    }
  }

  Future<void> performAction(String action) async {
    final ride = state.activeRide;
    if (ride == null || state.isPerformingAction) return;
    state = state.copyWith(isPerformingAction: true, clearError: true);
    try {
      await _repo.performAction(ride.id, action);
      // Immediately refresh to pick up the new status from the backend.
      await _fetchActiveRide();
      state = state.copyWith(isPerformingAction: false);
    } catch (e) {
      state = state.copyWith(
        isPerformingAction: false,
        errorMessage: e.toString(),
      );
    }
  }
}

final driverProvider =
    NotifierProvider<DriverNotifier, DriverState>(DriverNotifier.new);
