/// Ngôn ngữ giao diện người dùng đã chọn. `null` trong [Settings.language]
/// nghĩa là theo ngôn ngữ máy (AD-20).
enum AppLanguage { vi, en }

/// Giao diện sáng/tối. [system] theo cài đặt của máy.
enum Appearance { system, light, dark }

/// Các mức thời gian (phút) hợp lệ cho autolock, phiên và clipboard (AD-20).
const Set<int> settingsMinuteChoices = {1, 3, 5, 10};

/// Độ dài mật khẩu sinh ra nhỏ nhất và lớn nhất (AD-20, FR-29).
const int genLengthMin = 4;
const int genLengthMax = 99;

/// Cấu hình generator lưu trong `settings` (`gen`). Bất biến.
final class GenSettings {
  const GenSettings({
    required this.length,
    required this.upper,
    required this.lower,
    required this.digits,
    required this.special,
  });

  /// Độ dài 16, bật mọi loại ký tự (epics 1.3).
  static const defaults = GenSettings(
    length: 16,
    upper: true,
    lower: true,
    digits: true,
    special: true,
  );

  final int length;
  final bool upper;
  final bool lower;
  final bool digits;
  final bool special;

  /// `true` khi [length] nằm trong [genLengthMin]–[genLengthMax].
  bool get isValid => length >= genLengthMin && length <= genLengthMax;

  GenSettings copyWith({
    int? length,
    bool? upper,
    bool? lower,
    bool? digits,
    bool? special,
  }) => GenSettings(
    length: length ?? this.length,
    upper: upper ?? this.upper,
    lower: lower ?? this.lower,
    digits: digits ?? this.digits,
    special: special ?? this.special,
  );

  @override
  bool operator ==(Object other) =>
      other is GenSettings &&
      other.length == length &&
      other.upper == upper &&
      other.lower == lower &&
      other.digits == digits &&
      other.special == special;

  @override
  int get hashCode => Object.hash(length, upper, lower, digits, special);

  @override
  String toString() =>
      'GenSettings(length: $length, upper: $upper, lower: $lower, '
      'digits: $digits, special: $special)';
}

/// Nội dung file `settings` (AD-20). Bất biến; chỉ `SettingsStore` giữ bản
/// đang dùng.
final class Settings {
  const Settings({
    required this.language,
    required this.appearance,
    required this.autolockMin,
    required this.sessionMin,
    required this.clipboardMin,
    required this.gen,
    required this.lastExportAt,
  });

  /// Mặc định khi cài lần đầu (epics 1.3): theo ngôn ngữ và giao diện của
  /// máy, 3/10/3 phút, gen dài 16 với mọi loại bật, chưa export.
  static const defaults = Settings(
    language: null,
    appearance: Appearance.system,
    autolockMin: 3,
    sessionMin: 10,
    clipboardMin: 3,
    gen: GenSettings.defaults,
    lastExportAt: null,
  );

  /// `null` = theo ngôn ngữ máy.
  final AppLanguage? language;
  final Appearance appearance;
  final int autolockMin;
  final int sessionMin;
  final int clipboardMin;
  final GenSettings gen;

  /// Thời điểm export gần nhất, UTC epoch ms; `null` = chưa export.
  final int? lastExportAt;

  /// `true` khi mọi trường nằm trong miền của AD-20.
  bool get isValid =>
      settingsMinuteChoices.contains(autolockMin) &&
      settingsMinuteChoices.contains(sessionMin) &&
      settingsMinuteChoices.contains(clipboardMin) &&
      gen.isValid &&
      (lastExportAt == null || lastExportAt! >= 0);

  /// Trường nullable được xóa về `null` bằng [clearLanguage] /
  /// [clearLastExportAt] (ưu tiên hơn giá trị mới truyền vào).
  Settings copyWith({
    AppLanguage? language,
    bool clearLanguage = false,
    Appearance? appearance,
    int? autolockMin,
    int? sessionMin,
    int? clipboardMin,
    GenSettings? gen,
    int? lastExportAt,
    bool clearLastExportAt = false,
  }) => Settings(
    language: clearLanguage ? null : (language ?? this.language),
    appearance: appearance ?? this.appearance,
    autolockMin: autolockMin ?? this.autolockMin,
    sessionMin: sessionMin ?? this.sessionMin,
    clipboardMin: clipboardMin ?? this.clipboardMin,
    gen: gen ?? this.gen,
    lastExportAt: clearLastExportAt
        ? null
        : (lastExportAt ?? this.lastExportAt),
  );

  @override
  bool operator ==(Object other) =>
      other is Settings &&
      other.language == language &&
      other.appearance == appearance &&
      other.autolockMin == autolockMin &&
      other.sessionMin == sessionMin &&
      other.clipboardMin == clipboardMin &&
      other.gen == gen &&
      other.lastExportAt == lastExportAt;

  @override
  int get hashCode => Object.hash(
    language,
    appearance,
    autolockMin,
    sessionMin,
    clipboardMin,
    gen,
    lastExportAt,
  );

  @override
  String toString() =>
      'Settings(language: ${language?.name}, appearance: ${appearance.name}, '
      'autolockMin: $autolockMin, sessionMin: $sessionMin, '
      'clipboardMin: $clipboardMin, gen: $gen, lastExportAt: $lastExportAt)';
}
