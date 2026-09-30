import 'package:eazyvault/core/utils/validators.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Validators', () {
    test('positiveAmount rejects zero and negatives', () {
      expect(Validators.positiveAmount('0'), isNotNull);
      expect(Validators.positiveAmount('-5'), isNotNull);
      expect(Validators.positiveAmount('10.50'), isNull);
    });

    test('password requires upper, lower and a digit', () {
      expect(Validators.password('short'), isNotNull);
      expect(Validators.password('alllowercase1'), isNotNull);
      expect(Validators.password('Valid1Password'), isNull);
    });
  });
}
