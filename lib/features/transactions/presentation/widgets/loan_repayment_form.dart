import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/exceptions/app_exception.dart';
import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/utils/currency_utils.dart';
import '../../../accounts/data/models/account_model.dart';
import '../../../accounts/presentation/providers/accounts_notifier.dart';
import '../../../authentication/presentation/providers/auth_providers.dart';
import '../../data/models/transaction_model.dart';
import '../../domain/enums/transaction_type.dart';
import '../../domain/extensions/transaction_extensions.dart';
import '../../domain/models/loan_metadata.dart';
import '../providers/financial_refresh.dart';
import '../providers/loan_providers.dart';
import '../providers/transactions_notifier.dart';
import '../../../../core/utils/error_messages.dart';
import '../../../../core/utils/validators.dart';

class LoanRepaymentForm extends ConsumerStatefulWidget {
  const LoanRepaymentForm({
    super.key,
    required this.loanTransaction,
    this.onSuccess,
  });

  final TransactionModel loanTransaction;
  final VoidCallback? onSuccess;

  @override
  ConsumerState<LoanRepaymentForm> createState() => _LoanRepaymentFormState();
}

class _LoanRepaymentFormState extends ConsumerState<LoanRepaymentForm> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _notesController = TextEditingController();

  String? _accountId;
  DateTime _selectedDate = DateTime.now();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    // Pre-fill with remaining amount
    final loanMetadata = widget.loanTransaction.loanMetadata;
    if (loanMetadata != null) {
      final remaining = loanMetadata.remainingAmount ?? widget.loanTransaction.amount;
      if (remaining > 0 && !remaining.isNaN && remaining.isFinite) {
        _amountController.text = remaining.toStringAsFixed(2);
      }
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _submitRepayment() async {
    if (!_formKey.currentState!.validate()) return;

    if (_accountId == null) {
      context.showErrorSnackBar('Please select an account');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final user = ref.read(currentUserProvider);
      if (user == null) {
        throw const AuthenticationException(ErrorMessages.sessionExpired);
      }

      final repaymentAmount = double.tryParse(_amountController.text.trim()) ?? 0;
      if (repaymentAmount <= 0) {
        context.showErrorSnackBar('Invalid repayment amount');
        return;
      }
      final loanMetadata =
          widget.loanTransaction.loanMetadata ?? const LoanMetadata();
      final isLoanGiven = widget.loanTransaction.type == TransactionType.loanGiven;

      final repaymentMetadata = LoanMetadata(
        partyName: loanMetadata.partyName,
        partyContact: loanMetadata.partyContact,
        linkedLoanId: widget.loanTransaction.id,
        notes: _notesController.text.trim().isEmpty
            ? null
            : _notesController.text.trim(),
      );

      final repaymentTransaction = TransactionModel(
        id: '',
        type: TransactionType.loanRepayment,
        amount: repaymentAmount,
        accountId: _accountId!,
        categoryId: 'loan',
        date: _selectedDate,
        description: isLoanGiven
            ? 'Repayment received from ${loanMetadata.partyName}'
            : 'Repayment made to ${loanMetadata.partyName}',
        vendor: loanMetadata.partyName,
        metadata: repaymentMetadata.toJson(),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        createdBy: user.uid,
      );

      // Records the repayment, the balance change and the loan's remaining
      // amount in one atomic write.
      await ref.read(loanServiceProvider).recordRepayment(
            userId: user.uid,
            repayment: repaymentTransaction,
          );

      refreshFinancialData(ref.invalidate);
      ref.invalidate(transactionsNotifierProvider);

      if (mounted) {
        context.showSuccessSnackBar('Repayment recorded successfully');
        widget.onSuccess?.call();
      }
    } on AppException catch (e) {
      if (mounted) context.showErrorSnackBar(e.message);
    } catch (e) {
      if (mounted) {
        context.showErrorSnackBar(ErrorMessages.from(e, action: 'record repayment'));
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

    final loanMetadata = widget.loanTransaction.loanMetadata;
    if (loanMetadata == null) {
      return const Center(
        child: Text('Invalid loan transaction'),
      );
    }

    final isLoanGiven = widget.loanTransaction.type == TransactionType.loanGiven;
    final originalAmount = loanMetadata.originalAmount ?? widget.loanTransaction.amount;
    final remainingAmount = loanMetadata.remainingAmount ?? widget.loanTransaction.amount;
    final paidAmount = originalAmount - remainingAmount;
    final completionPercentage = originalAmount > 0
        ? ((paidAmount / originalAmount) * 100).clamp(0.0, 100.0)
        : 0.0;

    return Form(
      key: _formKey,
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Row(
              children: [
                Icon(
                  Icons.payment,
                  color: context.colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Record Repayment',
                    style: context.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  tooltip: 'Close',
                  onPressed: _isLoading ? null : () => Navigator.of(context).maybePop(),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Loan Summary Card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          isLoanGiven ? Icons.arrow_upward : Icons.arrow_downward,
                          color: isLoanGiven ? Colors.red : Colors.green,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            loanMetadata.partyName ?? 'Unknown',
                            style: context.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: _getStatusColor(loanMetadata.status).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            loanMetadata.status.displayName,
                            style: TextStyle(
                              color: _getStatusColor(loanMetadata.status),
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Flexible(
                          child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Original Amount',
                              style: context.textTheme.bodySmall,
                            ),
                            Text(
                              CurrencyUtils.format(originalAmount),
                              style: context.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        ),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              'Remaining',
                              style: context.textTheme.bodySmall,
                            ),
                            Text(
                              CurrencyUtils.format(remainingAmount),
                              style: context.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: Colors.orange,
                              ),
                              textAlign: TextAlign.end,
                            ),
                          ],
                        ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    // Progress Bar
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Progress',
                              style: context.textTheme.bodySmall,
                            ),
                            Text(
                              '${completionPercentage.toStringAsFixed(1)}%',
                              style: context.textTheme.bodySmall?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        LinearProgressIndicator(
                          value: completionPercentage / 100,
                          backgroundColor: context.colorScheme.surfaceContainerHighest,
                          minHeight: 8,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ],
                    ),
                    if (loanMetadata.dueDate != null) ...[
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Icon(
                            Icons.event,
                            size: 16,
                            color: context.colorScheme.onSurfaceVariant,
                          ),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                            'Due: ${loanMetadata.dueDate!.day}/${loanMetadata.dueDate!.month}/${loanMetadata.dueDate!.year}',
                            style: context.textTheme.bodySmall,
                          ),
                          ),
                          if (widget.loanTransaction.isOverdue) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.red.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text(
                                'OVERDUE',
                                style: TextStyle(
                                  color: Colors.red,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Repayment Amount
            TextFormField(
              controller: _amountController,
              decoration: InputDecoration(
                labelText: 'Repayment Amount',
                prefixIcon: const Icon(Icons.currency_rupee),
                border: const OutlineInputBorder(),
                helperText: 'Max: ${CurrencyUtils.format(remainingAmount)}',
              ),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
              ],
              validator: (value) {
                final error = Validators.positiveAmount(value);
                if (error != null) return error;
                final amount = double.parse(value!.trim());
                if (amount > remainingAmount) {
                  return 'Amount exceeds remaining balance';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            // Quick Amount Buttons
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (remainingAmount >= 100)
                  _QuickAmountChip(
                    label: '₹100',
                    onTap: () => _amountController.text = '100',
                  ),
                if (remainingAmount >= 500)
                  _QuickAmountChip(
                    label: '₹500',
                    onTap: () => _amountController.text = '500',
                  ),
                if (remainingAmount >= 1000)
                  _QuickAmountChip(
                    label: '₹1000',
                    onTap: () => _amountController.text = '1000',
                  ),
                _QuickAmountChip(
                  label: 'Full Amount',
                  onTap: () => _amountController.text = remainingAmount.toStringAsFixed(2),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Account Selection
            DropdownButtonFormField<String>(
              isExpanded: true,
              value: _accountId,
              decoration: const InputDecoration(
                labelText: 'Account',
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
                    ],
                  ),
                );
              }).toList(),
              onChanged: (value) => setState(() => _accountId = value),
              validator: (value) =>
                  value == null ? 'Please select an account' : null,
            ),
            const SizedBox(height: 16),

            // Payment Date
            InkWell(
              onTap: () async {
                final date = await showDatePicker(
                  context: context,
                  initialDate: _selectedDate,
                  firstDate: widget.loanTransaction.date,
                  lastDate: DateTime.now(),
                );
                if (date != null) {
                  setState(() => _selectedDate = date);
                }
              },
              child: InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'Payment Date',
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
            FilledButton.icon(
              onPressed: _isLoading ? null : _submitRepayment,
              icon: _isLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.check),
              label: Text(_isLoading ? 'Recording...' : 'Record Repayment'),
            ),
          ],
        ),
      ),
    );
  }

  Color _getStatusColor(LoanStatus status) {
    switch (status) {
      case LoanStatus.pending:
        return Colors.orange;
      case LoanStatus.partial:
        return Colors.blue;
      case LoanStatus.completed:
        return Colors.green;
      case LoanStatus.overdue:
        return Colors.red;
    }
  }
}

class _QuickAmountChip extends StatelessWidget {
  const _QuickAmountChip({
    required this.label,
    required this.onTap,
  });

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      label: Text(label),
      onPressed: onTap,
    );
  }
}
