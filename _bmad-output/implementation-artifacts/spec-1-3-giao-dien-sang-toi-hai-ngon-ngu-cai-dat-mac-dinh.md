---
title: 'Story 1.3 — Giao diện sáng/tối, hai ngôn ngữ và cài đặt mặc định'
type: 'feature'
created: '2026-11-05'
status: 'done'
route: 'dispatch'
baseline_commit: '9105be75db6a0ac9501601fbbdc344ca6ba13006'
review_loop_iteration: 0
context:
  - '{project-root}/_bmad-output/implementation-artifacts/epic-1-context.md'
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** App chưa có file `settings`, chưa có theme token, chưa có chuỗi vi/en và chưa khóa hướng theo loại thiết bị. Story 1.6 trở đi cần các nền này để dựng màn hình.

**Approach:**
- Thêm `settings_codec` (Dart thuần) và `SettingsStore`: nạp trước frame đầu, gom ghi 300 ms qua `AtomicFileWriter`.
- Thêm bộ token trong `features/shared/theme/`, ARB vi/en qua `flutter gen-l10n`, `ContentColumn` và chính sách hướng màn hình.
- `PakApp` đọc locale và theme từ store, ở phía trên `CupertinoApp`.

## Boundaries & Constraints

**Always:**
- Schema `settings` đúng bảng AD-20. Mặc định theo epics 1.3: `null`/`system`/3/10/3, gen dài 16 với mọi loại bật, `lastExportAt=null`.
- Chỉ `SettingsStore` đọc/ghi file `settings`, và chỉ `settings_codec` encode/decode file này.
- Màu:
  - Đủ **32** color token của DESIGN.md, mỗi token là một `CupertinoDynamicColor` có cặp light/dark, resolve theo `CupertinoTheme.brightnessOf`.
  - Hex 8 chữ số trong DESIGN là `#RRGGBBAA`, phải đổi sang `0xAARRGGBB`. Ví dụ `scrim` = `0x66000000`.
- Chữ: 11 kiểu chữ dùng font hệ thống qua family của `cupertino_ui`: `CupertinoSystemText` khi cỡ < 20, `CupertinoSystemDisplay` khi cỡ ≥ 20. Đặt `height = lineHeight / fontSize`. Không đặt `letterSpacing` và `color`.
- Spacing, radius và elevation theo DESIGN.md.
- l10n:
  - Delegates là `[AppLocalizations.delegate, ...GlobalCupertinoLocalizations.delegates]` của `cupertino_ui`. Không import `flutter_localizations` trong `lib/features/`. Không dùng hằng `localizationsDelegates` do gen-l10n sinh ra, vì hằng này kéo theo Material.
  - Key ARB là key microcopy đổi sang camelCase. Không hard-code chuỗi trong widget; tên app lấy qua `onGenerateTitle`.
- Chỉ thêm dependency `flutter_localizations` (sdk). `intl` vẫn là package bắc cầu.
- Khởi động không bao giờ bị chặn: lỗi khi đọc settings hay khi đặt hướng màn hình đều không ném ra trước `runApp`.
- Test chỉ dùng fake tự viết, và tên test gắn mã FR/NFR/UX-DR.

**Never:**
- Không thêm `flutter_riverpod`.
- Không làm UI chọn cài đặt (Epic 5), `SessionGate` hay S1–S3.
- Không ghi file `settings` khi chỉ nạp.
- Khi bootstrap trả `StorageUnavailable` thì không đọc/ghi file.
- Không dùng màu đỏ/destructive/trạng thái. Không dùng Material.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Cài lần đầu | không có file `settings` | `current` = mặc định | không ghi file |
| File hợp lệ | JSON v1 đủ trường | đọc đúng từng trường; `encode(decode(golden))` trùng byte với golden | — |
| Trường sai | `autolockMin: 7` hoặc `3.0`, `appearance: 1`, `gen.length: 100`, `gen.upper: "x"`, `language: "fr"`, `lastExportAt: -1` | chỉ trường đó lấy mặc định, các trường khác giữ nguyên | không ném |
| `gen` không phải object | `"gen": 5` hoặc thiếu | `gen` = mặc định | — |
| File hỏng | không phải UTF-8/JSON, không phải object, `v` ≠ 1 | toàn bộ mặc định | không ném |
| Đọc lỗi | lỗi I/O, `settings` là thư mục, file > 64 KB | toàn bộ mặc định, vẫn `runApp` | không ném |
| Gom ghi | 2 lần `update` cách nhau < 300 ms | 1 lần ghi, nội dung là snapshot mới nhất | — |
| Ghi tuần tự | `update` lúc lần ghi trước chưa xong | lần ghi sau chờ lần trước | — |
| Ghi lỗi | writer trả `AtomicWriteFailure` | RAM giữ giá trị mới, `dirty` vẫn bật; `flush()` hoặc `update` kế tiếp (kể cả no-op) ghi lại | không ném |
| Vào nền | `update` rồi app `hidden` trước 300 ms | `flush()` ghi ngay | — |
| Lưu trữ lỗi | bootstrap `StorageUnavailable` | store chỉ ở RAM với mặc định, không I/O | — |
| Ngôn ngữ | `language=null`, locale chính `vi_*` | Tiếng Việt; locale chính khác (kể cả `[fr, vi]`), `null` hoặc `[]` → English; `language` đã đặt thì dùng giá trị đó | — |
| Giao diện | `appearance=system`, máy tối | token `*-dark`, thanh hệ thống trong suốt với icon sáng; `light`/`dark` thì bỏ qua cài đặt máy | — |
| Hướng | cạnh ngắn logic của màn hình (display) < 600 | chỉ `portraitUp`; ≥ 600 → cả 4 hướng; size = 0 → chưa khóa, chờ metrics; tính lại khi display đổi (máy gập) | lỗi `SystemChrome` bị nuốt |

## Decisions

- **Git/CI:** làm trên nhánh `feat/1-3-theme-l10n-settings`, commit rồi push lên `origin` như story 1.2. Người dùng tự mở PR và tự kiểm CI.
- **`language=null` theo máy liên tục:** khi locale máy đổi thì resolve lại theo locale chính, tức phần tử đầu. Không ghi giá trị đã resolve vào file.
- **Tablet xoay mọi hướng** theo AD-1 và epics, bỏ qua dòng "tablet dọc" trong DESIGN.md. Thiết bị được phân loại theo kích thước màn hình (display), không theo cửa sổ, nên tablet vẫn là tablet khi chạy split-screen.
- **Code gen-l10n được commit:** bật `generate: true` vì Flutter 3.47.8 bắt buộc (người dùng duyệt 2026-11-09). CI chạy `flutter gen-l10n` trước bước Pigeon và yêu cầu `lib/l10n` không đổi.
- **Ngoài phạm vi:** không xử lý file `v` > 1 (trường hợp hạ cấp app) và không xử lý `gen` tắt cả 4 loại. Ràng buộc "phải bật ít nhất một loại" thuộc story 4.1.

</frozen-after-approval>

## Code Map

- `pak_manager/lib/main.dart` -- composition root. `runPakApp(StorageBootstrap, {releaseMode})` hiện chỉ nhận bootstrap. `PakApp` đang nằm ở đây.
- `pak_manager/lib/services/storage_bootstrap.dart` -- trả `StorageReady(PakPaths)` hoặc `StorageUnavailable`. Không sửa.
- `pak_manager/lib/core/io/atomic_file_writer.dart` -- `write(path, bytes)` trả `AtomicWriteResult`. Ghi song song cùng path là không an toàn.
- `pak_manager/lib/core/io/pak_paths.dart` -- có `settingsFile`.
- `pak_manager/lib/platform/pigeon_ports.dart` -- `PigeonPlatformPorts` cài cả `FileSyncPort` lẫn `BackupPort`.
- `pak_manager/tool/check_imports.dart:158` -- `features` chỉ được dùng các package `pak_manager`, `flutter`, `cupertino_ui`, `cupertino_icons`, `flutter_riverpod`. Được import `lib/services/` và `lib/l10n/`.
- `pak_manager/test/app_test.dart` -- đang gọi `app.PakApp()` không tham số và `runPakApp` theo chữ ký cũ. Test `main()` thật giả kênh `path_provider` và Pigeon.
- `pak_manager/ios/Runner/Info.plist` -- iPhone đang cho phép landscape; `~ipad` đã đủ 4 hướng; chưa có `CFBundleLocalizations`.
- `.github/workflows/ci.yml:61-75` -- `pub get`, sau đó bước Pigeon kiểm `git status --porcelain -- lib android ios`.
- `cupertino_ui-1.1.4`: `GlobalCupertinoLocalizations.delegates` gồm delegate Cupertino và delegate widgets. `text_theme.dart` dùng family `CupertinoSystemText`/`CupertinoSystemDisplay`.
- DESIGN.md (`_bmad-output/planning-artifacts/ux-designs/ux-passwordmanager-2026-10-26/`):
  - Màu: YAML L12–43 (light), L46–77 (dark), bảng L425–457.
  - Chữ: L78–145, bảng L480–492.
  - Spacing: YAML L152–191, bảng L502–519 và L521–539.
  - Radius: L146–151.
  - Elevation: L560–566.
- Microcopy: EXPERIENCE.md L100–206. Story này chỉ cần `app.name`, tức key `appName` = "PAK Manager".

## Tasks & Acceptance

**Execution:**
- [x] `pak_manager/pubspec.yaml`, `pubspec.lock`, `l10n.yaml` -- thêm `flutter_localizations: sdk: flutter`. Nội dung `l10n.yaml`: `arb-dir: lib/l10n`, template `app_en.arb`, `output-dir: lib/l10n`, `nullable-getter: false`.
- [x] `pak_manager/lib/l10n/{app_en,app_vi}.arb` và file sinh ra -- thêm key `appName`; xóa `.gitkeep`.
- [x] `.gitattributes` (gốc repo) -- thêm `pak_manager/test/fixtures/** -text`.
- [x] `pak_manager/lib/core/model/settings.dart`:
  - `Settings` và `GenSettings` bất biến; enum `AppLanguage{vi,en}`, `Appearance{system,light,dark}`.
  - `Settings.defaults`, `==`/`hashCode`, getter `isValid` theo miền ở task codec.
  - `copyWith` xóa được trường nullable bằng `clearLanguage`/`clearLastExportAt`.
- [x] `pak_manager/lib/core/format/settings_codec.dart`:
  - `decode(List<int>)` không bao giờ ném, xử lý theo Matrix.
  - `encode(Settings)` ra JSON UTF-8, thứ tự key như AD-20, không có khoảng trắng.
  - Miền hợp lệ:
    - 3 thời gian là `int` ∈ {1,3,5,10}.
    - `gen.length` là `int` trong 4–99.
    - Cờ `gen` là `bool`.
    - `language` ∈ {"vi","en",null}; `appearance` ∈ {"system","light","dark"}.
    - `lastExportAt` là `int` ≥ 0 hoặc null.
    - Key lạ bị bỏ qua.
- [x] `pak_manager/lib/services/settings_store.dart` -- `SettingsStore extends ChangeNotifier`:
  - `static Future<SettingsStore> load(String? path, AtomicFileWriter writer)` đọc tối đa 64 KB và không ném. `path` null nghĩa là chỉ dùng RAM. Thêm `SettingsStore.inMemory([Settings])` cho test.
  - `current` và `bool update(Settings Function(Settings) change)`: kết quả không hợp lệ thì trả `false` và không đổi gì; kết quả bằng `current` thì không notify.
  - Timer 300 ms bắt đầu từ thay đổi đầu tiên và không gia hạn. Hàng đợi ghi tuần tự. Snapshot lấy lúc lần ghi bắt đầu chạy.
  - Cờ `dirty` tắt sau khi ghi thành công.
  - `flush()`: hủy timer, enqueue nếu `dirty`, rồi chờ hàng đợi xong. `dispose()` hủy timer.
  - Timer và writer inject được.
- [x] `pak_manager/lib/features/shared/theme/`:
  - `pak_colors.dart`: 32 token, kèm `PakColors.all` (tên DESIGN → màu).
  - `pak_text_styles.dart`, `pak_spacing.dart` (đủ mọi key `spacing:`), `pak_radius.dart`.
  - `pak_elevation.dart`: doc ghi luật UX-DR5, cùng hằng bóng FAB.
  - `pak_theme.dart`: `pakTheme(Appearance)` → `CupertinoThemeData` với `brightness` null khi `system`, `primaryColor` = accent, nền `surface-base`, chữ `body` màu `ink-primary`.
- [x] `pak_manager/lib/features/shared/content_column.dart` -- `SafeArea` bọc `Align(topCenter)` và `ConstrainedBox(maxWidth: 672)`.
- [x] `pak_manager/lib/features/shared/orientation.dart`:
  - `preferredOrientationsFor(Size logical)` trả `null` khi size rỗng.
  - `applyOrientationPolicy(FlutterView)` lấy `display.size / display.devicePixelRatio`, bọc `try`.
- [x] `pak_manager/lib/features/shared/pak_app.dart` -- `PakApp(settings:)` là StatefulWidget:
  - `AppLifecycleListener(onHide: settings.flush)`.
  - Gọi lại chính sách hướng màn hình trong `didChangeMetrics`.
  - `ListenableBuilder` dựng `CupertinoApp` với:
    - `locale`, `localeListResolutionCallback` theo Matrix, `supportedLocales [en, vi]`;
    - delegates theo Always, `onGenerateTitle`, `theme`;
    - `builder` = `MediaQuery.withClampedTextScaling(maxScaleFactor: 1.3)` bọc `AnnotatedRegion<SystemUiOverlayStyle>`. Style đặt đủ `statusBarColor` và `systemNavigationBarColor` trong suốt, `statusBarBrightness`, `statusBarIconBrightness`, `systemNavigationBarIconBrightness`, theo `brightnessOf`;
    - `home` tạm: `CupertinoPageScaffold(child: ContentColumn(child: SizedBox.shrink()))`.
- [x] `pak_manager/lib/main.dart`:
  - Đổi chữ ký thành `runPakApp(storage, {required FileSyncPort fileSync, required bool releaseMode})`.
  - Thứ tự: `ensureInitialized` → `applyOrientationPolicy` → `storage.run()` → `SettingsStore.load(StorageReady ? settingsFile : null, AtomicFileWriter(fileSync))` → `runApp(PakApp(settings:))`.
  - `main()` truyền cùng một `PigeonPlatformPorts` cho cả backup lẫn `fileSync`.
- [x] `pak_manager/ios/Runner/Info.plist` -- iPhone chỉ cho Portrait; thêm `CFBundleLocalizations` [en, vi].
- [x] `.github/workflows/ci.yml` -- thêm bước `flutter gen-l10n` đặt **trước** bước Pigeon, kiểm `git status --porcelain -- lib/l10n` rỗng, với thông báo lỗi riêng.
- [x] Test:
  - `test/core/format/settings_codec_test.dart`, golden `test/fixtures/settings/v1/{defaults,custom}.json` (không newline cuối file); có test biên 0, 2, 4, 99, 3.0.
  - `test/services/settings_store_test.dart`: phủ mọi dòng Matrix về store, `dispose` khi timer đang chờ, gọi `flush()` đồng thời, `update` không hợp lệ.
  - `test/features/shared/{theme,content_column,orientation,pak_app}_test.dart`.
  - `test/l10n/arb_test.dart`: chỉ so các key không bắt đầu bằng `@`; chỉ quét giá trị message tìm `!`, `！` và emoji.
  - `test/tool/ios_plist_test.dart`.
  - Cập nhật `test/app_test.dart` theo chữ ký mới, giữ assert `pigeonCalls == ['excludeFromBackup']`.

**Acceptance Criteria:**
- Given `PakColors.all`, when resolve ở light và dark, then tập tên khớp đúng 32 token đọc từ YAML của DESIGN.md với đúng màu đã quy đổi, và không tên nào chứa red/destructive/error/success/warning.
- Given `PakSpacing`, when so với các key `spacing:` của DESIGN.md, then đủ và đúng giá trị.
- Given `MediaQuery` có `textScaler` 2.0, when build `PakApp`, then hệ số chữ bên trong app ≤ 1,3.
- Given màn rộng 1000, when đặt `ContentColumn`, then con rộng 672, nằm giữa theo chiều ngang và sát mép trên; màn rộng 375 thì con rộng hết màn.

### Review Findings

Code review 2026-11-09 (diff `9105be7..3ea75c6`; 4 lớp: blind, edge, verif-gap, acceptance). Tổng kết: 1 decision, 5 patch, 1 defer, 14 rejected.

- [x] [Review][Patch] (Decision đã chốt 2026-11-09: sửa triệt để — thêm `androidSdkInt` vào Pigeon; API ≥ 29 trong suốt, 26–28 đặc màu `surface-base`, 24–25 thanh đen icon trắng) Thanh điều hướng trong suốt làm nút điều hướng khó thấy hoặc không thấy trên Android < 29 — `SystemChrome.setEnabledSystemUIMode(edgeToEdge)` chỉ có tác dụng từ API 29 (`PlatformPlugin.java:360-361` của Flutter 3.47.8), nên ở API 24–28 app không vẽ sau thanh điều hướng. `systemNavigationBarColor` trong suốt lộ `windowBackground` của `NormalTheme` (`Theme.Light`, thực tế luôn sáng vì API < 29 gần như không có chế độ tối của hệ thống). Hệ quả: API 26–28 với `appearance` tối cho icon sáng trên nền sáng; API 24–25 bỏ qua `systemNavigationBarIconBrightness` (cần API 26) nên icon luôn trắng trên nền trắng. Trước diff này thanh điều hướng mặc định là đen nên không bị. Matrix ("thanh hệ thống trong suốt") không tính tới API < 29, vì vậy cần chọn hướng sửa. (medium; blind + edge)
- [x] [Review][Patch] Khôi phục assert chính xác các lời gọi Pigeon khi khởi động: `pigeonCalls.map(...) == ['excludeFromBackup']` và `pigeonCalls.single.$2 == [pak]`, đặt trước `store.update`; bỏ dòng `isNot(contains('fsyncDirectory'))` vì thừa [pak_manager/test/app_test.dart:141] (medium; acceptance + verif-gap + blind + edge)
- [x] [Review][Patch] Thêm test cho thấy `runPakApp` khóa hướng dọc **trước** khi bootstrap lưu trữ xong: display cỡ điện thoại, lưu trữ còn treo, `setPreferredOrientations([portraitUp])` đã gửi trong khi chưa có `CupertinoApp` [pak_manager/test/app_test.dart:219] (medium; verif-gap)
- [x] [Review][Patch] Đổi tiền tố test `ad1_` thành `ad01_` cho khớp quy ước có sẵn (`ad01_`, `ad02_`, `ad08_`…), áp cho 13 test trong `orientation_test`, `pak_app_test`, `app_test`, `ios_plist_test` [pak_manager/test/features/shared/orientation_test.dart:43] (low; acceptance)
- [x] [Review][Patch] Thêm test cho dòng Matrix "Đọc lỗi — lỗi I/O": file `settings` không đọc được (`chmod 000` trên POSIX, skip trên Windows) thì `load` trả mặc định và không ném; nhánh `on Object` của `_readCapped` hiện chưa test nào chạy tới [pak_manager/lib/services/settings_store.dart:189] (low; acceptance)
- [x] [Review][Patch] `resolveAppLocale` trả `const Locale('vi')` / `const Locale('en')` thay vì `pakSupportedLocales[1]` / `[0]`, để đổi thứ tự danh sách không đảo ngôn ngữ [pak_manager/lib/features/shared/pak_app.dart:35] (low; blind)
- [x] [Review][Defer] Máy gập: `display.size` có thể không đổi sau khi gập/mở nên chính sách hướng giữ theo trạng thái cũ [pak_manager/lib/features/shared/orientation.dart:40] — deferred: maybe-false, nếu đúng là medium. Cần xác nhận trên máy gập Android thật (hoặc emulator foldable) rằng `FlutterView.display.size` cập nhật khi gập; làm cùng mục deferred về `display.size` ở story 7.1.

**Rejected:**
- (acceptance) Thứ tự khởi động có thêm bước `edgeToEdge` nhưng spec chưa cập nhật — sửa là sửa spec đang review; bước này là patch #8 của build review.
- (acceptance) Decision đóng băng bị sửa mà Spec Change Log trống; `status: done` lệch sprint `review` — sửa là sửa spec; status được đồng bộ ở bước cuối của review này.
- (blind) Trạng thái spec mâu thuẫn (`done`/`review`/`review_loop_iteration`) — sửa là sửa spec.
- (blind) Implementation Notes/Verification chưa cập nhật sau patch của build review — sửa là sửa spec.
- (blind) iOS: vuốt sang app switcher (`inactive`) rồi kill trước 300 ms làm mất thay đổi — low: app `inactive` vẫn chạy nên timer 300 ms vẫn kích; không ai kill app kịp trong 300 ms sau khi đổi cài đặt.
- (blind) Regex ARB bỏ sót `‼`, `⏰`, mũi tên… — low: khó gặp trong microcopy; chọn dải nào cần phán đoán (`⌃⌄`, `→` có thể là chuỗi hợp lệ), không phải sửa thẳng.
- (blind) Chưa test nhánh hàm ghi ném lỗi — low: `AtomicFileWriter.write` tự bắt mọi lỗi (`on Object` ở L77/100/114), nên khi chạy thật không tới được nhánh này.
- (blind) Chưa test file có BOM — low: file nằm trong thư mục riêng của app, chỉ `encode` ghi, mà `encode` không bao giờ thêm BOM.
- (blind) `load` bắt buộc có `AtomicFileWriter` cả khi chỉ dùng RAM — low: không gây hại cụ thể cho ai; sửa phải đổi API công khai.
- (blind) `flush()` sau `dispose()` vẫn ghi — low: store sống suốt vòng đời app, không caller nào dispose rồi flush (giống triage build #10).
- (edge) `update()` sau `dispose()` → assert của `ChangeNotifier` — low: không ai gọi tới được (giống triage build #10); sửa phải thêm guard.
- (edge) Khẳng định "không bao giờ ném" sai khi `update` sau `dispose` — low: cùng lý do với dòng trên.
- (blind) Test `main()` chờ bằng vòng lặp thời gian thật — low: thay bằng `store.flush()` thì không còn kiểm được việc `onHide` có flush; giới hạn 2 giây là đủ.
- (blind) Chưa test theme đổi theo chế độ tối của máy lúc đang chạy — low: `brightness: null` nghĩa là `CupertinoApp` đọc `MediaQuery.platformBrightness` và tự build lại; khó bị hồi quy.

## Implementation Notes

- **Lệch Decisions (người dùng đã duyệt 2026-11-09, Decision đã sửa):** Flutter 3.47.8 từ chối `flutter gen-l10n` khi pubspec thiếu `flutter: generate: true` (`flutter_tools/lib/src/localizations/gen_l10n.dart` ném `Attempted to generate localizations code without having the flutter: generate flag turned on`), kể cả khi `output-dir` không phải package ảo. Để bước gen-l10n của Verification và CI chạy được, `pubspec.yaml` bật `generate: true`. Phần còn lại của quyết định vẫn giữ: code sinh ra nằm trong `lib/l10n/` và được commit, CI chạy `flutter gen-l10n` trước Pigeon và fail nếu `lib/l10n` đổi. Hệ quả: `flutter run`/`build` cũng sinh lại `lib/l10n` từ ARB (cùng nội dung nếu đã commit đúng).
- `flutter_localizations` từ transitive thành `direct main` trong `pubspec.lock`; `intl` vẫn transitive. File sinh ra import `intl` nhưng có `// ignore_for_file: type=lint` nên `depend_on_referenced_packages` không báo.
- `SettingsCodec` là lớp tĩnh (`SettingsCodec.decode/encode`) trong `lib/core/format/settings_codec.dart`. Miền hợp lệ dùng chung hằng trong `core/model/settings.dart` (`settingsMinuteChoices`, `genLengthMin/Max`) để `Settings.isValid` và codec không lệch nhau. `utf8.decode` của Dart bỏ BOM đầu file, nên file có BOM vẫn đọc được (không coi là hỏng).
- `SettingsStore.load(path, writer, {createTimer, write})`: `createTimer` và `write` là điểm inject cho test (`write` mặc định `writer.write`, vì `AtomicFileWriter` là `final class`). Đọc file: kiểm `FileSystemEntity.type == file` rồi đọc tối đa 64 KB + 1 byte; file đúng 64 KB vẫn đọc. Cờ `dirty` tắt chỉ khi lần ghi thành công **và** không có thay đổi mới trong lúc ghi (đếm `revision`). Store ở RAM (`path == null`) không bao giờ bật `dirty`.
- `ContentColumn` thêm `SizedBox(width: double.infinity)` trong `ConstrainedBox` để con lấp đủ bề ngang được phép (AC 672 / hết màn), thay vì co về bề rộng riêng.
- `PakApp` lấy `FlutterView` bằng `View.of(context)` trong `didChangeDependencies` (áp chính sách hướng lần đầu ở đó), rồi áp lại trong `didChangeMetrics`. `main.dart` áp trước `storage.run()` qua `platformDispatcher.implicitView`. `resolveAppLocale` được truyền thẳng làm `localeListResolutionCallback` (tear-off ổn định giữa các lần build).
- `.gitkeep` của `lib/core/format`, `lib/core/model`, `lib/features/shared`, `lib/features/shared/theme` cũng bị xóa vì các thư mục này đã có file.
- `test/features/shared/theme_test.dart` đọc thẳng YAML front matter của DESIGN.md (`../_bmad-output/...`), nên đổi token trong DESIGN mà không đổi code sẽ làm test đỏ.
- Trên máy dev Windows (`core.autocrlf=true`), chạy Pigeon làm `git status` báo đổi ở 3 file `.g.*` chỉ vì CRLF/LF (`git diff -w` rỗng); CI Linux không bị.
- **Verification (máy dev, 2026-11-09):** `flutter pub get --enforce-lockfile` OK; `flutter gen-l10n` + Pigeon không đổi nội dung; `flutter analyze --fatal-infos --fatal-warnings` 0 issue; `dart run tool/check_imports.dart` OK; `flutter test` 182 pass, 1 skip (có sẵn từ trước). Chưa chạy CI.

## Spec Change Log

## Review Triage Log

Review 2026-11-09 (diff `9105be7..` + cây làm việc; 3 lớp: blind, edge, verif-gap).

| # | Nguồn | Phát hiện | Verdict | Bằng chứng | Route |
|---|-------|-----------|---------|------------|-------|
| 1 | verif-gap | Không test nào cho thấy `runPakApp`/`main()` nạp file `settings` đã lưu và áp lên app | medium | Gap đã kiểm sẵn: test `main()` thật không có file `settings`; thay `paths.settingsFile` bằng `null` hoặc nối `fileSync` no-op thì vẫn xanh | patch |
| 2 | blind | Đọc lỗi tạm thời → mặc định, `update` kế tiếp ghi đè file thật | low | Có thật, nhưng chỉ khi đọc lỗi tạm thời (iOS data protection không áp với app ở tiền cảnh); file hỏng thì ghi đè là đúng. Muốn sửa phải thêm nhánh và trạng thái | reject |
| 3 | blind, edge | `didChangeMetrics` gọi `setPreferredOrientations` ở mỗi frame bàn phím | low | Có thật (lời gọi kênh thừa, cùng giá trị); không lỗi hành vi. Sửa cần thêm cache | reject |
| 4 | blind | `pakTheme` không nối `barBackgroundColor`, nav/tab text style | low | Spec chỉ yêu cầu brightness, primary, nền, body; story này chưa có nav/tab bar (1.6 nối) | reject |
| 5 | blind | `pakSupportedLocales` chép tay; `resolveAppLocale` bỏ qua `supported` | low | PRD chỉ có vi/en; thêm ngôn ngữ thứ ba không nằm trong kế hoạch | reject |
| 6 | blind | Spec `in-review` lệch sprint `in-progress` | false | Đúng thiết kế: bước trình bày đồng bộ sprint-status | reject |
| 7 | blind | Android thiếu khóa hướng trong manifest và `localeConfig` | low | Manifest không phân biệt được phone/tablet; chính sách áp trước bootstrap. `localeConfig` không có trong yêu cầu (app có cài đặt ngôn ngữ riêng ở Epic 5) | reject |
| 8 | blind | Thanh điều hướng Android < 15 không thật sự trong suốt | medium | Không bật `SystemUiMode.edgeToEdge` thì nền dưới thanh là `windowBackground` của `NormalTheme` (theo chế độ tối của máy, `values-night/styles.xml`), không theo theme app; lệch dòng Matrix "Giao diện" | patch |
| 9 | blind, edge | Lỗi ghi bị nuốt, không tự thử lại; flush khi `hidden` có thể bị OS treo | low | Đúng thiết kế: AD-18 không log; Matrix chỉ yêu cầu ghi lại ở `flush`/`update` kế tiếp; ghi nguyên tử nên bị kill giữa chừng không hỏng file | reject |
| 10 | blind, edge | `update` sau `dispose` → assert của `ChangeNotifier` | low | Store sống suốt vòng đời app, không có caller nào dispose rồi update; sửa cần thêm guard | reject |
| 11 | blind, edge | `theme_test` đọc DESIGN.md ngoài package; `indexOf` −1 khi thiếu `typography:` | low | CI checkout cả repo nên đường dẫn ổn; chỉ ra lỗi khó hiểu khi DESIGN đổi cấu trúc; sửa cần thêm guard | reject |
| 12 | blind | `fr47_hidden_app_flushes_pending_settings` chờ 20 ms thật | low | Hàm ghi trong test là fake chạy trong bộ nhớ, 20 ms dư cho microtask; không có I/O thật | reject |
| 13 | blind | Không có gì chặn việc dùng hằng `localizationsDelegates` sinh ra; `intl` bắc cầu | low | Quyết định trong spec (Always); `intl` được `flutter_localizations` ghim theo SDK | reject |
| 14 | blind | Bóng FAB không phụ thuộc dark mode | low | Mâu thuẫn nằm trong DESIGN.md; FAB chưa dùng (story 3.1) | reject |
| 15 | blind | Code Map của spec lỗi thời | low | Sửa là sửa spec của build này | reject |
| 16 | edge | Hàm `change` truyền vào `update` ném | false | Lỗi của caller, ném to là hành vi đúng | reject |
| 17 | edge | `raf.read` trả thiếu byte với file thường | low | File cục bộ < 64 KB đọc một lần là đủ; sửa cần thêm vòng lặp | reject |
| 18 | edge | (đã ghi deferred-work) `display.size` bằng 0 và không có metrics sau đó → phone không bị khóa dọc | maybe-false | Cần chạy trên máy Android thật để xem `display.size` lúc khởi động; `didChangeDependencies` và `didChangeMetrics` đều áp lại; nếu đúng thì medium | defer |

## Design Notes

- **`ChangeNotifier` thay cho Riverpod:** khi story 1.6 thêm Riverpod, provider bọc chính instance này.
- **Timer không gia hạn:** nếu đặt lại timer ở mỗi lần đổi thì khi người dùng kéo slider liên tục sẽ không bao giờ có lần ghi.
- **`update` nhận hàm:** hàm được áp lên `current` mới nhất, nên hai nơi cùng ghi (generator, export, wipe) không đè nhau.
- **Ngưỡng 600:** đây là ngưỡng `sw600dp` của Android; mọi iPhone đều < 500.

## Verification

**Commands (trong `pak_manager/`):**
- `flutter pub get --enforce-lockfile` -- resolve được.
- `flutter gen-l10n; dart run pigeon --input pigeons/platform_api.dart; git status --porcelain -- lib android ios` -- rỗng.
- `flutter analyze --fatal-infos --fatal-warnings` -- 0 issue.
- `dart run tool/check_imports.dart` -- exit 0.
- `flutter test` -- mọi test pass.

**Manual checks (người dùng, sau khi mở PR):**
- CI xanh ở cả job ubuntu (bước gen-l10n) và job macOS (Info.plist).
