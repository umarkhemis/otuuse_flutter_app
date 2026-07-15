/// Mirrors the backend's ChatResponse.
class ChatApiResponse {
  ChatApiResponse({
    required this.reply,
    required this.intent,
    this.rideId,
    this.deliveryId,
    this.fareUgx,
    this.driverName,
    this.driverPhone,
    this.driverPlate,
  });

  final String reply;
  final String intent;
  final String? rideId;
  final String? deliveryId;
  final int? fareUgx;
  final String? driverName;
  final String? driverPhone;
  final String? driverPlate;

  factory ChatApiResponse.fromJson(Map<String, dynamic> json) {
    return ChatApiResponse(
      reply: json['reply'] as String,
      intent: json['intent'] as String,
      rideId: json['ride_id'] as String?,
      deliveryId: json['delivery_id'] as String?,
      fareUgx: json['fare_ugx'] as int?,
      driverName: json['driver_name'] as String?,
      driverPhone: json['driver_phone'] as String?,
      driverPlate: json['driver_plate'] as String?,
    );
  }
}

/// Returned by GET /chat/ride-status/{ride_id}.
class RideStatusResponse {
  const RideStatusResponse({
    required this.status,
    this.fareUgx,
    this.distanceKm,
    this.driverName,
    this.driverPhone,
    this.driverPlate,
  });

  final String status;
  final int? fareUgx;
  final double? distanceKm;
  final String? driverName;
  final String? driverPhone;
  final String? driverPlate;

  bool get isAccepted =>
      status == 'accepted' ||
      status == 'driver_arriving' ||
      status == 'in_progress';
  bool get isCancelled => status == 'cancelled';
  bool get isCompleted => status == 'completed' || status == 'paid';

  factory RideStatusResponse.fromJson(Map<String, dynamic> json) =>
      RideStatusResponse(
        status: json['status'] as String,
        fareUgx: json['fare_ugx'] as int?,
        distanceKm: (json['distance_km'] as num?)?.toDouble(),
        driverName: json['driver_name'] as String?,
        driverPhone: json['driver_phone'] as String?,
        driverPlate: json['driver_plate'] as String?,
      );
}

/// Returned by GET /chat/delivery-status/{delivery_id}.
/// Passenger polls this to receive admin replies.
class DeliveryStatusResponse {
  const DeliveryStatusResponse({
    required this.status,
    this.adminReply,
    this.repliedAt,
  });

  final String status;

  /// The latest admin relay message, if any.
  final String? adminReply;

  /// ISO timestamp of the latest reply - used to detect new replies.
  final String? repliedAt;

  bool get hasReply => adminReply != null;
  bool get isClosed => status == 'completed' || status == 'cancelled';

  factory DeliveryStatusResponse.fromJson(Map<String, dynamic> json) =>
      DeliveryStatusResponse(
        status: json['status'] as String,
        adminReply: json['admin_reply'] as String?,
        repliedAt: json['replied_at'] as String?,
      );
}

/// Result of POST /chat/confirm-ride.
class ConfirmRideResult {
  ConfirmRideResult({this.rideId, required this.message});
  final String? rideId;
  final String message;
}

enum ChatTurnRole { user, agent }

enum FareQuoteStatus { pending, confirmed, cancelled }

class ChatTurn {
  const ChatTurn({
    required this.role,
    required this.text,
    this.isSearching = false,
    this.pendingRideId,
    this.fareUgx,
    this.fareStatus,
    this.driverName,
    this.driverPhone,
    this.driverPlate,
  });

  final ChatTurnRole role;
  final String text;
  final bool isSearching;
  final String? pendingRideId;
  final int? fareUgx;
  final FareQuoteStatus? fareStatus;
  final String? driverName;
  final String? driverPhone;
  final String? driverPlate;

  ChatTurn copyWith({
    bool? isSearching,
    String? pendingRideId,
    int? fareUgx,
    FareQuoteStatus? fareStatus,
    String? driverName,
    String? driverPhone,
    String? driverPlate,
  }) {
    return ChatTurn(
      role: role,
      text: text,
      isSearching: isSearching ?? this.isSearching,
      pendingRideId: pendingRideId ?? this.pendingRideId,
      fareUgx: fareUgx ?? this.fareUgx,
      fareStatus: fareStatus ?? this.fareStatus,
      driverName: driverName ?? this.driverName,
      driverPhone: driverPhone ?? this.driverPhone,
      driverPlate: driverPlate ?? this.driverPlate,
    );
  }
}
