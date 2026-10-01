import 'package:flutter_test/flutter_test.dart';
import 'package:sona/core/utils/pin_hasher.dart';

void main() {
  group('PinHasher.isValid', () {
    test('принимает ровно четыре цифры', () {
      expect(PinHasher.isValid('1234'), isTrue);
      expect(PinHasher.isValid('0000'), isTrue);
    });

    test('отклоняет неверную длину и нецифры', () {
      expect(PinHasher.isValid('123'), isFalse);
      expect(PinHasher.isValid('12345'), isFalse);
      expect(PinHasher.isValid('12a4'), isFalse);
      expect(PinHasher.isValid(''), isFalse);
    });
  });

  group('PinHasher.hash/verify', () {
    test('хеш детерминирован и не содержит открытый PIN', () {
      final hash = PinHasher.hash('1234');
      expect(hash, PinHasher.hash('1234'));
      expect(hash.contains('1234'), isFalse);
    });

    test('разные PIN дают разные хеши', () {
      expect(PinHasher.hash('1234'), isNot(PinHasher.hash('4321')));
    });

    test('verify сверяет PIN с хешем', () {
      final hash = PinHasher.hash('9876');
      expect(PinHasher.verify('9876', hash), isTrue);
      expect(PinHasher.verify('1234', hash), isFalse);
      expect(PinHasher.verify('9876', null), isFalse);
    });
  });
}
