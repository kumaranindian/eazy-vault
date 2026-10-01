import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'budget_model.freezed.dart';
part 'budget_model.g.dart';

/// A monthly spending limit for one expense category. "Spent" is computed at
/// read time from the category's current-month expense total (see
/// `budget_progress_provider.dart`); it is never stored on this document.
@freezed
class BudgetModel with _$BudgetModel {
  const factory BudgetModel({
    required String id,
    required String categoryId,
    required double amount,
    required bool isActive,
    required DateTime createdAt,
    required DateTime updatedAt,
    required String createdBy,
    @Default(false) bool isDeleted,
  }) = _BudgetModel;

  factory BudgetModel.fromJson(Map<String, dynamic> json) => _$BudgetModelFromJson(json);

  factory BudgetModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return BudgetModel(
      id: doc.id,
      categoryId: data['categoryId'] as String,
      amount: (data['amount'] as num).toDouble(),
      isActive: data['isActive'] as bool? ?? true,
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      updatedAt: (data['updatedAt'] as Timestamp).toDate(),
      createdBy: data['createdBy'] as String,
      isDeleted: data['isDeleted'] as bool? ?? false,
    );
  }
}

extension BudgetModelExtension on BudgetModel {
  Map<String, dynamic> toFirestore() {
    return {
      'categoryId': categoryId,
      'amount': amount,
      'isActive': isActive,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      'createdBy': createdBy,
      'isDeleted': isDeleted,
    };
  }
}
