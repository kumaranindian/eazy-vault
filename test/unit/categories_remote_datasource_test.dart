import 'package:eazyvault/core/exceptions/app_exception.dart';
import 'package:eazyvault/features/categories/data/datasources/categories_remote_datasource.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/mock_firebase.dart';
import '../helpers/test_helpers.dart';

void main() {
  const userId = TestHelpers.testUserId;
  late FakeFirebaseFirestore firestore;
  late CategoriesRemoteDataSourceImpl dataSource;

  setUp(() async {
    firestore = MockFirebase.getFakeFirestore();
    dataSource = CategoriesRemoteDataSourceImpl(firestore: firestore);
    await MockFirebase.seedFirestore(firestore, userId);
  });

  group('deleteCategory', () {
    test('is rejected while the category is used by a transaction', () async {
      // Seeded transaction-1 references category-1.
      await expectLater(
        dataSource.deleteCategory(userId, 'category-1'),
        throwsA(isA<ValidationException>()),
      );
    });

    test('soft-deletes an unused category', () async {
      await dataSource.deleteCategory(userId, 'category-2');
      final category = await dataSource.getCategory(userId, 'category-2');
      expect(category.isDeleted, isTrue);
    });
  });
}
