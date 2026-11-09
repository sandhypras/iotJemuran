import 'package:flutter/material.dart';

import '../app_controller.dart';
import '../core/app_theme.dart';

class PairingScreen extends StatefulWidget {
  const PairingScreen({required this.controller, super.key});
  final AppController controller;

  @override
  State<PairingScreen> createState() => _PairingScreenState();
}

class _PairingScreenState extends State<PairingScreen> {
  final formKey = GlobalKey<FormState>();
  final codeController = TextEditingController();

  @override
  void dispose() {
    codeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppTheme.navy,
    body: SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(24, 26, 24, 30),
        children: [
          const SizedBox(height: 22),
          Container(
            height: 72,
            width: 72,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: .12),
              borderRadius: BorderRadius.circular(24),
            ),
            child: const Icon(
              Icons.wb_twilight_rounded,
              color: Colors.white,
              size: 38,
            ),
          ),
          const SizedBox(height: 26),
          const Text(
            'Smart\nClothesline',
            style: TextStyle(
              color: Colors.white,
              fontSize: 38,
              height: 1.08,
              fontWeight: FontWeight.w800,
              letterSpacing: -.8,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Pantau jemuran Anda dari mana saja.',
            style: TextStyle(
              color: Colors.white.withValues(alpha: .75),
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 36),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(22),
              child: Form(
                key: formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Hubungkan perangkat',
                      style: TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.ink,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Masukkan kode pairing yang diberikan saat perangkat disiapkan.',
                      style: TextStyle(color: AppTheme.muted, height: 1.4),
                    ),
                    const SizedBox(height: 20),
                    TextFormField(
                      controller: codeController,
                      textCapitalization: TextCapitalization.characters,
                      autocorrect: false,
                      decoration: const InputDecoration(
                        labelText: 'Kode pairing',
                        hintText: 'Contoh: 8K4M2P7Q',
                        prefixIcon: Icon(Icons.key_rounded),
                      ),
                      validator: (value) =>
                          (value == null || value.trim().length < 8)
                          ? 'Masukkan kode minimal 8 karakter.'
                          : null,
                    ),
                    if (widget.controller.errorMessage != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        widget.controller.errorMessage!,
                        style: const TextStyle(
                          color: AppTheme.red,
                          fontSize: 13,
                        ),
                      ),
                    ],
                    const SizedBox(height: 18),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: widget.controller.isLoading
                            ? null
                            : () {
                                if (formKey.currentState!.validate()) {
                                  widget.controller.pair(codeController.text);
                                }
                              },
                        icon: widget.controller.isLoading
                            ? const SizedBox.square(
                                dimension: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.link_rounded),
                        label: const Text('Sambungkan perangkat'),
                        style: FilledButton.styleFrom(
                          minimumSize: const Size.fromHeight(52),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 18),
          const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.lock_outline_rounded, size: 16, color: Colors.white70),
              SizedBox(width: 7),
              Text(
                'Koneksi dilindungi kode pairing',
                style: TextStyle(color: Colors.white70, fontSize: 12),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}
