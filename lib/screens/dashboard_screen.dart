import 'package:flutter/material.dart';

import '../app_controller.dart';
import '../core/app_theme.dart';
import '../widgets/metric_card.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({required this.controller, super.key});
  final AppController controller;

  @override
  Widget build(BuildContext context) {
    final reading = controller.latestReading;
    final status = controller.status;
    final isManual = (controller.pendingMode ?? status?.mode) == 'manual';
    final isOpen = status?.position == 'open';
    final rain = reading?.rainDetected ?? false;
    final stamp = reading?.createdAt;
    final pendingMessage = controller.pendingMessage;
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          onRefresh: controller.refresh,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(18, 12, 18, 28),
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Smart Clothesline',
                          style: TextStyle(
                            fontSize: 21,
                            fontWeight: FontWeight.w800,
                            color: AppTheme.ink,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Ringkasan kondisi jemuran',
                          style: TextStyle(fontSize: 13, color: AppTheme.muted),
                        ),
                      ],
                    ),
                  ),
                  _StatusBadge(online: controller.isOnline),
                ],
              ),
              const SizedBox(height: 16),
              _ClotheslineHero(isOpen: isOpen, rain: rain, lastUpdated: stamp),
              if (controller.errorMessage != null) ...[
                const SizedBox(height: 12),
                _InlineError(message: controller.errorMessage!),
              ],
              const SizedBox(height: 18),
              const Text(
                'Kondisi sensor',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.ink,
                ),
              ),
              const SizedBox(height: 10),
              LayoutBuilder(
                builder: (context, constraints) {
                  final rainCard = MetricCard(
                    icon: Icons.water_drop_rounded,
                    title: 'Sensor hujan',
                    value: reading == null ? '—' : (rain ? 'Basah' : 'Kering'),
                    unit: '',
                    caption: reading == null
                        ? 'Belum ada data'
                        : 'Sensor digital · DO aktif LOW',
                    color: rain ? AppTheme.red : AppTheme.blue,
                  );
                  final lightCard = MetricCard(
                    icon: Icons.wb_sunny_rounded,
                    title: 'Kondisi cahaya',
                    value: reading == null
                        ? '—'
                        : (reading.lightPercent >= 50 ? 'Terang' : 'Gelap'),
                    unit: '',
                    caption: reading == null
                        ? 'Belum ada data'
                        : 'Sensor LDR digital · DO',
                    color: const Color(0xFFE2A631),
                  );
                  if (constraints.maxWidth < 280) {
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
                      const SizedBox(width: 10),
                      Expanded(child: lightCard),
                    ],
                  );
                },
              ),
              const SizedBox(height: 18),
              const Text(
                'Kontrol jemuran',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.ink,
                ),
              ),
              const SizedBox(height: 10),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SegmentedButton<String>(
                        segments: const [
                          ButtonSegment(
                            value: 'automatic',
                            icon: Icon(Icons.auto_awesome_rounded),
                            label: Text('Otomatis'),
                          ),
                          ButtonSegment(
                            value: 'manual',
                            icon: Icon(Icons.touch_app_rounded),
                            label: Text('Manual'),
                          ),
                        ],
                        selected: {isManual ? 'manual' : 'automatic'},
                        onSelectionChanged: controller.isSendingCommand
                            ? null
                            : (value) => controller.command(
                                'set_mode',
                                mode: value.first,
                              ),
                        showSelectedIcon: false,
                      ),
                      const SizedBox(height: 10),
                      Text(
                        isManual
                            ? 'Kontrol jemuran langsung dari aplikasi.'
                            : 'ESP8266 mengatur jemuran mengikuti sensor.',
                        style: const TextStyle(
                          color: AppTheme.muted,
                          fontSize: 12,
                        ),
                      ),
                      if (isManual) ...[
                        const SizedBox(height: 15),
                        LayoutBuilder(
                          builder: (context, constraints) {
                            final openButton = OutlinedButton.icon(
                              onPressed: controller.isSendingCommand || rain
                                  ? null
                                  : () => controller.command('open'),
                              icon: const Icon(Icons.open_in_full_rounded),
                              label: const Text('Buka Jemuran'),
                              style: OutlinedButton.styleFrom(
                                minimumSize: const Size.fromHeight(48),
                              ),
                            );
                            final closeButton = FilledButton.icon(
                              onPressed: controller.isSendingCommand
                                  ? null
                                  : () => controller.command('close'),
                              icon: const Icon(Icons.close_fullscreen_rounded),
                              label: const Text('Tutup Jemuran'),
                              style: FilledButton.styleFrom(
                                minimumSize: const Size.fromHeight(48),
                              ),
                            );
                            if (constraints.maxWidth < 280) {
                              return Column(
                                children: [
                                  SizedBox(
                                    width: double.infinity,
                                    child: openButton,
                                  ),
                                  const SizedBox(height: 10),
                                  SizedBox(
                                    width: double.infinity,
                                    child: closeButton,
                                  ),
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
                        if (rain)
                          const Padding(
                            padding: EdgeInsets.only(top: 9),
                            child: Text(
                              'Buka dinonaktifkan saat hujan terdeteksi.',
                              style: TextStyle(
                                color: AppTheme.red,
                                fontSize: 12,
                              ),
                            ),
                          ),
                      ],
                      if (pendingMessage != null) ...[
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            const SizedBox(
                              width: 15,
                              height: 15,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                            const SizedBox(width: 9),
                            Expanded(
                              child: Text(
                                pendingMessage,
                                style: const TextStyle(
                                  color: AppTheme.blue,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Icon(
                    Icons.offline_bolt_rounded,
                    size: 18,
                    color: AppTheme.blue,
                  ),
                  const SizedBox(width: 7),
                  Expanded(
                    child: Text(
                      'Perlindungan hujan dan mode otomatis tetap berjalan di ESP8266 saat internet terputus.',
                      style: TextStyle(
                        color: AppTheme.navy.withValues(alpha: .82),
                        fontSize: 12,
                        height: 1.35,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.online});
  final bool online;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
    decoration: BoxDecoration(
      color: online ? const Color(0xFFE4F4ED) : const Color(0xFFFCECEC),
      borderRadius: BorderRadius.circular(30),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 7,
          height: 7,
          decoration: BoxDecoration(
            color: online ? AppTheme.green : AppTheme.red,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 6),
        Text(
          online ? 'Online' : 'Offline',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: online ? AppTheme.green : AppTheme.red,
          ),
        ),
      ],
    ),
  );
}

class _ClotheslineHero extends StatelessWidget {
  const _ClotheslineHero({
    required this.isOpen,
    required this.rain,
    required this.lastUpdated,
  });
  final bool isOpen;
  final bool rain;
  final DateTime? lastUpdated;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      gradient: const LinearGradient(
        colors: [Color(0xFF173E69), Color(0xFF2F76C2)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      borderRadius: BorderRadius.circular(24),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: .15),
                borderRadius: BorderRadius.circular(15),
              ),
              child: Icon(
                isOpen ? Icons.dry_cleaning_rounded : Icons.roofing_rounded,
                color: Colors.white,
                size: 26,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'POSISI JEMURAN',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.1,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    isOpen ? 'Terbuka' : 'Tertutup',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 23,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              rain ? Icons.umbrella_rounded : Icons.wb_sunny_rounded,
              color: Colors.white.withValues(alpha: .9),
              size: 26,
            ),
          ],
        ),
        const SizedBox(height: 16),
        Container(height: 1, color: Colors.white.withValues(alpha: .18)),
        const SizedBox(height: 12),
        Row(
          children: [
            Icon(
              rain
                  ? Icons.water_drop_rounded
                  : Icons.check_circle_outline_rounded,
              color: Colors.white70,
              size: 15,
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                rain ? 'Hujan terdeteksi' : 'Tidak ada hujan',
                style: const TextStyle(color: Colors.white, fontSize: 12),
              ),
            ),
            Text(
              lastUpdated == null
                  ? 'Menunggu data'
                  : 'Diperbarui ${TimeOfDay.fromDateTime(lastUpdated!).format(context)}',
              style: const TextStyle(color: Colors.white70, fontSize: 11),
            ),
          ],
        ),
      ],
    ),
  );
}

class _InlineError extends StatelessWidget {
  const _InlineError({required this.message});
  final String message;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: const Color(0xFFFFEEEE),
      borderRadius: BorderRadius.circular(14),
    ),
    child: Text(
      message,
      style: const TextStyle(color: AppTheme.red, fontSize: 12),
    ),
  );
}
