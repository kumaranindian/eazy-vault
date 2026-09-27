import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/exceptions/app_exception.dart';
import '../../../../core/services/logger_service.dart';

abstract class AuthLocalDataSource {
  Future<bool> getRememberMe();
  Future<void> setRememberMe(bool value);
  Future<String?> getLastEmail();
  Future<void> setLastEmail(String email);
  Future<void> clearAuthData();
}

class AuthLocalDataSourceImpl implements AuthLocalDataSource {
  AuthLocalDataSourceImpl({required SharedPreferences sharedPreferences})
      : _sharedPreferences = sharedPreferences;

  final SharedPreferences _sharedPreferences;

  @override
  Future<bool> getRememberMe() async {
    try {
      return _sharedPreferences.getBool(AppConstants.sharedPrefsRememberMe) ?? false;
    } catch (e, stackTrace) {
      LoggerService.error('Get remember me error', error: e, stackTrace: stackTrace);
      throw CacheException('Failed to get remember me preference');
    }
  }

  @override
  Future<void> setRememberMe(bool value) async {
    try {
      await _sharedPreferences.setBool(AppConstants.sharedPrefsRememberMe, value);
    } catch (e, stackTrace) {
      LoggerService.error('Set remember me error', error: e, stackTrace: stackTrace);
      throw CacheException('Failed to set remember me preference');
    }
  }

  @override
  Future<String?> getLastEmail() async {
    try {
      return _sharedPreferences.getString(AppConstants.sharedPrefsLastEmail);
    } catch (e, stackTrace) {
      LoggerService.error('Get last email error', error: e, stackTrace: stackTrace);
      throw CacheException('Failed to get last email');
    }
  }

  @override
  Future<void> setLastEmail(String email) async {
    try {
      await _sharedPreferences.setString(AppConstants.sharedPrefsLastEmail, email);
    } catch (e, stackTrace) {
      LoggerService.error('Set last email error', error: e, stackTrace: stackTrace);
      throw CacheException('Failed to set last email');
    }
  }

  @override
  Future<void> clearAuthData() async {
    try {
      await Future.wait([
        _sharedPreferences.remove(AppConstants.sharedPrefsRememberMe),
        _sharedPreferences.remove(AppConstants.sharedPrefsLastEmail),
      ]);
    } catch (e, stackTrace) {
      LoggerService.error('Clear auth data error', error: e, stackTrace: stackTrace);
      throw CacheException('Failed to clear auth data');
    }
  }
}
