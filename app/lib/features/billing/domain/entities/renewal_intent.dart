class RenewalIntent {
  const RenewalIntent({
    required this.reference,
    required this.tenantCode,
    required this.tenantName,
    required this.plan,
    required this.planLabel,
    required this.extendDays,
    this.currentExpiredAt,
    required this.instructions,
  });

  final String reference;
  final String tenantCode;
  final String tenantName;
  final String plan;
  final String planLabel;
  final int extendDays;
  final String? currentExpiredAt;
  final String instructions;

  factory RenewalIntent.fromJson(Map<String, dynamic> json) {
    return RenewalIntent(
      reference: json['reference']?.toString() ?? '',
      tenantCode: json['tenant_code']?.toString() ?? '',
      tenantName: json['tenant_name']?.toString() ?? '',
      plan: json['plan']?.toString() ?? '',
      planLabel: json['plan_label']?.toString() ?? '',
      extendDays: (json['extend_days'] as num?)?.toInt() ?? 365,
      currentExpiredAt: json['current_expired_at']?.toString(),
      instructions: json['instructions']?.toString() ?? '',
    );
  }
}
