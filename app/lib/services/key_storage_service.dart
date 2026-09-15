import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class LlmSettings {
  const LlmSettings({
    required this.provider,
    required this.baseUrl,
    required this.model,
    required this.hasApiKey,
  });

  final String provider;
  final String baseUrl;
  final String model;
  final bool hasApiKey;
}

class KeyStorageService {
  static const defaultProvider = 'Google Gemini (OpenAI Compatible)';
  static const defaultBaseUrl =
      'https://generativelanguage.googleapis.com/v1beta/openai';
  static const defaultModel = 'gemini-3.8-flash';

  static const _storage = FlutterSecureStorage();

  Future<LlmSettings> readSettings() async {
    final values = await _storage.readAll();
    return LlmSettings(
      provider: values['provider'] ?? defaultProvider,
      baseUrl: values['baseUrl'] ?? defaultBaseUrl,
      model: values['model'] ?? defaultModel,
      hasApiKey: (values['apiKey'] ?? '').isNotEmpty,
    );
  }

  Future<String?> readApiKey() => _storage.read(key: 'apiKey');

  Future<void> saveSettings({
    required String provider,
    required String baseUrl,
    required String model,
    required String apiKey,
  }) async {
    await _storage.write(key: 'provider', value: provider);
    await _storage.write(key: 'baseUrl', value: baseUrl);
    await _storage.write(key: 'model', value: model);
    if (apiKey.isNotEmpty) {
      await _storage.write(key: 'apiKey', value: apiKey);
    }
  }
}
