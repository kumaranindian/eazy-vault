import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'onboarding_providers.dart';

part 'onboarding_notifier.g.dart';

/// Whether the current device has already seen the "Getting Started"
/// welcome prompt. Stored locally (`SharedPreferences`), the same way
/// `rememberMe`/`notificationsEnabled` already are — this app has no other
/// per-user preferences mechanism, and it isn't worth a Firestore round
/// trip for a one-time UI flag. Known limitation: it's per-device, not
/// per-account, so a new browser/device shows the prompt again.
@riverpod
class HasSeenGettingStartedNotifier extends _$HasSeenGettingStartedNotifier {
  @override
  Future<bool> build() async {
    final dataSource =
        await ref.watch(onboardingLocalDataSourceProvider.future);
    return dataSource.getHasSeenGettingStarted();
  }

  Future<void> markSeen() async {
    final dataSource = await ref.read(onboardingLocalDataSourceProvider.future);
    await dataSource.setHasSeenGettingStarted(true);
    state = const AsyncData(true);
  }
}
