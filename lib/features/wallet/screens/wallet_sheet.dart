import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../data/wallet_models.dart';
import '../providers/wallet_provider.dart';

/// Call this from any screen to open the wallet bottom sheet.
void showWalletSheet(BuildContext context) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => const WalletSheet(),
  );
}

class WalletSheet extends ConsumerStatefulWidget {
  const WalletSheet({super.key});

  @override
  ConsumerState<WalletSheet> createState() => _WalletSheetState();
}

class _WalletSheetState extends ConsumerState<WalletSheet>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final _customAmountController = TextEditingController();
  int? _selectedAmount;

  static const _presets = [5000, 10000, 20000, 50000];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    // Load transactions lazily when user switches to that tab.
    _tabController.addListener(() {
      if (_tabController.index == 1 &&
          ref.read(walletProvider).transactions.isEmpty) {
        ref.read(walletProvider.notifier).loadTransactions();
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _customAmountController.dispose();
    super.dispose();
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

  Future<void> _onTopUp() async {
    int? amount = _selectedAmount;
    if (amount == null) {
      final raw = int.tryParse(_customAmountController.text.trim());
      if (raw == null || raw < 1000) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Minimum top-up is UGX 1,000')),
        );
        return;
      }
      amount = raw;
    }

    final url =
        await ref.read(walletProvider.notifier).initiateTopup(amount);
    if (url == null) return; // error already shown via state

    final launched = await launchUrl(
      Uri.parse(url),
      mode: LaunchMode.externalApplication,
    );

    if (!launched && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Could not open payment page. Try again.')),
      );
      return;
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'Complete payment in the browser. Your balance will update automatically.'),
          duration: Duration(seconds: 6),
        ),
      );
      // Refresh balance after user returns (delayed to allow IPN to process).
      await Future.delayed(const Duration(seconds: 5));
      if (mounted) ref.read(walletProvider.notifier).refreshBalance();
    }
  }

  @override
  Widget build(BuildContext context) {
    final walletState = ref.watch(walletProvider);

    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) => Column(
        children: [
          // Handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withOpacity(0.2),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Title + balance
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
            child: Row(
              children: [
                const Icon(Icons.account_balance_wallet_outlined,
                    size: 22),
                const SizedBox(width: 10),
                Text('Your Wallet',
                    style: Theme.of(context).textTheme.titleLarge),
                const Spacer(),
                if (walletState.isLoadingBalance)
                  const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2))
                else
                  Text(
                    walletState.balanceUgx != null
                        ? 'UGX ${_formatUgx(walletState.balanceUgx!)}'
                        : '—',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                  ),
              ],
            ),
          ),

          const SizedBox(height: 8),

          // Tabs
          TabBar(
            controller: _tabController,
            tabs: const [Tab(text: 'Top Up'), Tab(text: 'History')],
          ),

          if (walletState.errorMessage != null)
            Container(
              margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(walletState.errorMessage!,
                  style: TextStyle(color: Colors.red.shade900)),
            ),

          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                // ── Top-Up tab ──────────────────────────────────────────────
                ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.all(20),
                  children: [
                    Text('Select amount',
                        style: Theme.of(context).textTheme.labelLarge),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: _presets.map((amount) {
                        final selected = _selectedAmount == amount;
                        return ChoiceChip(
                          label: Text('UGX ${_formatUgx(amount)}'),
                          selected: selected,
                          onSelected: (_) => setState(() {
                            _selectedAmount = selected ? null : amount;
                            if (!selected) _customAmountController.clear();
                          }),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 16),
                    Text('Or enter amount',
                        style: Theme.of(context).textTheme.labelLarge),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _customAmountController,
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly
                      ],
                      decoration: const InputDecoration(
                        prefixText: 'UGX ',
                        border: OutlineInputBorder(),
                        hintText: 'e.g. 30000',
                      ),
                      onChanged: (v) =>
                          setState(() => _selectedAmount = null),
                    ),
                    const SizedBox(height: 24),
                    FilledButton.icon(
                      onPressed: walletState.isInitiatingTopup
                          ? null
                          : _onTopUp,
                      icon: walletState.isInitiatingTopup
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.phone_android),
                      label: const Text('Pay with MoMo / Airtel'),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'You will be redirected to PesaPal to complete payment via MTN MoMo or Airtel Money. Your balance updates automatically after payment.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context)
                                .colorScheme
                                .onSurface
                                .withOpacity(0.5),
                          ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),

                // ── History tab ─────────────────────────────────────────────
                walletState.isLoadingTransactions
                    ? const Center(child: CircularProgressIndicator())
                    : walletState.transactions.isEmpty
                        ? Center(
                            child: Text('No transactions yet',
                                style: Theme.of(context)
                                    .textTheme
                                    .bodyMedium
                                    ?.copyWith(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .onSurface
                                            .withOpacity(0.4))))
                        : ListView.separated(
                            controller: scrollController,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 8),
                            itemCount:
                                walletState.transactions.length,
                            separatorBuilder: (_, __) =>
                                const Divider(height: 1),
                            itemBuilder: (_, i) => _TxnTile(
                              txn: walletState.transactions[i],
                              formatUgx: _formatUgx,
                            ),
                          ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TxnTile extends StatelessWidget {
  const _TxnTile({required this.txn, required this.formatUgx});
  final WalletTransaction txn;
  final String Function(int) formatUgx;

  @override
  Widget build(BuildContext context) {
    final isCredit = txn.isCredit;
    final color = isCredit ? Colors.green.shade700 : Colors.red.shade700;

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      leading: CircleAvatar(
        radius: 18,
        backgroundColor: color.withOpacity(0.12),
        child: Icon(
          isCredit ? Icons.add : Icons.remove,
          color: color,
          size: 18,
        ),
      ),
      title: Text(
        txn.description ?? txn.type.replaceAll('_', ' '),
        style: Theme.of(context).textTheme.bodyMedium,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        txn.status,
        style: Theme.of(context).textTheme.bodySmall,
      ),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            '${isCredit ? '+' : '-'}UGX ${formatUgx(txn.amountUgx)}',
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(color: color, fontWeight: FontWeight.w600),
          ),
          if (txn.balanceAfterUgx != null)
            Text(
              'Bal: UGX ${formatUgx(txn.balanceAfterUgx!)}',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withOpacity(0.4),
                  ),
            ),
        ],
      ),
    );
  }
}
