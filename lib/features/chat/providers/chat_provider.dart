import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/providers/auth_provider.dart';
import '../data/chat_models.dart';
import '../data/chat_repository.dart';

class ChatState {
  const ChatState({
    this.turns = const [],
    this.isSending = false,
    this.isUploadingPhoto = false,
    this.errorMessage,
    this.completedRideId,
    this.activeDeliveryId,
  });

  final List<ChatTurn> turns;
  final bool isSending;
  final bool isUploadingPhoto;
  final String? errorMessage;
  final String? completedRideId;

  /// Set when a delivery is created - shows the attachment button.
  final String? activeDeliveryId;

  ChatState copyWith({
    List<ChatTurn>? turns,
    bool? isSending,
    bool? isUploadingPhoto,
    String? errorMessage,
    String? completedRideId,
    bool clearCompletedRide = false,
    String? activeDeliveryId,
    bool clearActiveDelivery = false,
  }) {
    return ChatState(
      turns: turns ?? this.turns,
      isSending: isSending ?? this.isSending,
      isUploadingPhoto: isUploadingPhoto ?? this.isUploadingPhoto,
      errorMessage: errorMessage,
      completedRideId: clearCompletedRide ? null : (completedRideId ?? this.completedRideId),
      activeDeliveryId: clearActiveDelivery ? null : (activeDeliveryId ?? this.activeDeliveryId),
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
  String? _lastSeenAdminPhotoUrl;

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
    final greeting =
        hour < 12 ? 'Good morning' : hour < 17 ? 'Good afternoon' : 'Good evening';
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
      turns: [...state.turns, ChatTurn(role: ChatTurnRole.user, text: trimmed)],
      isSending: true,
      errorMessage: null,
    );

    try {
      final response = await _repo.sendMessage(trimmed);

      if (response.rideId != null && response.fareUgx == null) {
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
        state = state.copyWith(
          turns: [...state.turns, ChatTurn(role: ChatTurnRole.agent, text: response.reply)],
          isSending: false,
          activeDeliveryId: response.deliveryId,
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
              fareStatus: response.fareUgx != null ? FareQuoteStatus.pending : null,
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

  // ── Photo upload ──────────────────────────────────────────────────────────

  Future<void> uploadDeliveryPhoto(List<int> bytes, String filename) async {
    final deliveryId = state.activeDeliveryId;
    if (deliveryId == null || state.isUploadingPhoto) return;

    state = state.copyWith(isUploadingPhoto: true, errorMessage: null);
    try {
      final url = await _repo.uploadDeliveryPhoto(deliveryId, bytes, filename);
      state = state.copyWith(
        turns: [
          ...state.turns,
          ChatTurn(
            role: ChatTurnRole.user,
            text: 'Photo attached',
            photoUrl: url,
          ),
        ],
        isUploadingPhoto: false,
      );
    } catch (e) {
      state = state.copyWith(isUploadingPhoto: false, errorMessage: 'Photo upload failed: $e');
    }
  }

  // ── Driver acceptance polling ─────────────────────────────────────────────

  void _startSearchPolling(String rideId, int turnIndex) {
    _searchTimer?.cancel();
    _searchingRideId = rideId;
    _searchingTurnIndex = turnIndex;
    _pollRideStatus();
    _searchTimer = Timer.periodic(const Duration(seconds: 4), (_) => _pollRideStatus());
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
        if (_searchingTurnIndex >= 0 && _searchingTurnIndex < updatedTurns.length) {
          updatedTurns[_searchingTurnIndex] = updatedTurns[_searchingTurnIndex].copyWith(
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
        if (_searchingTurnIndex >= 0 && _searchingTurnIndex < updatedTurns.length) {
          updatedTurns[_searchingTurnIndex] = ChatTurn(
            role: ChatTurnRole.agent,
            text: "Sorry, we couldn't find a driver right now. Please try again.",
          );
        }
        state = state.copyWith(turns: updatedTurns);
      }
    } catch (_) {}
  }

  // ── Delivery polling ──────────────────────────────────────────────────────

  void _startDeliveryPolling(String deliveryId) {
    _deliveryTimer?.cancel();
    _pollingDeliveryId = deliveryId;
    _lastSeenReplyAt = null;
    _lastSeenAdminPhotoUrl = null;
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

      // New text reply from admin
      if (status.hasReply &&
          status.repliedAt != null &&
          status.repliedAt != _lastSeenReplyAt) {
        _lastSeenReplyAt = status.repliedAt;
        state = state.copyWith(
          turns: [
            ...state.turns,
            ChatTurn(role: ChatTurnRole.agent, text: status.adminReply!),
          ],
        );
      }

      // Admin uploaded a photo
      if (status.adminPhotoUrl != null &&
          status.adminPhotoUrl != _lastSeenAdminPhotoUrl) {
        _lastSeenAdminPhotoUrl = status.adminPhotoUrl;
        state = state.copyWith(
          turns: [
            ...state.turns,
            ChatTurn(
              role: ChatTurnRole.agent,
              text: 'Photo from our team:',
              photoUrl: status.adminPhotoUrl,
            ),
          ],
        );
      }

      if (status.isClosed) {
        _deliveryTimer?.cancel();
        _deliveryTimer = null;
        _pollingDeliveryId = null;
        state = state.copyWith(clearActiveDelivery: true);
      }
    } catch (_) {}
  }

  // ── Ride completion polling ───────────────────────────────────────────────

  void _startCompletionPolling(String rideId) {
    _completionTimer?.cancel();
    _completionTimer = Timer.periodic(const Duration(seconds: 15), (_) async {
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
    });
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
        fareStatus: confirmed ? FareQuoteStatus.confirmed : FareQuoteStatus.cancelled,
      );
      updatedTurns.add(ChatTurn(role: ChatTurnRole.agent, text: result.message));
      state = state.copyWith(turns: updatedTurns, isSending: false);
      if (confirmed) _startCompletionPolling(rideId);
    } catch (e) {
      state = state.copyWith(isSending: false, errorMessage: e.toString());
    }
  }

  // ── History ───────────────────────────────────────────────────────────────

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
    _lastSeenAdminPhotoUrl = null;
    state = ChatState(turns: [_buildWelcomeTurn()]);
  }

  void clearCompletedRide() => state = state.copyWith(clearCompletedRide: true);
}

final chatRepositoryProvider = Provider<ChatRepository>((ref) {
  return ChatRepository(ref.watch(apiClientProvider));
});

final chatProvider = NotifierProvider<ChatNotifier, ChatState>(ChatNotifier.new);
