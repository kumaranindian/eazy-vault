import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/exceptions/app_exception.dart';
import '../../../../core/services/logger_service.dart';

abstract class OnboardingLocalDataSource {
  Future<bool> getHasSeenGettingStarted();
  Future<void> setHasSeenGettingStarted(bool value);
}

class OnboardingLocalDataSourceImpl implements OnboardingLocalDataSource {
  OnboardingLocalDataSourceImpl({required SharedPreferences sharedPreferences})
      : _sharedPreferences = sharedPreferences;

  final SharedPreferences _sharedPreferences;

  @override
  Future<bool> getHasSeenGettingStarted() async {
    try {
      return _sharedPreferences
              .getBool(AppConstants.sharedPrefsHasSeenGettingStarted) ??
          false;
    } catch (e, stackTrace) {
      LoggerService.error('Get has-seen-getting-started error',
          error: e, stackTrace: stackTrace);
      throw CacheException('Failed to read onboarding preference');
    }
  }

  @override
  Future<void> setHasSeenGettingStarted(bool value) async {
    try {
      await _sharedPreferences.setBool(
          AppConstants.sharedPrefsHasSeenGettingStarted, value);
    } catch (e, stackTrace) {
      LoggerService.error('Set has-seen-getting-started error',
          error: e, stackTrace: stackTrace);
      throw CacheException('Failed to save onboarding preference');
    }
  }
}
