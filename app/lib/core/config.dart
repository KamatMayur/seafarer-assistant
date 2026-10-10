/// App-wide constants. The API address can be overridden at build time:
///   flutter run --dart-define=API_BASE=https://api.example.com
/// and changed by the user in Settings (stored locally).
class AppConfig {
  static const defaultApiBase = String.fromEnvironment('API_BASE', defaultValue: 'http://127.0.0.1:8000');
  static const appName = 'Seafarer Assistant';
  static const pollInterval = Duration(minutes: 30);
  static const dataSaverPollInterval = Duration(hours: 2);
  static const privacyPolicyVersion = 'draft-0.1';

  static const unofficialNotice =
      'Independent app. Not affiliated with DGMA, DG Shipping or the Government of India.';
  static const disclaimer =
      'Automatic extract from the official document. Always verify with the official circular.';
}
