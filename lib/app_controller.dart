import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'data/device_repository.dart';
import 'models/activity_item.dart';
import 'models/device_snapshot.dart';
import 'models/sensor_reading.dart';

class AppController extends ChangeNotifier {
  AppController(this.repository);

  final DeviceRepository repository;
  String? deviceId;
  DeviceSnapshot? status;
  SensorReading? latestReading;
  bool isLoading = true;
  bool isSendingCommand = false;
  bool isRealtimeConnected = false;
  String? pendingMode;
  String? pendingAction;
  String? errorMessage;
  RealtimeChannel? _channel;
  Timer? _onlineTimer;
  Timer? _statusFallbackTimer;
  Timer? _refreshDebounce;
  bool _refreshing = false;
  bool _refreshAgain = false;
  int _realtimeRevision = 0;
  String? _pendingActionType;
  DateTime? _statusBeforeCommand;

  Future<void> initialize() async {
    try {
      await repository.ensureAnonymousSession();
      deviceId = await repository.restorePairedDevice();
      if (deviceId != null) await connectToDevice(deviceId!, updateId: false);
    } catch (error) {
      errorMessage = _friendlyError(error);
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> pair(String code) async {
    errorMessage = null;
    isLoading = true;
    notifyListeners();
    try {
      await repository.ensureAnonymousSession();
      final id = await repository.pair(code);
      await connectToDevice(id);
    } catch (error) {
      errorMessage = _friendlyError(error);
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> connectToDevice(String id, {bool updateId = true}) async {
    if (updateId && deviceId != id) {
      deviceId = id;
      isRealtimeConnected = false;
      _clearPendingCommand();
      _refreshDebounce?.cancel();
    }
    await _channel?.unsubscribe();
    await refresh();
    _channel = Supabase.instance.client.channel('device-$id');
    // Hanya tabel yang mengubah dashboard. Perubahan riwayat tidak perlu
    // memicu dua query tambahan setiap kali ada aktivitas.
    for (final table in ['device_status', 'sensor_readings']) {
      _channel!.onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: table,
        filter: PostgresChangeFilter(
          type: PostgresChangeFilterType.eq,
          column: 'device_id',
          value: id,
        ),
        callback: (payload) {
          _realtimeRevision++;
          final record = payload.newRecord;
          if (record.isEmpty) {
            _scheduleRefresh();
            return;
          }

          // Gunakan baris yang dikirim Realtime langsung, tanpa menunggu dua
          // query tambahan untuk menampilkan posisi dan pembacaan terbaru.
          if (table == 'device_status') {
            status = DeviceSnapshot.fromMap(record);
          } else if (table == 'sensor_readings') {
            latestReading = SensorReading.fromMap(record);
          }
          errorMessage = null;
          _resolvePendingCommand();
          notifyListeners();
        },
      );
    }
    _channel!.subscribe((state, _) {
      isRealtimeConnected = state == RealtimeSubscribeStatus.subscribed;
      notifyListeners();
      if (isRealtimeConnected) unawaited(refresh());
    });
    _onlineTimer?.cancel();
    _onlineTimer = Timer.periodic(
      const Duration(seconds: 5),
      (_) => notifyListeners(),
    );
    // Refresh cadangan agar badge tetap benar jika socket Realtime terputus.
    _statusFallbackTimer?.cancel();
    _statusFallbackTimer = Timer.periodic(
      const Duration(seconds: 15),
      (_) => unawaited(refresh()),
    );
  }

  void _scheduleRefresh() {
    _refreshDebounce?.cancel();
    _refreshDebounce = Timer(const Duration(milliseconds: 120), refresh);
  }

  Future<void> refresh() async {
    final id = deviceId;
    if (id == null) return;
    if (_refreshing) {
      _refreshAgain = true;
      return;
    }

    _refreshing = true;
    try {
      do {
        _refreshAgain = false;
        final requestDeviceId = deviceId;
        if (requestDeviceId == null) break;
        final revisionAtRequest = _realtimeRevision;
        try {
          final results = await Future.wait([
            repository.getStatus(requestDeviceId),
            repository.getLatestReading(requestDeviceId),
          ]);
          // Jangan menimpa dashboard perangkat baru dengan respons lama.
          if (requestDeviceId != deviceId) continue;
          // Jika payload realtime tiba saat query berjalan, ulangi query agar
          // respons yang lebih lama tidak mengganti status yang baru diterima.
          if (revisionAtRequest != _realtimeRevision) {
            _refreshAgain = true;
            continue;
          }
          status = results[0] as DeviceSnapshot?;
          latestReading = results[1] as SensorReading?;
          errorMessage = null;
          _resolvePendingCommand();
        } catch (error) {
          errorMessage = _friendlyError(error);
        }
      } while (_refreshAgain);
    } finally {
      _refreshing = false;
      notifyListeners();
    }
  }

  void _resolvePendingCommand() {
    final action = pendingAction;
    final deviceStatus = status;
    if (action == null || deviceStatus == null) return;
    final seenAt = deviceStatus.lastSeenAt;
    final isFreshStatus =
        seenAt != null &&
        (_statusBeforeCommand == null || seenAt.isAfter(_statusBeforeCommand!));
    if (!isFreshStatus) return;

    final actionType = _pendingActionType;
    if (actionType == 'open' && (latestReading?.rainDetected ?? false)) {
      errorMessage =
          'Perintah buka tidak dijalankan karena sensor mendeteksi hujan.';
      _clearPendingCommand();
      return;
    }
    final confirmed = switch (actionType) {
      'set_mode' => deviceStatus.mode == action,
      'open' => deviceStatus.position == 'open',
      'close' => deviceStatus.position == 'closed',
      _ => false,
    };
    if (confirmed) _clearPendingCommand();
  }

  void _clearPendingCommand() {
    pendingAction = null;
    pendingMode = null;
    _pendingActionType = null;
    _statusBeforeCommand = null;
  }

  String? get pendingMessage {
    final action = pendingAction;
    if (action == null) return null;
    if (isSendingCommand) return 'Mengirim perintah…';
    if (!isOnline) return 'Perintah tersimpan, menunggu perangkat online.';
    final label = switch (action) {
      'open' => 'Buka jemuran',
      'close' => 'Tutup jemuran',
      'manual' => 'Mode manual',
      'automatic' => 'Mode otomatis',
      _ => 'Perintah',
    };
    return '$label dikirim, menunggu konfirmasi ESP8266…';
  }

  Future<void> command(String command, {String? mode}) async {
    final id = deviceId;
    if (id == null || isSendingCommand) return;
    isSendingCommand = true;
    _statusBeforeCommand = status?.lastSeenAt;
    _pendingActionType = command;
    pendingAction = command == 'set_mode' ? mode : command;
    if (command == 'set_mode') pendingMode = mode;
    errorMessage = null;
    notifyListeners();
    try {
      await repository.sendCommand(id, command, mode: mode);
    } catch (error) {
      errorMessage = _friendlyError(error);
      _clearPendingCommand();
    } finally {
      isSendingCommand = false;
      notifyListeners();
    }
  }

  Future<List<ActivityItem>> loadActivities(DateTime day) async {
    if (deviceId == null) return [];
    return repository.getActivities(deviceId!, day);
  }

  Future<List<SensorReading>> loadReadings(DateTime day) async {
    if (deviceId == null) return [];
    return repository.getReadings(deviceId!, day);
  }

  bool get isOnline => status?.isOnlineAt(DateTime.now()) ?? false;

  static String _friendlyError(Object error) {
    if (error is FunctionException) {
      final details = error.details;
      if (details is Map && details['error'] is String) {
        return details['error'] as String;
      }
    }
    return error.toString().replaceFirst('Exception: ', '');
  }

  @override
  void dispose() {
    _onlineTimer?.cancel();
    _statusFallbackTimer?.cancel();
    _refreshDebounce?.cancel();
    if (_channel != null) Supabase.instance.client.removeChannel(_channel!);
    super.dispose();
  }
}
