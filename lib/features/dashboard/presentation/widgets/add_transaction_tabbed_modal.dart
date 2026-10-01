import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_spacing.dart';
import '../../../../core/constants/breakpoints.dart';
import '../../../../core/widgets/branded_dialog_title.dart';
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
    final screenHeight = MediaQuery.sizeOf(context).height;
    final isMobile = Breakpoints.isMobile(MediaQuery.sizeOf(context).width);

    if (isMobile) {
      return Dialog.fullscreen(
        child: Scaffold(
          appBar: AppBar(
            title: const Text('Add Transaction'),
            bottom: TabBar(
              controller: _tabController,
              tabs: const [
                Tab(icon: Icon(Icons.arrow_upward), text: 'Income'),
                Tab(icon: Icon(Icons.arrow_downward), text: 'Expense'),
              ],
            ),
          ),
          body: TabBarView(
            controller: _tabController,
            children: const [
              AddTransactionDialog(type: TransactionType.income, showDialog: false),
              AddTransactionDialog(type: TransactionType.expense, showDialog: false),
            ],
          ),
        ),
      );
    }

    // Dialog (not AlertDialog) so the tab view can take a bounded height
    // that follows the current viewport: rotation, resize and the keyboard
    // (Dialog subtracts it) all shrink the form area, which then scrolls.
    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: Breakpoints.formMaxWidth),
        child: Padding(
          padding: AppSpacing.paddingLG,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              BrandedDialogTitle(
                title: const Text('Add Transaction'),
                actions: [
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                    tooltip: 'Close',
                  ),
                ],
              ),
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
              Flexible(
                child: SizedBox(
                  height: screenHeight * 0.6,
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
      ),
    );
  }
}
