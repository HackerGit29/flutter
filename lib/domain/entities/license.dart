class License {
  final String id;
  final String subscriptionId;
  final DateTime activationDate;
  final DateTime? expirationDate;
  final String licenseKey;

  const License({
    required this.id, required this.subscriptionId,
    required this.activationDate, this.expirationDate, required this.licenseKey,
  });

  bool get isValid {
    final now = DateTime.now();
    return now.isAfter(activationDate) && (expirationDate == null || now.isBefore(expirationDate!));
  }

  factory License.fromJson(Map<String, dynamic> json) => License(
    id: json['id'] as String,
    subscriptionId: json['subscription_id'] as String,
    activationDate: DateTime.parse(json['activation_date'] as String),
    expirationDate: json['expiration_date'] != null ? DateTime.parse(json['expiration_date'] as String) : null,
    licenseKey: json['license_key'] as String,
  );
}
