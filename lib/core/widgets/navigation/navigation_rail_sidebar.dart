import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../features/authentication/presentation/providers/auth_notifier.dart';
import '../../../features/authentication/presentation/providers/auth_providers.dart';
import '../../config/app_config.dart';
import '../../constants/app_spacing.dart';
import '../sign_out_button.dart';

class NavigationRailSidebar extends ConsumerWidget {
  const NavigationRailSidebar({
    super.key,
    required this.destinations,
    required this.selectedIndex,
    required this.onDestinationSelected,
    this.extended = false,
  });

  final List<NavigationDestination> destinations;
  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;
  final bool extended;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final user = ref.watch(currentUserProvider);

    return NavigationRail(
      extended: extended,
      selectedIndex: selectedIndex,
      onDestinationSelected: onDestinationSelected,
      leading: extended
          ? Padding(
              padding: AppSpacing.paddingMD,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.account_balance_wallet,
                        color: theme.colorScheme.primary,
                        size: 32,
                      ),
                      AppSpacing.gapSM,
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            AppConfig.appName,
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: theme.colorScheme.primary,
                            ),
                          ),
                          Text(
                            AppConfig.appTagline,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color:
                                  theme.colorScheme.onSurface.withOpacity(0.6),
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  AppSpacing.gapXL,
                  if (user != null) ...[
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 20,
                          backgroundColor: theme.colorScheme.primaryContainer,
                          child: Text(
                            user.email?.substring(0, 1).toUpperCase() ?? 'U',
                            style: theme.textTheme.titleMedium?.copyWith(
                              color: theme.colorScheme.onPrimaryContainer,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        AppSpacing.gapSM,
                        // Not Expanded: NavigationRail measures `leading`
                        // under an unbounded width constraint (it sizes
                        // itself from its content), so a flex child here
                        // throws a RenderFlex "unbounded width" layout
                        // exception the moment this rail is actually shown.
                        // A fixed width still lets the Text widgets below
                        // ellipsize instead of overflowing.
                        SizedBox(
                          width: 160,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                user.displayName ?? 'User',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                user.email ?? '',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurface
                                      .withOpacity(0.6),
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    AppSpacing.gapMD,
                    const Divider(),
                  ],
                ],
              ),
            )
          : Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Icon(
                Icons.account_balance_wallet,
                color: theme.colorScheme.primary,
                size: 32,
              ),
            ),
      trailing: extended
          ? Expanded(
              child: Align(
                alignment: Alignment.bottomLeft,
                child: Padding(
                  padding: AppSpacing.paddingMD,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Divider(),
                      AppSpacing.gapSM,
                      const SignOutButton(asListTile: true),
                      AppSpacing.gapSM,
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Text(
                          'v${AppConfig.appVersion}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurface.withOpacity(0.5),
                          ),
                        ),
                      ),
                      AppSpacing.gapSM,
                    ],
                  ),
                ),
              ),
            )
          // Collapsed (tablet) rail: otherwise there's no way to sign out
          // once the user has navigated away from the dashboard.
          : const Padding(
              padding: EdgeInsets.only(bottom: 8),
              child: SignOutButton(),
            ),
      destinations: destinations
          .map(
            (dest) => NavigationRailDestination(
              icon: dest.icon,
              selectedIcon: dest.selectedIcon,
              label: Text(dest.label),
            ),
          )
          .toList(),
    );
  }
}
