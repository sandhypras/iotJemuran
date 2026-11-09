import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app.dart';
import 'core/app_config.dart';
import 'core/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final config = AppConfig.fromEnvironment();
  if (!config.isConfigured) {
    runApp(const ConfigurationApp());
    return;
  }

  await initializeDateFormatting('id_ID');
  await Supabase.initialize(
    url: config.supabaseUrl,
    publishableKey: config.supabasePublishableKey,
  );
  runApp(const SmartClotheslineApp());
}

class ConfigurationApp extends StatelessWidget {
  const ConfigurationApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Smart Clothesline',
    debugShowCheckedModeBanner: false,
    theme: AppTheme.light,
    home: const Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: EdgeInsets.all(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.cloud_off_rounded,
                  size: 56,
                  color: Color(0xFF1C477A),
                ),
                SizedBox(height: 18),
                Text(
                  'Konfigurasi Supabase belum diisi',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 10),
                Text(
                  'Jalankan aplikasi dengan --dart-define-from-file=supabase.env.json. Lihat README.md untuk langkah lengkap.',
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
