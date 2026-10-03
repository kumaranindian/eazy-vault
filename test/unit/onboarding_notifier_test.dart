import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:eazyvault/features/authentication/presentation/providers/auth_providers.dart';
import 'package:eazyvault/features/onboarding/presentation/providers/onboarding_notifier.dart';

void main() {
  group('HasSeenGettingStartedNotifier', () {
    test('defaults to false on a fresh install', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final container = ProviderContainer(
        overrides: [sharedPreferencesProvider.overrideWith((ref) async => prefs)],
      );
      addTearDown(container.dispose);

      final hasSeen = await container.read(hasSeenGettingStartedNotifierProvider.future);

      expect(hasSeen, isFalse);
    });

    test('markSeen persists so a later read (e.g. after app restart) sees true', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final container = ProviderContainer(
        overrides: [sharedPreferencesProvider.overrideWith((ref) async => prefs)],
      );
      addTearDown(container.dispose);

      await container.read(hasSeenGettingStartedNotifierProvider.future);
      await container
          .read(hasSeenGettingStartedNotifierProvider.notifier)
          .markSeen();

      expect(
        container.read(hasSeenGettingStartedNotifierProvider).value,
        isTrue,
      );

      // A fresh container simulates the next app launch, reading from the
      // same underlying SharedPreferences instance rather than in-memory
      // provider state.
      final restarted = ProviderContainer(
        overrides: [sharedPreferencesProvider.overrideWith((ref) async => prefs)],
      );
      addTearDown(restarted.dispose);

      final hasSeenAfterRestart =
          await restarted.read(hasSeenGettingStartedNotifierProvider.future);

      expect(hasSeenAfterRestart, isTrue);
    });
  });
}
