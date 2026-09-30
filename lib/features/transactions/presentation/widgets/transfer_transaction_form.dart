import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/exceptions/app_exception.dart';
import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/extensions/double_extensions.dart';
import '../../../../core/widgets/loading_indicator.dart';
import '../../../accounts/data/models/account_model.dart';
import '../../../accounts/presentation/providers/accounts_notifier.dart';
import '../../../authentication/presentation/providers/auth_providers.dart';
import '../providers/financial_refresh.dart';
import '../providers/transactions_notifier.dart';
import '../providers/transfer_providers.dart';
import '../../../../core/utils/error_messages.dart';
import '../../../../core/utils/validators.dart';

class TransferTransactionForm extends ConsumerStatefulWidget {
  const TransferTransactionForm({
    super.key,
    this.onSuccess,
  });

  final VoidCallback? onSuccess;

  @override
  ConsumerState<TransferTransactionForm> createState() =>
      _TransferTransactionFormState();
}

class _TransferTransactionFormState
    extends ConsumerState<TransferTransactionForm> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _notesController = TextEditingController();

  String? _fromAccountId;
  String? _toAccountId;
  DateTime _selectedDate = DateTime.now();
  bool _isLoading = false;

  @override
  void dispose() {
    _amountController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _submitTransfer() async {
    if (!_formKey.currentState!.validate()) return;

    if (_fromAccountId == null || _toAccountId == null) {
      context.showErrorSnackBar('Please select both accounts');
      return;
    }

    if (_fromAccountId == _toAccountId) {
      context.showErrorSnackBar('Cannot transfer to the same account');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final user = ref.read(currentUserProvider);
      if (user == null) {
        throw const AuthenticationException(ErrorMessages.sessionExpired);
      }

      final amount = double.tryParse(_amountController.text.trim()) ?? 0;
      if (amount <= 0) {
        context.showErrorSnackBar('Invalid transfer amount');
        return;
      }

      final notes = _notesController.text.trim();

      // Records the transfer and moves both balances in one atomic write.
      await ref.read(transferServiceProvider).createTransfer(
            userId: user.uid,
            fromAccountId: _fromAccountId!,
            toAccountId: _toAccountId!,
            amount: amount,
            date: _selectedDate,
            description: notes.isEmpty ? null : notes,
          );

      refreshFinancialData(ref.invalidate);
      ref.invalidate(transactionsNotifierProvider);

      if (mounted) {
        context.showSuccessSnackBar('Transfer completed successfully');
        widget.onSuccess?.call();
      }
    } on AppException catch (e) {
      if (mounted) context.showErrorSnackBar(e.message);
    } catch (e) {
      if (mounted) {
        context.showErrorSnackBar(ErrorMessages.from(e, action: 'create transfer'));
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final accountsState = ref.watch(accountsNotifierProvider);
    final accounts = accountsState.maybeWhen(
      loaded: (accounts) => accounts.where((a) => a.isActive).toList(),
      orElse: () => <AccountModel>[],
    );

    return Form(
      key: _formKey,
      child: SingleChildScrollView(
        child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // From Account
          DropdownButtonFormField<String>(
            isExpanded: true,
            value: _fromAccountId,
            decoration: const InputDecoration(
              labelText: 'From Account',
              prefixIcon: Icon(Icons.account_balance_wallet),
              border: OutlineInputBorder(),
            ),
            items: accounts.map((account) {
              return DropdownMenuItem(
                value: account.id,
                child: Row(
                  children: [
                    Text(account.type.icon),
                    const SizedBox(width: 8),
                    Expanded(child: Text(account.name)),
                    Text(
                      account.currentBalance.toCurrency(),
                      style: TextStyle(
                        color: account.currentBalance >= 0
                            ? Colors.green
                            : Colors.red,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
            onChanged: _isLoading
                ? null
                : (value) => setState(() => _fromAccountId = value),
            validator: (value) =>
                value == null ? 'Please select source account' : null,
          ),
          const SizedBox(height: 16),

          // Transfer Icon
          Center(
            child: Icon(
              Icons.arrow_downward,
              color: context.colorScheme.primary,
              size: 32,
            ),
          ),
          const SizedBox(height: 16),

          // To Account
          DropdownButtonFormField<String>(
            isExpanded: true,
            value: _toAccountId,
            decoration: const InputDecoration(
              labelText: 'To Account',
              prefixIcon: Icon(Icons.account_balance),
              border: OutlineInputBorder(),
            ),
            items: accounts.map((account) {
              return DropdownMenuItem(
                value: account.id,
                child: Row(
                  children: [
                    Text(account.type.icon),
                    const SizedBox(width: 8),
                    Expanded(child: Text(account.name)),
                    Text(
                      account.currentBalance.toCurrency(),
                      style: TextStyle(
                        color: account.currentBalance >= 0
                            ? Colors.green
                            : Colors.red,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
            onChanged: _isLoading
                ? null
                : (value) => setState(() => _toAccountId = value),
            validator: (value) {
              if (value == null) return 'Please select destination account';
              if (value == _fromAccountId) {
                return 'Choose a different account than the source';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),

          // Amount
          TextFormField(
            controller: _amountController,
            decoration: const InputDecoration(
              labelText: 'Amount',
              prefixIcon: Icon(Icons.currency_rupee),
              border: OutlineInputBorder(),
            ),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
            ],
            validator: Validators.positiveAmount,
          ),
          const SizedBox(height: 16),

          // Date
          InkWell(
            onTap: () async {
              final date = await showDatePicker(
                context: context,
                initialDate: _selectedDate,
                firstDate: DateTime(2000),
                lastDate: DateTime.now(),
              );
              if (date != null) {
                setState(() => _selectedDate = date);
              }
            },
            child: InputDecorator(
              decoration: const InputDecoration(
                labelText: 'Date',
                prefixIcon: Icon(Icons.calendar_today),
                border: OutlineInputBorder(),
              ),
              child: Text(
                '${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year}',
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Notes
          TextFormField(
            controller: _notesController,
            decoration: const InputDecoration(
              labelText: 'Notes (Optional)',
              prefixIcon: Icon(Icons.note),
              border: OutlineInputBorder(),
            ),
            maxLines: 2,
          ),
          const SizedBox(height: 24),

          // Submit Button
          FilledButton(
            onPressed: _isLoading ? null : _submitTransfer,
            child: _isLoading
                ? const ButtonProgress(label: 'Transferring...')
                : const Text('Transfer'),
          ),
        ],
      ),
      ),
    );
  }
}
