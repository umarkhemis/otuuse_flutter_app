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
  });

  final List<ChatTurn> turns;
  final bool isSending;
  final String? errorMessage;

  ChatState copyWith({
    List<ChatTurn>? turns,
    bool? isSending,
    String? errorMessage,
  }) {
    return ChatState(
      turns: turns ?? this.turns,
      isSending: isSending ?? this.isSending,
      // Explicitly nullable - copyWith(errorMessage: null) clears it.
      errorMessage: errorMessage,
    );
  }
}

class ChatNotifier extends Notifier<ChatState> {
  Timer? _searchTimer;
  String? _searchingRideId;
  int _searchingTurnIndex = -1;

  @override
  ChatState build() {
    ref.onDispose(() => _searchTimer?.cancel());
    return const ChatState(
      turns: [
        ChatTurn(
          role: ChatTurnRole.agent,
          text:
              'Hi! Where would you like to go, or what would you like delivered?',
        ),
      ],
    );
  }

  ChatRepository get _repo => ref.read(chatRepositoryProvider);

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
        // Dispatch-first flow: driver has been alerted but hasn't accepted yet.
        // Show "Hold on..." message with a searching spinner.
        // The fare card appears after the driver accepts (via polling below).
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
      } else {
        // Regular response (chat, delivery, status update, etc.)
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
    // Check immediately, then every 4 seconds.
    _pollRideStatus();
    _searchTimer = Timer.periodic(
      const Duration(seconds: 4),
      (_) => _pollRideStatus(),
    );
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

        // Update the searching turn: stop spinner + attach fare card data.
        // The passenger now sees the fare card with driver details.
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
            text:
                "Sorry, we couldn't find an available driver right now. Please try again in a few minutes.",
            isSearching: false,
          );
        }
        state = state.copyWith(turns: updatedTurns);
      }
      // If status is 'requested' or 'matched', keep polling.
    } catch (_) {
      // Polling failures are silent - don't disrupt the passenger's view.
    }
  }

  // ── Fare card confirmation ────────────────────────────────────────────────

  /// Called when passenger taps Confirm or Cancel on the fare card.
  /// [turnIndex] identifies which turn holds the fare card.
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
      updatedTurns.add(
          ChatTurn(role: ChatTurnRole.agent, text: result.message));

      state = state.copyWith(turns: updatedTurns, isSending: false);
    } catch (e) {
      state = state.copyWith(isSending: false, errorMessage: e.toString());
    }
  }
}

final chatRepositoryProvider = Provider<ChatRepository>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return ChatRepository(apiClient);
});

final chatProvider =
    NotifierProvider<ChatNotifier, ChatState>(ChatNotifier.new);
