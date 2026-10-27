import 'package:flutter_test/flutter_test.dart';

import 'package:{{project_name}}/core/validators/validators.dart';

void main() {
  group('whitespace-only input is rejected everywhere', () {
    const spaces = '     ';
    test('required / name / email / phone / otp / required password', () {
      expect(Validators.required('Message')(spaces), 'Message is required');
      expect(Validators.name()(spaces), 'Name is required');
      expect(Validators.email()(spaces), 'Email is required');
      expect(Validators.phone()(spaces), 'Phone number is required');
      expect(Validators.otp()(spaces), isNotNull);
      expect(Validators.requiredPassword()(spaces), 'Password is required');
      expect(Validators.requiredPassword('Current password')(spaces), 'Current password is required');
    });

    test('null and empty are rejected too', () {
      for (final v in [Validators.name(), Validators.email(), Validators.phone(), Validators.otp()]) {
        expect(v(null), isNotNull);
        expect(v(''), isNotNull);
      }
    });

    test('a new password of only spaces is rejected', () {
      expect(Validators.newPassword()(spaces), 'Password cannot be only spaces');
    });
  });

  group('email', () {
    test('accepts valid addresses, including surrounding spaces', () {
      expect(Validators.email()('a@b.co'), isNull);
      expect(Validators.email()('  first.last+tag@mail.example.com  '), isNull);
    });
    test('rejects malformed addresses and inner spaces', () {
      for (final bad in ['abc', 'a@b', 'a@@b.com', '@b.com', 'a b@c.com', 'a@b.c']) {
        expect(Validators.email()(bad), 'Enter a valid email', reason: bad);
      }
    });
  });

  group('phone', () {
    test('accepts common formats', () {
      for (final ok in ['0412 345 678', '+61 2 1234 5678', '+14155552671', '041-234-5678']) {
        expect(Validators.phone()(ok), isNull, reason: ok);
      }
    });
    test('rejects letters and too-short numbers', () {
      for (final bad in ['abc', '123', '04abc45678', '++61412345678']) {
        expect(Validators.phone()(bad), isNotNull, reason: bad);
      }
    });
    test('optionalPhone allows blank but still checks a value', () {
      expect(Validators.optionalPhone()(''), isNull);
      expect(Validators.optionalPhone()('   '), isNull);
      expect(Validators.optionalPhone()('abc'), isNotNull);
      expect(Validators.optionalPhone()('0412 345 678'), isNull);
    });
  });

  group('name', () {
    test('needs at least two characters', () {
      expect(Validators.name()('A'), 'Enter your full name');
      expect(Validators.name()(' Jo '), isNull);
    });
  });

  group('otp', () {
    test('needs exactly 4 digits', () {
      expect(Validators.otp()('1234'), isNull);
      expect(Validators.otp()(' 1234 '), isNull);
      expect(Validators.otp()('123'), isNotNull);
      expect(Validators.otp()('12345'), isNotNull);
      expect(Validators.otp()('12a4'), isNotNull);
    });
  });

  group('new password: 8 chars, capital, number, special char, no spaces', () {
    final v = Validators.newPassword();

    test('accepts a strong password', () {
      expect(v('Passw0rd!'), isNull);
      expect(v('Abcdef1#xyz'), isNull);
    });

    test('names the first rule that fails', () {
      expect(v(''), 'Password is required');
      expect(v('Pass 0rd!x'), 'Password must not contain spaces');
      expect(v('Pa0!'), 'Password must be at least 8 characters');
      expect(v('passw0rd!'), 'Password needs a capital letter');
      expect(v('Password!'), 'Password needs a number');
      expect(v('Passw0rdd'), 'Password needs a special character');
    });

    test('a space anywhere is rejected, including leading and trailing', () {
      expect(v(' Passw0rd!'), 'Password must not contain spaces');
      expect(v('Passw0rd! '), 'Password must not contain spaces');
    });

    test('PasswordRules.isValid agrees with the validator', () {
      for (final p in ['Passw0rd!', 'passw0rd!', 'Password!', 'Passw0rdd', 'Pa0!', 'Pass w0rd!', '', '        ']) {
        expect(PasswordRules.isValid(p), Validators.newPassword()(p) == null, reason: p);
      }
    });
  });

  group('confirm password', () {
    test('must match', () {
      final v = Validators.confirmPassword(() => 'Passw0rd!');
      expect(v(''), 'Please confirm your password');
      expect(v('Passw0rd?'), 'Passwords do not match');
      expect(v('Passw0rd!'), isNull);
    });
  });
}
