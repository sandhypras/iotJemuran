class DeviceSnapshot {
  const DeviceSnapshot({
    this.mode = 'automatic',
    this.position = 'closed',
    this.lastSeenAt,
  });

  final String mode;
  final String position;
  final DateTime? lastSeenAt;

  bool isOnlineAt(DateTime now) =>
      lastSeenAt != null && now.difference(lastSeenAt!).inSeconds < 45;

  factory DeviceSnapshot.fromMap(Map<String, dynamic> map) => DeviceSnapshot(
    mode: map['mode'] as String? ?? 'automatic',
    position: map['servo_position'] as String? ?? 'closed',
    lastSeenAt: DateTime.tryParse(
      map['last_seen_at'] as String? ?? '',
    )?.toLocal(),
  );
}
