import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/extensions/date_time_extensions.dart';
import '../../../../core/extensions/double_extensions.dart';
import '../../../../core/widgets/confirmation_dialog.dart';
import '../../../../core/widgets/loading_indicator.dart';
import '../providers/accounts_notifier.dart';

class AccountDetailPage extends ConsumerWidget {
  const AccountDetailPage({
    super.key,
    required this.accountId,
  });

  final String accountId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accountAsync = ref.watch(accountProvider(accountId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Account Details'),
        actions: [
          accountAsync.when(
            data: (account) {
              if (account == null) return const SizedBox.shrink();
              return PopupMenuButton(
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'edit',
                    child: Row(
                      children: [
                        Icon(Icons.edit_outlined),
                        SizedBox(width: 12),
                        Text('Edit'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'delete',
                    child: Row(
                      children: [
                        Icon(Icons.delete_outline, color: Colors.red),
                        SizedBox(width: 12),
                        Text('Delete', style: TextStyle(color: Colors.red)),
                      ],
                    ),
                  ),
                ],
                onSelected: (value) async {
                  if (value == 'edit') {
                    context.push(
                      RouteConstants.editAccount.replaceAll(':id', accountId),
                    );
                  } else if (value == 'delete') {
                    final confirmed = await ConfirmationDialog.show(
                      context,
                      title: 'Delete Account',
                      message:
                          'Are you sure you want to delete this account? This action cannot be undone.',
                      confirmText: 'Delete',
                      isDestructive: true,
                    );

                    if (confirmed && context.mounted) {
                      final success = await ref
                          .read(accountsNotifierProvider.notifier)
                          .deleteAccount(accountId);

                      if (success && context.mounted) {
                        context.showSuccessSnackBar('Account deleted successfully');
                        context.pop();
                      } else if (context.mounted) {
                        final accountsState = ref.read(accountsNotifierProvider);
                        accountsState.whenOrNull(
                          error: (failure) =>
                              context.showErrorSnackBar(failure.message),
                        );
                      }
                    }
                  }
                },
              );
            },
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
          ),
        ],
      ),
      body: accountAsync.when(
        data: (account) {
          if (account == null) {
            return const Center(
              child: Text('Account not found'),
            );
          }

          return ListView(
            padding: AppSpacing.paddingMD,
            children: [
              Card(
                child: Padding(
                  padding: AppSpacing.paddingLG,
                  child: Column(
                    children: [
                      Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          color: Color(account.color).withOpacity(0.2),
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Text(
                            account.icon,
                            style: const TextStyle(fontSize: 40),
                          ),
                        ),
                      ),
                      AppSpacing.gapMD,
                      Text(
                        account.name,
                        style: context.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      AppSpacing.gapXS,
                      Text(
                        account.type.displayName,
                        style: context.textTheme.bodyMedium?.copyWith(
                          color: context.colorScheme.onSurface.withOpacity(0.6),
                        ),
                      ),
                      if (!account.isActive) ...[
                        AppSpacing.gapSM,
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: context.colorScheme.error.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Text(
                            'Inactive',
                            style: context.textTheme.labelMedium?.copyWith(
                              color: context.colorScheme.error,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              AppSpacing.gapMD,
              Card(
                child: Padding(
                  padding: AppSpacing.paddingLG,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Balance',
                        style: context.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      AppSpacing.gapMD,
                      _buildInfoRow(
                        context,
                        'Current Balance',
                        account.currentBalance.toCurrency(),
                        valueColor: account.currentBalance >= 0
                            ? context.colorScheme.primary
                            : context.colorScheme.error,
                        isHighlighted: true,
                        icon: Icons.account_balance_wallet,
                      ),
                      const Divider(height: 24),
                      _buildInfoRow(
                        context,
                        'Opening Balance',
                        account.openingBalance.toCurrency(),
                        valueColor: context.colorScheme.tertiary,
                        icon: Icons.account_balance,
                      ),
                    ],
                  ),
                ),
              ),
              AppSpacing.gapMD,
              Card(
                child: Padding(
                  padding: AppSpacing.paddingLG,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Details',
                        style: context.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      AppSpacing.gapMD,
                      if (account.description != null) ...[
                        _buildInfoRow(
                          context,
                          'Description',
                          account.description!,
                        ),
                        const Divider(height: 24),
                      ],
                      _buildInfoRow(
                        context,
                        'Created',
                        account.createdAt.toFormattedDate(),
                      ),
                      const Divider(height: 24),
                      _buildInfoRow(
                        context,
                        'Last Updated',
                        account.updatedAt.toFormattedDate(),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
        loading: () => const LoadingIndicator(),
        error: (error, stack) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 64, color: Colors.red),
              AppSpacing.gapMD,
              Text(
                'Failed to load account',
                style: context.textTheme.titleMedium,
              ),
              AppSpacing.gapSM,
              Text(
                error.toString(),
                style: context.textTheme.bodySmall,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(
    BuildContext context,
    String label,
    String value, {
    Color? valueColor,
    bool isHighlighted = false,
    IconData? icon,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            if (icon != null) ...[
              Icon(
                icon,
                size: 20,
                color: context.colorScheme.onSurface.withOpacity(0.6),
              ),
              const SizedBox(width: 8),
            ],
            Text(
              label,
              style: context.textTheme.bodyMedium?.copyWith(
                color: context.colorScheme.onSurface.withOpacity(0.6),
              ),
            ),
          ],
        ),
        Text(
          value,
          style: isHighlighted
              ? context.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: valueColor,
                )
              : context.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: valueColor,
                ),
        ),
      ],
    );
  }
}
