import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../app_controller.dart';
import '../core/app_theme.dart';
import '../models/activity_item.dart';
import '../models/sensor_reading.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({required this.controller, super.key});

  final AppController controller;

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  DateTime selectedDay = DateTime.now();
  int selectedType = 0;
  late Future<List<dynamic>> data;

  @override
  void initState() {
    super.initState();
    data = _load();
  }

  Future<List<dynamic>> _load() => selectedType == 0
      ? widget.controller.loadActivities(selectedDay)
      : widget.controller.loadReadings(selectedDay);

  Future<void> _reload() async {
    final refreshed = _load();
    setState(() => data = refreshed);
    try {
      await refreshed;
    } catch (_) {
      // FutureBuilder menampilkan tampilan error dari future yang sama.
    }
  }

  void _selectType(int type) {
    if (selectedType == type) return;
    setState(() {
      selectedType = type;
      data = _load();
    });
  }

  Future<void> _chooseDay() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: selectedDay,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      helpText: 'Pilih tanggal riwayat',
    );
    if (picked == null || !mounted) return;
    setState(() {
      selectedDay = picked;
      data = _load();
    });
  }

  void _shiftDay(int amount) {
    final next = DateTime(
      selectedDay.year,
      selectedDay.month,
      selectedDay.day + amount,
    );
    final today = DateTime.now();
    if (next.isAfter(DateTime(today.year, today.month, today.day))) return;
    setState(() {
      selectedDay = next;
      data = _load();
    });
  }

  bool get _isToday {
    final now = DateTime.now();
    return selectedDay.year == now.year &&
        selectedDay.month == now.month &&
        selectedDay.day == now.day;
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text(
        'Riwayat',
        style: TextStyle(fontWeight: FontWeight.w800),
      ),
      actions: [
        IconButton(
          onPressed: _chooseDay,
          tooltip: 'Pilih tanggal',
          icon: const Icon(Icons.calendar_month_rounded),
        ),
      ],
    ),
    body: Column(
      children: [
        _DateHeader(
          selectedDay: selectedDay,
          isToday: _isToday,
          onPrevious: () => _shiftDay(-1),
          onNext: _isToday ? null : () => _shiftDay(1),
          onChooseDate: _chooseDay,
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 12),
          child: _HistoryTypeSelector(
            selectedType: selectedType,
            onSelected: _selectType,
          ),
        ),
        Expanded(
          child: FutureBuilder<List<dynamic>>(
            future: data,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const _HistoryLoading();
              }
              if (snapshot.hasError) {
                return _HistoryMessage(
                  icon: Icons.cloud_off_rounded,
                  title: 'Riwayat belum tersedia',
                  message: 'Periksa koneksi internet, lalu coba muat ulang.',
                  actionLabel: 'Coba lagi',
                  onAction: _reload,
                );
              }

              final rows = snapshot.data ?? [];
              if (rows.isEmpty) {
                return _HistoryMessage(
                  icon: selectedType == 0
                      ? Icons.event_note_rounded
                      : Icons.sensors_rounded,
                  title: 'Belum ada catatan',
                  message: selectedType == 0
                      ? 'Aktivitas jemuran pada tanggal ini akan muncul di sini.'
                      : 'Data sensor pada tanggal ini akan muncul di sini.',
                  actionLabel: 'Pilih tanggal lain',
                  onAction: _chooseDay,
                );
              }

              return RefreshIndicator(
                onRefresh: _reload,
                child: ListView.separated(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(18, 2, 18, 30),
                  itemCount: rows.length + 1,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    if (index == 0) {
                      return _HistoryCountCard(
                        count: rows.length,
                        selectedType: selectedType,
                      );
                    }
                    final row = rows[index - 1];
                    return selectedType == 0
                        ? _ActivityTile(item: row as ActivityItem)
                        : _SensorTile(item: row as SensorReading);
                  },
                ),
              );
            },
          ),
        ),
      ],
    ),
  );
}

class _DateHeader extends StatelessWidget {
  const _DateHeader({
    required this.selectedDay,
    required this.isToday,
    required this.onPrevious,
    required this.onNext,
    required this.onChooseDate,
  });

  final DateTime selectedDay;
  final bool isToday;
  final VoidCallback onPrevious;
  final VoidCallback? onNext;
  final VoidCallback onChooseDate;

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
    padding: const EdgeInsets.fromLTRB(18, 17, 14, 16),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(24),
      gradient: const LinearGradient(
        colors: [AppTheme.navy, Color(0xFF205A7B)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      boxShadow: [
        BoxShadow(
          color: AppTheme.navy.withValues(alpha: 0.18),
          blurRadius: 18,
          offset: const Offset(0, 8),
        ),
      ],
    ),
    child: Row(
      children: [
        Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(16),
          ),
          child: const Icon(Icons.calendar_month_rounded, color: Colors.white),
        ),
        const SizedBox(width: 13),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isToday ? 'HARI INI' : 'RIWAYAT TANGGAL',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.68),
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.1,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                DateFormat('EEEE, d MMMM y', 'id_ID').format(selectedDay),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
        IconButton(
          onPressed: onPrevious,
          tooltip: 'Hari sebelumnya',
          visualDensity: VisualDensity.compact,
          style: IconButton.styleFrom(
            backgroundColor: Colors.white.withValues(alpha: 0.1),
            foregroundColor: Colors.white,
          ),
          icon: const Icon(Icons.chevron_left_rounded),
        ),
        const SizedBox(width: 4),
        IconButton(
          onPressed: onNext,
          tooltip: 'Hari berikutnya',
          visualDensity: VisualDensity.compact,
          style: IconButton.styleFrom(
            backgroundColor: Colors.white.withValues(alpha: 0.1),
            foregroundColor: Colors.white,
            disabledForegroundColor: Colors.white38,
          ),
          icon: const Icon(Icons.chevron_right_rounded),
        ),
      ],
    ),
  );
}

class _HistoryTypeSelector extends StatelessWidget {
  const _HistoryTypeSelector({
    required this.selectedType,
    required this.onSelected,
  });

  final int selectedType;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(5),
    decoration: BoxDecoration(
      color: const Color(0xFFE6EEF1),
      borderRadius: BorderRadius.circular(19),
    ),
    child: Row(
      children: [
        Expanded(
          child: _HistoryTypeButton(
            title: 'Aktivitas',
            icon: Icons.bolt_rounded,
            selected: selectedType == 0,
            onTap: () => onSelected(0),
          ),
        ),
        Expanded(
          child: _HistoryTypeButton(
            title: 'Sensor',
            icon: Icons.sensors_rounded,
            selected: selectedType == 1,
            onTap: () => onSelected(1),
          ),
        ),
      ],
    ),
  );
}

class _HistoryTypeButton extends StatelessWidget {
  const _HistoryTypeButton({
    required this.title,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String title;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => AnimatedContainer(
    duration: const Duration(milliseconds: 180),
    curve: Curves.easeOut,
    decoration: BoxDecoration(
      color: selected ? Colors.white : Colors.transparent,
      borderRadius: BorderRadius.circular(15),
      boxShadow: selected
          ? [
              BoxShadow(
                color: AppTheme.navy.withValues(alpha: 0.08),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ]
          : null,
    ),
    child: Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(15),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 18,
                color: selected ? AppTheme.navy : AppTheme.muted,
              ),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  color: selected ? AppTheme.navy : AppTheme.muted,
                  fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _HistoryCountCard extends StatelessWidget {
  const _HistoryCountCard({required this.count, required this.selectedType});

  final int count;
  final int selectedType;

  @override
  Widget build(BuildContext context) {
    final isActivity = selectedType == 0;
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: AppTheme.paleBlue,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              isActivity ? Icons.bolt_rounded : Icons.sensors_rounded,
              color: AppTheme.blue,
              size: 19,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              isActivity ? 'Catatan aktivitas' : 'Rekaman sensor',
              style: const TextStyle(
                color: AppTheme.ink,
                fontWeight: FontWeight.w800,
                fontSize: 13,
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(30),
              border: Border.all(color: AppTheme.line),
            ),
            child: Text(
              '$count data',
              style: const TextStyle(
                color: AppTheme.muted,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ActivityTile extends StatelessWidget {
  const _ActivityTile({required this.item});

  final ActivityItem item;

  @override
  Widget build(BuildContext context) {
    final (icon, title, color) = switch (item.eventType) {
      'line_opened' => (
        Icons.open_in_full_rounded,
        'Jemuran dibuka',
        AppTheme.green,
      ),
      'line_closed' => (
        Icons.close_fullscreen_rounded,
        'Jemuran ditutup',
        AppTheme.blue,
      ),
      'mode_changed' => (
        Icons.tune_rounded,
        'Mode sistem berubah',
        AppTheme.teal,
      ),
      _ => (Icons.bolt_rounded, 'Aktivitas perangkat', AppTheme.amber),
    };

    return _HistoryCard(
      child: Padding(
        padding: const EdgeInsets.all(15),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.11),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(icon, color: color, size: 21),
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: AppTheme.ink,
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  if (item.message.trim().isNotEmpty) ...[
                    const SizedBox(height: 5),
                    Text(
                      item.message,
                      style: const TextStyle(
                        color: AppTheme.muted,
                        fontSize: 12,
                        height: 1.4,
                      ),
                    ),
                  ],
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Icon(Icons.schedule_rounded, size: 14, color: color),
                      const SizedBox(width: 5),
                      Text(
                        DateFormat('HH:mm:ss').format(item.createdAt),
                        style: TextStyle(
                          color: color,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        width: 4,
                        height: 4,
                        decoration: const BoxDecoration(
                          color: AppTheme.line,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'Jemuran',
                        style: TextStyle(
                          color: AppTheme.muted,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              Icons.chevron_right_rounded,
              color: color.withValues(alpha: 0.55),
            ),
          ],
        ),
      ),
    );
  }
}

class _SensorTile extends StatelessWidget {
  const _SensorTile({required this.item});

  final SensorReading item;

  @override
  Widget build(BuildContext context) {
    final rainColor = item.rainDetected ? AppTheme.red : AppTheme.green;
    final lightColor = item.lightPercent >= 50 ? AppTheme.amber : AppTheme.blue;
    final lightLabel = item.lightPercent >= 50 ? 'Terang' : 'Redup';

    return _HistoryCard(
      child: Padding(
        padding: const EdgeInsets.all(15),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: AppTheme.paleBlue,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(
                    Icons.sensors_rounded,
                    color: AppTheme.blue,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 11),
                const Expanded(
                  child: Text(
                    'Pembacaan sensor',
                    style: TextStyle(
                      color: AppTheme.ink,
                      fontWeight: FontWeight.w800,
                      fontSize: 14,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.background,
                    borderRadius: BorderRadius.circular(30),
                  ),
                  child: Text(
                    DateFormat('HH:mm').format(item.createdAt),
                    style: const TextStyle(
                      color: AppTheme.ink,
                      fontWeight: FontWeight.w800,
                      fontSize: 11,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: _SensorValueCard(
                    icon: item.rainDetected
                        ? Icons.water_drop_rounded
                        : Icons.water_drop_outlined,
                    label: 'SENSOR HUJAN',
                    value: item.rainDetected
                        ? 'Hujan terdeteksi'
                        : 'Tidak hujan',
                    detail: 'Nilai ADC ${item.rainValue}',
                    color: rainColor,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _LightValueCard(
                    value: item.lightPercent,
                    label: lightLabel,
                    color: lightColor,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SensorValueCard extends StatelessWidget {
  const _SensorValueCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.detail,
    required this.color,
  });

  final IconData icon;
  final String label;
  final String value;
  final String detail;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    constraints: const BoxConstraints(minHeight: 114),
    padding: const EdgeInsets.all(11),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.07),
      borderRadius: BorderRadius.circular(17),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: color, size: 15),
            const SizedBox(width: 5),
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: color,
                  fontSize: 9,
                  letterSpacing: 0.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 9),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: AppTheme.ink,
            fontSize: 13,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          detail,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(color: AppTheme.muted, fontSize: 9),
        ),
      ],
    ),
  );
}

class _LightValueCard extends StatelessWidget {
  const _LightValueCard({
    required this.value,
    required this.label,
    required this.color,
  });

  final double value;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final normalized = (value / 100).clamp(0.0, 1.0).toDouble();
    return Container(
      constraints: const BoxConstraints(minHeight: 114),
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(17),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.wb_sunny_rounded, color: color, size: 15),
              const SizedBox(width: 5),
              Text(
                'CAHAYA',
                style: TextStyle(
                  color: color,
                  fontSize: 9,
                  letterSpacing: 0.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '${value.toStringAsFixed(0)}%',
            style: const TextStyle(
              color: AppTheme.ink,
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(
              color: AppTheme.muted,
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 9),
          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: LinearProgressIndicator(
              value: normalized,
              minHeight: 5,
              backgroundColor: Colors.white,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _HistoryCard extends StatelessWidget {
  const _HistoryCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(21),
      border: Border.all(color: AppTheme.line.withValues(alpha: 0.7)),
      boxShadow: [
        BoxShadow(
          color: AppTheme.navy.withValues(alpha: 0.045),
          blurRadius: 15,
          offset: const Offset(0, 5),
        ),
      ],
    ),
    child: child,
  );
}

class _HistoryLoading extends StatelessWidget {
  const _HistoryLoading();

  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 62,
          height: 62,
          decoration: BoxDecoration(
            color: AppTheme.paleBlue,
            borderRadius: BorderRadius.circular(22),
          ),
          child: const Padding(
            padding: EdgeInsets.all(18),
            child: CircularProgressIndicator(
              strokeWidth: 2.5,
              color: AppTheme.blue,
            ),
          ),
        ),
        const SizedBox(height: 14),
        const Text(
          'Memuat riwayat…',
          style: TextStyle(
            color: AppTheme.muted,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    ),
  );
}

class _HistoryMessage extends StatelessWidget {
  const _HistoryMessage({
    required this.icon,
    required this.title,
    required this.message,
    required this.actionLabel,
    required this.onAction,
  });

  final IconData icon;
  final String title;
  final String message;
  final String actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 76,
            height: 76,
            decoration: BoxDecoration(
              color: AppTheme.paleBlue,
              borderRadius: BorderRadius.circular(26),
            ),
            child: Icon(icon, color: AppTheme.blue, size: 34),
          ),
          const SizedBox(height: 17),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppTheme.ink,
              fontSize: 17,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 7),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppTheme.muted,
              fontSize: 13,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 17),
          FilledButton.tonalIcon(
            onPressed: onAction,
            icon: Icon(
              actionLabel == 'Coba lagi'
                  ? Icons.refresh_rounded
                  : Icons.calendar_month_rounded,
            ),
            label: Text(actionLabel),
          ),
        ],
      ),
    ),
  );
}
