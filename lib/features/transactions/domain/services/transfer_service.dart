import '../../../../core/exceptions/app_exception.dart';
import '../../../../core/services/logger_service.dart';
import '../../data/models/transaction_model.dart';
import '../enums/transaction_type.dart';
import '../extensions/transaction_extensions.dart';
import '../models/loan_metadata.dart';
import 'account_balance_service.dart';
import '../../../../core/utils/error_messages.dart';

/// Category id stored on transfer transactions (not a real category document).
const String transferCategoryId = 'transfer';

class TransferService {
  TransferService({required AccountBalanceService balanceService})
      : _balanceService = balanceService;

  final AccountBalanceService _balanceService;

  /// Moves [amount] between two accounts and records the transfer.
  ///
  /// The transaction record and both balance changes are written atomically.
  Future<TransactionModel> createTransfer({
    required String userId,
    required String fromAccountId,
    required String toAccountId,
    required double amount,
    required DateTime date,
    String? description,
  }) async {
    try {
      LoggerService.info('Creating transfer transaction');

      if (fromAccountId == toAccountId) {
        throw const ValidationException('Cannot transfer to the same account');
      }

      if (amount <= 0) {
        throw const ValidationException('Transfer amount must be positive');
      }

      final now = DateTime.now();
      final transaction = TransactionModel(
        id: '',
        type: TransactionType.transfer,
        amount: amount,
        accountId: fromAccountId,
        categoryId: transferCategoryId,
        date: date,
        description: description ?? 'Transfer',
        metadata: TransferMetadata(
          fromAccountId: fromAccountId,
          toAccountId: toAccountId,
          notes: description,
        ).toJson(),
        createdAt: now,
        updatedAt: now,
        createdBy: userId,
      );

      final created = await _balanceService.createTransaction(
        userId,
        transaction,
        nonNegativeAccountId: fromAccountId,
      );

      LoggerService.info('Transfer completed successfully');
      return created;
    } catch (e, stackTrace) {
      LoggerService.error('Transfer error', error: e, stackTrace: stackTrace);
      if (e is AppException) rethrow;
      throw ServerException(ErrorMessages.from(e, action: 'create transfer'));
    }
  }

  /// Reverse a transfer transaction by recording an opposite transfer.
  Future<TransactionModel> reverseTransfer({
    required String userId,
    required TransactionModel transferTransaction,
  }) async {
    if (transferTransaction.type != TransactionType.transfer) {
      throw const ValidationException('Not a transfer transaction');
    }

    final metadata = transferTransaction.transferMetadata;
    if (metadata == null) {
      throw const ValidationException('Transfer metadata not found');
    }

    return createTransfer(
      userId: userId,
      fromAccountId: metadata.toAccountId,
      toAccountId: metadata.fromAccountId,
      amount: transferTransaction.amount,
      date: DateTime.now(),
      description: 'Reversal: ${transferTransaction.description ?? "Transfer"}',
    );
  }
}
