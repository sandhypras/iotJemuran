class ActivityItem {
  const ActivityItem({
    required this.eventType,
    required this.message,
    required this.createdAt,
  });

  final String eventType;
  final String message;
  final DateTime createdAt;

  factory ActivityItem.fromMap(Map<String, dynamic> map) => ActivityItem(
    eventType: map['event_type'] as String? ?? 'activity',
    message: map['message'] as String? ?? 'Aktivitas perangkat',
    createdAt:
        DateTime.tryParse(map['created_at'] as String? ?? '')?.toLocal() ??
        DateTime.now(),
  );
}
