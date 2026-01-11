import 'package:flutter_test/flutter_test.dart';
import 'package:docovue/src/utils/validators.dart';

void main() {
  group('Aadhaar Validation', () {
    test('should validate correct Aadhaar numbers', () {
      // Valid Aadhaar numbers (using Verhoeff algorithm)
      expect(isValidAadhaar('234123412346'), isTrue);
      expect(isValidAadhaar('2341 2341 2346'), isTrue);
      expect(isValidAadhaar('2341-2341-2346'), isTrue);
    });

    test('should reject invalid Aadhaar numbers', () {
      expect(isValidAadhaar(''), isFalse);
      expect(isValidAadhaar('123456789012'), isFalse); // Invalid checksum
      expect(isValidAadhaar('000000000000'), isFalse); // Starts with 0
      expect(isValidAadhaar('111111111111'), isFalse); // Starts with 1
      expect(isValidAadhaar('12345678901'), isFalse); // Too short
      expect(isValidAadhaar('1234567890123'), isFalse); // Too long
      expect(isValidAadhaar('abcd1234efgh'), isFalse); // Non-numeric
    });
  });

  group('PAN Validation', () {
    test('should validate correct PAN numbers', () {
      expect(isValidPan('ABCDE1234F'), isTrue);
      expect(isValidPan('AAAPL1234C'), isTrue);
      expect(isValidPan('abcde1234f'), isTrue); // Should handle lowercase
    });

    test('should reject invalid PAN numbers', () {
      expect(isValidPan(''), isFalse);
      expect(isValidPan('ABCDE1234'), isFalse); // Too short
      expect(isValidPan('ABCDE12345F'), isFalse); // Too long
      expect(isValidPan('12345ABCDE'), isFalse); // Wrong format
      expect(isValidPan('ABCDEFGHIJ'), isFalse); // No numbers
      expect(isValidPan('1234567890'), isFalse); // No letters
    });
  });

  group('Card Number Validation', () {
    test('should validate correct card numbers', () {
      expect(isValidCardNumber('4111111111111111'), isTrue); // Visa test card
      expect(isValidCardNumber('5555555555554444'), isTrue); // Mastercard test card
      expect(isValidCardNumber('378282246310005'), isTrue); // Amex test card
      expect(isValidCardNumber('4111 1111 1111 1111'), isTrue); // With spaces
      expect(isValidCardNumber('4111-1111-1111-1111'), isTrue); // With hyphens
    });

    test('should reject invalid card numbers', () {
      expect(isValidCardNumber(''), isFalse);
      expect(isValidCardNumber('1234567890123456'), isFalse); // Invalid Luhn
      expect(isValidCardNumber('123456789012'), isFalse); // Too short
      expect(isValidCardNumber('12345678901234567890'), isFalse); // Too long
      expect(isValidCardNumber('abcd1234efgh5678'), isFalse); // Non-numeric
    });
  });

  group('Luhn Algorithm', () {
    test('should validate correct Luhn checksums', () {
      expect(luhnCheck('4111111111111111'), isTrue);
      expect(luhnCheck('5555555555554444'), isTrue);
      expect(luhnCheck('378282246310005'), isTrue);
    });

    test('should reject incorrect Luhn checksums', () {
      expect(luhnCheck(''), isFalse);
      expect(luhnCheck('1234567890123456'), isFalse);
      expect(luhnCheck('abcd'), isFalse);
    });
  });

  group('Verhoeff Algorithm', () {
    test('should validate correct Verhoeff checksums', () {
      expect(verhoeffCheck('234123412346'), isTrue);
      expect(verhoeffCheck('123456789012'), isFalse); // This should fail
    });

    test('should reject incorrect Verhoeff checksums', () {
      expect(verhoeffCheck(''), isFalse);
      expect(verhoeffCheck('abcd'), isFalse);
    });
  });

  group('Expiry Date Validation', () {
    test('should validate future expiry dates', () {
      final futureYear = DateTime.now().year + 2;
      expect(isValidExpiryDate('12/${futureYear.toString().substring(2)}'), isTrue);
      expect(isValidExpiryDate('12/$futureYear'), isTrue);
    });

    test('should reject past expiry dates', () {
      expect(isValidExpiryDate('12/20'), isFalse); // Assuming current year > 2020
      expect(isValidExpiryDate('12/2020'), isFalse);
    });

    test('should reject invalid formats', () {
      expect(isValidExpiryDate(''), isFalse);
      expect(isValidExpiryDate('13/25'), isFalse); // Invalid month
      expect(isValidExpiryDate('00/25'), isFalse); // Invalid month
      expect(isValidExpiryDate('12'), isFalse); // Incomplete
      expect(isValidExpiryDate('ab/cd'), isFalse); // Non-numeric
    });
  });

  group('Card Brand Detection', () {
    test('should detect Visa cards', () {
      expect(getCardBrand('4111111111111111'), equals('Visa'));
      expect(getCardBrand('4000000000000000'), equals('Visa'));
    });

    test('should detect Mastercard', () {
      expect(getCardBrand('5555555555554444'), equals('Mastercard'));
      expect(getCardBrand('5105105105105100'), equals('Mastercard'));
      expect(getCardBrand('2223000048400011'), equals('Mastercard')); // New range
    });

    test('should detect American Express', () {
      expect(getCardBrand('378282246310005'), equals('American Express'));
      expect(getCardBrand('371449635398431'), equals('American Express'));
    });

    test('should detect RuPay', () {
      expect(getCardBrand('6076820000000000'), equals('RuPay')); // 607 is RuPay
      expect(getCardBrand('6521000000000000'), equals('RuPay'));
    });

    test('should return Unknown for unrecognized cards', () {
      expect(getCardBrand(''), equals('Unknown'));
      expect(getCardBrand('1234567890123456'), equals('Unknown'));
    });
  });

  group('Data Masking', () {
    test('should mask card numbers correctly', () {
      expect(maskCardNumber('4111111111111111'), equals('4111 ******** 1111'));
      expect(maskCardNumber('378282246310005'), equals('3782 ******* 0005'));
      expect(maskCardNumber(''), equals(''));
      expect(maskCardNumber('1234'), equals('****')); // Too short
    });

    test('should mask Aadhaar numbers correctly', () {
      expect(maskAadhaarNumber('123456789012'), equals('XXXX-XXXX-9012'));
      expect(maskAadhaarNumber(''), equals(''));
      expect(maskAadhaarNumber('12345'), equals('XXXXX')); // Wrong length
    });

    test('should mask PAN numbers correctly', () {
      expect(maskPanNumber('ABCDE1234F'), equals('XXXXX1234X'));
      expect(maskPanNumber(''), equals(''));
      expect(maskPanNumber('ABCDE'), equals('XXXXX')); // Wrong length
    });
  });

  group('Passport Number Validation', () {
    test('should validate correct passport numbers', () {
      expect(isValidPassportNumber('A1234567'), isTrue);
      expect(isValidPassportNumber('AB123456'), isTrue);
      expect(isValidPassportNumber('123456789'), isTrue);
    });

    test('should reject invalid passport numbers', () {
      expect(isValidPassportNumber(''), isFalse);
      expect(isValidPassportNumber('A123'), isFalse); // Too short
      expect(isValidPassportNumber('A1234567890'), isFalse); // Too long
      expect(isValidPassportNumber('A@#\$%^&*'), isFalse); // Invalid characters
    });
  });
}