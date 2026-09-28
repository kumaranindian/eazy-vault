import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/extensions/context_extensions.dart';
import '../../../accounts/data/models/account_model.dart';
import '../../../accounts/presentation/providers/accounts_notifier.dart';
import '../../../authentication/presentation/providers/auth_providers.dart';
import '../../data/models/transaction_model.dart';
import '../../domain/enums/transaction_type.dart';
import '../../domain/models/loan_metadata.dart';
import '../providers/transactions_notifier.dart';

class LoanTransactionForm extends ConsumerStatefulWidget {
  const LoanTransactionForm({
    super.key,
    required this.loanType,
    this.onSuccess,
  });

  final TransactionType loanType; // loanGiven or loanTaken
  final VoidCallback? onSuccess;

  @override
  ConsumerState<LoanTransactionForm> createState() =>
      _LoanTransactionFormState();
}

class _LoanTransactionFormState extends ConsumerState<LoanTransactionForm> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _partyNameController = TextEditingController();
  final _partyContactController = TextEditingController();
  final _interestRateController = TextEditingController();
  final _notesController = TextEditingController();

  String? _accountId;
  DateTime _selectedDate = DateTime.now();
  DateTime? _dueDate;
  bool _hasInterest = false;
  bool _hasInstallments = false;
  int _numberOfInstallments = 2;
  bool _isLoading = false;

  @override
  void dispose() {
    _amountController.dispose();
    _partyNameController.dispose();
    _partyContactController.dispose();
    _interestRateController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  List<LoanInstallment> _generateInstallments() {
    if (!_hasInstallments || _dueDate == null) return [];

    final installments = <LoanInstallment>[];
    final amount = double.tryParse(_amountController.text.trim()) ?? 0;
    if (amount <= 0) return [];
    final installmentAmount = amount / _numberOfInstallments;

    final daysBetween = _dueDate!.difference(_selectedDate).inDays;
    final daysPerInstallment = daysBetween / _numberOfInstallments;

    for (int i = 0; i < _numberOfInstallments; i++) {
      final dueDate = _selectedDate.add(
        Duration(days: ((i + 1) * daysPerInstallment).round()),
      );

      installments.add(LoanInstallment(
        dueDate: dueDate,
        amount: installmentAmount,
        isPaid: false,
      ));
    }

    return installments;
  }

  Future<void> _submitLoan() async {
    if (!_formKey.currentState!.validate()) return;

    if (_accountId == null) {
      context.showErrorSnackBar('Please select an account');
      return;
    }

    if (_partyNameController.text.trim().isEmpty) {
      context.showErrorSnackBar('Please enter party name');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final user = ref.read(currentUserProvider);
      if (user == null) throw Exception('User not authenticated');

      final amount = double.tryParse(_amountController.text.trim()) ?? 0;
      if (amount <= 0) {
        context.showErrorSnackBar('Invalid loan amount');
        return;
      }

      final interestRate = _hasInterest && _interestRateController.text.isNotEmpty
          ? double.tryParse(_interestRateController.text.trim())
          : null;

      final loanMetadata = LoanMetadata(
        partyName: _partyNameController.text.trim(),
        partyContact: _partyContactController.text.trim().isEmpty
            ? null
            : _partyContactController.text.trim(),
        dueDate: _dueDate,
        interestRate: interestRate,
        status: LoanStatus.pending,
        originalAmount: amount,
        remainingAmount: amount,
        notes: _notesController.text.trim().isEmpty
            ? null
            : _notesController.text.trim(),
        installments: _hasInstallments ? _generateInstallments() : null,
      );

      final transaction = TransactionModel(
        id: '',
        type: widget.loanType,
        amount: amount,
        accountId: _accountId!,
        categoryId: 'loan', // Special category for loans
        date: _selectedDate,
        description: widget.loanType == TransactionType.loanGiven
            ? 'Loan given to ${_partyNameController.text.trim()}'
            : 'Loan taken from ${_partyNameController.text.trim()}',
        vendor: _partyNameController.text.trim(),
        metadata: loanMetadata.toJson(),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        createdBy: user.uid,
      );

      // The notifier refreshes balances and loan data on success.
      final failure = await ref
          .read(transactionsNotifierProvider.notifier)
          .createTransaction(transaction);

      if (failure != null) {
        if (mounted) context.showErrorSnackBar(failure.message);
        return;
      }

      if (mounted) {
        context.showSuccessSnackBar(
          widget.loanType == TransactionType.loanGiven
              ? 'Loan given recorded successfully'
              : 'Loan taken recorded successfully',
        );
        widget.onSuccess?.call();
      }
    } catch (e) {
      if (mounted) {
        context.showErrorSnackBar('Failed to record loan: ${e.toString()}');
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

    final isLoanGiven = widget.loanType == TransactionType.loanGiven;
    final title = isLoanGiven ? 'Loan Given' : 'Loan Taken';
    final partyLabel = isLoanGiven ? 'Borrower Name' : 'Lender Name';
    final partyHint = isLoanGiven ? 'Who are you lending to?' : 'Who are you borrowing from?';

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
                  isLoanGiven ? Icons.arrow_upward : Icons.arrow_downward,
                  color: isLoanGiven ? Colors.red : Colors.green,
                ),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: context.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Party Name
            TextFormField(
              controller: _partyNameController,
              decoration: InputDecoration(
                labelText: partyLabel,
                hintText: partyHint,
                prefixIcon: const Icon(Icons.person),
                border: const OutlineInputBorder(),
              ),
              textCapitalization: TextCapitalization.words,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter $partyLabel';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            // Party Contact (Optional)
            TextFormField(
              controller: _partyContactController,
              decoration: const InputDecoration(
                labelText: 'Contact (Optional)',
                hintText: 'Phone or email',
                prefixIcon: Icon(Icons.contact_phone),
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: 16),

            // Amount
            TextFormField(
              controller: _amountController,
              decoration: const InputDecoration(
                labelText: 'Loan Amount',
                prefixIcon: Icon(Icons.currency_rupee),
                border: OutlineInputBorder(),
              ),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
              ],
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter amount';
                }
                final amount = double.tryParse(value);
                if (amount == null || amount <= 0) {
                  return 'Please enter a valid amount';
                }
                return null;
              },
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
                  labelText: 'Loan Date',
                  prefixIcon: Icon(Icons.calendar_today),
                  border: OutlineInputBorder(),
                ),
                child: Text(
                  '${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year}',
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Due Date
            InkWell(
              onTap: () async {
                final date = await showDatePicker(
                  context: context,
                  initialDate: _dueDate ?? DateTime.now().add(const Duration(days: 30)),
                  firstDate: _selectedDate,
                  lastDate: DateTime(2100),
                );
                if (date != null) {
                  setState(() => _dueDate = date);
                }
              },
              child: InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'Due Date (Optional)',
                  prefixIcon: Icon(Icons.event),
                  border: OutlineInputBorder(),
                ),
                child: Text(
                  _dueDate == null
                      ? 'Select due date'
                      : '${_dueDate!.day}/${_dueDate!.month}/${_dueDate!.year}',
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Interest Rate Toggle
            SwitchListTile(
              title: const Text('Add Interest Rate'),
              value: _hasInterest,
              onChanged: (value) => setState(() => _hasInterest = value),
              contentPadding: EdgeInsets.zero,
            ),

            // Interest Rate Field
            if (_hasInterest) ...[
              const SizedBox(height: 8),
              TextFormField(
                controller: _interestRateController,
                decoration: const InputDecoration(
                  labelText: 'Interest Rate (%)',
                  prefixIcon: Icon(Icons.percent),
                  border: OutlineInputBorder(),
                  hintText: 'e.g., 5.5',
                ),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
                ],
                validator: _hasInterest
                    ? (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter interest rate';
                        }
                        final rate = double.tryParse(value);
                        if (rate == null || rate < 0 || rate > 100) {
                          return 'Please enter a valid rate (0-100)';
                        }
                        return null;
                      }
                    : null,
              ),
              const SizedBox(height: 16),
            ],

            // Installments Toggle
            SwitchListTile(
              title: const Text('Split into Installments'),
              value: _hasInstallments,
              onChanged: _dueDate == null
                  ? null
                  : (value) => setState(() => _hasInstallments = value),
              contentPadding: EdgeInsets.zero,
              subtitle: _dueDate == null
                  ? const Text('Please set due date first', style: TextStyle(color: Colors.red))
                  : null,
            ),

            // Number of Installments
            if (_hasInstallments) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  const Text('Number of Installments:'),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.remove),
                    onPressed: _numberOfInstallments > 2
                        ? () => setState(() => _numberOfInstallments--)
                        : null,
                  ),
                  Text(
                    '$_numberOfInstallments',
                    style: context.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.add),
                    onPressed: _numberOfInstallments < 12
                        ? () => setState(() => _numberOfInstallments++)
                        : null,
                  ),
                ],
              ),
              const SizedBox(height: 16),
            ],

            // Notes
            TextFormField(
              controller: _notesController,
              decoration: const InputDecoration(
                labelText: 'Notes (Optional)',
                prefixIcon: Icon(Icons.note),
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 24),

            // Submit Button
            FilledButton.icon(
              onPressed: _isLoading ? null : _submitLoan,
              icon: _isLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Icon(isLoanGiven ? Icons.arrow_upward : Icons.arrow_downward),
              label: Text(_isLoading ? 'Recording...' : 'Record $title'),
            ),
          ],
        ),
      ),
    );
  }
}
