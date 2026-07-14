class WalletTransaction {
  const WalletTransaction({
    required this.id,
    required this.type,
    required this.status,
    required this.amountUgx,
    this.description,
    this.balanceAfterUgx,
    required this.createdAt,
  });

  final String id;
  final String type;   // wallet_topup | ride_payment | driver_credit | ...
  final String status; // pending | completed | failed
  final int amountUgx;
  final String? description;
  final int? balanceAfterUgx;
  final String createdAt;

  factory WalletTransaction.fromJson(Map<String, dynamic> json) =>
      WalletTransaction(
        id: json['id'] as String,
        type: json['type'] as String,
        status: json['status'] as String,
        amountUgx: json['amount_ugx'] as int,
        description: json['description'] as String?,
        balanceAfterUgx: json['balance_after_ugx'] as int?,
        createdAt: json['created_at'] as String,
      );

  bool get isCredit =>
      type == 'wallet_topup' || type == 'driver_credit' || type == 'refund';
}
