import 'dart:html' as html;

/// Thin wrapper over the browser Notification API — the only notification
/// channel available to this app (Flutter Web only; no android/ios targets,
/// so a plugin like flutter_local_notifications has nothing to attach to).
class WebNotifier {
  const WebNotifier._();

  static bool get isSupported => html.Notification.supported;

  /// `'granted'`, `'denied'`, or `'default'` (not yet asked).
  static String get permission =>
      (isSupported ? html.Notification.permission : null) ?? 'denied';

  static Future<String> requestPermission() async {
    if (!isSupported) return 'denied';
    return html.Notification.requestPermission();
  }

  static void show(String title, {String? body}) {
    if (!isSupported || permission != 'granted') return;
    html.Notification(title, body: body);
  }
}
