import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../core/models/failure.dart';
import '../../../../core/services/logger_service.dart';
import '../../../authentication/presentation/providers/auth_providers.dart';
import '../../data/models/category_model.dart';
import '../../domain/enums/category_type.dart';
import 'categories_providers.dart';

part 'categories_notifier.freezed.dart';
part 'categories_notifier.g.dart';

@freezed
class CategoriesState with _$CategoriesState {
  const factory CategoriesState.initial() = _Initial;
  const factory CategoriesState.loading() = _Loading;
  const factory CategoriesState.loaded(List<CategoryModel> categories) = _Loaded;
  const factory CategoriesState.error(Failure failure) = _Error;
}

@riverpod
class CategoriesNotifier extends _$CategoriesNotifier {
  @override
  CategoriesState build() {
    _loadCategories();
    return const CategoriesState.initial();
  }

  Future<void> _loadCategories() async {
    final user = ref.read(currentUserProvider);
    if (user == null) {
      state = const CategoriesState.error(
        Failure.authenticationError('User not authenticated'),
      );
      return;
    }

    state = const CategoriesState.loading();

    final repository = ref.read(categoriesRepositoryProvider);
    final result = await repository.getCategories(user.uid);

    if (result.failure != null) {
      state = CategoriesState.error(result.failure!);
    } else {
      state = CategoriesState.loaded(result.categories);
    }
  }

  Future<Failure?> createCategory(CategoryModel category) {
    return _mutate((userId) async {
      final result = await ref
          .read(categoriesRepositoryProvider)
          .createCategory(userId, category);
      return result.failure;
    });
  }

  Future<Failure?> updateCategory(CategoryModel category) {
    return _mutate((userId) async {
      final result = await ref
          .read(categoriesRepositoryProvider)
          .updateCategory(userId, category);
      return result.failure;
    });
  }

  Future<Failure?> deleteCategory(String categoryId) {
    return _mutate((userId) async {
      return ref
          .read(categoriesRepositoryProvider)
          .deleteCategory(userId, categoryId);
    });
  }

  Future<Failure?> seedDefaultCategories() {
    return _mutate((userId) async {
      return ref
          .read(categoriesRepositoryProvider)
          .seedDefaultCategories(userId);
    });
  }

  /// Runs a write and reloads the list on success. Returns `null` on success,
  /// otherwise the [Failure]; the list state is left untouched on failure.
  Future<Failure?> _mutate(
    Future<Failure?> Function(String userId) operation,
  ) async {
    final user = ref.read(currentUserProvider);
    if (user == null) {
      return const Failure.authenticationError('User not authenticated');
    }

    final link = ref.keepAlive();
    try {
      final failure = await operation(user.uid);
      if (failure != null) return failure;

      await _loadCategories();
      return null;
    } finally {
      link.close();
    }
  }

  void refresh() {
    _loadCategories();
  }
}

@riverpod
Stream<List<CategoryModel>> categoriesStream(
  CategoriesStreamRef ref, {
  CategoryType? type,
}) {
  final user = ref.watch(currentUserProvider);
  if (user == null) {
    return Stream.value([]);
  }

  final repository = ref.watch(categoriesRepositoryProvider);
  return repository.watchCategories(user.uid, type: type);
}

@riverpod
Future<CategoryModel?> category(CategoryRef ref, String categoryId) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) {
    LoggerService.warning('User not authenticated');
    return null;
  }

  final repository = ref.watch(categoriesRepositoryProvider);
  final result = await repository.getCategory(user.uid, categoryId);

  if (result.failure != null) {
    LoggerService.error('Failed to fetch category', error: result.failure);
    return null;
  }

  return result.category;
}

@riverpod
List<CategoryModel> incomeCategories(IncomeCategoriesRef ref) {
  final categoriesState = ref.watch(categoriesNotifierProvider);

  return categoriesState.maybeWhen(
    loaded: (categories) => categories
        .where((cat) => cat.type == CategoryType.income && cat.isActive)
        .toList(),
    orElse: () => [],
  );
}

@riverpod
List<CategoryModel> expenseCategories(ExpenseCategoriesRef ref) {
  final categoriesState = ref.watch(categoriesNotifierProvider);

  return categoriesState.maybeWhen(
    loaded: (categories) => categories
        .where((cat) => cat.type == CategoryType.expense && cat.isActive)
        .toList(),
    orElse: () => [],
  );
}
