import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Windows toast notifications (FCM has no Windows client; decisions.md D8). Toasts are raised while the app is
/// running: by the 30-minute poll for new alerts and by the local expiry-reminder check.
class ToastService {
  final _plugin = FlutterLocalNotificationsPlugin();
  bool _ready = false;
  void Function(String? payload)? onTap;

  Future<void> init() async {
    if (_ready) return;
    const settings = InitializationSettings(
      windows: WindowsInitializationSettings(
        appName: 'Seafarer Assistant',
        appUserModelId: 'SeafarerAssistant.App',
        guid: '6f1d5b1e-8c1a-4f5e-9a9f-2d3c4b5a6e7f',
      ),
    );
    await _plugin.initialize(
      settings: settings,
      onDidReceiveNotificationResponse: (r) => onTap?.call(r.payload),
    );
    _ready = true;
  }

  Future<void> show({required int id, required String title, required String body, String? payload}) async {
    if (!_ready) return;
    await _plugin.show(
      id: id,
      title: title,
      body: body,
      notificationDetails: const NotificationDetails(windows: WindowsNotificationDetails()),
      payload: payload,
    );
  }
}
