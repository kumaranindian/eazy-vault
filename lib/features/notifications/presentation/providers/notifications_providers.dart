import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../authentication/presentation/providers/auth_providers.dart';
import '../../data/datasources/notifications_local_datasource.dart';
import '../../domain/services/notification_dispatch_service.dart';

part 'notifications_providers.g.dart';

@Riverpod(keepAlive: true)
Future<NotificationsLocalDataSource> notificationsLocalDataSource(
  NotificationsLocalDataSourceRef ref,
) async {
  final prefs = await ref.watch(sharedPreferencesProvider.future);
  return NotificationsLocalDataSourceImpl(sharedPreferences: prefs);
}

@Riverpod(keepAlive: true)
Future<NotificationDispatchService> notificationDispatchService(
  NotificationDispatchServiceRef ref,
) async {
  return NotificationDispatchService(
    localDataSource: await ref.watch(notificationsLocalDataSourceProvider.future),
  );
}
