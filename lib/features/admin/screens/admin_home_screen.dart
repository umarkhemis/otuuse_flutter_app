import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/providers/auth_provider.dart';
import '../data/admin_models.dart';
import '../providers/admin_provider.dart';

class AdminHomeScreen extends ConsumerWidget {
  const AdminHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Otuuse Admin'),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: 'Refresh',
              onPressed: () {
                ref.read(adminProvider.notifier).loadDashboard();
                ref.read(adminProvider.notifier).loadDrivers();
              },
            ),
            IconButton(
              icon: const Icon(Icons.logout),
              onPressed: () => ref.read(authProvider.notifier).logout(),
            ),
          ],
          bottom: const TabBar(
            tabs: [
              Tab(icon: Icon(Icons.dashboard_outlined), text: 'Overview'),
              Tab(icon: Icon(Icons.people_outline), text: 'Drivers'),
              Tab(icon: Icon(Icons.directions_bike_outlined), text: 'Rides'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            _OverviewTab(),
            _DriversTab(),
            _RidesTab(),
          ],
        ),
      ),
    );
  }
}

// ── Overview tab ──────────────────────────────────────────────────────────────

class _OverviewTab extends ConsumerWidget {
  const _OverviewTab();

  String _formatUgx(int n) {
    final s = n.toString();
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
    final state = ref.watch(adminProvider);

    if (state.isLoadingStats) {
      return const Center(child: CircularProgressIndicator());
    }

    final stats = state.stats;
    if (stats == null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48),
            const SizedBox(height: 12),
            Text(state.errorMessage ?? 'Failed to load dashboard'),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: () =>
                  ref.read(adminProvider.notifier).loadDashboard(),
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => ref.read(adminProvider.notifier).loadDashboard(),
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Today\'s snapshot',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 1.6,
            children: [
              _StatCard(
                icon: Icons.directions_bike,
                label: 'Drivers Online',
                value: '${stats.driversOnlineNow}',
                color: Colors.green,
              ),
              _StatCard(
                icon: Icons.people,
                label: 'Active Drivers',
                value: '${stats.totalActiveDrivers}',
                color: Colors.blue,
              ),
              _StatCard(
                icon: Icons.route,
                label: 'Active Rides',
                value: '${stats.activeRidesNow}',
                color: Colors.orange,
              ),
              _StatCard(
                icon: Icons.check_circle_outline,
                label: 'Rides Today',
                value: '${stats.ridesCompletedToday}',
                color: Colors.teal,
              ),
              _StatCard(
                icon: Icons.payments_outlined,
                label: 'Revenue Today',
                value: 'UGX ${_formatUgx(stats.revenueToday)}',
                color: Colors.purple,
              ),
              _StatCard(
                icon: Icons.inbox_outlined,
                label: 'Pending Deliveries',
                value: '${stats.pendingDeliveries}',
                color: stats.pendingDeliveries > 0
                    ? Colors.red
                    : Colors.grey,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Icon(icon, color: color, size: 22),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(value,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold, color: color)),
                Text(label,
                    style: Theme.of(context).textTheme.bodySmall,
                    overflow: TextOverflow.ellipsis),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ── Drivers tab ───────────────────────────────────────────────────────────────

class _DriversTab extends ConsumerWidget {
  const _DriversTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(adminProvider);

    return Scaffold(
      body: state.isLoadingDrivers
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: () =>
                  ref.read(adminProvider.notifier).loadDrivers(),
              child: state.drivers.isEmpty
                  ? const Center(child: Text('No drivers yet'))
                  : ListView.separated(
                      padding: const EdgeInsets.all(12),
                      itemCount: state.drivers.length,
                      separatorBuilder: (_, __) =>
                          const SizedBox(height: 8),
                      itemBuilder: (_, i) => _DriverCard(
                        driver: state.drivers[i],
                        isPendingAction: state.pendingActionDriverId ==
                            state.drivers[i].userId,
                      ),
                    ),
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showOnboardSheet(context, ref),
        icon: const Icon(Icons.person_add_outlined),
        label: const Text('Onboard Driver'),
      ),
    );
  }

  void _showOnboardSheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => const _OnboardDriverSheet(),
    );
  }
}

class _DriverCard extends ConsumerWidget {
  const _DriverCard(
      {required this.driver, required this.isPendingAction});

  final DriverListItem driver;
  final bool isPendingAction;

  Color _availabilityColor(String a) {
    switch (a) {
      case 'online':
        return Colors.green;
      case 'on_ride':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(adminProvider.notifier);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(driver.name,
                          style: Theme.of(context)
                              .textTheme
                              .titleSmall
                              ?.copyWith(
                                  fontWeight: FontWeight.w600)),
                      Text(driver.phoneNumber,
                          style:
                              Theme.of(context).textTheme.bodySmall),
                    ],
                  ),
                ),
                // Availability badge
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: _availabilityColor(driver.availability)
                        .withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    driver.availability.replaceAll('_', ' '),
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color:
                          _availabilityColor(driver.availability),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.star, size: 14, color: Colors.amber.shade700),
                const SizedBox(width: 3),
                Text(driver.rating.toStringAsFixed(1),
                    style: Theme.of(context).textTheme.bodySmall),
                const SizedBox(width: 12),
                Icon(Icons.directions_bike,
                    size: 14,
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withOpacity(0.5)),
                const SizedBox(width: 3),
                Text('${driver.totalRides} rides',
                    style: Theme.of(context).textTheme.bodySmall),
                const Spacer(),
                _SubscriptionBadge(active: driver.subscriptionActive),
              ],
            ),
            if (!driver.documentsVerified) ...[
              const SizedBox(height: 6),
              Row(
                children: [
                  Icon(Icons.warning_amber_outlined,
                      size: 14, color: Colors.orange.shade700),
                  const SizedBox(width: 4),
                  Text('Documents pending verification',
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(
                              color: Colors.orange.shade700)),
                ],
              ),
            ],
            const SizedBox(height: 12),
            // Actions
            isPendingAction
                ? const Center(
                    child: SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2)))
                : Row(
                    children: [
                      if (driver.isActive)
                        OutlinedButton(
                          onPressed: () =>
                              notifier.suspendDriver(driver.userId),
                          style: OutlinedButton.styleFrom(
                              foregroundColor:
                                  Colors.red.shade700),
                          child: const Text('Suspend'),
                        )
                      else
                        FilledButton(
                          onPressed: () =>
                              notifier.reinstateDriver(driver.userId),
                          child: const Text('Reinstate'),
                        ),
                      const SizedBox(width: 8),
                      OutlinedButton(
                        onPressed: () =>
                            _showRenewDialog(context, ref),
                        child: const Text('Renew Sub'),
                      ),
                    ],
                  ),
          ],
        ),
      ),
    );
  }

  void _showRenewDialog(BuildContext context, WidgetRef ref) {
    int months = 1;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Renew ${driver.name}\'s subscription'),
        content: StatefulBuilder(
          builder: (_, setState) => DropdownButton<int>(
            value: months,
            items: [1, 3, 6, 12]
                .map((m) => DropdownMenuItem(
                    value: m, child: Text('$m month${m > 1 ? 's' : ''}')))
                .toList(),
            onChanged: (v) => setState(() => months = v!),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              ref
                  .read(adminProvider.notifier)
                  .renewSubscription(driver.userId, months);
            },
            child: const Text('Renew'),
          ),
        ],
      ),
    );
  }
}

class _SubscriptionBadge extends StatelessWidget {
  const _SubscriptionBadge({required this.active});
  final bool active;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: active
            ? Colors.teal.withOpacity(0.12)
            : Colors.red.withOpacity(0.12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        active ? 'Subscribed' : 'Expired',
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: active ? Colors.teal.shade700 : Colors.red.shade700,
        ),
      ),
    );
  }
}

// ── Onboard driver sheet ──────────────────────────────────────────────────────

class _OnboardDriverSheet extends ConsumerStatefulWidget {
  const _OnboardDriverSheet();

  @override
  ConsumerState<_OnboardDriverSheet> createState() =>
      _OnboardDriverSheetState();
}

class _OnboardDriverSheetState
    extends ConsumerState<_OnboardDriverSheet> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _pinCtrl = TextEditingController();
  int _months = 1;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _pinCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final result =
        await ref.read(adminProvider.notifier).onboardDriver(
              phoneNumber: _phoneCtrl.text.trim(),
              name: _nameCtrl.text.trim(),
              initialPin: _pinCtrl.text.trim(),
              subscriptionMonths: _months,
            );

    if (result != null && mounted) {
      Navigator.pop(context);
      _showInviteCodeDialog(context, result);
    }
  }

  void _showInviteCodeDialog(BuildContext ctx, OnboardResult result) {
    showDialog(
      context: ctx,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        title: const Text('Driver Onboarded'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${result.message}\n'),
            Text('Driver: ${result.phoneNumber}',
                style: const TextStyle(fontWeight: FontWeight.w500)),
            const SizedBox(height: 12),
            const Text('Invite code:'),
            const SizedBox(height: 6),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Theme.of(ctx).colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    result.inviteCode,
                    style: Theme.of(ctx).textTheme.headlineSmall?.copyWith(
                          letterSpacing: 4,
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.copy),
                    tooltip: 'Copy',
                    onPressed: () {
                      Clipboard.setData(
                          ClipboardData(text: result.inviteCode));
                      ScaffoldMessenger.of(ctx).showSnackBar(
                        const SnackBar(
                            content: Text('Invite code copied')),
                      );
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Share this code with ${_nameCtrl.text}. '
              'They will use it when setting up their account.',
              style: Theme.of(ctx).textTheme.bodySmall,
            ),
          ],
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(_),
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(adminProvider);

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Text('Onboard New Driver',
                      style: Theme.of(context).textTheme.titleLarge),
                  const Spacer(),
                  IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context)),
                ],
              ),
              const SizedBox(height: 16),
              if (state.errorMessage != null)
                Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(state.errorMessage!,
                      style: TextStyle(color: Colors.red.shade900)),
                ),
              TextFormField(
                controller: _nameCtrl,
                decoration: const InputDecoration(
                    labelText: 'Full name', border: OutlineInputBorder()),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _phoneCtrl,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'Phone number',
                  hintText: '+256...',
                  border: OutlineInputBorder(),
                ),
                validator: (v) =>
                    (v == null || v.trim().length < 8) ? 'Required' : null,
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _pinCtrl,
                keyboardType: TextInputType.number,
                obscureText: true,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                maxLength: 6,
                decoration: const InputDecoration(
                  labelText: 'Initial PIN (4-6 digits)',
                  border: OutlineInputBorder(),
                ),
                validator: (v) {
                  if (v == null || v.length < 4) {
                    return 'PIN must be 4-6 digits';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Text('Subscription:',
                      style: Theme.of(context).textTheme.bodyMedium),
                  const SizedBox(width: 12),
                  DropdownButton<int>(
                    value: _months,
                    items: [1, 3, 6, 12]
                        .map((m) => DropdownMenuItem(
                            value: m,
                            child: Text(
                                '$m month${m > 1 ? 's' : ''}')))
                        .toList(),
                    onChanged: (v) => setState(() => _months = v!),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: state.isOnboarding ? null : _submit,
                child: state.isOnboarding
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Text('Create Driver Account'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Rides tab ─────────────────────────────────────────────────────────────────

class _RidesTab extends ConsumerWidget {
  const _RidesTab();

  String _formatUgx(int n) {
    final s = n.toString();
    final buf = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      final fromEnd = s.length - i;
      buf.write(s[i]);
      if (fromEnd > 1 && fromEnd % 3 == 1) buf.write(',');
    }
    return buf.toString();
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'completed':
      case 'paid':
        return Colors.green;
      case 'in_progress':
      case 'driver_arriving':
      case 'accepted':
      case 'matched':
        return Colors.orange;
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(adminProvider);

    // Lazy load rides when this tab is first viewed
    if (state.rides.isEmpty && !state.isLoadingRides) {
      Future.microtask(
          () => ref.read(adminProvider.notifier).loadRides());
    }

    if (state.isLoadingRides) {
      return const Center(child: CircularProgressIndicator());
    }

    if (state.rides.isEmpty) {
      return const Center(child: Text('No rides yet'));
    }

    return ListView.separated(
      padding: const EdgeInsets.all(12),
      itemCount: state.rides.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (_, i) {
        final ride = state.rides[i];
        final color = _statusColor(ride.status);
        final fare =
            ride.finalFareUgx ?? ride.estimatedFareUgx;
        return Card(
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(
                horizontal: 14, vertical: 8),
            title: Text(
              '${ride.pickupName} → ${ride.dropoffName}',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w500),
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Text(
              ride.requestedAt.substring(0, 10),
              style: Theme.of(context).textTheme.bodySmall,
            ),
            trailing: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    ride.status.replaceAll('_', ' '),
                    style: TextStyle(
                        fontSize: 11,
                        color: color,
                        fontWeight: FontWeight.w600),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'UGX ${_formatUgx(fare)}',
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
