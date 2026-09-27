import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

import '../../domain/enums/category_type.dart';

part 'category_model.freezed.dart';
part 'category_model.g.dart';

@freezed
class CategoryModel with _$CategoryModel {
  const factory CategoryModel({
    required String id,
    required String name,
    required CategoryType type,
    required int color,
    required String icon,
    String? description,
    required bool isDefault,
    required bool isActive,
    required DateTime createdAt,
    required DateTime updatedAt,
    required String createdBy,
    @Default(false) bool isDeleted,
  }) = _CategoryModel;

  factory CategoryModel.fromJson(Map<String, dynamic> json) =>
      _$CategoryModelFromJson(json);

  factory CategoryModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return CategoryModel(
      id: doc.id,
      name: data['name'] as String,
      type: CategoryType.values.firstWhere(
        (e) => e.name == data['type'],
        orElse: () => CategoryType.expense,
      ),
      color: data['color'] as int,
      icon: data['icon'] as String,
      description: data['description'] as String?,
      isDefault: data['isDefault'] as bool? ?? false,
      isActive: data['isActive'] as bool? ?? true,
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      updatedAt: (data['updatedAt'] as Timestamp).toDate(),
      createdBy: data['createdBy'] as String,
      isDeleted: data['isDeleted'] as bool? ?? false,
    );
  }
}

extension CategoryModelExtension on CategoryModel {
  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'type': type.name,
      'color': color,
      'icon': icon,
      'description': description,
      'isDefault': isDefault,
      'isActive': isActive,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      'createdBy': createdBy,
      'isDeleted': isDeleted,
    };
  }
}
