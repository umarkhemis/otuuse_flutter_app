import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../auth/providers/auth_provider.dart';
import '../../rating/screens/rating_dialog.dart';
import '../../wallet/providers/wallet_provider.dart';
import '../../wallet/screens/wallet_sheet.dart';
import '../data/chat_models.dart';
import '../providers/chat_provider.dart';

class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({super.key});

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  final _imagePicker = ImagePicker();

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _send() {
    final text = _controller.text;
    if (text.trim().isEmpty) return;
    _controller.clear();
    ref.read(chatProvider.notifier).sendMessage(text);
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }

  Future<void> _pickPhoto() async {
    final source = await _showPhotoSourceSheet();
    if (source == null) return;

    final XFile? image = await _imagePicker.pickImage(
      source: source,
      maxWidth: 1200,
      maxHeight: 1200,
      imageQuality: 85,
    );
    if (image == null || !mounted) return;

    final bytes = await image.readAsBytes();
    await ref.read(chatProvider.notifier).uploadDeliveryPhoto(
          bytes,
          image.name.isNotEmpty ? image.name : 'delivery_photo.jpg',
        );
  }

  Future<ImageSource?> _showPhotoSourceSheet() async {
    return showModalBottomSheet<ImageSource>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined),
              title: const Text('Take a photo'),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Choose from gallery'),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmClearHistory() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Clear chat'),
        content: const Text('This will delete all messages and start fresh.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              ref.read(chatProvider.notifier).clearHistory();
            },
            style: FilledButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.error),
            child: const Text('Clear'),
          ),
        ],
      ),
    );
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
  Widget build(BuildContext context) {
    final chatState = ref.watch(chatProvider);
    final walletState = ref.watch(walletProvider);

    ref.listen(chatProvider, (previous, next) {
      if (next.turns.length != previous?.turns.length) _scrollToBottom();
      if (next.completedRideId != null && previous?.completedRideId == null) {
        WidgetsBinding.instance.addPostFrameCallback((_) async {
          await showRatingDialog(
            context: context,
            ref: ref,
            rideId: next.completedRideId!,
            ratingFor: 'driver',
          );
          if (mounted) ref.read(chatProvider.notifier).clearCompletedRide();
        });
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text('Otuuse Transport'),
        actions: [
          // Wallet balance chip
          InkWell(
            onTap: () => showWalletSheet(context),
            borderRadius: BorderRadius.circular(20),
            child: Container(
              margin: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.6),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.account_balance_wallet_outlined,
                      size: 15, color: Theme.of(context).colorScheme.primary),
                  const SizedBox(width: 4),
                  walletState.isLoadingBalance
                      ? const SizedBox(width: 12, height: 12,
                          child: CircularProgressIndicator(strokeWidth: 1.5))
                      : Text(
                          walletState.balanceUgx != null
                              ? 'UGX ${_formatUgx(walletState.balanceUgx!)}'
                              : '—',
                          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).colorScheme.primary),
                        ),
                ],
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            tooltip: 'Clear chat',
            onPressed: _confirmClearHistory,
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Log out',
            onPressed: () => ref.read(authProvider.notifier).logout(),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            if (chatState.errorMessage != null)
              Container(
                width: double.infinity,
                color: Colors.red.shade50,
                padding: const EdgeInsets.all(12),
                child: Text(chatState.errorMessage!,
                    style: TextStyle(color: Colors.red.shade900)),
              ),
            Expanded(
              child: ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.all(16),
                itemCount: chatState.turns.length,
                itemBuilder: (context, index) {
                  final turn = chatState.turns[index];
                  return _ChatBubble(
                    turn: turn,
                    isSending: chatState.isSending,
                    onRespond: (confirmed) =>
                        ref.read(chatProvider.notifier).respondToFareQuote(index, confirmed),
                  );
                },
              ),
            ),
            if (chatState.isSending || chatState.isUploadingPhoto)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SizedBox(height: 18, width: 18,
                        child: CircularProgressIndicator(strokeWidth: 2)),
                    if (chatState.isUploadingPhoto) ...[
                      const SizedBox(width: 8),
                      Text('Uploading photo...',
                          style: Theme.of(context).textTheme.bodySmall),
                    ],
                  ],
                ),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              child: Row(
                children: [
                  // Attachment button - only shown when delivery is active
                  if (chatState.activeDeliveryId != null)
                    IconButton(
                      icon: Icon(
                        Icons.attach_file,
                        color: chatState.isUploadingPhoto
                            ? Theme.of(context).colorScheme.onSurface.withOpacity(0.3)
                            : Theme.of(context).colorScheme.primary,
                      ),
                      tooltip: 'Attach photo of item',
                      onPressed: chatState.isUploadingPhoto ? null : _pickPhoto,
                    ),
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _send(),
                      decoration: InputDecoration(
                        hintText: chatState.activeDeliveryId != null
                            ? 'Chat about your delivery...'
                            : 'Where are you headed?',
                        border: const OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    onPressed: chatState.isSending ? null : _send,
                    icon: const Icon(Icons.send),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Chat bubble ───────────────────────────────────────────────────────────────

class _ChatBubble extends StatelessWidget {
  const _ChatBubble({
    required this.turn,
    required this.isSending,
    required this.onRespond,
  });

  final ChatTurn turn;
  final bool isSending;
  final void Function(bool confirmed) onRespond;

  @override
  Widget build(BuildContext context) {
    final isUser = turn.role == ChatTurnRole.user;
    final colorScheme = Theme.of(context).colorScheme;

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.78),
        margin: const EdgeInsets.symmetric(vertical: 6),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isUser ? colorScheme.primaryContainer : colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (turn.text.isNotEmpty) Text(turn.text),

            // Photo attachment
            if (turn.photoUrl != null) ...[
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(
                  turn.photoUrl!,
                  width: 220,
                  height: 180,
                  fit: BoxFit.cover,
                  loadingBuilder: (_, child, progress) => progress == null
                      ? child
                      : Container(
                          width: 220,
                          height: 180,
                          color: colorScheme.surfaceContainerHighest,
                          child: Center(
                            child: CircularProgressIndicator(
                              value: progress.expectedTotalBytes != null
                                  ? progress.cumulativeBytesLoaded / progress.expectedTotalBytes!
                                  : null,
                            ),
                          ),
                        ),
                  errorBuilder: (_, __, ___) => Container(
                    width: 220,
                    height: 60,
                    color: colorScheme.errorContainer,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.broken_image_outlined, color: colorScheme.error),
                        const SizedBox(width: 8),
                        Text('Could not load photo',
                            style: TextStyle(color: colorScheme.error, fontSize: 12)),
                      ],
                    ),
                  ),
                ),
              ),
            ],

            // Searching spinner
            if (turn.isSearching) ...[
              const SizedBox(height: 10),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 14, height: 14,
                    child: CircularProgressIndicator(strokeWidth: 1.5, color: colorScheme.primary),
                  ),
                  const SizedBox(width: 8),
                  Text('Finding your driver...',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(color: colorScheme.primary)),
                ],
              ),
            ],

            // Fare card
            if (turn.fareUgx != null) ...[
              const SizedBox(height: 10),
              _FareQuoteCard(
                fareUgx: turn.fareUgx!,
                status: turn.fareStatus ?? FareQuoteStatus.pending,
                isSending: isSending,
                driverName: turn.driverName,
                driverPhone: turn.driverPhone,
                driverPlate: turn.driverPlate,
                onRespond: onRespond,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ── Fare quote card ───────────────────────────────────────────────────────────

class _FareQuoteCard extends StatelessWidget {
  const _FareQuoteCard({
    required this.fareUgx,
    required this.status,
    required this.isSending,
    required this.onRespond,
    this.driverName,
    this.driverPhone,
    this.driverPlate,
  });

  final int fareUgx;
  final FareQuoteStatus status;
  final bool isSending;
  final void Function(bool confirmed) onRespond;
  final String? driverName;
  final String? driverPhone;
  final String? driverPlate;

  String _fmt(int n) {
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
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (driverName != null) ...[
              Row(children: [
                Icon(Icons.directions_bike_outlined, size: 16,
                    color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 6),
                Text(driverName!, style: Theme.of(context).textTheme.bodyMedium
                    ?.copyWith(fontWeight: FontWeight.w600)),
              ]),
              if (driverPlate != null && driverPlate != '—') ...[
                const SizedBox(height: 3),
                Text('Plate: $driverPlate',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6))),
              ],
              if (driverPhone != null && driverPhone!.isNotEmpty) ...[
                const SizedBox(height: 3),
                Row(children: [
                  Icon(Icons.phone_outlined, size: 13,
                      color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5)),
                  const SizedBox(width: 4),
                  Text(driverPhone!, style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6))),
                ]),
              ],
              Divider(height: 16,
                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.1)),
            ],
            Text('Estimated fare', style: Theme.of(context).textTheme.labelMedium),
            Text('UGX ${_fmt(fareUgx)}', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            if (status == FareQuoteStatus.pending)
              Row(children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: isSending ? null : () => onRespond(false),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton(
                    onPressed: isSending ? null : () => onRespond(true),
                    child: const Text('Confirm ride'),
                  ),
                ),
              ])
            else
              Text(
                status == FareQuoteStatus.confirmed ? 'Ride confirmed' : 'Cancelled',
                style: TextStyle(
                  color: status == FareQuoteStatus.confirmed
                      ? Colors.green.shade700 : Colors.grey,
                  fontWeight: FontWeight.w600,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
