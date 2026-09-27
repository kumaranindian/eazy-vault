import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/config/app_config.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/extensions/context_extensions.dart';
import '../../../transactions/domain/enums/transaction_type.dart';
import 'add_transaction_dialog.dart';

class AddTransactionTabbedModal extends ConsumerStatefulWidget {
  const AddTransactionTabbedModal({super.key});

  @override
  ConsumerState<AddTransactionTabbedModal> createState() => _AddTransactionTabbedModalState();
}

class _AddTransactionTabbedModalState extends ConsumerState<AddTransactionTabbedModal>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
            'Add Transaction',
            style: context.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: 500,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TabBar(
              controller: _tabController,
              tabs: const [
                Tab(
                  icon: Icon(Icons.arrow_upward),
                  text: 'Income',
                ),
                Tab(
                  icon: Icon(Icons.arrow_downward),
                  text: 'Expense',
                ),
              ],
            ),
            AppSpacing.gapMD,
            Expanded(
              child: SizedBox(
                height: MediaQuery.of(context).size.height * 0.6,
                child: TabBarView(
                  controller: _tabController,
                  children: const [
                    AddTransactionDialog(type: TransactionType.income, showDialog: false),
                    AddTransactionDialog(type: TransactionType.expense, showDialog: false),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
