import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

import '../../domain/enums/account_type.dart';

part 'account_model.freezed.dart';
part 'account_model.g.dart';

@freezed
class AccountModel with _$AccountModel {
  const factory AccountModel({
    required String id,
    required String name,
    required AccountType type,
    required double openingBalance,
    required double currentBalance,
    required int color,
    required String icon,
    required bool isActive,
    String? description,
    required DateTime createdAt,
    required DateTime updatedAt,
    required String createdBy,
    @Default(false) bool isDeleted,
  }) = _AccountModel;

  factory AccountModel.fromJson(Map<String, dynamic> json) =>
      _$AccountModelFromJson(json);

  factory AccountModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return AccountModel(
      id: doc.id,
      name: data['name'] as String,
      type: AccountType.values.firstWhere(
        (e) => e.name == data['type'],
        orElse: () => AccountType.cash,
      ),
      openingBalance: (data['openingBalance'] as num).toDouble(),
      currentBalance: (data['currentBalance'] as num).toDouble(),
      color: data['color'] as int,
      icon: data['icon'] as String,
      isActive: data['isActive'] as bool? ?? true,
      description: data['description'] as String?,
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      updatedAt: (data['updatedAt'] as Timestamp).toDate(),
      createdBy: data['createdBy'] as String,
      isDeleted: data['isDeleted'] as bool? ?? false,
    );
  }
}

extension AccountModelExtension on AccountModel {
  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'type': type.name,
      'openingBalance': openingBalance,
      'currentBalance': currentBalance,
      'color': color,
      'icon': icon,
      'isActive': isActive,
      'description': description,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      'createdBy': createdBy,
      'isDeleted': isDeleted,
    };
  }

  AccountModel copyWithBalance(double newBalance) {
    return copyWith(
      currentBalance: newBalance,
      updatedAt: DateTime.now(),
    );
  }
}
