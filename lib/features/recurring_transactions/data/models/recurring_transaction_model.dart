import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

import '../../../transactions/domain/enums/transaction_type.dart';
import '../../domain/enums/recurrence_frequency.dart';

part 'recurring_transaction_model.freezed.dart';
part 'recurring_transaction_model.g.dart';

/// A rule for an income/expense transaction that repeats on a schedule.
/// Actual transactions are generated client-side (see
/// `RecurringTransactionService.catchUp`) when the app is opened, for every
/// occurrence due since [lastGeneratedDate]; nothing runs while the app is
/// closed.
@freezed
class RecurringTransactionModel with _$RecurringTransactionModel {
  const factory RecurringTransactionModel({
    required String id,
    required TransactionType type,
    required double amount,
    required String accountId,
    required String categoryId,
    String? description,
    String? vendor,
    required RecurrenceFrequency frequency,
    required DateTime startDate,
    DateTime? endDate,
    DateTime? lastGeneratedDate,
    required bool isActive,
    required DateTime createdAt,
    required DateTime updatedAt,
    required String createdBy,
    @Default(false) bool isDeleted,
  }) = _RecurringTransactionModel;

  factory RecurringTransactionModel.fromJson(Map<String, dynamic> json) =>
      _$RecurringTransactionModelFromJson(json);

  factory RecurringTransactionModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return RecurringTransactionModel(
      id: doc.id,
      type: TransactionType.values.firstWhere(
        (e) => e.name == data['type'],
        orElse: () => TransactionType.expense,
      ),
      amount: (data['amount'] as num).toDouble(),
      accountId: data['accountId'] as String,
      categoryId: data['categoryId'] as String,
      description: data['description'] as String?,
      vendor: data['vendor'] as String?,
      frequency: RecurrenceFrequency.values.firstWhere(
        (e) => e.name == data['frequency'],
        orElse: () => RecurrenceFrequency.monthly,
      ),
      startDate: (data['startDate'] as Timestamp).toDate(),
      endDate: (data['endDate'] as Timestamp?)?.toDate(),
      lastGeneratedDate: (data['lastGeneratedDate'] as Timestamp?)?.toDate(),
      isActive: data['isActive'] as bool? ?? true,
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      updatedAt: (data['updatedAt'] as Timestamp).toDate(),
      createdBy: data['createdBy'] as String,
      isDeleted: data['isDeleted'] as bool? ?? false,
    );
  }
}

extension RecurringTransactionModelExtension on RecurringTransactionModel {
  Map<String, dynamic> toFirestore() {
    return {
      'type': type.name,
      'amount': amount,
      'accountId': accountId,
      'categoryId': categoryId,
      'description': description,
      'vendor': vendor,
      'frequency': frequency.name,
      'startDate': Timestamp.fromDate(startDate),
      'endDate': endDate == null ? null : Timestamp.fromDate(endDate!),
      'lastGeneratedDate':
          lastGeneratedDate == null ? null : Timestamp.fromDate(lastGeneratedDate!),
      'isActive': isActive,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      'createdBy': createdBy,
      'isDeleted': isDeleted,
    };
  }
}
