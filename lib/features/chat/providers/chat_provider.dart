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
    return ChatState(turns: [_buildWelcomeTurn()]);
  }

  /// Builds a time-aware, personalised welcome message.
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
    final text =
        '$greeting$nameClause! 👋 Where would you like to go today, '
        'or what would you like delivered?';

    return ChatTurn(role: ChatTurnRole.agent, text: text);
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
        // Driver-first flow: ride dispatched, waiting for driver to accept.
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
        state = state.copyWith(
          turns: [
            ...state.turns,
            ChatTurn(
              role: ChatTurnRole.agent,
              text: response.reply,
              fareUgx: response.fareUgx,
              fareStatus:
                  response.fareUgx != null ? FareQuoteStatus.pending : null,
              driverName:  response.driverName,
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

        final updatedTurns = List<ChatTurn>.from(state.turns);
        if (_searchingTurnIndex >= 0 &&
            _searchingTurnIndex < updatedTurns.length) {
          updatedTurns[_searchingTurnIndex] =
              updatedTurns[_searchingTurnIndex].copyWith(
            isSearching: false,
            fareUgx:     status.fareUgx,
            fareStatus:  FareQuoteStatus.pending,
            driverName:  status.driverName,
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
                "Sorry, we couldn't find a driver right now. Please try again in a few minutes.",
          );
        }
        state = state.copyWith(turns: updatedTurns);
      }
    } catch (_) {
      // Silent - don't disrupt the passenger's view.
    }
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
    } catch (e) {
      state = state.copyWith(isSending: false, errorMessage: e.toString());
    }
  }

  // ── Chat history ──────────────────────────────────────────────────────────

  /// Clears all messages and resets to the personalised welcome greeting.
  void clearHistory() {
    _searchTimer?.cancel();
    _searchTimer = null;
    _searchingRideId = null;
    _searchingTurnIndex = -1;
    state = ChatState(turns: [_buildWelcomeTurn()]);
  }
}

final chatRepositoryProvider = Provider<ChatRepository>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return ChatRepository(apiClient);
});

final chatProvider =
    NotifierProvider<ChatNotifier, ChatState>(ChatNotifier.new);
