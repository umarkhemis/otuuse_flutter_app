import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/providers/auth_provider.dart';
import '../../rating/screens/rating_dialog.dart';
import '../data/driver_models.dart';
import '../providers/driver_provider.dart';

class DriverHomeScreen extends ConsumerWidget {
  const DriverHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(driverProvider);

    ref.listen(driverProvider, (previous, next) {
      if (next.completedRideId != null && previous?.completedRideId == null) {
        WidgetsBinding.instance.addPostFrameCallback((_) async {
          await showRatingDialog(
            context: context,
            ref: ref,
            rideId: next.completedRideId!,
            ratingFor: 'passenger',
          );
          ref.read(driverProvider.notifier).clearCompletedRide();
        });
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text('Otuuse Driver'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Log out',
            onPressed: () => ref.read(authProvider.notifier).logout(),
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (state.errorMessage != null)
                Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    state.errorMessage!,
                    style: TextStyle(color: Colors.red.shade900),
                  ),
                ),
              _AvailabilityCard(state: state),
              const SizedBox(height: 20),
              if (state.isOnline)
                Expanded(
                  child: state.activeRide != null
                      ? _RideCard(ride: state.activeRide!, state: state)
                      : const _WaitingView(),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Availability toggle ───────────────────────────────────────────────────────

class _AvailabilityCard extends ConsumerWidget {
  const _AvailabilityCard({required this.state});
  final DriverState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isOnline = state.isOnline;
    final loading = state.isTogglingAvailability;

    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Row(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isOnline ? Colors.green : Colors.grey.shade400,
                boxShadow: isOnline
                    ? [
                        BoxShadow(
                          color: Colors.green.withOpacity(0.4),
                          blurRadius: 6,
                          spreadRadius: 2,
                        )
                      ]
                    : null,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isOnline ? 'You are online' : 'You are offline',
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.w600),
                  ),
                  Text(
                    isOnline
                        ? 'Accepting ride requests'
                        : 'Tap to start receiving rides',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            loading
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Switch(
                    value: isOnline,
                    onChanged: (_) =>
                        ref.read(driverProvider.notifier).toggleAvailability(),
                  ),
          ],
        ),
      ),
    );
  }
}

// ── Waiting state ─────────────────────────────────────────────────────────────

class _WaitingView extends StatelessWidget {
  const _WaitingView();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.directions_bike,
            size: 72,
            color:
                Theme.of(context).colorScheme.primary.withOpacity(0.25),
          ),
          const SizedBox(height: 20),
          Text(
            'Waiting for a ride...',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withOpacity(0.5),
                ),
          ),
          const SizedBox(height: 6),
          Text(
            'You will see a ride request here when one is dispatched',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withOpacity(0.35),
                ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

// ── Active ride card ──────────────────────────────────────────────────────────

class _RideCard extends ConsumerWidget {
  const _RideCard({required this.ride, required this.state});
  final ActiveRide ride;
  final DriverState state;

  String get _statusLabel {
    switch (ride.status) {
      case 'matched':
        return 'New Ride Request';
      case 'accepted':
        return 'Ride Accepted';
      case 'driver_arriving':
        return 'At Pickup Point';
      case 'in_progress':
        return 'Ride in Progress';
      default:
        return ride.status;
    }
  }

  Color _statusColor(BuildContext context) {
    switch (ride.status) {
      case 'matched':
        return Colors.orange;
      case 'accepted':
        return Colors.blue;
      case 'driver_arriving':
        return Colors.purple;
      case 'in_progress':
        return Colors.green;
      default:
        return Theme.of(context).colorScheme.primary;
    }
  }

  String _formatUgx(int amount) {
    final s = amount.toString();
    final buf = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      final fromEnd = s.length - i;
      buf.write(s[i]);
      if (fromEnd > 1 && fromEnd % 3 == 1) buf.write(',');
    }
    return buf.toString();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(driverProvider.notifier);
    final loading = state.isPerformingAction;
    final statusColor = _statusColor(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Status + fare row
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    _statusLabel,
                    style: TextStyle(
                      color: statusColor,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                ),
                const Spacer(),
                Text(
                  'UGX ${_formatUgx(ride.estimatedFareUgx)}',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 18),

            // Passenger name + phone
            Row(
              children: [
                const Icon(Icons.person_outline, size: 18),
                const SizedBox(width: 8),
                Text(
                  ride.passengerName,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
            if (ride.passengerPhone.isNotEmpty) ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(Icons.phone_outlined,
                      size: 16,
                      color: Theme.of(context).colorScheme.primary),
                  const SizedBox(width: 8),
                  Text(
                    ride.passengerPhone,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.primary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 14),

            // Route box
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context)
                    .colorScheme
                    .surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                children: [
                  _RouteRow(
                    icon: Icons.trip_origin,
                    label: 'From',
                    name: ride.pickupName,
                  ),
                  Padding(
                    padding: const EdgeInsets.only(left: 9),
                    child: SizedBox(
                      height: 14,
                      child: VerticalDivider(
                        width: 1,
                        thickness: 1,
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withOpacity(0.2),
                      ),
                    ),
                  ),
                  _RouteRow(
                    icon: Icons.location_on,
                    label: 'To',
                    name: ride.dropoffName,
                  ),
                ],
              ),
            ),

            // Distance / duration
            if (ride.estimatedDistanceKm != null) ...[
              const SizedBox(height: 8),
              Text(
                [
                  '${ride.estimatedDistanceKm!.toStringAsFixed(1)} km',
                  if (ride.estimatedDurationMinutes != null)
                    '${ride.estimatedDurationMinutes!.round()} min',
                ].join(' · '),
                style: Theme.of(context).textTheme.bodySmall,
                textAlign: TextAlign.center,
              ),
            ],
            const SizedBox(height: 20),

            // Action buttons - change based on current status
            if (ride.status == 'matched') ...[
              FilledButton(
                onPressed: loading
                    ? null
                    : () => notifier.performAction('accept'),
                child: loading
                    ? const _ButtonSpinner()
                    : const Text('Accept Ride'),
              ),
              const SizedBox(height: 8),
              OutlinedButton(
                onPressed: loading
                    ? null
                    : () => notifier.performAction('decline'),
                style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red.shade700),
                child: const Text('Decline'),
              ),
            ] else if (ride.status == 'accepted') ...[
              FilledButton(
                onPressed: loading
                    ? null
                    : () => notifier.performAction('arrived'),
                child: loading
                    ? const _ButtonSpinner()
                    : const Text("I've Arrived at Pickup"),
              ),
            ] else if (ride.status == 'driver_arriving') ...[
              FilledButton(
                onPressed: loading
                    ? null
                    : () => notifier.performAction('start'),
                child: loading
                    ? const _ButtonSpinner()
                    : const Text('Start Ride'),
              ),
            ] else if (ride.status == 'in_progress') ...[
              FilledButton(
                onPressed: loading
                    ? null
                    : () => notifier.performAction('complete'),
                style: FilledButton.styleFrom(
                    backgroundColor: Colors.green.shade700),
                child: loading
                    ? const _ButtonSpinner()
                    : const Text('Complete Ride'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _RouteRow extends StatelessWidget {
  const _RouteRow({
    required this.icon,
    required this.label,
    required this.name,
  });
  final IconData icon;
  final String label;
  final String name;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon,
            size: 18,
            color: Theme.of(context).colorScheme.primary),
        const SizedBox(width: 8),
        Text(
          '$label: ',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        Expanded(
          child: Text(
            name,
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(fontWeight: FontWeight.w500),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

class _ButtonSpinner extends StatelessWidget {
  const _ButtonSpinner();

  @override
  Widget build(BuildContext context) => const SizedBox(
        height: 18,
        width: 18,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          color: Colors.white,
        ),
      );
}
