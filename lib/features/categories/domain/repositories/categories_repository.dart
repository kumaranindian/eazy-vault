import '../../../../core/models/failure.dart';
import '../../data/models/category_model.dart';
import '../enums/category_type.dart';

abstract class CategoriesRepository {
  Future<({List<CategoryModel> categories, Failure? failure})> getCategories(
    String userId, {
    CategoryType? type,
  });
  
  Future<({CategoryModel? category, Failure? failure})> getCategory(
    String userId,
    String categoryId,
  );
  
  Future<({CategoryModel? category, Failure? failure})> createCategory(
    String userId,
    CategoryModel category,
  );
  
  Future<({CategoryModel? category, Failure? failure})> updateCategory(
    String userId,
    CategoryModel category,
  );
  
  Future<Failure?> deleteCategory(String userId, String categoryId);
  
  Future<Failure?> seedDefaultCategories(String userId);
  
  Stream<List<CategoryModel>> watchCategories(String userId, {CategoryType? type});
}
