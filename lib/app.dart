import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app_controller.dart';
import 'core/app_theme.dart';
import 'data/device_repository.dart';
import 'screens/history_screen.dart';
import 'screens/live_dashboard_screen.dart';
import 'screens/pairing_screen.dart';

class SmartClotheslineApp extends StatefulWidget {
  const SmartClotheslineApp({super.key});

  @override
  State<SmartClotheslineApp> createState() => _SmartClotheslineAppState();
}

class _SmartClotheslineAppState extends State<SmartClotheslineApp> {
  late final AppController controller;

  @override
  void initState() {
    super.initState();
    controller = AppController(DeviceRepository(Supabase.instance.client))
      ..initialize();
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Smart Clothesline',
    debugShowCheckedModeBanner: false,
    theme: AppTheme.light,
    home: AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        if (controller.isLoading && controller.deviceId == null) {
          return const _LoadingScreen();
        }
        if (controller.deviceId == null) {
          return PairingScreen(controller: controller);
        }
        return HomeShell(controller: controller);
      },
    ),
  );
}

class HomeShell extends StatefulWidget {
  const HomeShell({required this.controller, super.key});
  final AppController controller;

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int selectedIndex = 0;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: IndexedStack(
      index: selectedIndex,
      children: [
        LiveDashboardScreen(controller: widget.controller),
        HistoryScreen(controller: widget.controller),
      ],
    ),
    bottomNavigationBar: SafeArea(
      top: false,
      minimum: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      child: Container(
        height: 70,
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(25),
          border: Border.all(color: AppTheme.line.withValues(alpha: .8)),
          boxShadow: [
            BoxShadow(
              color: AppTheme.navy.withValues(alpha: .10),
              blurRadius: 22,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: _BottomNavItem(
                label: 'Dashboard',
                icon: Icons.space_dashboard_outlined,
                selectedIcon: Icons.space_dashboard_rounded,
                selected: selectedIndex == 0,
                onTap: () => setState(() => selectedIndex = 0),
              ),
            ),
            Expanded(
              child: _BottomNavItem(
                label: 'Riwayat',
                icon: Icons.history_rounded,
                selectedIcon: Icons.history_rounded,
                selected: selectedIndex == 1,
                onTap: () => setState(() => selectedIndex = 1),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _BottomNavItem extends StatelessWidget {
  const _BottomNavItem({
    required this.label,
    required this.icon,
    required this.selectedIcon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final IconData selectedIcon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Tooltip(
    message: label,
    child: Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(19),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          margin: const EdgeInsets.symmetric(horizontal: 3),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          decoration: BoxDecoration(
            color: selected ? AppTheme.navy : Colors.transparent,
            borderRadius: BorderRadius.circular(19),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 180),
                transitionBuilder: (child, animation) =>
                    ScaleTransition(scale: animation, child: child),
                child: Icon(
                  selected ? selectedIcon : icon,
                  key: ValueKey(selected),
                  size: 19,
                  color: selected ? Colors.white : AppTheme.muted,
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: selected ? Colors.white : AppTheme.muted,
                    fontSize: 11,
                    fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _LoadingScreen extends StatefulWidget {
  const _LoadingScreen();

  @override
  State<_LoadingScreen> createState() => _LoadingScreenState();
}

class _LoadingScreenState extends State<_LoadingScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;
  late final Animation<double> _pulse;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _pulse = Tween<double>(begin: .94, end: 1.04).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppTheme.background,
    body: SafeArea(
      child: Stack(
        children: [
          Positioned(
            top: -100,
            right: -90,
            child: _LoadingOrb(size: 250, color: AppTheme.paleBlue),
          ),
          Positioned(
            bottom: -120,
            left: -90,
            child: _LoadingOrb(size: 280, color: const Color(0xFFEAF3F2)),
          ),
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 360),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 28),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 154,
                      height: 154,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          const SizedBox.square(
                            dimension: 148,
                            child: CircularProgressIndicator(
                              strokeWidth: 3,
                              color: AppTheme.teal,
                              backgroundColor: AppTheme.line,
                            ),
                          ),
                          ScaleTransition(
                            scale: _pulse,
                            child: Container(
                              width: 104,
                              height: 104,
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [AppTheme.navy, AppTheme.blue],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                borderRadius: BorderRadius.circular(34),
                                boxShadow: [
                                  BoxShadow(
                                    color: AppTheme.navy.withValues(alpha: .2),
                                    blurRadius: 22,
                                    offset: const Offset(0, 10),
                                  ),
                                ],
                              ),
                              child: const Icon(
                                Icons.local_laundry_service_rounded,
                                color: Colors.white,
                                size: 48,
                              ),
                            ),
                          ),
                          Positioned(
                            right: 9,
                            bottom: 20,
                            child: Container(
                              width: 27,
                              height: 27,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                                border: Border.all(color: AppTheme.line),
                              ),
                              child: const Icon(
                                Icons.wb_sunny_rounded,
                                color: AppTheme.amber,
                                size: 15,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 28),
                    const Text(
                      'SMART CLOTHESLINE',
                      style: TextStyle(
                        color: AppTheme.blue,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 2.2,
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'Menyiapkan jemuran',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: AppTheme.ink,
                        fontSize: 23,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -.6,
                      ),
                    ),
                    const SizedBox(height: 7),
                    const Text(
                      'Menghubungkan perangkat dan memuat kondisi terbaru.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: AppTheme.muted,
                        fontSize: 13,
                        height: 1.45,
                      ),
                    ),
                    const SizedBox(height: 24),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: const LinearProgressIndicator(
                        minHeight: 4,
                        color: AppTheme.blue,
                        backgroundColor: AppTheme.line,
                      ),
                    ),
                    const SizedBox(height: 11),
                    const Text(
                      'MEMULIHKAN KONEKSI AMAN',
                      style: TextStyle(
                        color: AppTheme.muted,
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.25,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

class _LoadingOrb extends StatelessWidget {
  const _LoadingOrb({required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(color: color, shape: BoxShape.circle),
  );
}
