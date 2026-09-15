class AppConfig {
  const AppConfig._();

  static const backendBaseUrl = String.fromEnvironment(
    'FLM_BACKEND_URL',
    defaultValue: 'http://localhost:8000',
  );
}
