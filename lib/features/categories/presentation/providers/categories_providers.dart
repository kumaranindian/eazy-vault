import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../authentication/presentation/providers/auth_providers.dart';
import '../../data/datasources/categories_remote_datasource.dart';
import '../../data/repositories/categories_repository_impl.dart';
import '../../domain/repositories/categories_repository.dart';

part 'categories_providers.g.dart';

@Riverpod(keepAlive: true)
CategoriesRemoteDataSource categoriesRemoteDataSource(
  CategoriesRemoteDataSourceRef ref,
) {
  return CategoriesRemoteDataSourceImpl(
    firestore: ref.watch(firebaseFirestoreProvider),
  );
}

@Riverpod(keepAlive: true)
CategoriesRepository categoriesRepository(CategoriesRepositoryRef ref) {
  return CategoriesRepositoryImpl(
    remoteDataSource: ref.watch(categoriesRemoteDataSourceProvider),
  );
}
