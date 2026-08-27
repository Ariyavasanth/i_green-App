import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Candidate Form Format Validation Tests', () {
    test('Aadhaar number validation format', () {
      final aadhaarRegExp = RegExp(r'^\d{12}$');
      expect(aadhaarRegExp.hasMatch('123456789012'), true);
      expect(aadhaarRegExp.hasMatch('12345'), false);
      expect(aadhaarRegExp.hasMatch('12345678901A'), false);
    });

    test('Primary mobile number format', () {
      final phoneDigitsRegExp = RegExp(r'^\d+$');
      expect(phoneDigitsRegExp.hasMatch('9876543210'), true);
      expect(phoneDigitsRegExp.hasMatch('98765'), true); // length check happens separately
      expect(phoneDigitsRegExp.hasMatch('98765abc'), false);
    });

    test('PAN card format validation', () {
      final panRegExp = RegExp(r'^[A-Z]{5}[0-9]{4}[A-Z]{1}$');
      expect(panRegExp.hasMatch('ABCDE1234F'), true);
      expect(panRegExp.hasMatch('1234567890'), false);
      expect(panRegExp.hasMatch('ABCD12345F'), false);
    });

    test('IFSC code format validation', () {
      final ifscRegExp = RegExp(r'^[A-Z]{4}0[A-Z0-9]{6}$');
      expect(ifscRegExp.hasMatch('SBIN0001234'), true);
      expect(ifscRegExp.hasMatch('SBIN1001234'), false);
      expect(ifscRegExp.hasMatch('SBI0001234'), false);
    });

    test('Email format validation', () {
      final emailRegExp = RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$');
      expect(emailRegExp.hasMatch('user@gmail.com'), true);
      expect(emailRegExp.hasMatch('invalid-email'), false);
      expect(emailRegExp.hasMatch('user@com'), false);
    });

    test('ESI number format validation', () {
      final esiRegExp = RegExp(r'^\d{17}$');
      expect(esiRegExp.hasMatch('12345678901234567'), true);
      expect(esiRegExp.hasMatch('1234567890'), false);
    });

    test('Bank account number format validation', () {
      final bankAccRegExp = RegExp(r'^\d{9,18}$');
      expect(bankAccRegExp.hasMatch('123456789012'), true);
      expect(bankAccRegExp.hasMatch('12345'), false);
      expect(bankAccRegExp.hasMatch('12345678901234567890'), false);
    });
  });
}
