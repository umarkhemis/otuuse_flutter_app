"""
Replaces the Rides tab in admin_home_screen.dart with a Deliveries tab
that shows delivery requests and allows admin to reply to passengers.
"""

path = "/mnt/c/Users/HP PROBOOK/projects/otuuse_transport_app/lib/features/admin/screens/admin_home_screen.dart"
with open(path) as f:
    content = f.read()

warnings = []

# 1. Change tab definition: Rides -> Deliveries
old_tab = "              Tab(icon: Icon(Icons.directions_bike_outlined), text: 'Rides'),"
new_tab = "              Tab(icon: Icon(Icons.local_shipping_outlined), text: 'Deliveries'),"

if old_tab in content:
    content = content.replace(old_tab, new_tab, 1)
else:
    warnings.append("Rides tab definition anchor not found")

# 2. Replace _RidesTab() with _DeliveriesTab() in TabBarView
old_tab_view = "            _RidesTab(),"
new_tab_view = "            _DeliveriesTab(),"

if old_tab_view in content:
    content = content.replace(old_tab_view, new_tab_view, 1)
else:
    warnings.append("_RidesTab() in TabBarView not found")

# 3. Find and replace the entire _RidesTab class with _DeliveriesTab
# First find where _RidesTab starts
rides_start = content.find("// ── Rides tab")
if rides_start == -1:
    warnings.append("_RidesTab class start not found")
else:
    # Everything from _RidesTab to end of file gets replaced
    content = content[:rides_start] + DELIVERIES_TAB_CODE

# Write the result
with open(path, "w") as f:
    f.write(content)

if warnings:
    print("WARNINGS:")
    for w in warnings:
        print(f"  - {w}")
else:
    print("Done - Deliveries tab added to admin_home_screen.dart")


DELIVERIES_TAB_CODE = '''// ── Deliveries tab ───────────────────────────────────────────────────────────

class _DeliveriesTab extends ConsumerWidget {
  const _DeliveriesTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(adminProvider);

    if (state.isLoadingDeliveries) {
      return const Center(child: CircularProgressIndicator());
    }

    if (state.deliveries.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.local_shipping_outlined,
                size: 48,
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.3)),
            const SizedBox(height: 12),
            Text('No delivery requests yet',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5))),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => ref.read(adminProvider.notifier).loadDeliveries(),
      child: ListView.separated(
        padding: const EdgeInsets.all(12),
        itemCount: state.deliveries.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (_, i) => _DeliveryCard(delivery: state.deliveries[i]),
      ),
    );
  }
}

class _DeliveryCard extends ConsumerWidget {
  const _DeliveryCard({required this.delivery});
  final DeliveryListItem delivery;

  Color _statusColor(String status) {
    switch (status) {
      case 'pending':
        return Colors.orange;
      case 'confirmed':
        return Colors.blue;
      case 'in_progress':
        return Colors.purple;
      case 'completed':
        return Colors.green;
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String _formatDate(String iso) {
    try {
      final dt = DateTime.parse(iso).toLocal();
      return '\${dt.day}/\${dt.month} \${dt.hour.toString().padLeft(2, "0")}:\${dt.minute.toString().padLeft(2, "0")}';
    } catch (_) {
      return iso.substring(0, 10);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final color = _statusColor(delivery.status);
    final isOpen = delivery.status == 'pending' || delivery.status == 'confirmed';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Status row
            Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    delivery.status.replaceAll('_', ' '),
                    style: TextStyle(
                        fontSize: 11,
                        color: color,
                        fontWeight: FontWeight.w600),
                  ),
                ),
                if (delivery.isUrgent) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text('URGENT',
                        style: TextStyle(
                            fontSize: 11,
                            color: Colors.red,
                            fontWeight: FontWeight.w700)),
                  ),
                ],
                const Spacer(),
                Text(_formatDate(delivery.createdAt),
                    style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
            const SizedBox(height: 10),

            // Item description
            Text(
              delivery.itemDescription,
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 6),

            // Route
            Row(
              children: [
                Icon(Icons.radio_button_checked,
                    size: 14,
                    color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 4),
                Expanded(
                    child: Text(delivery.pickupName,
                        style: Theme.of(context).textTheme.bodySmall,
                        overflow: TextOverflow.ellipsis)),
              ],
            ),
            const SizedBox(height: 2),
            Row(
              children: [
                Icon(Icons.location_on,
                    size: 14, color: Colors.red.shade400),
                const SizedBox(width: 4),
                Expanded(
                    child: Text(delivery.dropoffName,
                        style: Theme.of(context).textTheme.bodySmall,
                        overflow: TextOverflow.ellipsis)),
              ],
            ),

            // Reply button for open deliveries
            if (isOpen) ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () => _showReplySheet(context, ref),
                  icon: const Icon(Icons.reply, size: 18),
                  label: const Text('Reply to Passenger'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _showReplySheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _DeliveryReplySheet(delivery: delivery, ref: ref),
    );
  }
}

class _DeliveryReplySheet extends StatefulWidget {
  const _DeliveryReplySheet({required this.delivery, required this.ref});
  final DeliveryListItem delivery;
  final WidgetRef ref;

  @override
  State<_DeliveryReplySheet> createState() => _DeliveryReplySheetState();
}

class _DeliveryReplySheetState extends State<_DeliveryReplySheet> {
  final _messageCtrl = TextEditingController();
  String? _newStatus;
  bool _isSubmitting = false;
  String? _error;

  @override
  void dispose() {
    _messageCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_messageCtrl.text.trim().isEmpty) {
      setState(() => _error = 'Please type a message to the passenger');
      return;
    }
    setState(() {
      _isSubmitting = true;
      _error = null;
    });
    final success = await widget.ref.read(adminProvider.notifier).replyToDelivery(
          widget.delivery.id,
          _messageCtrl.text.trim(),
          _newStatus,
        );
    if (mounted) {
      if (success) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Reply sent to passenger ✓')),
        );
      } else {
        setState(() {
          _isSubmitting = false;
          _error = 'Failed to send reply. Please try again.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                    child: Text('Reply to Passenger',
                        style: Theme.of(context).textTheme.titleLarge)),
                IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context)),
              ],
            ),
            Text(
              'Delivery: \${widget.delivery.itemDescription}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 16),

            if (_error != null) ...[
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(8)),
                child: Text(_error!,
                    style: TextStyle(color: Colors.red.shade900)),
              ),
              const SizedBox(height: 12),
            ],

            TextField(
              controller: _messageCtrl,
              maxLines: 4,
              decoration: const InputDecoration(
                hintText: 'Type your message to the passenger...',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 14),

            Row(
              children: [
                Text('Update status:',
                    style: Theme.of(context).textTheme.bodyMedium),
                const SizedBox(width: 12),
                DropdownButton<String?>(
                  value: _newStatus,
                  hint: const Text('No change'),
                  items: const [
                    DropdownMenuItem(value: null, child: Text('No change')),
                    DropdownMenuItem(
                        value: 'confirmed', child: Text('Confirmed')),
                    DropdownMenuItem(
                        value: 'in_progress', child: Text('In Progress')),
                    DropdownMenuItem(
                        value: 'completed', child: Text('Completed')),
                    DropdownMenuItem(
                        value: 'cancelled', child: Text('Cancelled')),
                  ],
                  onChanged: (v) => setState(() => _newStatus = v),
                ),
              ],
            ),
            const SizedBox(height: 20),

            FilledButton(
              onPressed: _isSubmitting ? null : _submit,
              child: _isSubmitting
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Text('Send Reply'),
            ),
          ],
        ),
      ),
    );
  }
}
'''
