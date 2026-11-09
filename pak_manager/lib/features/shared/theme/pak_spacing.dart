/// Token spacing của DESIGN.md (UX-DR4), đơn vị pt (iOS) = dp (Android).
/// Lưới 4pt cộng các khoảng đo từ ảnh tham chiếu (±1pt).
abstract final class PakSpacing {
  static const double s1 = 4;
  static const double s2 = 8;
  static const double s3 = 12;
  static const double s4 = 16;
  static const double s5 = 24;
  static const double s6 = 32;
  static const double margin = 16;
  static const double cellInset = 16;
  static const double chipGap = 10;
  static const double cardGap = 12;
  static const double sectionGap = 35;
  static const double buttonInsetGenerator = 30;
  static const double buttonInsetSheet = 40;
  static const double rowHeight = 44;
  static const double recentRowHeight = 72;
  static const double buttonHeight = 48;
  static const double chipHeight = 50;
  static const double circleButton = 36;
  static const double touchIcon = 44;
  static const double fabSize = 56;
  static const double holdButton = 72;
  static const double contentMaxTablet = 672;
  static const double switchInsetGenerator = 10;
  static const double passwordRefreshGap = 10;
  static const double generatorButtonToList = 60;
  static const double chipCheckGap = 12;
  static const double sheetPasswordToCard = 55;
  static const double sheetLabelToSlider = 25;
  static const double sheetSliderToHairline = 33;
  static const double sheetHairlineToChips = 16;
  static const double sheetCardToButton = 16;
  static const double sheetButtonToBottom = 40;
  static const double recentHeaderHeight = 91;
  static const double recentRowPadTop = 18;
  static const double recentRowPadBottom = 17;
  static const double recentRowLineGap = 6;
  static const double toolbarHeight = 49;
  static const double valueChevronGap = 12;

  /// Key `spacing:` trong DESIGN.md → giá trị.
  static const Map<String, double> all = {
    '1': s1,
    '2': s2,
    '3': s3,
    '4': s4,
    '5': s5,
    '6': s6,
    'margin': margin,
    'cell-inset': cellInset,
    'chip-gap': chipGap,
    'card-gap': cardGap,
    'section-gap': sectionGap,
    'button-inset-generator': buttonInsetGenerator,
    'button-inset-sheet': buttonInsetSheet,
    'row-height': rowHeight,
    'recent-row-height': recentRowHeight,
    'button-height': buttonHeight,
    'chip-height': chipHeight,
    'circle-button': circleButton,
    'touch-icon': touchIcon,
    'fab-size': fabSize,
    'hold-button': holdButton,
    'content-max-tablet': contentMaxTablet,
    'switch-inset-generator': switchInsetGenerator,
    'password-refresh-gap': passwordRefreshGap,
    'generator-button-to-list': generatorButtonToList,
    'chip-check-gap': chipCheckGap,
    'sheet-password-to-card': sheetPasswordToCard,
    'sheet-label-to-slider': sheetLabelToSlider,
    'sheet-slider-to-hairline': sheetSliderToHairline,
    'sheet-hairline-to-chips': sheetHairlineToChips,
    'sheet-card-to-button': sheetCardToButton,
    'sheet-button-to-bottom': sheetButtonToBottom,
    'recent-header-height': recentHeaderHeight,
    'recent-row-pad-top': recentRowPadTop,
    'recent-row-pad-bottom': recentRowPadBottom,
    'recent-row-line-gap': recentRowLineGap,
    'toolbar-height': toolbarHeight,
    'value-chevron-gap': valueChevronGap,
  };
}
