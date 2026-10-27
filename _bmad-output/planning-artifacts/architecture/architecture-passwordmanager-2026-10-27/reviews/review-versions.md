---
type: architecture-review
lens: versions & reality-check (mọi quyết định đã chốt có được kiểm chứng trên web hay chỉ khẳng định từ trí nhớ)
target: ../ARCHITECTURE-SPINE.md
context: ../.memlog.md
reviewed: '2026-10-27'
verdict: 'CHƯA ĐẠT — sửa bảng Stack, AD-1, AD-5/ghi chú sodium rồi mới giao story'
---

# Review phiên bản và kiểm chứng thực tế — Architecture Spine PAK Manager

## Kết luận

**Chưa đạt, nhưng sửa nhanh.** Hướng công nghệ vẫn đúng: Flutter + libsodium + Pigeon + Riverpod đều còn tồn tại, còn được bảo trì, hỗ trợ Android + iOS và hợp với min Android API 24 / iOS 15. Các API native mà AD-8/AD-11/AD-14 dựa vào đều có thật, và API level khớp với khẳng định trong spine. Vấn đề là:

1. **Hai điểm sai về thực tế (High):** spine không biết Material/Cupertino đã tách khỏi Flutter SDK (Flutter 3.47, tháng 8/2026), và memlog ghi khởi tạo `SodiumInit.init()`, nhưng API này **không có** `pwhash`.
2. **Hai version trong bảng Stack đã cũ dù memlog ghi "Web 2026-10-27"** (flutter_riverpod, pigeon). Nguồn tra lúc đó đã lỗi thời.
3. **Bốn mục trong Stack không có dòng `(version)` nào trong memlog** (path_provider, share_plus, file_selector, cupertino_icons). Các API native trong AD-11/AD-14 cũng chỉ được khẳng định, không có dòng kiểm chứng. Review này đã kiểm tra lại: phần lớn đúng, trừ `cupertino_icons`.

Mức độ: **High** = agent làm đúng spine vẫn build sai hoặc sẽ phải migrate ngay; **Medium** = version/yêu cầu nền tảng lệch, gây lỗi build hoặc bị store từ chối nếu không sửa; **Low** = thiếu chi tiết, rủi ro nhỏ.

## Phát hiện

### V-1 [High] Material/Cupertino đã tách thành package riêng; spine vẫn dựa vào `package:flutter/cupertino.dart`

- **Spine nói:** AD-1 dùng `CupertinoApp`, `CupertinoTabScaffold`, `CupertinoIcons`; AD-14 dùng `CupertinoTextField`; Stack ghim `cupertino_icons 1.0.9` và "`flutter_localizations` theo SDK".
- **Thực tế:**
  - Flutter 3.47 (12/08/2026) phát hành `cupertino_ui` và `material_ui` 1.0 thành package độc lập. Code Cupertino trong SDK bị đóng băng từ 3.44. Thư viện trong SDK "scheduled for formal deprecation in the upcoming Fall stable release in November", tức Flutter 3.50 (branch cut 2026-10-06), chỉ còn vài tuần. Nguồn: https://flutter.dev/blog/whats-new-in-flutter-3-47, https://docs.flutter.dev/release/breaking-changes/material-ui-and-cupertino-ui
  - `cupertino_ui` hiện là **1.1.4** (flutter.dev, 6 ngày trước). Nguồn: https://pub.dev/packages/cupertino_ui
  - `cupertino_icons` hiện là **2.0.0** (28 ngày trước): "Switches the package to `cupertino_ui`", min Flutter 3.44 / Dart 3.12. Bản 1.0.9 là bản trước. Nguồn: https://pub.dev/packages/cupertino_icons/changelog
  - Localization delegate của Cupertino giờ nằm trong `cupertino_ui` (`GlobalCupertinoLocalizations` lấy từ `cupertino_ui`, không lấy từ `flutter_localizations`).
- **Hậu quả:** agent code theo spine sẽ import `package:flutter/cupertino.dart`, viết code sắp bị deprecated, rồi phải chạy migrate ngay sau khi lên 3.50. Hai package (`cupertino_ui` của app và `flutter/cupertino` của plugin) cùng tồn tại thì widget type không khớp.
- **Sửa:**
  - Stack: thêm `cupertino_ui ^1.1.4` và đổi `cupertino_icons` thành `2.0.0`.
  - AD-1: "import `package:cupertino_ui/cupertino_ui.dart`; cấm `package:flutter/cupertino.dart` và `package:flutter/material.dart`/`material_ui`". Đưa luật này vào lint import của AD-2, vì nó còn chặn được Material lẫn vào chắc hơn.
  - Conventions "Chuỗi giao diện": delegate Cupertino lấy từ `cupertino_ui`.
  - Ghi `(version)` vào memlog.

### V-2 [High] `pwhash` của package `sodium` chỉ có trong API sumo; `SodiumInit.init()` không đủ

- **Memlog nói:** "pub 'sodium' 4.1.2 … ho tro crypto_pwhash … init SodiumInit.init()". AD-5 dựa toàn bộ vào `crypto_pwhash`.
- **Thực tế:**
  - Class `Crypto` (từ `Sodium`/`SodiumInit`) chỉ có `aeadXChaCha20Poly1305IETF`, `secretBox`, `kdf`… và **không có `pwhash`**. Nguồn: https://pub.dev/documentation/sodium/latest/sodium/Crypto-class.html
  - README: `crypto_pwhash` được đánh dấu cột Sumo ("available only in the sumo API"). Cách dùng: "replace `SodiumInit` with `SodiumSumoInit` from the `package:sodium/sodium_sumo.dart` import". Trên native, binary của hai bản không khác nhau, nên không tốn thêm dung lượng. Nguồn: https://pub.dev/documentation/sodium/latest/
  - 4.1.0 (2026-08-24): `crypto.pwhash.call` bị deprecated, thay bằng `callRaw`/`callStr`. Nguồn: https://pub.dev/packages/sodium/changelog
- **Sửa:** AD-5/AD-16 hoặc Stack thêm ghi chú "khởi tạo bằng `SodiumSumoInit.init()` (`package:sodium/sodium_sumo.dart`); KDF dùng `pwhash.callRaw`". Sửa dòng memlog sai.
- **Ghi chú liên quan (ngoài lens):** KDF chạy 1–2 giây (AD-5) mà chạy trên UI isolate thì giao diện đứng hình. Package có `Sodium.runIsolated(...)` kèm `createTransferrableSecureKey`, nên dùng cho KDF. Nguồn: https://pub.dev/documentation/sodium/latest/sodium/Sodium-class.html

### V-3 [Medium] flutter_riverpod 3.3.1 đã cũ, bản hiện hành là 3.4.3

- **Spine:** `flutter_riverpod 3.3.1`. Memlog: "3.3.1 stable (03/2026)".
- **Thực tế:** Bản mới nhất là **3.4.3** (2026-09-04, min Dart 3.12). Chuỗi 3.4.0–3.4.2 phát hành tháng 7/2026, sửa lỗi `markNeedsBuild` và listener leak khi `ConsumerState.dispose`. 3.4.0 deprecate `SyncProviderTransformerMixin`. Không có thay đổi breaking, provider viết tay (không codegen) vẫn được hỗ trợ. Bản 3.3.1 đã 7 tháng tuổi. Nguồn: https://pub.dev/packages/flutter_riverpod/versions, https://pub.dev/packages/flutter_riverpod/changelog
- **Sửa:** Stack ghi `flutter_riverpod ^3.4.3`.

### V-4 [Medium] pigeon 26.3.x chậm 3 major; bản hiện hành là 29.0.11

- **Spine:** `pigeon (dev) 26.3.x`.
- **Thực tế:** Bản mới nhất là **29.0.11** (7 ngày trước, flutter.dev, min Dart 3.11). Bản 26.3.4 cuối cùng đã 6 tháng tuổi. Các thay đổi breaking:
  - 27.0.0: data class sinh ra override `toString`.
  - **28.0.0: generator Kotlin/Swift mặc định sinh `suspend`/`async`** cho `@FlutterApi` và `@HostApi` có `@async`.
  - 29.0.0: thêm FFI/JNI thử nghiệm.

  Nguồn: https://pub.dev/packages/pigeon/versions, https://pub.dev/packages/pigeon/changelog
- **Sửa:** Stack ghi `pigeon ^29.0.11` (dev). AD-11 nói rõ dùng kênh mặc định (không bật FFI/JNI thử nghiệm). Clock/clipboard nên là `@HostApi` đồng bộ để không phụ thuộc sự khác biệt `async`.

### V-5 [Medium] Ghim Flutter "3.47.x" quá lỏng; cần sàn 3.47.8 và chính sách cho 3.50

- **Thực tế:**
  - Stable hiện hành là **3.47.8** (2026-10-23, Dart 3.13.7). Bản này chặn khóa CA eMudhra bị lộ. Nguồn: https://storage.googleapis.com/flutter_infra_release/releases/releases_linux.json, https://docs.flutter.dev/release/archive
  - `sodium` 4.1.1+ yêu cầu Dart `^3.13.0`, nên Flutter 3.44 trở xuống không resolve được. `cupertino_icons 2.0.0` cần Flutter ≥3.44.
  - Flutter 3.50 dự kiến ra tháng 11/2026 (branch cut 2026-10-06) và mang theo đợt deprecate ở V-1.
- **Đã đúng:** docs.flutter.dev cho Flutter 3.47 ghi Android "24 to 37", iOS "15 to 27". Mặc định của 3.47 là minSdk 24, compileSdk/targetSdk 36. Nguồn: https://docs.flutter.dev/reference/supported-platforms, https://flutter.dev/blog/whats-new-in-flutter-3-47
- **Sửa:**
  - Stack ghi "Flutter 3.47.8+ (Dart 3.13)". Thêm dòng "targetSdk/compileSdk 36".
  - Google Play bắt buộc target API 36 với app mới và bản cập nhật từ 31/08/2026, nên cần ghi rõ. Nguồn: https://developer.android.com/google/play/requirements/target-sdk
  - Thêm vào Deferred: "nâng lên 3.50 sau khi ra, kèm migrate `cupertino_ui`".

### V-6 [Medium] libsodium build từ source qua build hook: chưa kiểm 16 KB page size và môi trường build Windows

- **Thực tế:**
  - Từ 4.0.0, `sodium` không còn đóng gói binary build sẵn. Package tự build libsodium qua build hook cho từng nền tảng. Nguồn: https://pub.dev/packages/sodium
  - Google Play yêu cầu `.so` của app target Android 15+ hỗ trợ trang 16 KB. Nguồn: https://developer.android.com/guide/practices/page-sizes
  - Không tìm thấy tài liệu nào xác nhận `.so` libsodium do build hook sinh ra đã align 16 KB. Có một PR "Add support for Android's new 16K page sizes" ở repo libsodium, trạng thái chưa rõ.
  - Changelog 4.0.1 ghi: build Android trên Windows cần bash không phải WSL (ưu tiên Git Bash) và `make` trong PATH. Người dùng/agent làm việc trên Windows (memlog), nên build Android local cần hai công cụ này.
- **Sửa:**
  - AD-19 thêm bước CI: kiểm alignment 16 KB của mọi `.so` trong AAB (`zipalign -c -P 16 -v 4` hoặc script `check_elf_alignment.sh` của Google).
  - Ghi yêu cầu Git Bash + make vào hướng dẫn môi trường dev, hoặc ghi rõ "chỉ build Android trên CI".

### V-7 [Low] iOS: nguồn `bootId` chưa được chỉ định; privacy manifest; UIScene

- AD-11 ghi iOS dùng `mach_continuous_time`, đúng: Apple mô tả "increments monotonically … including while the system is asleep" và khuyên dùng tương đương `clock_gettime_nsec_np(CLOCK_MONOTONIC_RAW)`. Nguồn: https://developer.apple.com/documentation/kernel/1646199-mach_continuous_time
- **Nhưng spine không nói `bootId` trên iOS lấy từ đâu.** Android có `BOOT_COUNT`, iOS không có API tương đương công khai.
  - Ứng viên là `sysctl` `kern.bootsessionuuid`. Review này chưa kiểm chứng được trên trang Apple, cần thử trên máy thật.
  - `kern.boottime` dịch chuyển khi đổi giờ hệ thống. Hướng sai đó vẫn an toàn (chỉ làm thời gian chờ bắt đầu lại), nhưng gây khó chịu cho người dùng.
  - AD-8/AD-11 cần chốt một nguồn.
- Privacy manifest: danh mục `NSPrivacyAccessedAPICategorySystemBootTime` chỉ liệt kê `ProcessInfo.systemUptime` và `mach_absolute_time()`, không có `mach_continuous_time`. Nếu agent đổi sang `mach_absolute_time`/`systemUptime` thì phải khai báo lý do `35F9.1`. `mach_absolute_time` còn không tính lúc máy ngủ, nên đổi là sai. Danh mục File timestamp gồm `stat`/`fstat`/`creationDate`…: native code của Pigeon không được dùng các API này nếu không khai báo. Nguồn: https://developer.apple.com/documentation/bundleresources/app-privacy-configuration/nsprivacyaccessedapitypes/nsprivacyaccessedapitype
- UIScene: blog 3.47 ghi "Apps built with Xcode 27 that do not adopt `UIScene` will fail to launch on startup". Flutter 3.41+ tự migrate template. Đăng ký Pigeon API phải đặt trong `didInitializeImplicitFlutterEngine` (`FlutterImplicitEngineDelegate`), không đặt trong `didFinishLaunching`. Nên ghi vào AD-11. Nguồn: https://docs.flutter.dev/release/breaking-changes/uiscenedelegate

### V-8 [Low] `file_selector` trên iOS/Android cần type group riêng theo nền tảng; `share_plus` ghi file tạm ngoài danh sách AD-13

- `file_selector 1.1.0` đúng là bản mới nhất (flutter.dev, 11 tháng trước). README cảnh báo `XTypeGroup` phải có filter cho mọi nền tảng, nếu không sẽ gặp `ArgumentError`. iOS cần `uniformTypeIdentifiers`: file `.pakx` cần khai báo exported UTI trong Info.plist hoặc lọc bằng `public.data`. Android dùng `mimeTypes`. `getSaveLocation` không hỗ trợ trên Android/iOS. Spine đã chọn share sheet cho export nên không bị ảnh hưởng. Nguồn: https://pub.dev/packages/file_selector
- `share_plus 13.3.1` đúng là bản mới nhất (fluttercommunity.dev, 25 ngày trước, iOS 13+, cần Flutter ≥3.38.1). Manifest **không có `uses-permission`**, chỉ có `ShareFileProvider` và receiver `SharePlusPendingIntent`. Nguồn: https://pub.dev/packages/share_plus, https://github.com/fluttercommunity/plus_plugins/blob/main/packages/share_plus/share_plus/android/src/main/AndroidManifest.xml
  - `XFile.fromData` ghi file tạm vào cache. File export đã mã hóa nên không lộ bản rõ. Nhưng AD-13 nói ngoài vault "chỉ ghi `guard` và `settings`", nên cần thêm ngoại lệ cho file export tạm và quy tắc dọn file tạm (README khuyên dọn lúc khởi động).

### V-9 [Low] zxcvbnm 1.1.1: đúng version nhưng gần như ngừng cập nhật

- 1.1.1 là bản mới nhất, nhưng phát hành **23 tháng trước**, uploader chưa xác minh, 4.36k lượt tải. Package ràng `intl >=0.17.0 <0.21.0`, nên khi Flutter/`cupertino_ui` lên `intl 0.21` thì zxcvbnm sẽ chặn nâng cấp. Package không có từ điển tiếng Việt. Nguồn: https://pub.dev/packages/zxcvbnm
- **Sửa:** ghi rủi ro chấp nhận vào AD-15, kèm phương án dự phòng (vendor mã nguồn MIT vào `third_party/` nếu xung đột `intl`). Kiểm tra mã nguồn không có network code (phụ thuộc chỉ gồm `algorithmic`, `intl`).

## Đã kiểm chứng: đúng như spine

| Khẳng định | Kết quả | Nguồn |
| --- | --- | --- |
| Flutter 3.47 là stable hiện hành; Android 24–37, iOS 15–27 | Đúng (3.47.8, 2026-10-23) | https://docs.flutter.dev/reference/supported-platforms |
| `sodium 4.1.2`, libsodium 1.0.22, Android+iOS | Đúng (2026-10-14, skycoder42.de, BSD-3/ISC). `aeadXChaCha20Poly1305IETF` có thật; `sodium_libs` đã discontinued, chuyển sang `sodium` là đúng | https://pub.dev/packages/sodium, https://pub.dev/packages/sodium_libs |
| libsodium Argon2id cố định p=1 | Đúng: `crypto_pwhash_argon2id` gọi `argon2id_hash_raw(..., (uint32_t) 1U, ...)` | https://github.com/jedisct1/libsodium/blob/master/src/libsodium/crypto_pwhash/argon2/pwhash_argon2id.c |
| `path_provider 2.1.6` | Đúng (4 tháng trước, flutter.dev; Android SDK 24+, iOS 13+) | https://pub.dev/packages/path_provider |
| `share_plus 13.3.1` | Đúng; không có quyền nào trong manifest | xem V-8 |
| `file_selector 1.1.0` | Đúng; xem lưu ý V-8 | https://pub.dev/packages/file_selector |
| `zxcvbnm 1.1.1` | Đúng; xem rủi ro V-9 | https://pub.dev/packages/zxcvbnm |
| `TextField`/`CupertinoTextField` có `enableIMEPersonalizedLearning` | Đúng, mặc định `true`. **Chỉ có tác dụng trên Android** ("On iOS, there is no equivalent flag") | https://api.flutter.dev/flutter/material/TextField/enableIMEPersonalizedLearning.html, https://api.flutter.dev/flutter/cupertino/CupertinoTextField/enableIMEPersonalizedLearning.html |
| `ClipDescription.EXTRA_IS_SENSITIVE` từ API 33 | Đúng (`android.content.extra.IS_SENSITIVE`). Chỉ là gợi ý hiển thị, không tăng bảo mật; compileSdk 36 nên dùng được hằng số | https://developer.android.com/reference/android/content/ClipDescription, https://developer.android.com/privacy-and-security/risks/secure-clipboard-handling |
| `Settings.Global.BOOT_COUNT` | Có từ **API 24** (API diff 24): bằng đúng minSdk, không còn dư | https://developer.android.com/sdk/api_diff/24/changes/android.provider.Settings.Global |
| `mach_continuous_time` tính cả lúc ngủ | Đúng (macOS 10.12 / iOS 10+) | xem V-7 |
| `UIPasteboard` `expirationDate` / `localOnly` | Đúng, cả hai có từ iOS 10.0. `localOnly` = không chia sẻ qua Handoff/Universal Clipboard | https://developer.apple.com/documentation/uikit/uipasteboard/optionskey/expirationdate, https://developer.apple.com/documentation/uikit/uipasteboard/optionskey/localonly |
| Plugin không thêm `INTERNET` | Đúng với share_plus (đã đọc manifest). path_provider/file_selector là plugin flutter.dev, không có network code. CI chặn `INTERNET` (AD-12) vẫn là lưới an toàn cuối | — |

## Độ phủ kiểm chứng trong memlog

| Mục | Có dòng `(version)` web? | Ghi chú |
| --- | --- | --- |
| Flutter, min OS | Có | Đúng; thiếu sàn patch (V-5) |
| sodium | Có | Version đúng; sai cách init (V-2) |
| flutter_riverpod | Có | Nguồn cũ (V-3) |
| pigeon | Có | Nguồn cũ (V-4) |
| zxcvbnm, SecLists | Có | Đúng; thiếu đánh giá bảo trì (V-9) |
| path_provider, share_plus, file_selector, cupertino_icons | **Không** | Ba mục đầu tình cờ đúng; cupertino_icons sai (V-1) |
| API native AD-11/AD-14 | **Không** | Đúng, ngoại trừ thiếu nguồn bootId iOS (V-7) |
| Material/Cupertino decoupling, targetSdk Play, 16 KB, UIScene | **Không** | V-1, V-5, V-6, V-7 |

## Đề xuất bảng Stack sau sửa

| Name | Version |
| --- | --- |
| Flutter SDK (kèm Dart 3.13) | 3.47.8+ stable (lên 3.50 khi ra, kèm migrate) |
| Android | minSdk 24, compileSdk/targetSdk 36 |
| iOS tối thiểu | 15.0 |
| sodium (libsodium 1.0.22) | ^4.1.2, dùng `SodiumSumoInit` |
| cupertino_ui | ^1.1.4 |
| cupertino_icons | ^2.0.0 |
| flutter_riverpod | ^3.4.3 |
| pigeon (dev) | ^29.0.11 |
| zxcvbnm | 1.1.1 (rủi ro bảo trì, V-9) |
| path_provider | ^2.1.6 |
| share_plus | ^13.3.1 |
| file_selector | ^1.1.0 |
