class BillingPlan {
  const BillingPlan({
    required this.id,
    required this.label,
    required this.description,
    this.maxBranches,
    this.days,
  });

  final String id;
  final String label;
  final String description;
  final int? maxBranches;
  final int? days;

  factory BillingPlan.fromJson(Map<String, dynamic> json) {
    return BillingPlan(
      id: json['id']?.toString() ?? '',
      label: json['label']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      maxBranches: (json['max_branches'] as num?)?.toInt(),
      days: (json['days'] as num?)?.toInt(),
    );
  }
}
