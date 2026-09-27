import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/config/app_config.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/extensions/double_extensions.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/error_view.dart';
import '../../../../core/widgets/loading_indicator.dart';
import '../providers/accounts_notifier.dart';
import '../widgets/account_card.dart';
import '../widgets/add_account_modal.dart';

class AccountsModal extends ConsumerStatefulWidget {
  const AccountsModal({super.key});

  @override
  ConsumerState<AccountsModal> createState() => _AccountsModalState();
}

class _AccountsModalState extends ConsumerState<AccountsModal> {
  @override
  Widget build(BuildContext context) {
    final accountsState = ref.watch(accountsNotifierProvider);
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    // Responsive sizing
    final bool isMobile = screenWidth < 600;
    final bool isTablet = screenWidth >= 600 && screenWidth < 1024;
    final bool isDesktop = screenWidth >= 1024;

    final double dialogWidth = isMobile
        ? screenWidth * 0.95
        : isTablet
            ? screenWidth * 0.85
            : screenWidth * 0.7;

    final double dialogHeight = isMobile
        ? screenHeight * 0.9
        : isTablet
            ? screenHeight * 0.85
            : screenHeight * 0.8;

    return AlertDialog(
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(
                Icons.account_balance_wallet,
                size: 24,
                color: context.colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Text(
                AppConfig.appName,
                style: context.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: context.colorScheme.primary,
                ),
              ),
              const Spacer(),
              IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close),
                tooltip: 'Close',
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            AppConfig.appTagline,
            style: context.textTheme.bodySmall?.copyWith(
              color: context.colorScheme.onSurface.withOpacity(0.6),
              fontStyle: FontStyle.italic,
            ),
          ),
          const SizedBox(height: 12),
          const Divider(),
          const SizedBox(height: 8),
          Text(
            'All Accounts',
            style: context.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: dialogWidth,
        height: dialogHeight,
        child: accountsState.when(
          initial: () => const LoadingIndicator(),
          loading: () => const LoadingIndicator(),
          error: (failure) => ErrorView(
            message: failure.message,
            onRetry: () => ref.read(accountsNotifierProvider.notifier).refresh(),
          ),
          loaded: (accounts) {
            if (accounts.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.account_balance_wallet_outlined,
                      size: 64,
                      color: context.colorScheme.outline,
                    ),
                    AppSpacing.gapMD,
                    Text(
                      'No Accounts Yet',
                      style: context.textTheme.titleMedium,
                    ),
                    AppSpacing.gapSM,
                    Text(
                      'Create your first account to start tracking your finances',
                      style: context.textTheme.bodyMedium?.copyWith(
                        color: context.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    AppSpacing.gapXL,
                    FilledButton.icon(
                      onPressed: () {
                        showDialog(
                          context: context,
                          builder: (context) => const AddAccountModal(),
                        );
                      },
                      icon: const Icon(Icons.add),
                      label: const Text('Add Account'),
                    ),
                  ],
                ),
              );
            }

            return ListView.builder(
              padding: EdgeInsets.all(isMobile ? 8 : 16),
              itemCount: accounts.length,
              itemBuilder: (context, index) {
                final account = accounts[index];
                return Padding(
                  padding: EdgeInsets.only(
                    bottom: index < accounts.length - 1 ? 8 : 0,
                  ),
                  child: AccountCard(
                    account: account,
                    onTap: () {
                      Navigator.of(context).pop();
                      context.push(
                        RouteConstants.accountDetail.replaceAll(':id', account.id),
                      );
                    },
                  ),
                );
              },
            );
          },
        ),
      ),
      actions: [
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            FilledButton.icon(
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (context) => const AddAccountModal(),
                );
              },
              icon: const Icon(Icons.add),
              label: const Text('Add Account'),
            ),
          ],
        ),
      ],
    );
  }
}
