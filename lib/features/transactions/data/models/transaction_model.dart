import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

import '../../domain/enums/transaction_type.dart';

part 'transaction_model.freezed.dart';
part 'transaction_model.g.dart';

@freezed
class TransactionModel with _$TransactionModel {
  const factory TransactionModel({
    required String id,
    required TransactionType type,
    required double amount,
    required String accountId,
    required String categoryId,
    required DateTime date,
    String? description,
    String? vendor,
    List<String>? attachments,
    Map<String, dynamic>? metadata,
    // Income only: the `YYYY-MM` reporting month, independent of `date` (the
    // actual credited/money-movement date). Null means "use date's month" —
    // the fallback for income written before this field existed. See
    // `IncomePeriod` and `TransactionModelExtensions.effectiveIncomePeriod`.
    String? incomePeriod,
    required DateTime createdAt,
    required DateTime updatedAt,
    required String createdBy,
    @Default(false) bool isDeleted,
  }) = _TransactionModel;

  factory TransactionModel.fromJson(Map<String, dynamic> json) =>
      _$TransactionModelFromJson(json);

  factory TransactionModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return TransactionModel(
      id: doc.id,
      type: TransactionType.values.firstWhere(
        (e) => e.name == data['type'],
        orElse: () => TransactionType.expense,
      ),
      amount: (data['amount'] as num).toDouble(),
      accountId: data['accountId'] as String,
      categoryId: data['categoryId'] as String,
      date: (data['date'] as Timestamp).toDate(),
      description: data['description'] as String?,
      vendor: data['vendor'] as String?,
      attachments: (data['attachments'] as List<dynamic>?)?.cast<String>(),
      metadata: data['metadata'] as Map<String, dynamic>?,
      incomePeriod: data['incomePeriod'] as String?,
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      updatedAt: (data['updatedAt'] as Timestamp).toDate(),
      createdBy: data['createdBy'] as String,
      isDeleted: data['isDeleted'] as bool? ?? false,
    );
  }
}

extension TransactionModelExtension on TransactionModel {
  Map<String, dynamic> toFirestore() {
    return {
      'type': type.name,
      'amount': amount,
      'accountId': accountId,
      'categoryId': categoryId,
      'date': Timestamp.fromDate(date),
      'description': description,
      'vendor': vendor,
      'attachments': attachments,
      'metadata': metadata,
      'incomePeriod': incomePeriod,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      'createdBy': createdBy,
      'isDeleted': isDeleted,
    };
  }

  bool get isIncome => type == TransactionType.income;
  bool get isExpense => type == TransactionType.expense;
}
