import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/badge_tag.dart';
import '../../core/widgets/glass_card.dart';
import '../../repositories/providers.dart';
import '../../services/key_storage_service.dart';

class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key});

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  final provider = TextEditingController(
    text: KeyStorageService.defaultProvider,
  );
  final baseUrl = TextEditingController(text: KeyStorageService.defaultBaseUrl);
  final model = TextEditingController(text: KeyStorageService.defaultModel);
  final apiKey = TextEditingController();
  bool obscureKey = true;
  String status = '';

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  @override
  void dispose() {
    provider.dispose();
    baseUrl.dispose();
    model.dispose();
    apiKey.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          const Text(
            'Settings & API Key Management',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Configure your BYOK (Bring Your Own Key) LLM endpoint settings for AI-assisted syllabus Q&A.',
            style: TextStyle(
              fontSize: 13,
              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
            ),
          ),
          const SizedBox(height: 24),

          Expanded(
            child: ListView(
              children: [
                // Section 1: Provider & Endpoint Settings
                GlassCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(
                            Icons.tune_rounded,
                            color: AppColors.primaryViolet,
                            size: 20,
                          ),
                          SizedBox(width: 8),
                          Text(
                            'LLM Engine Endpoint Config',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: provider,
                        decoration: const InputDecoration(
                          labelText: 'Provider Name',
                          hintText: 'e.g. Google Gemini, OpenAI, LM Studio',
                          prefixIcon: Icon(Icons.dns_rounded),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: baseUrl,
                        decoration: const InputDecoration(
                          labelText: 'API Base URL',
                          hintText: KeyStorageService.defaultBaseUrl,
                          prefixIcon: Icon(Icons.link_rounded),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: model,
                        decoration: const InputDecoration(
                          labelText: 'Model Identifier',
                          hintText: KeyStorageService.defaultModel,
                          prefixIcon: Icon(Icons.smart_toy_rounded),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // Section 2: Security & API Key Credentials
                GlassCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Row(
                            children: [
                              Icon(
                                Icons.security_rounded,
                                color: AppColors.primaryCyan,
                                size: 20,
                              ),
                              SizedBox(width: 8),
                              Text(
                                'API Credentials & Security',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          BadgeTag(
                            label: status.contains('Configured')
                                ? 'Key Saved'
                                : 'No Key',
                            style: status.contains('Configured')
                                ? BadgeStyle.emerald
                                : BadgeStyle.amber,
                            icon: status.contains('Configured')
                                ? Icons.check_circle_rounded
                                : Icons.warning_amber_rounded,
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: apiKey,
                        obscureText: obscureKey,
                        decoration: InputDecoration(
                          labelText: 'Secret API Key',
                          hintText: 'AIza...',
                          prefixIcon: const Icon(Icons.key_rounded),
                          suffixIcon: IconButton(
                            icon: Icon(
                              obscureKey
                                  ? Icons.visibility_rounded
                                  : Icons.visibility_off_rounded,
                              size: 18,
                            ),
                            onPressed: () =>
                                setState(() => obscureKey = !obscureKey),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Your API key is stored securely in encrypted platform storage (Flutter Secure Storage) and never sent to external servers.',
                        style: TextStyle(
                          fontSize: 12,
                          color: Color(0xFF94A3B8),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // Save Action Button
                Align(
                  alignment: Alignment.centerLeft,
                  child: FilledButton.icon(
                    onPressed: _save,
                    icon: const Icon(Icons.save_rounded, size: 18),
                    label: const Text('Save Settings'),
                  ),
                ),

                if (status.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.accentEmerald.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: AppColors.accentEmerald.withValues(alpha: 0.35),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.check_circle_rounded,
                          color: AppColors.accentEmerald,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          status,
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppColors.accentEmerald,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _loadSettings() async {
    final settings = await ref.read(keyStorageServiceProvider).readSettings();
    if (!mounted) return;
    setState(() {
      provider.text = settings.provider;
      baseUrl.text = settings.baseUrl;
      model.text = settings.model;
      status = settings.hasApiKey
          ? 'API Key Configured & Stored Securely.'
          : '';
    });
  }

  Future<void> _save() async {
    await ref
        .read(keyStorageServiceProvider)
        .saveSettings(
          provider: provider.text.trim(),
          baseUrl: baseUrl.text.trim(),
          model: model.text.trim(),
          apiKey: apiKey.text.trim(),
        );
    if (!mounted) return;
    setState(() => status = 'Settings & API Key saved successfully.');
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Settings saved successfully!'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}
