import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/providers/auth_provider.dart';
import '../data/chat_models.dart';
import '../data/chat_repository.dart';

class ChatState {
  const ChatState({
    this.turns = const [],
    this.isSending = false,
    this.errorMessage,
    this.completedRideId,
  });

  final List<ChatTurn> turns;
  final bool isSending;
  final String? errorMessage;
  final String? completedRideId;

  ChatState copyWith({
    List<ChatTurn>? turns,
    bool? isSending,
    String? errorMessage,
    String? completedRideId,
    bool clearCompletedRide = false,
  }) {
    return ChatState(
      turns: turns ?? this.turns,
      isSending: isSending ?? this.isSending,
      errorMessage: errorMessage,
      completedRideId: clearCompletedRide
          ? null
          : (completedRideId ?? this.completedRideId),
    );
  }
}

class ChatNotifier extends Notifier<ChatState> {
  Timer? _searchTimer;
  Timer? _completionTimer;
  Timer? _deliveryTimer;
  String? _searchingRideId;
  int _searchingTurnIndex = -1;
  String? _pollingDeliveryId;
  String? _lastSeenReplyAt;

  @override
  ChatState build() {
    ref.onDispose(() {
      _searchTimer?.cancel();
      _completionTimer?.cancel();
      _deliveryTimer?.cancel();
    });
    return ChatState(turns: [_buildWelcomeTurn()]);
  }

  ChatTurn _buildWelcomeTurn() {
    final authState = ref.read(authProvider);
    final name = authState.session?.name ?? '';
    final hour = DateTime.now().hour;
    final greeting = hour < 12
        ? 'Good morning'
        : hour < 17
            ? 'Good afternoon'
            : 'Good evening';
    final nameClause = name.isNotEmpty ? ', $name' : '';
    return ChatTurn(
      role: ChatTurnRole.agent,
      text: '$greeting$nameClause! 👋 Where would you like to go today, '
          'or what would you like delivered?',
    );
  }

  ChatRepository get _repo => ref.read(chatRepositoryProvider);

  // ── Messaging ─────────────────────────────────────────────────────────────

  Future<void> sendMessage(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty || state.isSending) return;

    state = state.copyWith(
      turns: [
        ...state.turns,
        ChatTurn(role: ChatTurnRole.user, text: trimmed),
      ],
      isSending: true,
      errorMessage: null,
    );

    try {
      final response = await _repo.sendMessage(trimmed);

      if (response.rideId != null && response.fareUgx == null) {
        // Driver-first flow: searching for driver
        final searchTurnIndex = state.turns.length;
        state = state.copyWith(
          turns: [
            ...state.turns,
            ChatTurn(
              role: ChatTurnRole.agent,
              text: response.reply,
              isSearching: true,
              pendingRideId: response.rideId,
            ),
          ],
          isSending: false,
        );
        _startSearchPolling(response.rideId!, searchTurnIndex);
      } else if (response.deliveryId != null) {
        // Delivery created - poll for admin reply
        state = state.copyWith(
          turns: [
            ...state.turns,
            ChatTurn(role: ChatTurnRole.agent, text: response.reply),
          ],
          isSending: false,
        );
        _startDeliveryPolling(response.deliveryId!);
      } else {
        state = state.copyWith(
          turns: [
            ...state.turns,
            ChatTurn(
              role: ChatTurnRole.agent,
              text: response.reply,
              fareUgx: response.fareUgx,
              fareStatus:
                  response.fareUgx != null ? FareQuoteStatus.pending : null,
              driverName: response.driverName,
              driverPhone: response.driverPhone,
              driverPlate: response.driverPlate,
            ),
          ],
          isSending: false,
        );
      }
    } catch (e) {
      state = state.copyWith(isSending: false, errorMessage: e.toString());
    }
  }

  // ── Driver acceptance polling ─────────────────────────────────────────────

  void _startSearchPolling(String rideId, int turnIndex) {
    _searchTimer?.cancel();
    _searchingRideId = rideId;
    _searchingTurnIndex = turnIndex;
    _pollRideStatus();
    _searchTimer = Timer.periodic(
        const Duration(seconds: 4), (_) => _pollRideStatus());
  }

  Future<void> _pollRideStatus() async {
    final rideId = _searchingRideId;
    if (rideId == null) return;
    try {
      final status = await _repo.getRideStatus(rideId);
      if (status.isAccepted) {
        _searchTimer?.cancel();
        _searchTimer = null;
        _searchingRideId = null;
        final updatedTurns = List<ChatTurn>.from(state.turns);
        if (_searchingTurnIndex >= 0 &&
            _searchingTurnIndex < updatedTurns.length) {
          updatedTurns[_searchingTurnIndex] =
              updatedTurns[_searchingTurnIndex].copyWith(
            isSearching: false,
            fareUgx: status.fareUgx,
            fareStatus: FareQuoteStatus.pending,
            driverName: status.driverName,
            driverPhone: status.driverPhone,
            driverPlate: status.driverPlate,
          );
        }
        state = state.copyWith(turns: updatedTurns);
      } else if (status.isCancelled) {
        _searchTimer?.cancel();
        _searchTimer = null;
        _searchingRideId = null;
        final updatedTurns = List<ChatTurn>.from(state.turns);
        if (_searchingTurnIndex >= 0 &&
            _searchingTurnIndex < updatedTurns.length) {
          updatedTurns[_searchingTurnIndex] = ChatTurn(
            role: ChatTurnRole.agent,
            text: "Sorry, we couldn't find a driver right now. Please try again.",
          );
        }
        state = state.copyWith(turns: updatedTurns);
      }
    } catch (_) {}
  }

  // ── Delivery admin reply polling ──────────────────────────────────────────

  /// Polls every 15 seconds for admin reply on a delivery request.
  void _startDeliveryPolling(String deliveryId) {
    _deliveryTimer?.cancel();
    _pollingDeliveryId = deliveryId;
    _lastSeenReplyAt = null;
    _deliveryTimer = Timer.periodic(
      const Duration(seconds: 15),
      (_) => _pollDeliveryStatus(),
    );
  }

  Future<void> _pollDeliveryStatus() async {
    final deliveryId = _pollingDeliveryId;
    if (deliveryId == null) return;
    try {
      final status = await _repo.getDeliveryStatus(deliveryId);

      if (status.hasReply &&
          status.repliedAt != null &&
          status.repliedAt != _lastSeenReplyAt) {
        // New admin reply - show it as a chat message
        _lastSeenReplyAt = status.repliedAt;
        state = state.copyWith(
          turns: [
            ...state.turns,
            ChatTurn(
              role: ChatTurnRole.agent,
              text: status.adminReply!,
            ),
          ],
        );
      }

      // Stop polling once delivery is closed
      if (status.isClosed) {
        _deliveryTimer?.cancel();
        _deliveryTimer = null;
        _pollingDeliveryId = null;
      }
    } catch (_) {}
  }

  // ── Ride completion polling ───────────────────────────────────────────────

  void _startCompletionPolling(String rideId) {
    _completionTimer?.cancel();
    _completionTimer = Timer.periodic(
      const Duration(seconds: 15),
      (_) async {
        try {
          final status = await _repo.getRideStatus(rideId);
          if (status.isCompleted) {
            _completionTimer?.cancel();
            _completionTimer = null;
            state = state.copyWith(completedRideId: rideId);
          } else if (status.isCancelled) {
            _completionTimer?.cancel();
            _completionTimer = null;
          }
        } catch (_) {}
      },
    );
  }

  // ── Fare card ─────────────────────────────────────────────────────────────

  Future<void> respondToFareQuote(int turnIndex, bool confirmed) async {
    final rideId = state.turns[turnIndex].pendingRideId;
    if (rideId == null || state.isSending) return;

    state = state.copyWith(isSending: true, errorMessage: null);

    try {
      final result = await _repo.confirmRide(rideId, confirmed);
      final updatedTurns = List<ChatTurn>.from(state.turns);
      updatedTurns[turnIndex] = updatedTurns[turnIndex].copyWith(
        fareStatus:
            confirmed ? FareQuoteStatus.confirmed : FareQuoteStatus.cancelled,
      );
      updatedTurns
          .add(ChatTurn(role: ChatTurnRole.agent, text: result.message));
      state = state.copyWith(turns: updatedTurns, isSending: false);

      if (confirmed) _startCompletionPolling(rideId);
    } catch (e) {
      state = state.copyWith(isSending: false, errorMessage: e.toString());
    }
  }

  // ── History + rating ──────────────────────────────────────────────────────

  void clearHistory() {
    _searchTimer?.cancel();
    _completionTimer?.cancel();
    _deliveryTimer?.cancel();
    _searchTimer = null;
    _completionTimer = null;
    _deliveryTimer = null;
    _searchingRideId = null;
    _searchingTurnIndex = -1;
    _pollingDeliveryId = null;
    _lastSeenReplyAt = null;
    state = ChatState(turns: [_buildWelcomeTurn()]);
  }

  void clearCompletedRide() {
    state = state.copyWith(clearCompletedRide: true);
  }
}

final chatRepositoryProvider = Provider<ChatRepository>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return ChatRepository(apiClient);
});

final chatProvider =
    NotifierProvider<ChatNotifier, ChatState>(ChatNotifier.new);
