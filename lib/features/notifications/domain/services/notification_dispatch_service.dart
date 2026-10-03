import '../../data/datasources/notifications_local_datasource.dart';
import '../models/app_alert.dart';
import 'web_notifier.dart';

/// Turns newly-crossed alerts into a browser notification, once per dedup
/// key. The in-app bell shows every current [AppAlert] regardless of what
/// this has already fired for — this only decides what becomes a popup.
class NotificationDispatchService {
  NotificationDispatchService({required NotificationsLocalDataSource localDataSource})
      : _localDataSource = localDataSource;

  final NotificationsLocalDataSource _localDataSource;

  /// Shows a browser notification for each alert in [alerts] that hasn't
  /// already fired, provided notifications are [enabled] and permitted.
  /// Returns how many were newly shown.
  Future<int> dispatchNew(List<AppAlert> alerts, {required bool enabled}) async {
    if (!enabled || WebNotifier.permission != 'granted') return 0;

    var shown = 0;
    for (final alert in alerts) {
      if (await _localDataSource.hasNotified(alert.key)) continue;
      WebNotifier.show(alert.title, body: alert.body);
      await _localDataSource.markNotified(alert.key);
      shown++;
    }
    return shown;
  }
}
