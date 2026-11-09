import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../app_controller.dart';
import '../core/app_theme.dart';
import '../models/device_snapshot.dart';

class LiveDashboardScreen extends StatelessWidget {
  const LiveDashboardScreen({required this.controller, super.key});

  final AppController controller;

  @override
  Widget build(BuildContext context) {
    final reading = controller.latestReading;
    final status = controller.status;
    final isOnline = controller.isOnline;
    final isManual = (controller.pendingMode ?? status?.mode) == 'manual';

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          color: AppTheme.blue,
          onRefresh: controller.refresh,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final width = math.min(constraints.maxWidth, 760.0).toDouble();
              final side = width < 400 ? 18.0 : 28.0;
              return Center(
                child: SizedBox(
                  width: width,
                  height: constraints.maxHeight,
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(
                      parent: BouncingScrollPhysics(),
                    ),
                    padding: EdgeInsets.fromLTRB(side, 18, side, 30),
                    children: [
                      _DashboardHeader(
                        online: isOnline,
                        realtimeConnected: controller.isRealtimeConnected,
                      ),
                      const SizedBox(height: 20),
                      _ClotheslineHero(
                        status: status,
                        rain: reading?.rainDetected ?? false,
                        online: isOnline,
                        realtimeConnected: controller.isRealtimeConnected,
                        pendingAction: controller.pendingAction,
                      ),
                      if (!isOnline || !controller.isRealtimeConnected) ...[
                        const SizedBox(height: 12),
                        _ConnectionNotice(
                          online: isOnline,
                          realtimeConnected: controller.isRealtimeConnected,
                          lastSeenAt: status?.lastSeenAt,
                          onRefresh: controller.refresh,
                        ),
                      ],
                      if (controller.errorMessage != null) ...[
                        const SizedBox(height: 12),
                        _ErrorNotice(message: controller.errorMessage!),
                      ],
                      const SizedBox(height: 25),
                      const _SectionHeading(
                        eyebrow: 'PEMANTAUAN',
                        title: 'Kondisi sensor',
                      ),
                      const SizedBox(height: 12),
                      LayoutBuilder(
                        builder: (context, cardConstraints) {
                          final rainCard = _SensorCard(
                            icon: Icons.water_drop_rounded,
                            title: 'Sensor hujan',
                            value: reading == null
                                ? '—'
                                : reading.rainDetected
                                ? 'Basah'
                                : 'Kering',
                            detail: reading == null
                                ? 'Menunggu data dari ESP8266'
                                : 'Digital · DO aktif LOW',
                            accent: reading?.rainDetected == true
                                ? AppTheme.red
                                : AppTheme.blue,
                            background: const Color(0xFFE8F3F8),
                          );
                          final lightCard = _SensorCard(
                            icon: Icons.wb_sunny_rounded,
                            title: 'Cahaya',
                            value: reading == null
                                ? '—'
                                : reading.lightPercent >= 50
                                ? 'Terang'
                                : 'Redup',
                            detail: reading == null
                                ? 'Menunggu data dari ESP8266'
                                : 'LDR digital · DO',
                            accent: AppTheme.amber,
                            background: const Color(0xFFFFF4DF),
                          );
                          if (cardConstraints.maxWidth < 330) {
                            return Column(
                              children: [
                                rainCard,
                                const SizedBox(height: 10),
                                lightCard,
                              ],
                            );
                          }
                          return Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(child: rainCard),
                              const SizedBox(width: 12),
                              Expanded(child: lightCard),
                            ],
                          );
                        },
                      ),
                      const SizedBox(height: 25),
                      const _SectionHeading(
                        eyebrow: 'PENGENDALIAN',
                        title: 'Atur jemuran',
                      ),
                      const SizedBox(height: 12),
                      _ControlCard(
                        controller: controller,
                        isManual: isManual,
                        rain: reading?.rainDetected ?? false,
                      ),
                      const SizedBox(height: 14),
                      const _LocalSafetyNote(),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _DashboardHeader extends StatelessWidget {
  const _DashboardHeader({
    required this.online,
    required this.realtimeConnected,
  });

  final bool online;
  final bool realtimeConnected;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Container(
        width: 46,
        height: 46,
        decoration: BoxDecoration(
          color: AppTheme.navy,
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Icon(
          Icons.local_laundry_service_rounded,
          color: Colors.white,
          size: 24,
        ),
      ),
      const SizedBox(width: 12),
      const Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'SMART HOME',
              style: TextStyle(
                color: AppTheme.muted,
                fontSize: 10,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.5,
              ),
            ),
            SizedBox(height: 2),
            Text(
              'Smart Clothesline',
              style: TextStyle(
                color: AppTheme.ink,
                fontSize: 18,
                fontWeight: FontWeight.w800,
                letterSpacing: -.35,
              ),
            ),
          ],
        ),
      ),
      _ConnectionPill(online: online, compact: true),
    ],
  );
}

class _ClotheslineHero extends StatelessWidget {
  const _ClotheslineHero({
    required this.status,
    required this.rain,
    required this.online,
    required this.realtimeConnected,
    required this.pendingAction,
  });

  final DeviceSnapshot? status;
  final bool rain;
  final bool online;
  final bool realtimeConnected;
  final String? pendingAction;

  @override
  Widget build(BuildContext context) {
    final hasMotionCommand =
        pendingAction == 'open' || pendingAction == 'close';
    final isMoving = hasMotionCommand && online;
    final isOpen = isMoving
        ? pendingAction == 'open'
        : status?.position == 'open';
    final position = hasMotionCommand && !online
        ? 'Menunggu…'
        : isMoving
        ? pendingAction == 'open'
              ? 'Membuka…'
              : 'Menutup…'
        : status == null
        ? 'Menunggu data'
        : status!.position == 'open'
        ? 'Terbuka'
        : 'Tertutup';

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF102D45), Color(0xFF1B5367)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: AppTheme.navy.withValues(alpha: .18),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            top: -70,
            right: -32,
            child: Container(
              width: 210,
              height: 210,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white.withValues(alpha: .08)),
              ),
            ),
          ),
          Positioned(
            top: -25,
            right: 12,
            child: Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: .035),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(21, 20, 21, 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    _ConnectionPill(online: online),
                    const Spacer(),
                    _LiveIndicator(connected: realtimeConnected),
                  ],
                ),
                const SizedBox(height: 24),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'POSISI JEMURAN',
                            style: TextStyle(
                              color: Color(0xFFB8D2D8),
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.7,
                            ),
                          ),
                          const SizedBox(height: 6),
                          AnimatedSwitcher(
                            duration: const Duration(milliseconds: 260),
                            child: Text(
                              position,
                              key: ValueKey(position),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 34,
                                height: 1.05,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -1.1,
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            hasMotionCommand && !online
                                ? 'Perintah tersimpan · menunggu perangkat online'
                                : isMoving
                                ? 'Perintah dikirim · menunggu respons perangkat'
                                : status == null
                                ? 'Belum ada status dari perangkat'
                                : rain
                                ? 'Hujan terdeteksi · jemuran terlindungi'
                                : 'Kondisi aman untuk menjemur',
                            style: const TextStyle(
                              color: Color(0xFFD4E6E8),
                              fontSize: 12,
                              height: 1.35,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    _PositionIllustration(isOpen: isOpen),
                  ],
                ),
                const SizedBox(height: 20),
                Container(
                  height: 1,
                  color: Colors.white.withValues(alpha: .13),
                ),
                const SizedBox(height: 13),
                Row(
                  children: [
                    Icon(
                      rain ? Icons.umbrella_rounded : Icons.wb_sunny_rounded,
                      color: rain
                          ? const Color(0xFFFFC5A7)
                          : const Color(0xFFFFD784),
                      size: 16,
                    ),
                    const SizedBox(width: 7),
                    Expanded(
                      child: Text(
                        rain ? 'Sensor hujan: basah' : 'Sensor hujan: kering',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    Text(
                      status?.lastSeenAt == null
                          ? 'Belum ada heartbeat'
                          : 'Data ${_relativeTime(status!.lastSeenAt!)}',
                      style: const TextStyle(
                        color: Color(0xFFB8D2D8),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PositionIllustration extends StatelessWidget {
  const _PositionIllustration({required this.isOpen});

  final bool isOpen;

  @override
  Widget build(BuildContext context) => AnimatedContainer(
    duration: const Duration(milliseconds: 320),
    width: 82,
    height: 82,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: Colors.white.withValues(alpha: .11),
      border: Border.all(color: Colors.white.withValues(alpha: .16)),
    ),
    child: Icon(
      isOpen ? Icons.dry_cleaning_rounded : Icons.roofing_rounded,
      color: const Color(0xFFE3F4F4),
      size: 40,
    ),
  );
}

class _ConnectionPill extends StatelessWidget {
  const _ConnectionPill({required this.online, this.compact = false});

  final bool online;
  final bool compact;

  @override
  Widget build(BuildContext context) => Container(
    padding: EdgeInsets.symmetric(
      horizontal: compact ? 10 : 11,
      vertical: compact ? 7 : 8,
    ),
    decoration: BoxDecoration(
      color: online
          ? const Color(0xFF1D806E).withValues(alpha: .22)
          : const Color(0xFFB94F4D).withValues(alpha: .25),
      border: Border.all(
        color: online
            ? const Color(0xFF8FD7C2).withValues(alpha: .4)
            : const Color(0xFFFFB8A7).withValues(alpha: .45),
      ),
      borderRadius: BorderRadius.circular(30),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          online ? Icons.wifi_rounded : Icons.wifi_off_rounded,
          color: online ? const Color(0xFFB3F0D8) : const Color(0xFFFFC3B5),
          size: compact ? 14 : 15,
        ),
        const SizedBox(width: 6),
        Text(
          online ? 'ONLINE' : 'OFFLINE',
          style: TextStyle(
            color: online ? const Color(0xFFD3F5E8) : const Color(0xFFFFD4CA),
            fontSize: compact ? 10 : 11,
            fontWeight: FontWeight.w800,
            letterSpacing: .7,
          ),
        ),
      ],
    ),
  );
}

class _LiveIndicator extends StatelessWidget {
  const _LiveIndicator({required this.connected});

  final bool connected;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(
        connected ? Icons.bolt_rounded : Icons.sync_rounded,
        size: 14,
        color: connected ? const Color(0xFF9EE7CE) : const Color(0xFFFFD784),
      ),
      const SizedBox(width: 4),
      Text(
        connected ? 'LIVE' : 'MENYAMBUNG',
        style: TextStyle(
          color: connected ? const Color(0xFFC8F2E4) : const Color(0xFFFFE4B4),
          fontSize: 9,
          fontWeight: FontWeight.w800,
          letterSpacing: 1,
        ),
      ),
    ],
  );
}

class _ConnectionNotice extends StatelessWidget {
  const _ConnectionNotice({
    required this.online,
    required this.realtimeConnected,
    required this.lastSeenAt,
    required this.onRefresh,
  });

  final bool online;
  final bool realtimeConnected;
  final DateTime? lastSeenAt;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    final deviceOffline = !online;
    final color = deviceOffline ? AppTheme.amber : AppTheme.blue;
    final title = deviceOffline
        ? 'Heartbeat perangkat terlambat'
        : 'Koneksi realtime sedang pulih';
    final description = deviceOffline
        ? lastSeenAt == null
              ? 'Belum ada data heartbeat untuk perangkat ini. Periksa kode pairing dan koneksi ESP8266.'
              : 'Data terakhir ${_relativeTime(lastSeenAt!)}. ESP seharusnya mengirim status setiap 15 detik.'
        : realtimeConnected
        ? 'ESP8266 online. Pembaruan langsung aktif.'
        : 'Status diperiksa berkala sampai sambungan realtime pulih.';

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 13, 8, 13),
      decoration: BoxDecoration(
        color: deviceOffline ? const Color(0xFFFFF7E9) : AppTheme.paleBlue,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: .2)),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color.withValues(alpha: .12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              deviceOffline ? Icons.wifi_tethering_error_rounded : Icons.sync,
              color: color,
              size: 19,
            ),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: AppTheme.ink,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  description,
                  style: const TextStyle(
                    color: AppTheme.muted,
                    fontSize: 11,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Periksa status sekarang',
            onPressed: onRefresh,
            icon: Icon(Icons.refresh_rounded, color: color),
          ),
        ],
      ),
    );
  }
}

class _SectionHeading extends StatelessWidget {
  const _SectionHeading({required this.eyebrow, required this.title});

  final String eyebrow;
  final String title;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        eyebrow,
        style: const TextStyle(
          color: AppTheme.blue,
          fontSize: 9,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.5,
        ),
      ),
      const SizedBox(height: 3),
      Text(
        title,
        style: const TextStyle(
          color: AppTheme.ink,
          fontSize: 19,
          fontWeight: FontWeight.w800,
          letterSpacing: -.45,
        ),
      ),
    ],
  );
}

class _SensorCard extends StatelessWidget {
  const _SensorCard({
    required this.icon,
    required this.title,
    required this.value,
    required this.detail,
    required this.accent,
    required this.background,
  });

  final IconData icon;
  final String title;
  final String value;
  final String detail;
  final Color accent;
  final Color background;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(23),
      border: Border.all(color: AppTheme.line.withValues(alpha: .75)),
      boxShadow: [
        BoxShadow(
          color: AppTheme.navy.withValues(alpha: .035),
          blurRadius: 14,
          offset: const Offset(0, 6),
        ),
      ],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: background,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: accent, size: 19),
            ),
            const SizedBox(width: 9),
            Expanded(
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppTheme.muted,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            Container(
              width: 7,
              height: 7,
              decoration: BoxDecoration(color: accent, shape: BoxShape.circle),
            ),
          ],
        ),
        const SizedBox(height: 15),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: AppTheme.ink,
            fontSize: 27,
            height: 1.05,
            fontWeight: FontWeight.w800,
            letterSpacing: -.75,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          detail,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(color: AppTheme.muted, fontSize: 10.5),
        ),
      ],
    ),
  );
}

class _ControlCard extends StatelessWidget {
  const _ControlCard({
    required this.controller,
    required this.isManual,
    required this.rain,
  });

  final AppController controller;
  final bool isManual;
  final bool rain;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(17),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(25),
      border: Border.all(color: AppTheme.line.withValues(alpha: .75)),
      boxShadow: [
        BoxShadow(
          color: AppTheme.navy.withValues(alpha: .035),
          blurRadius: 14,
          offset: const Offset(0, 6),
        ),
      ],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'Mode pengendalian',
                style: TextStyle(
                  color: AppTheme.ink,
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            _ModeTag(isManual: isManual),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          isManual
              ? 'Kontrol langsung melalui aplikasi.'
              : 'ESP8266 mengikuti kondisi sensor secara otomatis.',
          style: const TextStyle(color: AppTheme.muted, fontSize: 11.5),
        ),
        const SizedBox(height: 15),
        SizedBox(
          width: double.infinity,
          child: SegmentedButton<String>(
            segments: const [
              ButtonSegment(
                value: 'automatic',
                icon: Icon(Icons.auto_awesome_rounded, size: 17),
                label: Text('Otomatis'),
              ),
              ButtonSegment(
                value: 'manual',
                icon: Icon(Icons.touch_app_rounded, size: 17),
                label: Text('Manual'),
              ),
            ],
            selected: {isManual ? 'manual' : 'automatic'},
            onSelectionChanged: controller.isSendingCommand
                ? null
                : (value) => controller.command('set_mode', mode: value.first),
            showSelectedIcon: false,
          ),
        ),
        if (isManual) ...[
          const SizedBox(height: 14),
          LayoutBuilder(
            builder: (context, constraints) {
              final openButton = OutlinedButton.icon(
                onPressed: controller.isSendingCommand || rain
                    ? null
                    : () => controller.command('open'),
                icon: const Icon(Icons.open_in_full_rounded, size: 18),
                label: const Text('Buka jemuran'),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(49),
                  foregroundColor: AppTheme.blue,
                  side: const BorderSide(color: AppTheme.line),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                ),
              );
              final closeButton = FilledButton.icon(
                onPressed: controller.isSendingCommand
                    ? null
                    : () => controller.command('close'),
                icon: const Icon(Icons.close_fullscreen_rounded, size: 18),
                label: const Text('Tutup jemuran'),
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(49),
                  backgroundColor: AppTheme.navy,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                ),
              );

              if (constraints.maxWidth < 330) {
                return Column(
                  children: [
                    SizedBox(width: double.infinity, child: openButton),
                    const SizedBox(height: 9),
                    SizedBox(width: double.infinity, child: closeButton),
                  ],
                );
              }
              return Row(
                children: [
                  Expanded(child: openButton),
                  const SizedBox(width: 10),
                  Expanded(child: closeButton),
                ],
              );
            },
          ),
          if (rain) ...[
            const SizedBox(height: 10),
            const Row(
              children: [
                Icon(Icons.shield_rounded, size: 16, color: AppTheme.red),
                SizedBox(width: 7),
                Expanded(
                  child: Text(
                    'Buka terkunci karena sensor mendeteksi hujan.',
                    style: TextStyle(color: AppTheme.red, fontSize: 11),
                  ),
                ),
              ],
            ),
          ],
        ],
        if (controller.pendingMessage != null) ...[
          const SizedBox(height: 13),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 180),
            child: Container(
              key: ValueKey(controller.pendingMessage),
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: AppTheme.paleBlue,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.sync_rounded,
                    color: AppTheme.blue,
                    size: 17,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      controller.pendingMessage!,
                      style: const TextStyle(
                        color: AppTheme.navy,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    ),
  );
}

class _ModeTag extends StatelessWidget {
  const _ModeTag({required this.isManual});

  final bool isManual;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
    decoration: BoxDecoration(
      color: isManual ? const Color(0xFFEAF1FA) : const Color(0xFFE8F5EF),
      borderRadius: BorderRadius.circular(30),
    ),
    child: Text(
      isManual ? 'MANUAL' : 'OTOMATIS',
      style: TextStyle(
        color: isManual ? AppTheme.blue : AppTheme.green,
        fontSize: 9,
        fontWeight: FontWeight.w800,
        letterSpacing: .6,
      ),
    ),
  );
}

class _LocalSafetyNote extends StatelessWidget {
  const _LocalSafetyNote();

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
    decoration: BoxDecoration(
      color: const Color(0xFFEAF3F3),
      borderRadius: BorderRadius.circular(18),
    ),
    child: const Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.shield_outlined, size: 18, color: AppTheme.teal),
        SizedBox(width: 9),
        Expanded(
          child: Text(
            'Perlindungan hujan dan mode otomatis tetap berjalan di ESP8266 saat internet terputus.',
            style: TextStyle(
              color: AppTheme.navy,
              fontSize: 11,
              height: 1.4,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    ),
  );
}

class _ErrorNotice extends StatelessWidget {
  const _ErrorNotice({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(13),
    decoration: BoxDecoration(
      color: const Color(0xFFFFEEEE),
      borderRadius: BorderRadius.circular(16),
    ),
    child: Row(
      children: [
        const Icon(Icons.error_outline_rounded, color: AppTheme.red, size: 18),
        const SizedBox(width: 9),
        Expanded(
          child: Text(
            message,
            style: const TextStyle(color: AppTheme.red, fontSize: 12),
          ),
        ),
      ],
    ),
  );
}

String _relativeTime(DateTime time) {
  final age = DateTime.now().difference(time);
  if (age.isNegative) return 'waktu perangkat tidak cocok';
  if (age.inSeconds < 5) return 'baru saja';
  if (age.inSeconds < 60) return '${age.inSeconds} dtk lalu';
  if (age.inMinutes < 60) return '${age.inMinutes} mnt lalu';
  if (age.inHours < 24) return '${age.inHours} jam lalu';
  return '${age.inDays} hari lalu';
}
