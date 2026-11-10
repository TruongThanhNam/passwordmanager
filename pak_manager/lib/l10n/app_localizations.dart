import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_vi.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('vi'),
  ];

  /// app.name: large title on S1 and S3; also the window/task title.
  ///
  /// In en, this message translates to:
  /// **'PAK Manager'**
  String get appName;

  /// tab.cards: tab 1 label and S7 nav title.
  ///
  /// In en, this message translates to:
  /// **'Passwords'**
  String get tabCards;

  /// tab.generator: tab 2 label.
  ///
  /// In en, this message translates to:
  /// **'Generator'**
  String get tabGenerator;

  /// generator.title: S14 nav title.
  ///
  /// In en, this message translates to:
  /// **'Password Generator'**
  String get generatorTitle;

  /// tab.settings: tab 3 label and S18 nav title.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get tabSettings;

  /// login.create: S1 button, S2 nav title and S2 button.
  ///
  /// In en, this message translates to:
  /// **'Create Account'**
  String get loginCreate;

  /// login.submit: S3 button.
  ///
  /// In en, this message translates to:
  /// **'Log In'**
  String get loginSubmit;

  /// login.wrong (FR-3): inline-message under the S3 field when the password is wrong.
  ///
  /// In en, this message translates to:
  /// **'Incorrect password.'**
  String get loginWrong;

  /// login.corrupt (FR-7): inline-message on S3 when the header is damaged or the data can't be decrypted.
  ///
  /// In en, this message translates to:
  /// **'Data is damaged — The password is correct but the data can\'t be read. You can use \"Erase & Create New Account\", then import your export file.'**
  String get loginCorrupt;

  /// create.warning (FR-1): paragraph above the two fields on S2.
  ///
  /// In en, this message translates to:
  /// **'There is no way to recover your main password. If you forget it, you lose all your data.'**
  String get createWarning;

  /// create.field.main: placeholder of the first S2 field.
  ///
  /// In en, this message translates to:
  /// **'Main password'**
  String get createFieldMain;

  /// create.field.confirm: placeholder of the second S2 field.
  ///
  /// In en, this message translates to:
  /// **'Re-enter main password'**
  String get createFieldConfirm;

  /// pw.nonAscii (FR-2): inline-message when the field has a non-ASCII character.
  ///
  /// In en, this message translates to:
  /// **'Use only unaccented letters, numbers, symbols and spaces. Accented letters may be typed differently by the keyboard and lock you out.'**
  String get pwNonAscii;

  /// pw.strength (FR-2): strength-meter line; level is pwStrengthLow/Medium/High.
  ///
  /// In en, this message translates to:
  /// **'Strength: {level}'**
  String pwStrength(String level);

  /// pw.strength level for zxcvbnm score 0-2.
  ///
  /// In en, this message translates to:
  /// **'Low'**
  String get pwStrengthLow;

  /// pw.strength level for zxcvbnm score 3.
  ///
  /// In en, this message translates to:
  /// **'Medium'**
  String get pwStrengthMedium;

  /// pw.strength level for zxcvbnm score 4.
  ///
  /// In en, this message translates to:
  /// **'High'**
  String get pwStrengthHigh;

  /// pw.tooShort: n is the current length.
  ///
  /// In en, this message translates to:
  /// **'At least 15 characters ({n} so far).'**
  String pwTooShort(int n);

  /// pw.tooLong.
  ///
  /// In en, this message translates to:
  /// **'128 characters maximum.'**
  String get pwTooLong;

  /// pw.common: password is in the offline blocklist.
  ///
  /// In en, this message translates to:
  /// **'This password is too common or has been leaked. Choose another.'**
  String get pwCommon;

  /// pw.pattern: repeated character or sequential run.
  ///
  /// In en, this message translates to:
  /// **'Don\'t use one repeated character or a sequence.'**
  String get pwPattern;

  /// pw.mismatch: shown once the re-entered field is as long as the first.
  ///
  /// In en, this message translates to:
  /// **'Passwords don\'t match.'**
  String get pwMismatch;

  /// create.unavailable: S1, under the disabled button when storage, Sodium or the blocklist failed to load.
  ///
  /// In en, this message translates to:
  /// **'Can\'t open app data. Restart the app.'**
  String get createUnavailable;

  /// create.failed: S2, under the button when AccountService.create failed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t create the account. Try again.'**
  String get createFailed;

  /// pw.reveal: screen-reader label of the eye button while the password is hidden.
  ///
  /// In en, this message translates to:
  /// **'Show password'**
  String get pwReveal;

  /// pw.hide: screen-reader label of the eye button while the password is shown.
  ///
  /// In en, this message translates to:
  /// **'Hide password'**
  String get pwHide;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'vi'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'vi':
      return AppLocalizationsVi();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
