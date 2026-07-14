class ActiveRide {
  const ActiveRide({
    required this.id,
    required this.status,
    required this.pickupName,
    required this.dropoffName,
    required this.estimatedFareUgx,
    this.estimatedDistanceKm,
    this.estimatedDurationMinutes,
    required this.passengerName,
    this.passengerPhone = '',
  });

  final String id;

  /// One of: matched | accepted | driver_arriving | in_progress
  final String status;
  final String pickupName;
  final String dropoffName;
  final int estimatedFareUgx;
  final double? estimatedDistanceKm;
  final double? estimatedDurationMinutes;
  final String passengerName;
  final String passengerPhone;

  factory ActiveRide.fromJson(Map<String, dynamic> json) => ActiveRide(
        id: json['id'] as String,
        status: json['status'] as String,
        pickupName: json['pickup_name'] as String,
        dropoffName: json['dropoff_name'] as String,
        estimatedFareUgx: json['estimated_fare_ugx'] as int,
        estimatedDistanceKm:
            (json['estimated_distance_km'] as num?)?.toDouble(),
        estimatedDurationMinutes:
            (json['estimated_duration_minutes'] as num?)?.toDouble(),
        passengerName: json['passenger_name'] as String? ?? 'Passenger',
        passengerPhone: json['passenger_phone'] as String? ?? '',
      );
}
