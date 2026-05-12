class EMReport {
  final int id;
  final int? userId;
  final DateTime createdAt;
  final double locationLat;
  final double locationLng;
  final bool takenCare;
  final int? incidentId;

  EMReport({
    required this.id,
    this.userId,
    required this.createdAt,
    required this.locationLat,
    required this.locationLng,
    required this.takenCare,
    this.incidentId,
  });

  factory EMReport.fromJson(Map<String, dynamic> json) {
    return EMReport(
      id: json['id'] as int,
      userId: json['user_id'] as int?,
      createdAt: DateTime.parse(json['created_at'] as String),
      locationLat: (json['location_lat'] as num).toDouble(),
      locationLng: (json['location_lng'] as num).toDouble(),
      takenCare: json['taken_care'] as bool? ?? false,
      incidentId: json['incident_id'] as int?,
    );
  }
}
