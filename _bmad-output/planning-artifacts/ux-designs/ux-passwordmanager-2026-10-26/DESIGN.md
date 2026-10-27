---
name: PAK Manager
description: Trình quản lý mật khẩu cá nhân, offline hoàn toàn, iOS + Android (điện thoại + máy tính bảng). Giao diện iOS native trên cả hai nền tảng, bám theo bố cục và phong cách của Kaspersky Password Manager, một màu nhấn teal.
status: final
sources:
  - _bmad-output/planning-artifacts/prds/prd-passwordmanager-2026-10-23/prd.md
  - _bmad-output/planning-artifacts/prds/prd-passwordmanager-2026-10-23/addendum.md
created: 2026-10-26
updated: 2026-10-27
colors:
  # Light — lấy mẫu pixel từ imports/ (xem .working/visual-extract.md), làm tròn về giá trị iOS gần nhất khi sai lệch chỉ do nhiễu JPEG.
  surface-base: '#FFFFFF'
  surface-grouped: '#F2F2F7'
  surface-raised: '#FFFFFF'
  surface-sheet: '#FFFFFF'
  surface-sheet-grouped: '#F2F2F7'
  surface-sheet-cell: '#FFFFFF'
  surface-muted: '#F5F5F5'
  surface-toolbar: '#FAFAFA'
  fill-search: '#E3E3E8'
  ink-primary: '#000000'
  ink-secondary: '#8A8A8E'
  ink-value: '#666666'
  ink-section: '#6D6D72'
  ink-disabled: '#C4C4C6'
  ink-tab-inactive: '#999999'
  accent: '#198470'
  accent-disabled: '#A3CEC6'
  accent-tint: '#E5F8F2'
  on-accent: '#FFFFFF'
  on-accent-disabled: '#FFFFFF'
  slider-fill: '#2DD1AC'
  thumb: '#FFFFFF'
  track: '#CCCCCC'
  separator: '#C6C6C8'
  separator-strong: '#ACACAC'
  border: '#CCCCCC'
  scrim: '#00000066'
  pw-letter: '#000000'
  pw-digit: '#007CC6'
  pw-symbol: '#E58B00'
  toast-bg: '#2C2C2E'
  toast-ink: '#FFFFFF'
  # Không có token đỏ / destructive — xem Colors › "Không có màu đỏ".
  # Dark — suy ra theo quy ước dark mode chuẩn của iOS; đã duyệt cùng mock light/dark, kèm 2 chỉnh sửa: page-sheet nâng nền, nút vô hiệu làm mờ chữ.
  surface-base-dark: '#000000'
  surface-grouped-dark: '#000000'
  surface-raised-dark: '#1C1C1E'
  surface-sheet-dark: '#1C1C1E'
  surface-sheet-grouped-dark: '#1C1C1E'
  surface-sheet-cell-dark: '#2C2C2E'
  surface-muted-dark: '#2C2C2E'
  surface-toolbar-dark: '#161618'
  fill-search-dark: '#1C1C1E'
  ink-primary-dark: '#FFFFFF'
  ink-secondary-dark: '#8D8D93'
  ink-value-dark: '#A1A1A6'
  ink-section-dark: '#8D8D93'
  ink-disabled-dark: '#48484A'
  ink-tab-inactive-dark: '#8D8D93'
  accent-dark: '#22A085'
  accent-disabled-dark: '#0F2E28'
  accent-tint-dark: '#1D3633'
  on-accent-dark: '#FFFFFF'
  on-accent-disabled-dark: '#7C8C88'
  slider-fill-dark: '#2DD1AC'
  thumb-dark: '#FFFFFF'
  track-dark: '#39393D'
  separator-dark: '#38383A'
  separator-strong-dark: '#545458'
  border-dark: '#48484A'
  scrim-dark: '#00000099'
  pw-letter-dark: '#FFFFFF'
  pw-digit-dark: '#0A84FF'
  pw-symbol-dark: '#FF9F0A'
  toast-bg-dark: '#E5E5EA'
  toast-ink-dark: '#000000'
typography:
  # fontFamily: SF Pro trên iOS; Android dùng Roboto thay thế [ASSUMPTION — đã ghi memlog]. Kích thước = cỡ mặc định (Large) của iOS text style tương ứng.
  large-title:
    fontFamily: 'SF Pro, Roboto'
    fontSize: 34px
    fontWeight: '700'
    lineHeight: 41px
    note: 'iOS Large Title — chỉ dùng cho tên app trên Login'
  nav-title:
    fontFamily: 'SF Pro, Roboto'
    fontSize: 17px
    fontWeight: '600'
    lineHeight: 22px
    note: 'iOS Headline — tiêu đề inline căn giữa, không dùng large title'
  body:
    fontFamily: 'SF Pro, Roboto'
    fontSize: 17px
    fontWeight: '400'
    lineHeight: 22px
    note: 'iOS Body'
  body-emphasis:
    fontFamily: 'SF Pro, Roboto'
    fontSize: 17px
    fontWeight: '600'
    lineHeight: 22px
    note: 'iOS Body semibold — nút đầy, nút Xóa hết (Clear), Lưu, nút hủy trong alert, nhãn chip, tiêu đề card'
  callout:
    fontFamily: 'SF Pro, Roboto'
    fontSize: 16px
    fontWeight: '400'
    lineHeight: 21px
    note: 'iOS Callout — thời điểm trong Recent'
  subhead:
    fontFamily: 'SF Pro, Roboto'
    fontSize: 15px
    fontWeight: '400'
    lineHeight: 20px
    note: 'iOS Subheadline — "Password Length:" (có dấu hai chấm) trong sheet, Ghi chú trên card'
  subhead-emphasis:
    fontFamily: 'SF Pro, Roboto'
    fontSize: 15px
    fontWeight: '600'
    lineHeight: 20px
    note: 'iOS Subheadline semibold — toast'
  footnote:
    fontFamily: 'SF Pro, Roboto'
    fontSize: 13px
    fontWeight: '400'
    lineHeight: 18px
    note: 'iOS Footnote — header nhóm VIẾT HOA, nhãn field, inline-message, dòng phụ Export'
  tab-label:
    fontFamily: 'SF Pro, Roboto'
    fontSize: 10px
    fontWeight: '500'
    lineHeight: 12px
    note: 'iOS tab bar item'
  password-display:
    fontFamily: 'SF Pro, Roboto'
    fontSize: 24px
    fontWeight: '600'
    lineHeight: 30px
    note: 'Mật khẩu lớn ở màn hình Tạo mật khẩu và sheet tạo mật khẩu. Sans thường, KHÔNG monospace (memlog Q3b)'
  password-inline:
    fontFamily: 'SF Pro, Roboto'
    fontSize: 17px
    fontWeight: '400'
    lineHeight: 22px
    note: 'Mật khẩu trong Recent và trên card khi hiện. Sans thường, KHÔNG monospace (memlog Q3b)'
rounded:
  sm: 6px
  md: 10px
  alert: 14px
  lg: 20px
  full: 9999px
spacing:
  '1': 4px
  '2': 8px
  '3': 12px
  '4': 16px
  '5': 24px
  '6': 32px
  margin: 16px
  cell-inset: 16px
  chip-gap: 10px
  card-gap: 12px
  section-gap: 35px
  button-inset-generator: 30px
  button-inset-sheet: 40px
  row-height: 44px
  recent-row-height: 72px
  button-height: 48px
  chip-height: 50px
  circle-button: 36px
  touch-icon: 44px
  fab-size: 56px
  hold-button: 72px
  content-max-tablet: 672px
  # Đo từ ảnh (reconcile-*.md) — giá trị xấp xỉ ±1pt do nhiễu ảnh.
  switch-inset-generator: 10px
  password-refresh-gap: 10px
  generator-button-to-list: 60px
  chip-check-gap: 12px
  sheet-password-to-card: 55px
  sheet-label-to-slider: 25px
  sheet-slider-to-hairline: 33px
  sheet-hairline-to-chips: 16px
  sheet-card-to-button: 16px
  sheet-button-to-bottom: 40px
  recent-header-height: 91px
  recent-row-pad-top: 18px
  recent-row-pad-bottom: 17px
  recent-row-line-gap: 6px
  toolbar-height: 49px
  value-chevron-gap: 12px
components:
  nav-bar:
    background: '{colors.surface-base}'
    title: '{typography.nav-title}'
    title-color: '{colors.ink-primary}'
    action-icon: '{colors.ink-primary}'
    back-chevron: '{colors.accent}'
  tab-bar:
    background: '{colors.surface-toolbar}'
    border-top: '{colors.separator}'
    active: '{colors.accent}'
    inactive: '{colors.ink-tab-inactive}'
    label: '{typography.tab-label}'
  button-primary:
    background: '{colors.accent}'
    background-disabled: '{colors.accent-disabled}'
    foreground: '{colors.on-accent}'
    foreground-disabled: '{colors.on-accent-disabled}'
    typography: '{typography.body-emphasis}'
    radius: '{rounded.sm}'
    height: '{spacing.button-height}'
  button-text:
    foreground: '{colors.accent}'
    foreground-disabled: '{colors.ink-disabled}'
    typography: '{typography.body}'
  icon-button:
    tint: '{colors.accent}'
    tint-card-menu: '{colors.ink-secondary}'
    tint-nav: '{colors.ink-primary}'
    hit-area: '{spacing.touch-icon}'
  icon-button-circle:
    background: '{colors.surface-sheet}'
    border: '{colors.border}'
    tint: '{colors.accent}'
    size: '{spacing.circle-button}'
    radius: '{rounded.full}'
  fab-new-card:
    background: '{colors.accent}'
    foreground: '{colors.on-accent}'
    size: '{spacing.fab-size}'
    radius: '{rounded.full}'
  search-bar:
    background: '{colors.fill-search}'
    foreground: '{colors.ink-primary}'
    placeholder: '{colors.ink-secondary}'
    typography: '{typography.body}'
    radius: '{rounded.md}'
  credential-card:
    background: '{colors.surface-raised}'
    radius: '{rounded.md}'
    padding: '{spacing.cell-inset}'
    title: '{typography.body-emphasis}'
    field-label: '{typography.footnote}'
    field-label-color: '{colors.ink-secondary}'
    field-value: '{typography.body}'
    note: '{typography.subhead}'
    separator: '{colors.separator}'
    gap: '{spacing.card-gap}'
  popup-menu:
    note: 'Dáng iOS UIMenu, phẳng (xem Elevation); Android vẽ lại cùng dáng'
    background: '{colors.surface-raised}'
    foreground: '{colors.ink-primary}'
    border: '{colors.border}'
    separator: '{colors.separator}'
    check: '{colors.ink-primary}'
    item-height: '{spacing.row-height}'
    radius: '{rounded.md}'
  text-field:
    background: '{colors.surface-raised}'
    background-in-sheet: '{colors.surface-sheet-cell}'
    foreground: '{colors.ink-primary}'
    placeholder: '{colors.ink-disabled}'
    typography: '{typography.body}'
    height: '{spacing.row-height}'
    radius: '{rounded.md}'
    label: '{typography.footnote}'
    label-color: '{colors.ink-secondary}'
  text-field-login:
    note: 'Biến thể Login (S1/S2/S3)'
    background: '{colors.surface-raised}'
    border: '{colors.border}'
    radius: '{rounded.sm}'
    height: '{spacing.button-height}'
    margin: '{spacing.margin}'
  strength-meter:
    note: 'Chỉ chữ, không vẽ thanh (FR-2)'
    label: '{typography.footnote}'
    label-color: '{colors.ink-secondary}'
  inline-message:
    typography: '{typography.footnote}'
    color: '{colors.ink-secondary}'
  list-row:
    background: '{colors.surface-raised}'
    height: '{spacing.row-height}'
    typography: '{typography.body}'
    value-color: '{colors.ink-value}'
    value-color-generator: '{colors.ink-secondary}'
    value-chevron-gap: '{spacing.value-chevron-gap}'
    chevron: '{colors.ink-secondary}'
    separator: '{colors.separator}'
  section-header:
    typography: '{typography.footnote}'
    color: '{colors.ink-section}'
    transform: uppercase
  toggle:
    on: '{colors.accent}'
    off-track: '{colors.track}'
    thumb: '{colors.thumb}'
    trailing-inset-generator: '{spacing.switch-inset-generator}'
  slider:
    fill: '{colors.slider-fill}'
    track: '{colors.track}'
    thumb: '{colors.thumb}'
  chip-toggle:
    background-selected: '{colors.accent-tint}'
    background-unselected: '{colors.surface-muted}'
    check-selected: '{colors.accent}'
    check-unselected: '{colors.border}'
    label: '{typography.body-emphasis}'
    label-color: '{colors.ink-primary}'
    height: '{spacing.chip-height}'
    radius: '{rounded.sm}'
    gap: '{spacing.chip-gap}'
    check-label-gap: '{spacing.chip-check-gap}'
  password-display:
    typography: '{typography.password-display}'
    letter: '{colors.pw-letter}'
    digit: '{colors.pw-digit}'
    symbol: '{colors.pw-symbol}'
    refresh-gap: '{spacing.password-refresh-gap}'
  password-inline:
    typography: '{typography.password-inline}'
    letter: '{colors.pw-letter}'
    digit: '{colors.pw-digit}'
    symbol: '{colors.pw-symbol}'
  bottom-sheet:
    background: '{colors.surface-sheet}'
    radius-top: '{rounded.lg}'
    grabber: '{colors.border}'
    scrim: '{colors.scrim}'
    inner-card-border: '{colors.border}'
    inner-card-radius: '{rounded.sm}'
    inner-card-padding: '{spacing.cell-inset}'
    inner-hairline: '{colors.separator}'
    inner-hairline-inset: '{spacing.cell-inset}'
    length-label: '{typography.subhead}'
    length-label-color: '{colors.ink-secondary}'
    length-value-color: '{colors.ink-primary}'
  page-sheet:
    background: '{colors.surface-sheet-grouped}'
    cell: '{colors.surface-sheet-cell}'
    radius-top: '{rounded.md}'
    scrim: '{colors.scrim}'
    recent-header-height: '{spacing.recent-header-height}'
  recent-row:
    height: '{spacing.recent-row-height}'
    background-odd: '{colors.surface-raised}'
    background-even: '{colors.surface-muted}'
    date: '{typography.callout}'
    date-color: '{colors.ink-secondary}'
    separator: '{colors.separator}'
    padding-top: '{spacing.recent-row-pad-top}'
    padding-bottom: '{spacing.recent-row-pad-bottom}'
    line-gap: '{spacing.recent-row-line-gap}'
    padding-horizontal: '{spacing.margin}'
  bottom-toolbar:
    background: '{colors.surface-toolbar}'
    border-top: '{colors.separator-strong}'
    height: '{spacing.toolbar-height}'
  toast:
    background: '{colors.toast-bg}'
    foreground: '{colors.toast-ink}'
    typography: '{typography.subhead-emphasis}'
    radius: '{rounded.full}'
  alert-dialog:
    note: 'Dáng iOS UIAlertController; Android vẽ lại cùng dáng'
    background: '{colors.surface-raised}'
    title: '{typography.body-emphasis}'
    body: '{typography.footnote}'
    body-color: '{colors.ink-primary}'
    action: '{colors.accent}'
    action-height: '{spacing.row-height}'
    separator: '{colors.separator}'
    scrim: '{colors.scrim}'
    radius: '{rounded.alert}'
  hold-confirm-button:
    size: '{spacing.hold-button}'
    ring-track: '{colors.track}'
    ring-progress: '{colors.accent}'
    icon: '{colors.accent}'
    label: '{typography.footnote}'
    label-color: '{colors.ink-secondary}'
  wheel-picker:
    note: 'Dáng iOS UIPickerView trong panel đáy; Android vẽ lại cùng dáng'
    background: '{colors.surface-sheet}'
    radius-top: '{rounded.lg}'
    bar-height: '{spacing.row-height}'
    selection-band: '{colors.surface-muted}'
    selection-radius: '{rounded.sm}'
    selection-inset: '{spacing.margin}'
    typography: '{typography.body}'
    scrim: '{colors.scrim}'
  empty-state:
    typography: '{typography.body}'
    color: '{colors.ink-secondary}'
  activity-indicator:
    color: '{colors.ink-secondary}'
---

# PAK Manager — Design Spine

> Ảnh tham chiếu (chụp từ Kaspersky Password Manager, là **mẫu bám theo**): [`imports/password_generator.jpg`](imports/password_generator.jpg) · [`imports/edit_pass.jpg`](imports/edit_pass.jpg) · [`imports/recent_password.jpg`](imports/recent_password.jpg) · [`imports/setting.jpg`](imports/setting.jpg). Số đo và màu light lấy từ các ảnh này.
>
> Mock đã duyệt (light + dark, phủ S1–S28): [`mockups/login.html`](mockups/login.html) · [`mockups/onboarding.html`](mockups/onboarding.html) · [`mockups/login-states.html`](mockups/login-states.html) · [`mockups/password-list.html`](mockups/password-list.html) · [`mockups/card-actions.html`](mockups/card-actions.html) · [`mockups/edit-card-sheet.html`](mockups/edit-card-sheet.html) · [`mockups/generator.html`](mockups/generator.html) · [`mockups/generator-extras.html`](mockups/generator-extras.html) · [`mockups/settings.html`](mockups/settings.html) · [`mockups/export-import.html`](mockups/export-import.html). Những chi tiết ảnh không có, mock tự bổ sung (ghi trong comment `<style>` đầu mỗi file); các chi tiết này đã được duyệt cùng mock và được nâng vào spine này.
>
> **Spine thắng mọi mâu thuẫn với `mockups/` và `imports/`** (DESIGN.md cho thị giác, EXPERIENCE.md cho hành vi). Mock và ảnh là minh họa; spine là hợp đồng.
>
> Quy ước đơn vị: `px` trong token = **pt** trên iOS = **dp** trên Android.
>
> ADD = addendum của PRD; memlog = nhật ký quyết định của chủ sản phẩm ([`.memlog.md`](.memlog.md)). Số memlog (Q…) chỉ được ghi khi quyết định ghi đè PRD hoặc khác ảnh tham chiếu.

## Brand & Style

PAK Manager là một công cụ cá nhân, không phải sản phẩm thương mại: offline, miễn phí, bảo mật là ưu tiên số một (PRD §1). Thị giác vì vậy cố ý **không có thương hiệu riêng**: không logo trên màn hình, không minh họa, không màu trang trí. App mượn trọn vẻ ngoài của một app iOS native chuẩn mực — nền trắng hoặc grouped xám nhạt, hàng 44pt, separator hairline, công tắc UISwitch — và chỉ thêm **một màu nhấn teal** (NFR-13).

Nguồn thị giác là Kaspersky Password Manager, được **bám theo sát**: bố cục màn hình Tạo mật khẩu, sheet tạo mật khẩu, sheet Recent và Cài đặt được giữ gần như nguyên vẹn. Chỉ lấy **bố cục và phong cách**; không dùng lại logo, tên, icon thương hiệu hay bất kỳ dấu hiệu nhận diện nào của Kaspersky.

UI system: **iOS native (UIKit/SwiftUI look, SF Pro) trên cả iOS và Android**. Token dưới đây mở rộng mặc định của iOS; trên Android, app vẽ lại cùng dáng iOS thay vì dùng Material. Ngoài màu nhấn teal, thứ duy nhất "có màu" trong app là mật khẩu: chữ cái, chữ số và ký tự đặc biệt mang ba màu khác nhau (FR-33) — đó là điểm nhận diện thị giác thật sự của sản phẩm.

## Colors

Bảng màu gồm một màu nhấn, ba màu ký tự mật khẩu và một thang trung tính iOS. Giá trị light lấy mẫu pixel từ ảnh tham chiếu; giá trị nào chỉ lệch do nhiễu JPEG được làm tròn về màu hệ thống iOS gần nhất (ghi chú bên dưới). Token `*-dark` suy ra theo dark mode chuẩn iOS và **đã được chủ sản phẩm duyệt** qua mock light/dark ([`mockups/`](mockups/)), kèm hai chỉnh sửa: page-sheet dùng `surface-sheet-grouped` để mép sheet tách khỏi nền đen, nút đầy vô hiệu làm mờ chữ (`on-accent-disabled`).

| Token (light / dark) | Light | Dark | Dùng cho | Không dùng cho |
|---|---|---|---|---|
| `accent` / `accent-dark` | `#198470` (lấy mẫu chính xác) | `#22A085` | Nút đầy, công tắc ON, nút chữ, icon hành động (copy, refresh, ẩn/hiện), tab đang chọn, vòng tick chip, FAB — kể cả hành động phá hủy, xem "Không có màu đỏ" bên dưới | Trang trí, nền lớn, trạng thái (độ mạnh/lỗi/cảnh báo) |
| `accent-disabled` | `#A3CEC6` (accent 40% trên trắng) | `#0F2E28` | Nền nút đầy khi vô hiệu (Đăng nhập < 15 ký tự) | — |
| `on-accent-disabled` | `#FFFFFF` | `#7C8C88` | Chữ trên nút đầy khi vô hiệu — bản tối làm mờ chữ để nút không trông như bấm được | — |
| `accent-tint` | `#E5F8F2` | `#1D3633` | Nền chip đã chọn (123 / ABC / !@#) | Nền hàng, nền màn hình |
| `on-accent` | `#FFFFFF` | `#FFFFFF` | Chữ/icon trên nút đầy và FAB | — |
| `slider-fill` | `#2DD1AC` (mint, khác accent — giữ như ảnh) | `#2DD1AC` | Phần đã chọn của slider Password Length | Bất kỳ chỗ nào khác |
| `pw-letter` | `#000000` (= `ink-primary`) | `#FFFFFF` | Chữ cái trong mật khẩu (FR-33 "đen") | — |
| `pw-digit` | `#007CC6` | `#0A84FF` (systemBlue dark) | Chữ số trong mật khẩu (FR-33 "xanh dương") | Link, trạng thái |
| `pw-symbol` | `#E58B00` | `#FF9F0A` (systemOrange dark) | Ký tự đặc biệt trong mật khẩu (FR-33 "cam") | Cảnh báo — cam **không** mang nghĩa "cảnh báo" ở đâu cả |
| `surface-base` | `#FFFFFF` | `#000000` | Nền màn hình Tạo mật khẩu, Login, nav bar | — |
| `surface-grouped` | `#F2F2F7` (mẫu `#F2F1F7` → iOS systemGroupedBackground) | `#000000` | Nền Cài đặt, tab Quản lý mật khẩu, form card | — |
| `surface-raised` | `#FFFFFF` | `#1C1C1E` | Ô nhóm trong Cài đặt, credential card, hàng lẻ Recent | — |
| `surface-sheet` | `#FFFFFF` | `#1C1C1E` | Nền bottom sheet tạo mật khẩu | — |
| `surface-sheet-grouped` | `#F2F2F7` | `#1C1C1E` | Nền page-sheet dạng nhóm (form card, Export, Import, Change Main Password) — bản tối nâng lên `#1C1C1E` để mép sheet tách khỏi nền `#000000` phía sau (iOS elevated) | — |
| `surface-sheet-cell` | `#FFFFFF` | `#2C2C2E` | Ô/hàng nằm trong page-sheet dạng nhóm | Ô trên màn gốc (dùng `surface-raised`) |
| `surface-muted` | `#F5F5F5` (mẫu `#F6F6F6`) | `#2C2C2E` | Header + vùng trống sheet Recent, hàng chẵn Recent, chip chưa chọn, dải chọn của wheel picker | — |
| `surface-toolbar` | `#FAFAFA` | `#161618` | Thanh đáy Recent ("Xóa hết"), tab bar (cùng màu) | — |
| `fill-search` | `#E3E3E8` | `#1C1C1E` | Nền ô tìm kiếm | — |
| `ink-primary` | `#000000` | `#FFFFFF` | Tiêu đề, chữ hàng, icon app bar (lịch sử) | — |
| `ink-secondary` | `#8A8A8E` (mẫu `#868686–#8A8A8A`) | `#8D8D93` | "Password strength: …", "Độ mạnh: …" (strength-meter), "Password Length:", giá trị "16" ở hàng Password Length của S14, thời điểm Recent, nhãn field, inline-message, empty-state | Chữ chính |
| `ink-value` | `#666666` (mẫu `#636363–#686868`) | `#A1A1A6` | **Chỉ** giá trị + ⌃⌄ bên phải hàng Cài đặt ("3 phút") | Hàng Password Length ở S14 (dùng `ink-secondary`, theo ảnh) |
| `ink-section` | `#6D6D72` (mẫu `#757479` → iOS grouped header) | `#8D8D93` | Header nhóm VIẾT HOA ("GENERAL") | — |
| `ink-disabled` | `#C4C4C6` (ảnh không có trạng thái vô hiệu) | `#48484A` | Nút chữ vô hiệu ("Xóa hết" khi Recent trống, "Lưu" khi thiếu field bắt buộc), placeholder, icon trong ô Login đang khóa | — |
| `ink-tab-inactive` | `#999999` (mẫu `#989898`) | `#8D8D93` | Icon + nhãn tab chưa chọn | — |
| `separator` | `#C6C6C8` (mẫu `#C5–#C8` → iOS opaqueSeparator) | `#38383A` | Hairline giữa hàng, giữa field trong card | — |
| `separator-strong` | `#ACACAC` | `#545458` | Đường trên thanh đáy Recent | — |
| `border` | `#CCCCCC` | `#48484A` | Viền card trong sheet, viền nút tròn refresh, grabber, vòng chip chưa chọn, viền ô mật khẩu Login, viền popup-menu | — |
| `track` | `#CCCCCC` (mẫu `#CBCBCB`) | `#39393D` | Track slider, track công tắc OFF, vòng nền hold-confirm | — |
| `thumb` | `#FFFFFF` | `#FFFFFF` | Núm slider, núm công tắc | — |
| `scrim` | `#00000066` (đen 40% → khớp mẫu `#999999` trên trắng) | `#00000099` | Lớp mờ sau sheet | — |
| `toast-bg` / `toast-ink` | `#2C2C2E` / `#FFFFFF` | `#E5E5EA` / `#000000` | Toast "Đã copy", "Đã thêm N card" | — |

**Không có màu trạng thái.** Độ mạnh mật khẩu (Low / Medium / High), lỗi nhập, cảnh báo quên mật khẩu, số lần thử còn lại, đồng hồ đếm ngược — **tất cả chỉ bằng chữ**, màu `{colors.ink-secondary}` hoặc `{colors.ink-primary}`, giống "Password strength: High" xám trong ảnh. Không xanh/vàng/đỏ cho trạng thái.

**Không có màu đỏ ở bất kỳ đâu trong app.** Bảng màu không có token destructive. Hành động phá hủy — nút Xóa card và "Xóa hết" Recent trong alert-dialog, nút "Xóa & Tạo tài khoản mới", icon và vòng tiến trình của hold-confirm-button — dùng `{colors.accent}` như mọi nút; mục "Xóa" trong popup-menu cùng màu chữ với "Sửa". Tính phá hủy được truyền bằng chữ trên nút và bằng bước xác nhận (alert-dialog, giữ 3 giây), không bằng màu.

**Độ tương phản đo được** (tham khảo; chủ sản phẩm đã bỏ sàn accessibility riêng nên đây không phải yêu cầu):

| Cặp | Tỉ lệ |
|---|---|
| `on-accent` trên `accent` (light) | 4.6:1 |
| `accent` trên `surface-raised` (light) | 4.6:1 |
| `on-accent` trên `accent-dark` | 3.3:1 (chỉ đạt mức chữ lớn; nút dùng 17pt semibold) |
| `accent-dark` trên `surface-raised-dark` | 5.3:1 |
| `ink-secondary` trên trắng | 3.4:1 (như iOS secondaryLabel) |
| `pw-digit` trên trắng | 4.5:1 |
| `pw-symbol` trên trắng | **2.6:1** (thấp — giữ đúng màu ảnh mẫu) |
| `pw-digit-dark` / `pw-symbol-dark` trên `#1C1C1E` | 4.7:1 / 8.3:1 |

## Typography

Một họ chữ: **SF Pro** (iOS system font). Trên Android: **Roboto** thay thế, vì SF Pro chỉ được cấp phép cho nền tảng Apple — **[ASSUMPTION — đã ghi memlog]**. Thang cỡ chữ là các text style iOS ở cỡ mặc định; số đo từ ảnh khớp với Body 17 / Headline 17 / Footnote 13.

| Token | Cỡ / weight | Vai trò |
|---|---|---|
| `{typography.large-title}` | 34 / bold | Chỉ chữ "PAK Manager" trên Login S1/S3 |
| `{typography.nav-title}` | 17 / semibold | Tiêu đề nav và tiêu đề page-sheet căn giữa: "Tạo mật khẩu" / "Password Generator", "Mật khẩu gần đây" / "Recent Passwords", "Cài đặt" / "Settings", "Sửa card", "Export"… Không dùng large title |
| `{typography.body}` | 17 / regular | Chữ hàng, field, nút chữ ("Đóng"/Close, "Hủy", "Đổi mật khẩu chính", "Khóa Vault", "Tạo mật khẩu"), cảnh báo `create.warning` ở S2, dòng chữ S5, empty-state |
| `{typography.body-emphasis}` | 17 / semibold | Nút đầy, nút "Xóa hết" (Clear), "Lưu" trên page-sheet, nút ưu tiên / hủy trong alert, nhãn chip "123 / ABC / !@#", tiêu đề credential card |
| `{typography.callout}` | 16 / regular | Thời điểm `dd/MM/yyyy HH:mm` trong Recent |
| `{typography.subhead}` | 15 / regular | "Độ dài mật khẩu:" / "Password Length:" (có dấu hai chấm) và giá trị trong sheet, Ghi chú trên card |
| `{typography.subhead-emphasis}` | 15 / semibold | Chữ trong toast |
| `{typography.footnote}` | 13 / regular | Header nhóm VIẾT HOA, nhãn field (trên card và trên ô form), inline-message, strength-meter ("Độ mạnh: …"), dòng "Lần export gần nhất", thân alert-dialog, nhãn dưới hold-confirm-button |
| `{typography.tab-label}` | 10 / medium | Nhãn tab bar |
| `{typography.password-display}` | 24 / semibold | Mật khẩu lớn ở màn hình Tạo mật khẩu và sheet |
| `{typography.password-inline}` | 17 / regular | Mật khẩu trong Recent và trên card |

**Font mật khẩu: sans thường ở mọi chỗ, KHÔNG monospace** (memlog Q3b; giải quyết điểm mở "Font mật khẩu" trong addendum). Ảnh mẫu dùng monospace ở màn hình Tạo mật khẩu và Recent — đây là chỗ app **khác** ảnh có chủ đích. Phân biệt `l/1/I`, `O/0` dựa vào màu ký tự (FR-33), không dựa vào font.

Viết hoa: Title Case cho nhãn tiếng Anh ("Password Length", "Use Password"); VIẾT HOA chỉ cho header nhóm. Mật khẩu dài (tới 99 ký tự, FR-29) **xuống dòng theo ký tự**, căn giữa, không cắt ellipsis [ASSUMPTION].

## Layout & Spacing

Lưới 4pt của iOS, cộng các khoảng đo từ ảnh:

| Token | Giá trị | Nguồn / dùng |
|---|---|---|
| `{spacing.margin}` | 16 | Lề ngang màn hình, lề card grouped |
| `{spacing.cell-inset}` | 16 | Đệm trong ô/card; separator giữa hàng thụt 16 |
| `{spacing.section-gap}` | 35 | Khoảng giữa các nhóm Cài đặt / nhóm công tắc (= iOS inset-grouped) |
| `{spacing.chip-gap}` | 10 | Khoảng giữa 3 chip |
| `{spacing.button-inset-generator}` | 30 | Lề hai bên nút Copy |
| `{spacing.button-inset-sheet}` | 40 | Lề hai bên nút Use Password |
| `{spacing.row-height}` | 44 | Hàng list, hàng Cài đặt, text-field |
| `{spacing.recent-row-height}` | 72 | Hàng Recent 2 dòng |
| `{spacing.button-height}` | 48 | Nút đầy (đo: Copy 48, Use Password ~49–50) |
| `{spacing.chip-height}` | 50 | Chip |
| `{spacing.circle-button}` | 36 | Nút tròn refresh trong sheet |
| `{spacing.card-gap}` | 12 | Khoảng giữa các credential card |
| `{spacing.touch-icon}` | 44 | Vùng chạm tối thiểu của icon-button (quy ước iOS HIG) |
| `{spacing.fab-size}` | 56 | FAB tạo card |
| `{spacing.hold-button}` | 72 | Nút giữ 3 giây |
| `{spacing.content-max-tablet}` | 672 | Độ rộng tối đa cột nội dung trên tablet dọc (≈ iOS readable content width) [ASSUMPTION — đã ghi memlog] |

Khoảng đo thêm từ ảnh (reconcile-*.md; xấp xỉ ±1pt):

| Token | Giá trị | Nguồn / dùng |
|---|---|---|
| `{spacing.switch-inset-generator}` | 10 | Lề phải công tắc tới mép màn ở S14 (khác lề `cell-inset` 16 mà giá trị "16 >" dùng) |
| `{spacing.password-refresh-gap}` | 10 | Khe mật khẩu → icon refresh ở S14 |
| `{spacing.generator-button-to-list}` | 60 | Đáy nút Copy → đầu nhóm tùy chọn ở S14 |
| `{spacing.chip-check-gap}` | 12 | Khe vòng tick → nhãn trong chip |
| `{spacing.sheet-password-to-card}` | 55 | Mật khẩu → card viền trong sheet S11 |
| `{spacing.sheet-label-to-slider}` | 25 | Hàng "Password Length:" → slider (trong card) |
| `{spacing.sheet-slider-to-hairline}` | 33 | Slider → hairline (trong card) |
| `{spacing.sheet-hairline-to-chips}` | 16 | Hairline → hàng chip (trong card) |
| `{spacing.sheet-card-to-button}` | 16 | Card → nút Use Password |
| `{spacing.sheet-button-to-bottom}` | 40 | Nút Use Password → home indicator |
| `{spacing.recent-header-height}` | 91 | Header sheet Recent, gồm dải trống ~45 nền `surface-muted` dưới hàng tiêu đề |
| `{spacing.recent-row-pad-top}` / `{spacing.recent-row-pad-bottom}` | 18 / 17 | Đệm trên / dưới trong recent-row |
| `{spacing.recent-row-line-gap}` | 6 | Khe dòng thời điểm → dòng mật khẩu |
| `{spacing.toolbar-height}` | 49 | Phần nội dung bottom-toolbar Recent (~78 tính cả home indicator) |
| `{spacing.value-chevron-gap}` | 12 | Khe giá trị → ⌃⌄ ở hàng Cài đặt |

**Máy tính bảng: một cột duy nhất, căn giữa, giới hạn độ rộng** `{spacing.content-max-tablet}`, **chỉ hướng dọc**. Nền màn hình phủ toàn bộ; chỉ cột nội dung bị giới hạn. Không có bố cục hai cột / master-detail.

Màn hình Tạo mật khẩu (S14) giữ nhịp dọc rộng rãi như ảnh (vị trí tính từ mép trên ảnh tham chiếu, ảnh đã cắt status bar): cụm mật khẩu có tâm ở ~124pt (≈ 1/6 chiều cao), nút Copy ở ~208–256pt, nhóm tùy chọn bắt đầu ở ~316pt (cách nút `{spacing.generator-button-to-list}`) — khoảng trắng lớn phía trên là có chủ đích. List chia **hai nhóm** cách nhau `{spacing.section-gap}`: nhóm 1 = Password Length · Uppercase Letters · Lowercase Letters · Digits; nhóm 2 = Special Characters + hàng bộ ký tự đặc biệt (chỉ đọc, ngay dưới Special Characters).

Sheet tạo mật khẩu (S11), từ trên xuống: mật khẩu → `{spacing.sheet-password-to-card}` → card (hàng "Password Length:" → `{spacing.sheet-label-to-slider}` → slider → `{spacing.sheet-slider-to-hairline}` → hairline → `{spacing.sheet-hairline-to-chips}` → chip; card cao tổng ~182) → `{spacing.sheet-card-to-button}` → Use Password → `{spacing.sheet-button-to-bottom}` → home indicator.

### Bố cục các màn không có ảnh

Các nhịp dưới đây do mock tự bổ sung và đã được duyệt cùng mock. Anatomy của từng phần tử nằm ở Components; bảng này chỉ ghi vị trí và nhịp dọc. Giá trị ngoài token ghi bằng pt, bỏ đơn vị.

| Màn | Bố cục | Mock |
|---|---|---|
| Login S1 / S3 | Nền `{colors.surface-base}`, không nav-bar. "PAK Manager" căn giữa, đỉnh chữ cách đáy status bar ~120. S3: text-field-login cách tên app 48 → inline-message (số lần thử, đếm ngược, `login.corrupt`) cách ô 6, các dòng cách nhau 2 → button-primary "Đăng nhập" cách khối chữ 24. Hàng "Xóa & Tạo tài khoản mới" cao `{spacing.row-height}`, đáy cách mép màn 42 (ngay trên home indicator). S1: chỉ "Tạo tài khoản" (button-primary) ở đúng chỗ ô mật khẩu của S3, cách tên app 48. | [`login.html`](mockups/login.html) · [`onboarding.html`](mockups/onboarding.html) · [`login-states.html`](mockups/login-states.html) |
| Tạo tài khoản S2 | Màn push trên `{colors.surface-base}`, tiêu đề "Tạo tài khoản". `create.warning` (`{colors.ink-primary}`, lề `{spacing.margin}`) cách nav 24 → ô mật khẩu chính (text-field-login) cách 24 → strength-meter / inline-message → ô nhập lại cách 16 → button-primary cách 24. | [`onboarding.html`](mockups/onboarding.html) |
| Đang xóa S5 | Toàn màn `{colors.surface-base}`, không nav, không nút; cụm activity-indicator + dòng chữ căn giữa màn, khe 14. | [`onboarding.html`](mockups/onboarding.html) |
| Quản lý mật khẩu S7 | Dải nav-bar + search-bar có đệm dưới 8. Card đầu cách dải 16. empty-state căn giữa vùng giữa dải tìm kiếm và tab bar. | [`password-list.html`](mockups/password-list.html) · [`card-actions.html`](mockups/card-actions.html) |
| Form trong page-sheet (S9, S10, S21, S22, S25) và màn push S20 | Ô field: lề `{spacing.margin}`, đệm trái `{spacing.cell-inset}`. Nhãn trên ô (không viết hoa) thụt 32, đệm trên 8 (16 từ field thứ hai trở đi) / dưới 6. inline-message, strength-meter, gợi ý và cảnh báo nằm dưới ô, thụt 32, cách ô 6, các dòng cách nhau 8. "Tạo mật khẩu" (S9/S10) dưới ô Mật khẩu, thụt 32, cách ô 8. button-primary (S20–S25) cách khối trên 24, lề `{spacing.margin}`. Ô Ghi chú đệm dọc 11. | [`edit-card-sheet.html`](mockups/edit-card-sheet.html) · [`card-actions.html`](mockups/card-actions.html) · [`settings.html`](mockups/settings.html) · [`export-import.html`](mockups/export-import.html) |
| Cài đặt S18 | Đo từ ảnh @3x: section-header đệm trên 17 (khối đầu) / 24 (các khối có header phía sau), dưới 6; nhóm lề `{spacing.margin}`; hai khối không header (Đổi mật khẩu chính, Khóa Vault) cách khối trên `{spacing.section-gap}`. Hàng Export hai dòng có đệm dọc 10. | [`settings.html`](mockups/settings.html) |

## Elevation & Depth

Phẳng (flat), như ảnh. Phân tầng bằng ba cách, theo thứ tự ưu tiên: (1) nền khác tông (`surface-raised` trên `surface-grouped`), (2) separator hairline `{colors.separator}`, (3) viền 1px `{colors.border}` (card và nút tròn trong sheet). Không đổ bóng card, không đổ bóng nút.

Ngoại lệ có bóng: núm slider và núm công tắc (mặc định iOS); sheet, wheel-picker và alert-dialog nổi trên `{colors.scrim}`; FAB có một bóng nhẹ (x 0, y 2, blur 8, đen 20%) để tách khỏi danh sách cuộn bên dưới. Trong dark mode, phân tầng bằng tông nền (`#000000` → `#1C1C1E` → `#2C2C2E`), không bằng bóng.

**popup-menu phẳng:** không bóng, không scrim — tách khỏi nội dung bên dưới chỉ bằng viền 1px `{colors.border}` (cách (3) ở trên).

## Shapes

Bo góc nhỏ, đúng như ảnh — "công cụ", không "bong bóng":

- `{rounded.sm}` 6 — nút đầy, chip, card viền trong sheet (ảnh đo 6–7), ô mật khẩu Login, dải chọn wheel-picker.
- `{rounded.md}` 10 — ô grouped Cài đặt, credential card, ô tìm kiếm, ô field trong form, góc trên mọi page-sheet, popup-menu (ảnh đo ~10).
- `{rounded.alert}` 14 — alert-dialog (mặc định iOS).
- `{rounded.lg}` 20 — góc trên bottom sheet tạo mật khẩu (ảnh đo 18–20) và panel wheel-picker.
- `{rounded.full}` — nút tròn refresh, FAB, toast, grabber, hold-confirm-button.

Không có nút dạng pill; chỉ toast có dạng viên thuốc.

## Components

Tên component dùng giống hệt trong EXPERIENCE.md (Component Patterns). Hành vi nằm ở EXPERIENCE.md; ở đây chỉ là thị giác.

Icon: SF Symbols trên iOS, nét mảnh, 22pt trong card / hàng, 24pt trên nav-bar, 26pt trên tab bar và FAB. Trên Android (SF Symbols chỉ được cấp phép cho nền tảng Apple) dùng một bộ icon tương đương hình dạng; việc chọn bộ icon chuyển sang bước architecture [ASSUMPTION — đã ghi memlog].

Cột **Mock** trỏ tới file trong [`mockups/`](mockups/) thể hiện component đó; spine thắng khi mâu thuẫn.

| Component | Anatomy & thị giác | Trạng thái | Mock |
|---|---|---|---|
| **nav-bar** | Cao 44. Tiêu đề `{typography.nav-title}` căn giữa trên `{colors.surface-base}` (hoặc `surface-grouped` ở Cài đặt), không viền dưới. Icon hành động bên phải màu `{colors.ink-primary}` 24pt (icon lịch sử: đồng hồ có mũi tên vòng ngược chiều kim, nửa trái vòng nét chấm). Chevron back `{colors.accent}` chỉ ở màn push: S20 hiện chevron + tên màn trước ("Cài đặt", mặc định iOS); S2 chỉ chevron (S1 không có tiêu đề). | — | [`generator.html`](mockups/generator.html) · [`settings.html`](mockups/settings.html) · [`onboarding.html`](mockups/onboarding.html) |
| **tab-bar** | 3 mục, cao 49 + home indicator (83 tổng): icon 26pt + nhãn `{typography.tab-label}`, khe 2. Nền `{colors.surface-toolbar}`, hairline trên `{colors.separator}`. Icon nét: chìa khóa (Quản lý mật khẩu) / đũa phép có tia sáng (Tạo mật khẩu) / núm xoay có vành răng (Cài đặt). | Chọn: `{colors.accent}`; chưa chọn: `{colors.ink-tab-inactive}` | [`password-list.html`](mockups/password-list.html) |
| **button-primary** | Nút đầy full-width trong lề, cao `{spacing.button-height}`, `{rounded.sm}`, nền `{colors.accent}`, chữ `{colors.on-accent}` `{typography.body-emphasis}`. Copy: lề `{spacing.button-inset-generator}`; Use Password: lề `{spacing.button-inset-sheet}`; các nút khác (Đăng nhập, Tạo tài khoản, Đổi mật khẩu, Tiếp tục, Tạo file): lề `{spacing.margin}`. | Vô hiệu: nền `{colors.accent-disabled}`, chữ `{colors.on-accent-disabled}`. Bận: chữ thay bằng activity-indicator màu `{colors.on-accent}` | [`login.html`](mockups/login.html) · [`generator.html`](mockups/generator.html) · [`export-import.html`](mockups/export-import.html) |
| **button-text** | Chữ `{colors.accent}` `{typography.body}`, không nền. "Xóa hết" (Clear) dùng `{typography.body-emphasis}` căn giữa. "Lưu" trên page-sheet: `{typography.body-emphasis}`. "Đổi mật khẩu chính", "Khóa Vault": căn trái trong một ô `{colors.surface-raised}` riêng, không chevron. "Xóa & Tạo tài khoản mới": căn giữa ở đáy S3. "Tạo mật khẩu" (S9/S10): căn trái dưới ô Mật khẩu. | Vô hiệu: `{colors.ink-disabled}` | [`login.html`](mockups/login.html) · [`settings.html`](mockups/settings.html) · [`edit-card-sheet.html`](mockups/edit-card-sheet.html) |
| **icon-button** | Icon nét 22pt (24 trên nav-bar), không nền, vùng chạm `{spacing.touch-icon}`, màu `{colors.accent}`. Gồm: copy (hai hình vuông bo góc chồng), refresh (hai mũi tên vòng tròn, cạnh mật khẩu), ẩn/hiện (mắt; **icon thể hiện hành động kế tiếp**: mật khẩu đang ẩn → mắt, đang hiện → mắt gạch chéo), ⋯ menu card (ba chấm ngang, `{colors.ink-secondary}`). | Trong ô Login đang khóa (đếm ngược): icon `{colors.ink-disabled}` | [`password-list.html`](mockups/password-list.html) |
| **icon-button-circle** | Vòng tròn `{spacing.circle-button}`, nền `{colors.surface-sheet}`, viền 1px `{colors.border}`, icon refresh `{colors.accent}` — góc trên phải sheet, cách mép 16. | — | [`edit-card-sheet.html`](mockups/edit-card-sheet.html) |
| **fab-new-card** | Tròn `{spacing.fab-size}`, nền `{colors.accent}`, dấu "+" nét dày 26pt `{colors.on-accent}`, góc dưới phải, cách mép `{spacing.margin}` và cách đỉnh tab bar `{spacing.margin}`, bóng nhẹ (Elevation), nổi trên danh sách cuộn. | — | [`password-list.html`](mockups/password-list.html) |
| **search-bar** | Ô cao 36 bo `{rounded.md}`, nền `{colors.fill-search}`, icon kính lúp 18pt + placeholder `{colors.ink-secondary}`, nút xóa (x tròn) khi có chữ; chữ đã gõ `{colors.ink-primary}`. Nằm dưới nav-bar, **chung dải nền `{colors.surface-base}`** với nav-bar, lề `{spacing.margin}`. | Focus: con trỏ `{colors.accent}` | [`password-list.html`](mockups/password-list.html) · [`card-actions.html`](mockups/card-actions.html) |
| **credential-card** | Ô `{colors.surface-raised}` bo `{rounded.md}`, lề ngang `{spacing.margin}`, cách nhau `{spacing.card-gap}`, trên nền `{colors.surface-grouped}`. Thứ tự: hàng tiêu đề cao 48 (`{typography.body-emphasis}`, ⋯ ở góc phải — FR-23); hàng Tên đăng nhập; hàng Mật khẩu; hàng Ghi chú (ẩn nếu trống). Mỗi hàng field cao tối thiểu 56, đệm dọc 8: nhãn `{typography.footnote}` `{colors.ink-secondary}` ở trên, giá trị `{typography.body}` ở dưới; hairline `{colors.separator}` thụt `{spacing.cell-inset}` giữa các hàng. Icon bên phải: Tên đăng nhập → copy; Mật khẩu → ẩn/hiện rồi copy (copy ở mép phải ngoài cùng); Ghi chú: chữ `{typography.subhead}`, không icon. | Mật khẩu ẩn: `••••••••` (8 chấm cố định, không lộ độ dài) màu `{colors.ink-primary}`; hiện: password-inline tô màu theo loại ký tự. Ghi chú thu gọn: tối đa 3 dòng + "…"; mở rộng: toàn bộ | [`password-list.html`](mockups/password-list.html) |
| **popup-menu** | Menu nổi kiểu iOS UIMenu, phẳng (xem Elevation): nền `{colors.surface-raised}`, viền 1px `{colors.border}`, bo `{rounded.md}`, rộng ~200–220. Hàng cao `{spacing.row-height}`, `{typography.body}` `{colors.ink-primary}`, chỉ chữ (không icon), hairline `{colors.separator}` giữa hàng. Mục đang chọn có ✓ `{colors.ink-primary}` ở **đầu** hàng, trong cột rộng 20. | — | [`card-actions.html`](mockups/card-actions.html) · [`settings.html`](mockups/settings.html) |
| **text-field** | **Form (S9, S10, S20, S21, S22, S25):** mỗi field một ô riêng bo `{rounded.md}`, cao tối thiểu `{spacing.row-height}`, nền `{colors.surface-sheet-cell}` (trong page-sheet) hoặc `{colors.surface-raised}` (S20), chữ `{typography.body}`, nhãn `{typography.footnote}` `{colors.ink-secondary}` **phía trên ô** — nhịp ở Layout & Spacing. Placeholder `{colors.ink-disabled}`. Ô mật khẩu có icon-button ẩn/hiện bên phải. Ghi chú: nhiều dòng, tự giãn. **Biến thể Login (S1/S2/S3, `text-field-login`):** ô **rộng đúng bằng nút "Đăng nhập"/"Tạo tài khoản"** (cùng lề `{spacing.margin}`), cao `{spacing.button-height}`, nền `{colors.surface-raised}`, viền 1px `{colors.border}` bo `{rounded.sm}`, đệm trái 15. | Focus: con trỏ `{colors.accent}`; không đổi màu viền khi lỗi. Khóa (S3 đếm ngược): ô trống, icon `{colors.ink-disabled}` | [`edit-card-sheet.html`](mockups/edit-card-sheet.html) · [`login.html`](mockups/login.html) · [`onboarding.html`](mockups/onboarding.html) |
| **strength-meter** | **Chỉ chữ, không vẽ thanh** (FR-2): một dòng "Độ mạnh: {mức}" / "Strength: {mức}" (ba mức Low / Medium / High; chữ theo microcopy `pw.strength` ở EXPERIENCE.md) `{typography.footnote}` `{colors.ink-secondary}`, ngay dưới ô mật khẩu (S2: ô đầu; S20: ô Mật khẩu mới; S22: ô Mật khẩu export), lề như inline-message — cùng tinh thần "Password strength: High" xám trong ảnh. Không màu theo mức, không icon. | Rỗng (ô trống): ẩn dòng | [`onboarding.html`](mockups/onboarding.html) · [`settings.html`](mockups/settings.html) |
| **inline-message** | Một dòng chữ `{typography.footnote}` `{colors.ink-secondary}` ngay dưới field hoặc nhóm field, cách 6, thụt `{spacing.margin}` + `{spacing.cell-inset}` (thẳng mép chữ trong ô). Dùng cho mọi lỗi, gợi ý, cảnh báo, số lần thử còn lại, đếm ngược. Không icon, không màu. Thứ tự dòng: khi một ô có cả strength-meter và inline-message, dòng độ mạnh ở trên, thông báo ở dưới; ở S3, `login.lockout` hoặc `login.corrupt` nằm trên dòng `login.attempts`, dòng này luôn ở cuối. | — | [`login.html`](mockups/login.html) · [`login-states.html`](mockups/login-states.html) |
| **list-row** | Cao `{spacing.row-height}`, nhãn `{typography.body}` trái. Biến thể: giá trị + chevron `>` (Password Length; giá trị "16" màu `{colors.ink-secondary}`, không phải `ink-value`); giá trị + ⌃⌄ (picker Cài đặt: giá trị `{colors.ink-value}` và chevron ⌃⌄ ~7×11 là một cụm sát phải, khe `{spacing.value-chevron-gap}`, chevron cách mép card `{spacing.cell-inset}`); toggle; chevron `>` `{colors.ink-secondary}` (Import, Export — Export thêm dòng phụ `{typography.footnote}` `{colors.ink-secondary}`, hàng tự cao lên); hàng chỉ đọc (bộ ký tự đặc biệt). Màn Tạo mật khẩu: list **full-width** nền `{colors.surface-base}`, hai nhóm (xem Layout & Spacing), separator giữa hàng thụt `{spacing.cell-inset}`, separator đầu/cuối nhóm chạy full-width. Cài đặt: **inset-grouped** bo `{rounded.md}`. | — | [`generator.html`](mockups/generator.html) · [`settings.html`](mockups/settings.html) |
| **section-header** | `{typography.footnote}` VIẾT HOA `{colors.ink-section}`, thụt `{spacing.margin}` + `{spacing.cell-inset}` ("GENERAL" / "CHUNG"). | — | [`settings.html`](mockups/settings.html) |
| **toggle** | UISwitch chuẩn 51×31: ON `{colors.accent}`, OFF track `{colors.track}`, núm `{colors.thumb}`. Ở S14, mép phải công tắc cách mép màn `{spacing.switch-inset-generator}`, không phải `cell-inset`. | ON / OFF | [`generator.html`](mockups/generator.html) |
| **slider** | Track cao 4, phần đã chọn `{colors.slider-fill}`, phần còn lại `{colors.track}`, núm tròn ~27 `{colors.thumb}` có bóng. | — | [`edit-card-sheet.html`](mockups/edit-card-sheet.html) |
| **chip-toggle** | 3 chip bằng nhau, cao `{spacing.chip-height}`, `{rounded.sm}`, cách `{spacing.chip-gap}`. Vòng tròn 24 + nhãn `{typography.body-emphasis}` `{colors.ink-primary}` là **một cụm căn giữa ngang** trong chip, khe vòng → nhãn `{spacing.chip-check-gap}`. | Chọn: nền `{colors.accent-tint}`, vòng đặc `{colors.accent}` có ✓ trắng. Chưa chọn: nền `{colors.surface-muted}`, vòng rỗng viền `{colors.border}`, không ✓ [ASSUMPTION — ảnh và mock chỉ có trạng thái chọn] | [`edit-card-sheet.html`](mockups/edit-card-sheet.html) |
| **password-display** | `{typography.password-display}` căn giữa, mỗi ký tự tô theo loại: chữ cái `{colors.pw-letter}`, chữ số `{colors.pw-digit}`, ký tự đặc biệt `{colors.pw-symbol}` (FR-33). Màn Tạo mật khẩu: icon-button refresh bên phải mật khẩu, khe `{spacing.password-refresh-gap}`; **cả cụm mật khẩu + icon được căn giữa** như một khối (mật khẩu vì vậy hơi lệch trái tâm màn). Trong sheet: mật khẩu căn giữa một mình (refresh ở nút tròn góc trên). | — | [`generator.html`](mockups/generator.html) · [`edit-card-sheet.html`](mockups/edit-card-sheet.html) |
| **password-inline** | Như password-display nhưng `{typography.password-inline}`, căn trái. Dùng trong recent-row và credential-card khi hiện. | — | [`generator-extras.html`](mockups/generator-extras.html) · [`password-list.html`](mockups/password-list.html) |
| **bottom-sheet** | Sheet tạo mật khẩu: nền `{colors.surface-sheet}`, góc trên `{rounded.lg}`, grabber ~31×4 `{colors.border}` cách đỉnh 8, `{colors.scrim}` phía sau, chồng trên page-sheet form card. Từ trên xuống: icon-button-circle phải; "Độ mạnh mật khẩu: …" / "Password strength: …" `{typography.body}` `{colors.ink-secondary}` căn giữa; password-display; card viền 1px `{colors.border}` `{rounded.sm}` lề `{spacing.margin}` đệm `{spacing.cell-inset}` chứa "Độ dài mật khẩu:" / "Password Length:" — **có dấu hai chấm** (`{typography.subhead}` `{colors.ink-secondary}`) + giá trị (`{colors.ink-primary}`), slider, hairline `{colors.separator}` **thụt theo đệm card** (không chạm viền card, cùng mép với slider và chip), 3 chip-toggle; button-primary "Dùng mật khẩu này" / "Use Password". Nhịp dọc đo từ ảnh ở Layout & Spacing. Cao theo nội dung. | — | [`edit-card-sheet.html`](mockups/edit-card-sheet.html) |
| **page-sheet** | Sheet cao gần toàn màn (mép trên cách đỉnh màn 54), góc trên `{rounded.md}`; màn phía sau lùi lại dưới `{colors.scrim}` (mặc định iOS page sheet). Nền mặc định `{colors.surface-sheet-grouped}`, ô bên trong `{colors.surface-sheet-cell}` (form card, Export, Import); Recent dùng `{colors.surface-muted}`. Header của mọi page-sheet dạng form (Card mới, Sửa card, Export, Import) cao 56: nút chữ trái ("Đóng" / "Hủy"; bước 2 Export: chỉ chevron back `{colors.accent}`) + `{typography.nav-title}` căn giữa + nút chữ phải "Lưu" `{typography.body-emphasis}` (form card). Recent: header cao `{spacing.recent-header-height}`, gồm dải trống ~45 nền `{colors.surface-muted}` giữa hàng tiêu đề và hàng Recent đầu tiên (spine giữ số đo ảnh; mock chia 56 + 35, cùng tổng 91). | "Lưu" vô hiệu: `{colors.ink-disabled}` | [`edit-card-sheet.html`](mockups/edit-card-sheet.html) · [`card-actions.html`](mockups/card-actions.html) · [`generator-extras.html`](mockups/generator-extras.html) · [`export-import.html`](mockups/export-import.html) |
| **recent-row** | Cao `{spacing.recent-row-height}`, 2 dòng: thời điểm `{typography.callout}` `{colors.ink-secondary}` + password-inline, cả hai căn trái lề `{spacing.margin}`; đệm trên `{spacing.recent-row-pad-top}`, dưới `{spacing.recent-row-pad-bottom}`, khe giữa hai dòng `{spacing.recent-row-line-gap}`; icon-button copy phải, căn giữa dọc theo hàng, lề phải `{spacing.margin}`. Nền xen kẽ `{colors.surface-raised}` (lẻ) / `{colors.surface-muted}` (chẵn), separator full-width. | — | [`generator-extras.html`](mockups/generator-extras.html) |
| **bottom-toolbar** | Thanh đáy sheet Recent: phần nội dung cao `{spacing.toolbar-height}` (~78 tính cả home indicator), nền `{colors.surface-toolbar}`, đường trên `{colors.separator-strong}`, button-text "Xóa hết" (Clear) `{typography.body-emphasis}` căn giữa. | "Xóa hết" vô hiệu: `{colors.ink-disabled}` | [`generator-extras.html`](mockups/generator-extras.html) |
| **toast** | Viên thuốc `{rounded.full}`, nền `{colors.toast-bg}`, chữ `{typography.subhead-emphasis}` `{colors.toast-ink}`, đệm 8×16, căn giữa ngang, một dòng, đáy cách đỉnh tab bar `{spacing.margin}` (cách home indicator `{spacing.margin}` khi không có tab bar). Không icon. | — | [`card-actions.html`](mockups/card-actions.html) · [`export-import.html`](mockups/export-import.html) |
| **alert-dialog** | Hộp thoại kiểu iOS UIAlertController, rộng 270, căn giữa màn trên `{colors.scrim}`: nền `{colors.surface-raised}`, `{rounded.alert}`, đệm nội dung ~19 trên / 16 ngang / 18–20 dưới, tiêu đề `{typography.body-emphasis}`, thân `{typography.footnote}` `{colors.ink-primary}` (có thể không có thân: S17, S27). Hàng nút cao `{spacing.row-height}`, ngăn bởi hairline `{colors.separator}`; hai nút nằm ngang, chữ `{colors.accent}`. Nút hủy / nút an toàn ở **trái**, `{typography.body-emphasis}` ("Hủy", "Tiếp tục sửa"); nút hành động ở phải, `{typography.body}`. Riêng S6: "Tiếp tục" (phải) đậm, "Bỏ bản nháp" (trái) thường. S27 một nút "OK" thường. | — | [`card-actions.html`](mockups/card-actions.html) · [`login-states.html`](mockups/login-states.html) · [`export-import.html`](mockups/export-import.html) · [`generator-extras.html`](mockups/generator-extras.html) |
| **hold-confirm-button** | Nút tròn `{spacing.hold-button}` nằm trong thân dialog "Xóa & Tạo tài khoản mới", cách thân chữ 16; **không nền** — vòng chính là viền nút. Icon thùng rác `{colors.accent}` ở giữa, **vòng tiến trình quanh nút** dày 4 — nền vòng `{colors.track}`, phần đã giữ `{colors.accent}` chạy theo chiều kim đồng hồ từ 12 giờ. Nhãn `erase.hold` dưới nút, cách 8, `{typography.footnote}` `{colors.ink-secondary}`. | Chờ / đang giữ (vòng chạy) / hoàn tất (vòng đầy) | [`login-states.html`](mockups/login-states.html) |
| **wheel-picker** | Panel đáy cao ~302, nền `{colors.surface-sheet}`, góc trên `{rounded.lg}`, **không grabber**, trên `{colors.scrim}`. Thanh trên cao `{spacing.row-height}` chỉ có nút chữ "Xong" bên phải. Bánh xe 4–99 kiểu iOS UIPickerView: 7 giá trị thấy được, mờ dần theo khoảng cách; dải chọn cao 32 `{colors.surface-muted}` bo `{rounded.sm}` lề `{spacing.margin}`; chữ `{typography.body}`. | — | [`generator-extras.html`](mockups/generator-extras.html) |
| **empty-state** | Đoạn chữ `{typography.body}` `{colors.ink-secondary}` căn giữa (ngang và dọc trong vùng nội dung trống), lề ngang 32, tối đa 2 câu, không minh họa, không icon. | — | [`password-list.html`](mockups/password-list.html) · [`generator-extras.html`](mockups/generator-extras.html) |
| **activity-indicator** | Spinner mặc định iOS `{colors.ink-secondary}` (trên nút đầy: `{colors.on-accent}`). S5: spinner + một dòng `{typography.body}` `{colors.ink-secondary}` (vị trí ở Layout & Spacing). | — | [`onboarding.html`](mockups/onboarding.html) |

## Do's and Don'ts

| Do | Don't |
|---|---|
| Bám bố cục ảnh Kaspersky cho 4 màn đã có ảnh | Dùng logo, tên, icon thương hiệu hay bất kỳ dấu nhận diện nào của Kaspersky |
| Một màu nhấn `{colors.accent}` cho mọi hành động | Thêm màu nhấn thứ hai (ngoại lệ duy nhất: `{colors.slider-fill}` của slider, giữ như ảnh) |
| Trạng thái (độ mạnh, lỗi, cảnh báo, số lần thử, đếm ngược) **chỉ bằng chữ** `{colors.ink-secondary}` / `{colors.ink-primary}`; hành động phá hủy dùng `{colors.accent}` như mọi hành động, nói rõ hậu quả bằng chữ + bước xác nhận | Màu đỏ ở bất kỳ đâu (kể cả systemRed cho nút phá hủy, màu riêng cho mục "Xóa" trong menu); xanh/vàng/đỏ cho độ mạnh hay lỗi; viền ô đỏ; icon ⚠ |
| Độ mạnh mật khẩu chính / export: một dòng chữ "Độ mạnh: …" | Vẽ thanh / đoạn độ mạnh (kể cả một màu) |
| Tô màu ký tự mật khẩu ở **mọi** chỗ mật khẩu hiển thị dạng rõ | Dùng `{colors.pw-digit}` / `{colors.pw-symbol}` cho bất cứ thứ gì không phải ký tự mật khẩu |
| Mật khẩu bằng sans thường (`{typography.password-display}`, `{typography.password-inline}`) | Monospace cho mật khẩu (dù ảnh mẫu dùng) |
| Dáng iOS native trên cả Android (UISwitch, sheet có grabber, alert iOS, popup-menu) | Material components, ripple, FAB Material mở rộng (extended FAB), top app bar Material |
| Phẳng: phân tầng bằng tông nền, hairline, viền 1px; popup-menu chỉ có viền 1px `{colors.border}` | Đổ bóng card / nút / popup-menu |
| Tablet: một cột căn giữa ≤ `{spacing.content-max-tablet}`, chỉ dọc | Kéo giãn hàng full-width màn tablet; master-detail hai cột; bố cục ngang |
| Dark mode theo các token `*-dark` | Đảo màu tự động hoặc dùng lại giá trị light trên nền tối |
