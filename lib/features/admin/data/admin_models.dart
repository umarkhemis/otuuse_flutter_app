class DashboardStats {
  const DashboardStats({
    required this.driversOnlineNow,
    required this.totalActiveDrivers,
    required this.activeRidesNow,
    required this.ridesCompletedToday,
    required this.revenueToday,
    required this.pendingDeliveries,
  });

  final int driversOnlineNow;
  final int totalActiveDrivers;
  final int activeRidesNow;
  final int ridesCompletedToday;
  final int revenueToday;
  final int pendingDeliveries;

  factory DashboardStats.fromJson(Map<String, dynamic> json) =>
      DashboardStats(
        driversOnlineNow: json['drivers_online_now'] as int,
        totalActiveDrivers: json['total_active_drivers'] as int,
        activeRidesNow: json['active_rides_now'] as int,
        ridesCompletedToday: json['rides_completed_today'] as int,
        revenueToday: json['revenue_today_ugx'] as int,
        pendingDeliveries: json['pending_delivery_requests'] as int,
      );
}

class DriverListItem {
  const DriverListItem({
    required this.userId,
    required this.name,
    required this.phoneNumber,
    required this.isActive,
    required this.availability,
    required this.rating,
    required this.totalRides,
    required this.subscriptionActive,
    this.subscriptionExpiresAt,
    required this.documentsVerified,
    required this.walletBalanceUgx,
  });

  final String userId;
  final String name;
  final String phoneNumber;
  final bool isActive;
  final String availability; // online | offline | on_ride
  final double rating;
  final int totalRides;
  final bool subscriptionActive;
  final String? subscriptionExpiresAt;
  final bool documentsVerified;
  final int walletBalanceUgx;

  factory DriverListItem.fromJson(Map<String, dynamic> json) =>
      DriverListItem(
        userId: json['user_id'] as String,
        name: json['name'] as String,
        phoneNumber: json['phone_number'] as String,
        isActive: json['is_active'] as bool,
        availability: json['availability'] as String,
        rating: (json['rating'] as num).toDouble(),
        totalRides: json['total_rides'] as int,
        subscriptionActive: json['subscription_active'] as bool,
        subscriptionExpiresAt:
            json['subscription_expires_at'] as String?,
        documentsVerified: json['documents_verified'] as bool,
        walletBalanceUgx: json['wallet_balance_ugx'] as int,
      );
}

class RecentRide {
  const RecentRide({
    required this.id,
    required this.pickupName,
    required this.dropoffName,
    required this.status,
    required this.estimatedFareUgx,
    this.finalFareUgx,
    required this.requestedAt,
  });

  final String id;
  final String pickupName;
  final String dropoffName;
  final String status;
  final int estimatedFareUgx;
  final int? finalFareUgx;
  final String requestedAt;

  factory RecentRide.fromJson(Map<String, dynamic> json) => RecentRide(
        id: json['id'] as String,
        pickupName: json['pickup_name'] as String,
        dropoffName: json['dropoff_name'] as String,
        status: json['status'] as String,
        estimatedFareUgx: json['estimated_fare_ugx'] as int,
        finalFareUgx: json['final_fare_ugx'] as int?,
        requestedAt: json['requested_at'] as String,
      );
}

/// Returned by the onboard endpoint.
class OnboardResult {
  const OnboardResult({
    required this.driverId,
    required this.phoneNumber,
    required this.inviteCode,
    required this.message,
  });

  final String driverId;
  final String phoneNumber;
  final String inviteCode;
  final String message;

  factory OnboardResult.fromJson(Map<String, dynamic> json) =>
      OnboardResult(
        driverId: json['driver_id'] as String,
        phoneNumber: json['phone_number'] as String,
        inviteCode: json['invite_code'] as String,
        message: json['message'] as String,
      );
}
