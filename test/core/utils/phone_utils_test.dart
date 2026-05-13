import 'package:flutter_test/flutter_test.dart';
import 'package:mobileallclubs/core/utils/phone_utils.dart';

void main() {
  test('normalizeDialablePhone keeps leading plus and strips separators', () {
    expect(normalizeDialablePhone('+998 (90) 123-45-67'), '+998901234567');
  });

  test('isValidPhoneNumber accepts formatted values', () {
    expect(isValidPhoneNumber('+998 90 123 45 67'), isTrue);
    expect(isValidPhoneNumber('(90) 123-45-67'), isTrue);
  });

  test('isValidPhoneNumber rejects too-short values', () {
    expect(isValidPhoneNumber('12-34'), isFalse);
  });
}
