class SensorReading {
  const SensorReading({
    required this.rainValue,
    required this.lightPercent,
    required this.rainDetected,
    required this.createdAt,
  });

  final int rainValue;
  final double lightPercent;
  final bool rainDetected;
  final DateTime createdAt;

  factory SensorReading.fromMap(Map<String, dynamic> map) => SensorReading(
    rainValue: (map['rain_value'] as num?)?.toInt() ?? 0,
    lightPercent: (map['light_percent'] as num?)?.toDouble() ?? 0,
    rainDetected: map['rain_detected'] as bool? ?? false,
    createdAt:
        DateTime.tryParse(map['created_at'] as String? ?? '')?.toLocal() ??
        DateTime.now(),
  );
}
