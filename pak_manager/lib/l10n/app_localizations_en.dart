// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appName => 'PAK Manager';

  @override
  String get tabCards => 'Passwords';

  @override
  String get tabGenerator => 'Generator';

  @override
  String get generatorTitle => 'Password Generator';

  @override
  String get tabSettings => 'Settings';

  @override
  String get loginCreate => 'Create Account';

  @override
  String get createWarning =>
      'There is no way to recover your main password. If you forget it, you lose all your data.';

  @override
  String get createFieldMain => 'Main password';

  @override
  String get createFieldConfirm => 'Re-enter main password';

  @override
  String get pwNonAscii =>
      'Use only unaccented letters, numbers, symbols and spaces. Accented letters may be typed differently by the keyboard and lock you out.';

  @override
  String pwStrength(String level) {
    return 'Strength: $level';
  }

  @override
  String get pwStrengthLow => 'Low';

  @override
  String get pwStrengthMedium => 'Medium';

  @override
  String get pwStrengthHigh => 'High';

  @override
  String pwTooShort(int n) {
    return 'At least 15 characters ($n so far).';
  }

  @override
  String get pwTooLong => '128 characters maximum.';

  @override
  String get pwCommon =>
      'This password is too common or has been leaked. Choose another.';

  @override
  String get pwPattern => 'Don\'t use one repeated character or a sequence.';

  @override
  String get pwMismatch => 'Passwords don\'t match.';

  @override
  String get createUnavailable => 'Can\'t open app data. Restart the app.';

  @override
  String get createFailed => 'Couldn\'t create the account. Try again.';

  @override
  String get pwReveal => 'Show password';

  @override
  String get pwHide => 'Hide password';
}
