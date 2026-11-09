import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/activity_item.dart';
import '../models/device_snapshot.dart';
import '../models/sensor_reading.dart';

class DeviceRepository {
  DeviceRepository(this.client);

  final SupabaseClient client;

  Future<void> ensureAnonymousSession() async {
    if (client.auth.currentSession == null) {
      await client.auth.signInAnonymously();
    }
  }

  Future<String?> restorePairedDevice() async {
    final userId = client.auth.currentUser?.id;
    if (userId == null) return null;
    final row = await client
        .from('app_device_access')
        .select('device_id')
        .eq('user_id', userId)
        .order('created_at')
        .limit(1)
        .maybeSingle();
    return row?['device_id'] as String?;
  }

  Future<String> pair(String pairingCode) async {
    final response = await client.functions.invoke(
      'pair-device',
      body: {'pairing_code': pairingCode.trim().toUpperCase()},
    );
    final data = response.data as Map<String, dynamic>;
    return data['device_id'] as String;
  }

  Future<DeviceSnapshot?> getStatus(String deviceId) async {
    final row = await client
        .from('device_status')
        .select('mode,servo_position,last_seen_at')
        .eq('device_id', deviceId)
        .maybeSingle();
    return row == null ? null : DeviceSnapshot.fromMap(row);
  }

  Future<SensorReading?> getLatestReading(String deviceId) async {
    final row = await client
        .from('sensor_readings')
        .select('rain_value,light_percent,rain_detected,created_at')
        .eq('device_id', deviceId)
        .order('created_at', ascending: false)
        .limit(1)
        .maybeSingle();
    return row == null ? null : SensorReading.fromMap(row);
  }

  Future<void> sendCommand(
    String deviceId,
    String command, {
    String? mode,
  }) async {
    await client.functions.invoke(
      'send-command',
      body: {'device_id': deviceId, 'command': command, 'mode': ?mode},
    );
  }

  Future<List<ActivityItem>> getActivities(
    String deviceId,
    DateTime day,
  ) async {
    final rows = await client
        .from('activity_history')
        .select('event_type,message,created_at')
        .eq('device_id', deviceId)
        .gte(
          'created_at',
          DateTime(day.year, day.month, day.day).toUtc().toIso8601String(),
        )
        .lt(
          'created_at',
          DateTime(day.year, day.month, day.day + 1).toUtc().toIso8601String(),
        )
        .order('created_at', ascending: false)
        .limit(200);
    return rows.map((row) => ActivityItem.fromMap(row)).toList();
  }

  Future<List<SensorReading>> getReadings(String deviceId, DateTime day) async {
    final rows = await client
        .from('sensor_readings')
        .select('rain_value,light_percent,rain_detected,created_at')
        .eq('device_id', deviceId)
        .gte(
          'created_at',
          DateTime(day.year, day.month, day.day).toUtc().toIso8601String(),
        )
        .lt(
          'created_at',
          DateTime(day.year, day.month, day.day + 1).toUtc().toIso8601String(),
        )
        .order('created_at', ascending: false)
        .limit(200);
    return rows.map((row) => SensorReading.fromMap(row)).toList();
  }
}
