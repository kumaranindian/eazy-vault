import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../authentication/presentation/providers/auth_providers.dart';
import '../../data/datasources/onboarding_local_datasource.dart';

part 'onboarding_providers.g.dart';

@Riverpod(keepAlive: true)
Future<OnboardingLocalDataSource> onboardingLocalDataSource(
  OnboardingLocalDataSourceRef ref,
) async {
  final prefs = await ref.watch(sharedPreferencesProvider.future);
  return OnboardingLocalDataSourceImpl(sharedPreferences: prefs);
}
