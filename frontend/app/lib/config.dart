class AppConfig {
  // Override for Android emulator (10.0.2.2) or an explicitly exposed LAN host.
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL', defaultValue: 'http://localhost:8000/api/v1');
  static final String socketUrl = const String.fromEnvironment('WS_URL').isNotEmpty
      ? const String.fromEnvironment('WS_URL')
      : '${baseUrl.replaceFirst(RegExp(r'^http'), 'ws')}/events/connect';
  static const bool fcmEnabled = bool.fromEnvironment('FCM_ENABLED');
}
