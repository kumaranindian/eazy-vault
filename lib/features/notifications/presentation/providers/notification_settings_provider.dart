import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../domain/services/web_notifier.dart';
import 'notifications_providers.dart';

part 'notification_settings_provider.g.dart';

@riverpod
class NotificationSettingsNotifier extends _$NotificationSettingsNotifier {
  @override
  Future<bool> build() async {
    final dataSource = await ref.watch(notificationsLocalDataSourceProvider.future);
    return dataSource.getEnabled();
  }

  /// Turning this on also requests browser notification permission (a no-op
  /// if already granted/denied, or if the browser doesn't support it — the
  /// in-app bell still works either way).
  Future<void> setEnabled(bool value) async {
    if (value) {
      await WebNotifier.requestPermission();
    }
    final dataSource = await ref.read(notificationsLocalDataSourceProvider.future);
    await dataSource.setEnabled(value);
    state = AsyncData(value);
  }
}
