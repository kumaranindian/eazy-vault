import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/exceptions/app_exception.dart';
import '../../../../core/services/logger_service.dart';
import '../../data/models/transaction_model.dart';
import '../enums/transaction_type.dart';
import '../models/loan_metadata.dart';
import '../../../../core/utils/error_messages.dart';

/// Writes transactions together with their effect on account balances.
///
/// Every write happens inside a single Firestore transaction so a transaction
/// document can never be stored without its balance change (or vice versa).
///
/// Balance effect per type:
/// - income, loanTaken: +amount on `accountId`
/// - expense, loanGiven: -amount on `accountId`
/// - transfer: -amount on `fromAccountId`, +amount on `toAccountId`
/// - loanRepayment: +amount when repaying a loan you gave (money received),
///   -amount when repaying a loan you took (money paid). A repayment also
///   reduces the linked loan's `remainingAmount` and updates its status.
class AccountBalanceService {
  AccountBalanceService({required FirebaseFirestore firestore})
      : _firestore = firestore;

  final FirebaseFirestore _firestore;

  static const double _epsilon = 0.005;

  CollectionReference<Map<String, dynamic>> _accounts(String userId) =>
      _firestore
          .collection(AppConstants.userCollection)
          .doc(userId)
          .collection(AppConstants.accountsCollection);

  CollectionReference<Map<String, dynamic>> _transactions(String userId) =>
      _firestore
          .collection(AppConstants.userCollection)
          .doc(userId)
          .collection(AppConstants.transactionsCollection);

  /// Stores [transaction] and applies its balance effect atomically.
  ///
  /// When [nonNegativeAccountId] is set, the write is rejected if that
  /// account's balance would drop below zero.
  Future<TransactionModel> createTransaction(
    String userId,
    TransactionModel transaction, {
    String? nonNegativeAccountId,
  }) async {
    final docRef = _transactions(userId).doc();
    final created = transaction.copyWith(id: docRef.id);

    await _run('create transaction', () {
      return _firestore.runTransaction((firestoreTransaction) async {
        final effects = _Effects();
        await _collectEffects(firestoreTransaction, userId, created, 1, effects);
        final balances =
            await _readBalances(firestoreTransaction, userId, effects.deltas.keys);

        final newBalances = _applyDeltas(balances, effects.deltas);
        if (nonNegativeAccountId != null &&
            (newBalances[nonNegativeAccountId] ?? 0) < -_epsilon) {
          throw const ValidationException('Insufficient balance in source account');
        }

        firestoreTransaction.set(docRef, created.toFirestore());
        _writeBalances(firestoreTransaction, userId, newBalances);
        _writeLoanUpdates(firestoreTransaction, effects);
      });
    });

    LoggerService.info('Transaction created: ${created.id}');
    return created;
  }

  /// Updates an income/expense transaction and moves the balance difference
  /// atomically. The stored version is used as the "old" state, so stale
  /// client copies can't corrupt balances. Transfers and loans can't be edited.
  Future<TransactionModel> updateTransaction(
    String userId,
    TransactionModel transaction,
  ) async {
    final docRef = _transactions(userId).doc(transaction.id);
    late TransactionModel updated;

    await _run('update transaction', () {
      return _firestore.runTransaction((firestoreTransaction) async {
        final storedDoc = await firestoreTransaction.get(docRef);
        if (!storedDoc.exists) {
          throw const NotFoundException('Transaction not found');
        }
        final stored = TransactionModel.fromFirestore(storedDoc);
        if (stored.isDeleted) {
          throw const NotFoundException('Transaction has been deleted');
        }
        if (!isEditableType(stored.type) || !isEditableType(transaction.type)) {
          throw const ValidationException(
            'Transfers and loans cannot be edited. Delete and re-create them instead.',
          );
        }

        updated = transaction.copyWith(
          metadata: stored.metadata,
          createdAt: stored.createdAt,
          createdBy: stored.createdBy,
          isDeleted: false,
          updatedAt: DateTime.now(),
        );

        final effects = _Effects();
        await _collectEffects(firestoreTransaction, userId, stored, -1, effects);
        await _collectEffects(firestoreTransaction, userId, updated, 1, effects);
        final balances =
            await _readBalances(firestoreTransaction, userId, effects.deltas.keys);

        firestoreTransaction.update(docRef, updated.toFirestore());
        _writeBalances(firestoreTransaction, userId, _applyDeltas(balances, effects.deltas));
      });
    });

    LoggerService.info('Transaction updated: ${transaction.id}');
    return updated;
  }

  /// Soft-deletes a transaction and reverts its balance effect atomically.
  /// Deleting an already-deleted transaction is a no-op.
  Future<void> deleteTransaction(String userId, String transactionId) async {
    final docRef = _transactions(userId).doc(transactionId);

    await _run('delete transaction', () {
      return _firestore.runTransaction((firestoreTransaction) async {
        final storedDoc = await firestoreTransaction.get(docRef);
        if (!storedDoc.exists) {
          throw const NotFoundException('Transaction not found');
        }
        final stored = TransactionModel.fromFirestore(storedDoc);
        if (stored.isDeleted) return;

        if (stored.type == TransactionType.loanGiven ||
            stored.type == TransactionType.loanTaken) {
          final loan = _loanMetadataOf(stored);
          final original = loan?.originalAmount ?? stored.amount;
          final remaining = loan?.remainingAmount ?? original;
          if (remaining < original - _epsilon) {
            throw const ValidationException(
              'This loan has repayments. Delete its repayments first.',
            );
          }
        }

        final effects = _Effects();
        await _collectEffects(firestoreTransaction, userId, stored, -1, effects);
        final balances =
            await _readBalances(firestoreTransaction, userId, effects.deltas.keys);

        firestoreTransaction.update(docRef, {
          AppConstants.isDeletedField: true,
          AppConstants.updatedAtField: Timestamp.now(),
        });
        _writeBalances(firestoreTransaction, userId, _applyDeltas(balances, effects.deltas));
        _writeLoanUpdates(firestoreTransaction, effects);
      });
    });

    LoggerService.info('Transaction deleted: $transactionId');
  }

  /// Rebuilds every account's stored `currentBalance` from its
  /// `openingBalance` plus the effect of all non-deleted transactions, using
  /// the same rules as live writes. Repairs balances corrupted by earlier
  /// versions of the app. Only accounts whose balance differs are written.
  ///
  /// Transactions whose effect can't be determined are left out: transfers
  /// that lost their destination account (older app versions erased it when a
  /// transfer was edited) are returned in `brokenTransfers` so the user can
  /// pick the destination with [setTransferDestination]; anything else is
  /// counted in `skipped`.
  Future<BalanceRecalculation> recalculateBalances(String userId) async {
    final corrections = <BalanceCorrection>[];
    final brokenTransfers = <TransactionModel>[];
    var skipped = 0;

    await _run('recalculate balances', () async {
      final transactionDocs = await _transactions(userId).get();
      final all = <String, TransactionModel>{};
      for (final doc in transactionDocs.docs) {
        try {
          all[doc.id] = TransactionModel.fromFirestore(doc);
        } catch (e) {
          skipped++;
        }
      }

      final effects = _Effects();
      for (final transaction in all.values) {
        if (transaction.isDeleted) continue;
        if (transaction.type == TransactionType.transfer &&
            transaction.metadata?['toAccountId'] == null) {
          brokenTransfers.add(transaction);
          continue;
        }
        try {
          if (transaction.type == TransactionType.loanRepayment) {
            final loanId = transaction.metadata?['linkedLoanId'] as String?;
            final loan = loanId == null ? null : all[loanId];
            if (loan == null) {
              skipped++;
              continue;
            }
            effects.add(
              transaction.accountId,
              _repaymentDirection(loan.type) * transaction.amount,
            );
          } else {
            _addBalanceEffects(transaction, 1, effects);
          }
        } catch (e) {
          skipped++;
        }
      }

      final accountDocs = await _accounts(userId).get();
      await _firestore.runTransaction((firestoreTransaction) async {
        // Firestore may retry this callback; start from a clean list.
        corrections.clear();
        final fresh = <String, Map<String, dynamic>>{};
        for (final doc in accountDocs.docs) {
          final snapshot = await firestoreTransaction.get(doc.reference);
          if (snapshot.exists) fresh[doc.id] = snapshot.data()!;
        }

        for (final entry in fresh.entries) {
          final data = entry.value;
          final opening = (data['openingBalance'] as num?)?.toDouble() ?? 0;
          final current = (data['currentBalance'] as num?)?.toDouble() ?? 0;
          final expected = opening + (effects.deltas[entry.key] ?? 0);
          if ((expected - current).abs() > _epsilon) {
            corrections.add(BalanceCorrection(
              accountId: entry.key,
              accountName: data['name'] as String? ?? entry.key,
              previousBalance: current,
              correctedBalance: expected,
            ));
            firestoreTransaction.update(_accounts(userId).doc(entry.key), {
              'currentBalance': expected,
              AppConstants.updatedAtField: Timestamp.now(),
            });
          }
        }
      });
    });

    LoggerService.info(
      'Recalculated balances: ${corrections.length} corrected, $skipped skipped',
    );
    brokenTransfers.sort((a, b) => b.date.compareTo(a.date));
    return BalanceRecalculation(
      corrections: corrections,
      brokenTransfers: brokenTransfers,
      skipped: skipped,
    );
  }

  /// Restores the destination of a transfer whose metadata was lost. Only
  /// the transfer record is changed; run [recalculateBalances] afterwards to
  /// apply the credit to [toAccountId].
  Future<void> setTransferDestination(
    String userId,
    String transactionId,
    String toAccountId,
  ) async {
    final docRef = _transactions(userId).doc(transactionId);

    await _run('repair transfer', () {
      return _firestore.runTransaction((firestoreTransaction) async {
        final doc = await firestoreTransaction.get(docRef);
        if (!doc.exists) {
          throw const NotFoundException('Transaction not found');
        }
        final transfer = TransactionModel.fromFirestore(doc);
        if (transfer.type != TransactionType.transfer || transfer.isDeleted) {
          throw const ValidationException('Not an active transfer');
        }
        final fromAccountId =
            transfer.metadata?['fromAccountId'] as String? ?? transfer.accountId;
        if (fromAccountId == toAccountId) {
          throw const ValidationException('Cannot transfer to the same account');
        }
        final targetDoc =
            await firestoreTransaction.get(_accounts(userId).doc(toAccountId));
        if (!targetDoc.exists) {
          throw const NotFoundException('Account not found');
        }

        firestoreTransaction.update(docRef, {
          'metadata': {
            ...?transfer.metadata,
            'fromAccountId': fromAccountId,
            'toAccountId': toAccountId,
          },
          AppConstants.updatedAtField: Timestamp.now(),
        });
      });
    });
  }

  /// Whether transactions of [type] can be edited through the generic form.
  static bool isEditableType(TransactionType type) =>
      type == TransactionType.income || type == TransactionType.expense;

  /// Adds the balance effect of [transaction] multiplied by [sign] (+1 to
  /// apply, -1 to revert) to [effects]. Only performs reads.
  Future<void> _collectEffects(
    Transaction firestoreTransaction,
    String userId,
    TransactionModel transaction,
    int sign,
    _Effects effects,
  ) async {
    if (transaction.amount <= 0) {
      throw const ValidationException('Amount must be greater than zero');
    }

    if (transaction.type == TransactionType.loanRepayment) {
      await _collectRepaymentEffects(
        firestoreTransaction,
        userId,
        transaction,
        sign,
        effects,
      );
    } else {
      _addBalanceEffects(transaction, sign, effects);
    }
  }

  /// Balance effect of every type except `loanRepayment` (which needs the
  /// linked loan's type, see [_repaymentDirection]). Shared by live writes and
  /// [recalculateBalances] so both always follow the same rules.
  static void _addBalanceEffects(
    TransactionModel transaction,
    int sign,
    _Effects effects,
  ) {
    final amount = transaction.amount;
    switch (transaction.type) {
      case TransactionType.income:
      case TransactionType.loanTaken:
        effects.add(transaction.accountId, sign * amount);
      case TransactionType.expense:
      case TransactionType.loanGiven:
        effects.add(transaction.accountId, -sign * amount);
      case TransactionType.transfer:
        final metadata = transaction.metadata;
        final toAccountId = metadata?['toAccountId'] as String?;
        final fromAccountId =
            metadata?['fromAccountId'] as String? ?? transaction.accountId;
        if (toAccountId == null) {
          throw const ValidationException('Transfer destination account is missing');
        }
        if (toAccountId == fromAccountId) {
          throw const ValidationException('Cannot transfer to the same account');
        }
        effects
          ..add(fromAccountId, -sign * amount)
          ..add(toAccountId, sign * amount);
      case TransactionType.loanRepayment:
        throw StateError('Repayments need the linked loan; use _repaymentDirection');
    }
  }

  /// +1 when repaying a loan you gave (money received), -1 for a loan you took.
  static int _repaymentDirection(TransactionType loanType) =>
      loanType == TransactionType.loanGiven ? 1 : -1;

  Future<void> _collectRepaymentEffects(
    Transaction firestoreTransaction,
    String userId,
    TransactionModel repayment,
    int sign,
    _Effects effects,
  ) async {
    final linkedLoanId = repayment.metadata?['linkedLoanId'] as String?;
    if (linkedLoanId == null) {
      throw const ValidationException('Repayment is not linked to a loan');
    }

    final loanRef = _transactions(userId).doc(linkedLoanId);
    final loanDoc = await firestoreTransaction.get(loanRef);
    if (!loanDoc.exists) {
      throw const NotFoundException('Loan not found');
    }
    final loan = TransactionModel.fromFirestore(loanDoc);
    if (loan.type != TransactionType.loanGiven &&
        loan.type != TransactionType.loanTaken) {
      throw const ValidationException('Linked transaction is not a loan');
    }
    if (loan.isDeleted && sign > 0) {
      throw const ValidationException('Cannot repay a deleted loan');
    }

    // Money comes back for a loan you gave; money goes out for a loan you took.
    final direction = _repaymentDirection(loan.type);
    effects.add(repayment.accountId, sign * direction * repayment.amount);

    final loanMetadata = _loanMetadataOf(loan) ?? const LoanMetadata();
    final original = loanMetadata.originalAmount ?? loan.amount;
    final remaining = loanMetadata.remainingAmount ?? original;

    double newRemaining;
    if (sign > 0) {
      if (repayment.amount > remaining + _epsilon) {
        throw const ValidationException('Repayment amount exceeds remaining loan amount');
      }
      newRemaining = remaining - repayment.amount;
    } else {
      newRemaining = remaining + repayment.amount;
      if (newRemaining > original) newRemaining = original;
    }
    if (newRemaining < _epsilon) newRemaining = 0;

    final LoanStatus newStatus;
    if (newRemaining == 0) {
      newStatus = LoanStatus.completed;
    } else if (newRemaining < original - _epsilon) {
      newStatus = LoanStatus.partial;
    } else {
      newStatus = LoanStatus.pending;
    }

    effects.loanUpdates[loanRef] = {
      'metadata': loanMetadata
          .copyWith(
            originalAmount: original,
            remainingAmount: newRemaining,
            status: newStatus,
          )
          .toJson(),
      AppConstants.updatedAtField: Timestamp.now(),
    };
  }

  Future<Map<String, double>> _readBalances(
    Transaction firestoreTransaction,
    String userId,
    Iterable<String> accountIds,
  ) async {
    final balances = <String, double>{};
    for (final accountId in accountIds.toList()) {
      final accountDoc =
          await firestoreTransaction.get(_accounts(userId).doc(accountId));
      if (!accountDoc.exists) {
        throw const NotFoundException('Account not found');
      }
      balances[accountId] =
          (accountDoc.data()?['currentBalance'] as num?)?.toDouble() ?? 0;
    }
    return balances;
  }

  Map<String, double> _applyDeltas(
    Map<String, double> balances,
    Map<String, double> deltas,
  ) {
    return {
      for (final entry in deltas.entries)
        entry.key: (balances[entry.key] ?? 0) + entry.value,
    };
  }

  void _writeBalances(
    Transaction firestoreTransaction,
    String userId,
    Map<String, double> newBalances,
  ) {
    for (final entry in newBalances.entries) {
      firestoreTransaction.update(_accounts(userId).doc(entry.key), {
        'currentBalance': entry.value,
        AppConstants.updatedAtField: Timestamp.now(),
      });
    }
  }

  void _writeLoanUpdates(Transaction firestoreTransaction, _Effects effects) {
    for (final entry in effects.loanUpdates.entries) {
      firestoreTransaction.update(entry.key, entry.value);
    }
  }

  LoanMetadata? _loanMetadataOf(TransactionModel transaction) {
    final metadata = transaction.metadata;
    if (metadata == null) return null;
    try {
      return LoanMetadata.fromJson(metadata);
    } catch (e) {
      return null;
    }
  }

  Future<void> _run(String operation, Future<void> Function() body) async {
    try {
      await body();
    } on AppException {
      rethrow;
    } catch (e, stackTrace) {
      LoggerService.error('Failed to $operation', error: e, stackTrace: stackTrace);
      throw ServerException(ErrorMessages.from(e, action: operation));
    }
  }
}

class _Effects {
  final Map<String, double> deltas = {};
  final Map<DocumentReference<Map<String, dynamic>>, Map<String, dynamic>>
      loanUpdates = {};

  void add(String accountId, double delta) {
    deltas[accountId] = (deltas[accountId] ?? 0) + delta;
  }
}

class BalanceCorrection {
  const BalanceCorrection({
    required this.accountId,
    required this.accountName,
    required this.previousBalance,
    required this.correctedBalance,
  });

  final String accountId;
  final String accountName;
  final double previousBalance;
  final double correctedBalance;
}

class BalanceRecalculation {
  const BalanceRecalculation({
    required this.corrections,
    required this.brokenTransfers,
    required this.skipped,
  });

  final List<BalanceCorrection> corrections;

  /// Transfers without a destination account; excluded from the balances
  /// until repaired with `setTransferDestination`.
  final List<TransactionModel> brokenTransfers;

  /// Transactions whose effect couldn't be determined and were left out.
  final int skipped;
}
