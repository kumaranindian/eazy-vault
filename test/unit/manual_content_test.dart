import 'package:flutter_test/flutter_test.dart';

import 'package:eazyvault/features/onboarding/domain/onboarding_steps.dart';
import 'package:eazyvault/features/user_manual/domain/manual_content.dart';

void main() {
  group('manualSections', () {
    test('every section has a unique, non-empty id', () {
      final ids = manualSections.map((s) => s.id).toList();
      expect(ids.toSet().length, ids.length);
      expect(ids.every((id) => id.isNotEmpty), isTrue);
    });

    test('every section has at least one entry with non-empty text', () {
      for (final section in manualSections) {
        expect(section.entries, isNotEmpty, reason: 'Section "${section.title}" has no entries');
        for (final entry in section.entries) {
          expect(entry.heading.trim(), isNotEmpty);
          expect(entry.body.trim(), isNotEmpty);
        }
      }
    });
  });

  group('onboardingSteps', () {
    test('every step has a non-empty title and body', () {
      for (final step in onboardingSteps) {
        expect(step.title.trim(), isNotEmpty);
        expect(step.body.trim(), isNotEmpty);
      }
    });
  });
}
