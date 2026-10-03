import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/exceptions/app_exception.dart';
import '../../../../core/services/logger_service.dart';

/// Caps how many dedup keys are kept, so the stored list can't grow forever
/// across months/years of use.
const int _maxStoredKeys = 300;

abstract class NotificationsLocalDataSource {
  Future<bool> getEnabled();
  Future<void> setEnabled(bool value);

  /// Whether [key] has already triggered a browser notification.
  Future<bool> hasNotified(String key);

  /// Records [key] as notified so it won't fire again.
  Future<void> markNotified(String key);
}

class NotificationsLocalDataSourceImpl implements NotificationsLocalDataSource {
  NotificationsLocalDataSourceImpl({required SharedPreferences sharedPreferences})
      : _sharedPreferences = sharedPreferences;

  final SharedPreferences _sharedPreferences;

  @override
  Future<bool> getEnabled() async {
    try {
      return _sharedPreferences.getBool(AppConstants.sharedPrefsNotificationsEnabled) ?? false;
    } catch (e, stackTrace) {
      LoggerService.error('Get notifications enabled error', error: e, stackTrace: stackTrace);
      throw CacheException('Failed to read notification settings');
    }
  }

  @override
  Future<void> setEnabled(bool value) async {
    try {
      await _sharedPreferences.setBool(AppConstants.sharedPrefsNotificationsEnabled, value);
    } catch (e, stackTrace) {
      LoggerService.error('Set notifications enabled error', error: e, stackTrace: stackTrace);
      throw CacheException('Failed to save notification settings');
    }
  }

  @override
  Future<bool> hasNotified(String key) async {
    try {
      final keys = _sharedPreferences.getStringList(AppConstants.sharedPrefsNotifiedAlertKeys) ?? [];
      return keys.contains(key);
    } catch (e, stackTrace) {
      LoggerService.error('Read notified keys error', error: e, stackTrace: stackTrace);
      return false;
    }
  }

  @override
  Future<void> markNotified(String key) async {
    try {
      final keys = _sharedPreferences.getStringList(AppConstants.sharedPrefsNotifiedAlertKeys) ?? [];
      if (keys.contains(key)) return;
      keys.add(key);
      final trimmed = keys.length > _maxStoredKeys
          ? keys.sublist(keys.length - _maxStoredKeys)
          : keys;
      await _sharedPreferences.setStringList(AppConstants.sharedPrefsNotifiedAlertKeys, trimmed);
    } catch (e, stackTrace) {
      LoggerService.error('Mark notified error', error: e, stackTrace: stackTrace);
    }
  }
}
