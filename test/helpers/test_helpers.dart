import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'mock_firebase.dart';

class TestHelpers {
  static ProviderContainer createContainer({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
    List<Override>? overrides,
  }) {
    return ProviderContainer(
      overrides: overrides ?? [],
    );
  }

  static void disposeContainer(ProviderContainer container) {
    container.dispose();
  }

  static DateTime getTestDate({int daysAgo = 0}) {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day - daysAgo);
  }

  static Timestamp getTestTimestamp({int daysAgo = 0}) {
    return Timestamp.fromDate(getTestDate(daysAgo: daysAgo));
  }

  static const String testUserId = 'test-user-id';
  static const String testUserEmail = 'test@example.com';
  static const String testUserName = 'Test User';

  static Future<void> pumpWithProviders(
    WidgetTester tester,
    Widget widget, {
    List<Override>? overrides,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: overrides ?? [],
        child: widget,
      ),
    );
  }
}

extension WidgetTesterExtensions on WidgetTester {
  Future<void> pumpAndSettle2() async {
    await pump();
    await pump(const Duration(seconds: 1));
  }
}
