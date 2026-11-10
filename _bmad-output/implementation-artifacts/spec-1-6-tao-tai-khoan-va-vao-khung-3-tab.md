---
title: 'Story 1.6 — Tạo tài khoản và vào khung 3 tab'
type: 'feature'
created: '2026-11-10'
status: 'done'
route: 'dispatch'
baseline_commit: '7659be650d4ef62453bcd79f0f17c0516795a484'
review_loop_iteration: 0
context:
  - '{project-root}/_bmad-output/implementation-artifacts/epic-1-context.md'
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** App mới chỉ có màn trống: chưa có `AccountService`, `VaultSession`, `SessionGate`, chưa có S1/S2, component shared (`SecretField`, nút, spinner) hay khung 3 tab. Người dùng chưa tạo được tài khoản (FR-1, FR-2, FR-10, FR-45; story 1.6 trong `epics.md:591`).

**Approach:** Thêm `AccountService.bootstrap()/create()` và `VaultSession` tối thiểu ở `lib/services/`; nối kết quả `StorageBootstrap`, Sodium và blocklist ở `main.dart` vào `SessionGate` qua provider Riverpod viết tay. `SessionGate` (trong `CupertinoApp.builder`) hiện S1 → push S2; tạo xong thì thay bằng cây sau đăng nhập `KeyedSubtree(epoch)` chứa `CupertinoTabScaffold` 3 tab.

## Boundaries & Constraints

**Always:**
- Phân lớp theo `tool/check_imports.dart`: `lib/features` không import `sodium`, `dart:io`, `lib/platform/`; chỉ `core/model|policy|search`, `lib/services`, `lib/l10n`. Chỉ `main.dart` nối platform.
- Kết quả là kiểu sealed, không ném qua ranh giới lớp. `bootstrap()` → `BootstrapNoAccount | BootstrapHasAccount | BootstrapUnavailable`; `create(String)` → `CreateSuccess(VaultSession) | CreateFailure`. Chừa chỗ (comment) cho bước Epic 2 trong `bootstrap`.
- `create` theo AD-7: `ascii.encode` mật khẩu → salt 16 byte từ `RandomSource` → `calibrateVaultKdf` → DEK 32 byte (`sodium.secureCopy(random.bytes(32))`, wipe bản tạm) → `HeaderCodec.create/encode` → xóa đệ quy `vault/` nếu có → tạo `vault/` → `fsyncDirectory(pakDir)` → ghi `cards` rỗng, `recent` rỗng → ghi `header` **cuối cùng**. Lỗi bất kỳ bước nào → `CreateFailure`, dispose KEK/DEK, không để lại `header`. Luôn wipe `Uint8List` mật khẩu và dispose KEK trong `finally`.
- Fail closed: `StorageUnavailable`, Sodium init lỗi hoặc `BlocklistFilter.parse` → `null` thì không đọc/ghi vault và không cho tạo tài khoản.
- Mọi ô bí mật là `SecretField` (AD-14): không autofill hints, `autocorrect`/`enableSuggestions`/`enableIMEPersonalizedLearning` = false, menu ngữ cảnh chỉ còn Dán (và Chọn tất cả), giữ ký tự không ASCII, `controller.clear()` trong `dispose()`, nút mắt hiện/ẩn (UX-DR19).
- S2: kiểm `PasswordPolicy.check` mỗi lần gõ; inline-message một dòng theo ưu tiên non-ASCII → độ dài → phổ biến → lặp/tuần tự → mismatch (mismatch chỉ khi ô nhập lại dài bằng ô đầu). Dòng độ mạnh ở trên thông báo, ẩn khi ô trống, tính bằng `StrengthEstimator` sau debounce 150 ms (tránh giật, xem deferred 1.5). Nút bật khi `PasswordOk` và hai ô bằng nhau. Return chuyển ô; ở ô cuối gửi nếu nút bật. Khi bận: spinner `on-accent`, khóa ô, chặn bấm lặp và chặn Back (`PopScope`).
- Theme/chuỗi: chỉ token `PakColors/PakTextStyles/PakSpacing/PakRadius`, không màu đỏ; mọi chuỗi qua ARB vi/en (key = microcopy camelCase), không `!`/emoji.
- Tên test gắn FR/AD/UX-DR; chỉ fake tự viết.

**Never:** Không làm logic đăng nhập S3 (1.7), `lock()`/`SessionController`/timer (1.8–1.9), `ModalPresenter`/toast (Epic 3), `LockoutGuard`/wipe (Epic 2). Không sửa hiệu chỉnh KDF (mục deferred 1.4 giữ nguyên), không thêm `integration_test` Pigeon (giữ deferred). Không thêm package ngoài Stack (chỉ thêm `flutter_riverpod: 3.4.3`). Không dùng `CupertinoTextField` trực tiếp cho bí mật, không Material.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Máy mới | không có `vault/header` | `BootstrapNoAccount`, S1 | — |
| Tắt giữa chừng | `vault/` có `cards`/`recent`, không `header` | S1; `create` sau đó dọn `vault/` rồi tạo lại | — |
| Đã có tài khoản | có `vault/header` | `BootstrapHasAccount`, S3 tạm (chỉ tiêu đề) | — |
| Lưu trữ/Sodium/blocklist hỏng | `StorageUnavailable` hoặc init lỗi | S1, nút vô hiệu, `create.unavailable` | không đọc/ghi vault |
| Gõ chữ có dấu | `mậtkhẩu…` | giữ ký tự, `pw.nonAscii`, nút vô hiệu; xóa → ẩn | — |
| Ngắn / dài | 14 ký tự; 129 ký tự | `pw.tooShort` (N=14); `pw.tooLong`, không cắt chuỗi | — |
| Nhập lại | ô 2 ngắn hơn ô 1 / bằng nhưng khác | không báo / `pw.mismatch` | — |
| Tạo thành công | hợp lệ, khớp | 3 file trong `vault/`, header ghi sau cùng; vào tab Quản lý mật khẩu | — |
| KDF hoặc ghi lỗi | `calibrateVaultKdf` → `null`, writer `AtomicWriteFailure` | `CreateFailure`; ở lại S2, giữ nội dung ô, nút bật lại, hiện `create.failed` | không có `header` |

## Decisions

Người dùng chọn 2026-11-10:
- **Thân tab:** mỗi tab chỉ có nav-bar với tiêu đề `tab.cards` / `generator.title` / `tab.settings`, thân trống; không hiện `empty.cards` (nút + thuộc story 3.1).
- **Dòng độ mạnh khi có lỗi luật** (chung cho 1.6/5.3/6.2): vẫn hiện mức `zxcvbnm` như mockup `onboarding.html:92`; không ép "Thấp", không ẩn.
- **Lỗi hệ thống:** thêm 2 key, hiện như inline-message (`footnote`, `ink-secondary`): `create.unavailable` ở S1 dưới nút vô hiệu — vi "Không mở được dữ liệu của app. Hãy khởi động lại app." / en "Can't open app data. Restart the app."; `create.failed` ở S2 dưới nút — vi "Không tạo được tài khoản. Hãy thử lại." / en "Couldn't create the account. Try again." (ẩn khi người dùng sửa ô hoặc bấm lại).
- **Đã có tài khoản (trước 1.7):** S3 tạm chỉ có tiêu đề "PAK Manager" đúng vị trí S1; story 1.7 thêm ô và nút.
- **Độ dài spec:** giữ một spec (~4.000 token) dù vượt mức 1.600.
- **Git:** nhánh `feat/1-6-create-account` từ `main` (`7659be6`); commit/push do bước sau của workflow.

</frozen-after-approval>

## Code Map

- `pak_manager/lib/main.dart:37-70` -- composition root. Thêm: `SodiumSumoInit.init()` (try/catch → unavailable), `rootBundle.load('assets/blocklist.bloom')` → `BlocklistFilter.parse`, dựng `StrengthEstimator()` (làm nóng), `AccountService`, `await bootstrap()` trước `runApp` (không có màn chờ, UX-DR30); `runApp(ProviderScope(overrides: …, child: PakApp(…)))`. Comment :60-61 thay bằng code thật.
- `pak_manager/lib/services/storage_bootstrap.dart` -- `StorageReady(PakPaths)` / `StorageUnavailable`; không sửa.
- `pak_manager/lib/core/crypto/kdf_calibration.dart:39` `calibrateVaultKdf({password, salt, derive, nowMs})` → `CalibratedKek?` (KEK dùng thẳng); `kekDeriver(sodium)` :19. `random_source.dart` `SodiumRandomSource`; `wipe.dart` `wipe()`.
- `pak_manager/lib/core/format/header_codec.dart:163` `HeaderCodec.create({kek, dek, salt, params, random})` → `VaultHeader?`; `encode` :203; `dekBytes` :11. Mẫu dùng: `test/core/format/header_codec_test.dart:84-98`.
- `pak_manager/lib/core/format/vault_file_codec.dart:62,82` `encodeCards(const [], dek)`, `encodeRecent(const [], dek)` → `Uint8List?`.
- `pak_manager/lib/core/io/atomic_file_writer.dart:63-70` -- không tạo thư mục cha; `pak_paths.dart` `vaultDir/headerFile/cardsFile/recentFile/pakDir`.
- `pak_manager/lib/core/policy/` -- `PasswordPolicy(filter).check`, sealed `PasswordCheck`; `StrengthEstimator.estimate` → `PasswordStrength`.
- `pak_manager/lib/features/shared/pak_app.dart:145-178` -- `builder` hiện bọc `MediaQuery.withClampedTextScaling` → `AnnotatedRegion`; đặt `SessionGate` thay `child` ở đó; `home` thành không cần (giữ `CupertinoApp` hợp lệ).
- `pak_manager/lib/features/shared/theme/*`, `content_column.dart` -- token và `ContentColumn` có sẵn; tái dùng.
- `pak_manager/lib/l10n/app_{en,vi}.arb` -- hiện chỉ có `appName`; `flutter gen-l10n` sinh code đã commit; `test/l10n/arb_test.dart` kiểm cùng tập key, không `!`/emoji.
- `pak_manager/test/app_test.dart` -- chạy `main()` thật, kiểm Pigeon calls `['excludeFromBackup','androidSdkInt']` và tìm `ContentColumn`/`CupertinoPageScaffold`; cập nhật theo S1, không đổi danh sách Pigeon.
- `pak_manager/test/core/vault_fixture.dart` -- `initSodium()`, `QueueRandomSource`, `fixtureParams` dùng cho test service; `test/core/policy/policy_test_support.dart` `emptyFilter()/assetFilter()`.
- Tham chiếu UX: `ux-designs/ux-passwordmanager-2026-10-26/{EXPERIENCE.md:108-150,DESIGN.md:553-602}`, mockup `mockups/onboarding.html` (S1 :79, S2 :73-92, tab-bar :52); `epics.md:218-287` (UX-DR).

## Tasks & Acceptance

**Execution:**
- [x] Nhánh `feat/1-6-create-account` từ `main`; `pak_manager/pubspec.yaml` + lock -- thêm `flutter_riverpod: 3.4.3`.
- [x] `pak_manager/lib/services/vault_session.dart` -- `VaultSession` giữ DEK `SecureKey`, `cards`, `recent`; `toString()` che giá trị; `dispose()` hủy DEK (1.8 làm `lock()` đầy đủ).
- [x] `pak_manager/lib/services/account_service.dart` -- `bootstrap()`, `create(String)` theo Always; inject `SodiumSumo`, `RandomSource`, `AtomicFileWriter`, `FileSyncPort`, `PakPaths`, `KekDeriver`.
- [x] `pak_manager/lib/features/shared/providers.dart` -- `accountServiceProvider`, `passwordPolicyProvider`, `strengthEstimatorProvider`, `bootstrapResultProvider` (override trong `main.dart`; `null` = unavailable).
- [x] `pak_manager/lib/features/shared/{secret_field.dart,pak_buttons.dart}` -- `SecretField`; `PakPrimaryButton` (thường/vô hiệu/bận, cao 48, `PakRadius.sm`), `PakTextButton`; spinner `CupertinoActivityIndicator` màu theo UX-DR30.
- [x] `pak_manager/lib/features/shared/icons/tab_icons.dart` -- 3 `CustomPainter` chìa khóa / đũa phép có tia / núm xoay có vành răng, vẽ theo màu `IconTheme`, cỡ 26.
- [x] `pak_manager/lib/features/shared/{session_gate.dart,home_shell.dart}` -- gate: `Navigator` riêng cho S1/S3 (push S2 bằng `CupertinoPageRoute`); sau `CreateSuccess` tăng epoch, hiện `KeyedSubtree(ValueKey(epoch))` → `Navigator` gốc → `CupertinoTabScaffold` 3 `CupertinoTabView`, tab mặc định 0, tab-bar theo UX-DR29.
- [x] `pak_manager/lib/features/auth/{login_screen.dart,create_account_screen.dart}` -- S1 (UX-DR31) và S2 (UX-DR32) theo Always.
- [x] `pak_manager/lib/features/shared/pak_app.dart`, `pak_manager/lib/main.dart` -- nối như Code Map.
- [x] `pak_manager/lib/l10n/app_{en,vi}.arb` + gen-l10n -- `tabCards`, `tabGenerator`, `generatorTitle`, `tabSettings`, `loginCreate`, `createWarning`, `createFieldMain`, `createFieldConfirm`, `pwNonAscii`, `pwStrength{level}` + 3 mức, `pwTooShort{n}`, `pwTooLong`, `pwCommon`, `pwPattern`, `pwMismatch` (chuỗi đúng `EXPERIENCE.md:108-150`) + `createUnavailable`, `createFailed` (Decisions).
- [x] Test: `test/services/account_service_test.dart` (thứ tự ghi header cuối bằng writer ghi nhận; KDF/ghi lỗi không để `header`; dọn `vault/` cũ; wipe mật khẩu), `test/features/shared/{secret_field,pak_buttons,session_gate}_test.dart`, `test/features/auth/create_account_screen_test.dart` (mọi dòng Matrix phía UI, Return, debounce độ mạnh, chặn bấm lặp), cập nhật `test/app_test.dart`, `test/features/shared/pak_app_test.dart`.

**Acceptance Criteria:**
- Given app mở lần đầu, when frame đầu vẽ, then S1 có "PAK Manager" và đúng một nút "Tạo tài khoản", không link quên mật khẩu/gợi ý/câu hỏi bảo mật.
- Given S2 với mật khẩu hợp lệ và khớp, when bấm "Tạo tài khoản" hai lần liên tiếp, then `create` chạy đúng một lần, nút hiện spinner, và sau khi xong `cards`, `recent` được ghi trước `header`.
- Given `CreateSuccess`, when gate dựng lại, then thấy `CupertinoTabScaffold` 3 tab "Quản lý mật khẩu", "Tạo mật khẩu", "Cài đặt", tab đang chọn là tab 0, S2 và mọi `SecretField` đã bị gỡ (controller đã `clear()`).
- Given widget test `SecretField`, then các thuộc tính AD-14 đúng, menu ngữ cảnh không có Copy/Cut nhưng có Paste.
- Given toàn repo, then `flutter analyze --fatal-infos --fatal-warnings` 0 issue và `dart tool/check_imports.dart` exit 0.

## Implementation Notes

- **Build (2026-11-10).** Ngoài Code Map: `features/shared/inline_message.dart` (inline-message/strength-meter dùng chung), `pak_theme.dart` thêm `navTitleTextStyle`/`tabLabelTextStyle` từ token, test dùng chung `test/support/account_fakes.dart`, xóa `.gitkeep` của `features/auth` và `features/shared/icons`.
- **Provider mặc định fail closed:** không override thì `accountServiceProvider`/`passwordPolicyProvider` = `null`, `bootstrapResultProvider` = `BootstrapUnavailable`. `main.dart` bỏ qua Sodium/blocklist khi `StorageUnavailable`.
- **`create` thêm hai chốt an toàn:** có `header` sẵn → `CreateFailure`, không xóa gì (bảo vệ tài khoản đã commit); gọi `create` khi lần trước chưa xong → `CreateFailure` (ngoài chốt `_busy` ở UI). Ghi `header` lỗi sau rename (fsync thư mục) → xóa `header` để khớp `CreateFailure`.
- **`pw.mismatch`** hiện khi ô nhập lại dài **≥** ô đầu và khác (đọc "đã dài bằng" của UX-DR21 là đã đạt độ dài), chỉ khi ô đầu đạt luật; lỗi luật nằm dưới ô đầu, `pw.mismatch` dưới ô nhập lại, `create.failed` dưới nút — tối đa một thông báo luật/khớp mỗi lúc.
- **Lỗi tìm thấy khi test:** hàng của `Column` ở S2 không có key thì dòng thông báo chen vào làm dựng lại `SecretField`, và `dispose()` của bản cũ `clear()` controller đang dùng (mất nội dung ô). Sửa bằng key cố định cho từng hàng; test `ux_dr21_messages_appearing_do_not_rebuild_or_clear_fields` (đột biến bỏ key → đỏ).
- **Back hệ thống:** `CupertinoApp` không còn navigator riêng, nên `SessionGate` (WidgetsBindingObserver) chuyển `didPopRoute` cho navigator của cây đang hiện; ở gốc trả `false` cho OS.
- **Autofill:** `CupertinoTextField` là autofill client; `autofillHints: null` làm `AutofillConfiguration` bị tắt trong cấu hình gửi xuống OS (test kiểm cấu hình đó, không kiểm `EditableText.autofillHints`).
- **Verification (máy dev Windows):** `flutter pub get --enforce-lockfile` OK; `flutter gen-l10n` không đổi file đã commit; `flutter analyze --fatal-infos --fatal-warnings` 0 issue; `dart tool/check_imports.dart` OK. `NIX_SKIP_SODIUM_BUILD_HOOKS=1 flutter test`: mọi test pass trừ các test cần libsodium thật (`setUpAll` của kdf/header/vault_file/random_source/account_service — đã đỏ từ trước trên máy này). Chạy thêm cục bộ với `libsodium.dll` 1.0.22 chính thức nạp trước bằng `DynamicLibrary.open` (file test tạm, đã xóa): `account_service_test` 13/13, `app_test` (main thật, S1 bật nút), header/vault_file/kdf/random_source đều pass. Toàn bộ suite với build hook thật chờ CI.

- **Kiểm ở bước 3 (2026-11-10, chạy lại độc lập):** `flutter analyze --fatal-infos --fatal-warnings` 0 issue; `check_imports` OK. `NIX_SKIP_SODIUM_BUILD_HOOKS=1 flutter test`: 297 pass, 1 skip, 7 lỗi đều ở `setUpAll` cần libsodium (kdf, random_source, header_codec, vault_file_codec, kdf_calibration `ad05_default_deriver_runs_real_kdf`, account_service). Chạy `account_service_test` + `app_test` qua file bọc tạm nạp `libsodium.dll` 1.0.22: 19/19 pass (file tạm đã xóa). Matrix: mọi dòng có test đã chạy; dòng "blocklist hỏng" chỉ được phủ ở tầng gate (`BootstrapUnavailable`), nhánh `parse` → `null` trong `_wireAccount` chưa có test riêng (đã thêm sau review, xem dưới).
- **Sửa sau review (2026-11-10, triage #3, #9, #13, #14, #21–23):** `SecretField` bọc `Actions({CopySelectionTextIntent: DoNothingAction()})` chặn Ctrl/Cmd+C/X khi đang hiện (test `ad14_copy_and_cut_shortcuts_do_nothing_when_revealed`); `create` fsync `vault/` best-effort sau khi xóa `header`; `account_service_test` theo dõi KEK bị hủy ở mọi nhánh; `app_test` thêm hai test blocklist hỏng (byte rác / không nạp được) → fail closed; test sửa ô đầu sau lỗi thì `create.failed` ẩn; `PakTabIcon` dự phòng bằng `PakColors.inkTabInactive`; xóa comment trùng. Mỗi test mới đỏ khi bỏ bản sửa tương ứng. Kiểm lại: analyze 0 issue, `check_imports` OK; `flutter test` không hook `sodium`: 301 pass, 1 skip, 7 lỗi `setUpAll` cần libsodium (như trước); bọc tạm nạp `libsodium.dll` cho account_service, app, kdf, header_codec, vault_file_codec: 67/67 pass (file tạm đã xóa). Toàn bộ suite với build hook thật chờ CI.

## Spec Change Log

## Review Triage Log

Review 2026-11-10 (diff `7659be6..` cây làm việc, bỏ code l10n sinh ra; 3 lớp: blind (B), edge (E), verif-gap (V)).

| # | Nguồn | Phát hiện | Verdict | Bằng chứng | Route |
|---|-------|-----------|---------|------------|-------|
| 1 | E | Ghi `header` lỗi sau rename và `_deleteQuietly` cũng lỗi → `header` còn, `create` bị từ chối mãi, lần mở sau ra S3 | low | Cần fsync thư mục lỗi **và** xóa file lỗi cùng lúc; khi đó tài khoản vẫn mở được bằng mật khẩu vừa gõ. Sửa phải thêm kết quả/nhánh mới | reject |
| 2 | B | `header` đã có → S2 báo lỗi mãi, không tới S3; `header` là thư mục/symlink hỏng → S3 | low | Chỉ tới được qua đường #1 (bootstrap đã báo `NoAccount`); `header` là thư mục là trạng thái không do app tạo ra. Sửa cần kết quả mới | reject |
| 3 | E, B | Xóa `header` sau fsync lỗi không fsync `vault/` → mất điện có thể khôi phục `header` dù UI báo lỗi | low | Có thật (unlink chưa bền); sửa là một lần `fsyncDirectory(vaultDir)` best-effort | patch |
| 4 | E | Claim "lỗi bất kỳ bước nào không để lại `header`" chỉ best-effort | low | Cùng gốc #1; sửa là sửa spec | reject |
| 5 | E | S2 bị gỡ khi `create` đang chạy → phiên bị hủy dù tài khoản đã commit | false | `PopScope(canPop: !_busy)` chặn chevron, Back hệ thống (`maybePop`) và vuốt back của `CupertinoPageRoute` (`popDisposition == doNotPop`); 1.6 không có đường nào khác gỡ S2 | reject |
| 6 | E, B | Phiên bị `dispose` ngoài gate → nhánh khóa dùng lại epoch và `GlobalKey` navigator; gate không được báo khi phiên hủy | low | Ở 1.6 chỉ gate gọi `dispose` (cùng lúc gỡ cây), nên không xảy ra. Bẫy cho 1.8: khóa phải tăng epoch và đổi `GlobalKey` (đúng AD-9). Sửa thêm cơ chế báo | reject |
| 7 | E | Cây chưa đăng nhập hiện lại sau khi tạo đọc `bootstrapResultProvider` cũ → S1 | false | 1.6 không có đường quay lại cây chưa đăng nhập (khóa là 1.8). Ghi chú cho 1.8: sau khóa gate phải hiện S3, không đọc lại kết quả bootstrap lúc khởi động | reject |
| 8 | E | Dán chuỗi rất dài → `zxcvbnm` chạy không giới hạn trên UI thread | false | `zxcvbnm` cắt ở `options.maxLength` = 256 (`zxcvbnm.dart:48`); `PasswordPolicy.check` trả `tooLong` sau một vòng quét | reject |
| 9 | E | Ô đang hiện, phím cứng Ctrl+C/Ctrl+X vẫn copy/cut mật khẩu | medium | `EditableText.copyEnabled`/`cutEnabled` chỉ chặn khi `obscureText` (`editable_text.dart:2649-2662`); khi bấm mắt, shortcut copy/cut chạy qua `CopySelectionTextIntent`, trái AD-14 | patch |
| 10 | E, B | `SecretField` không `clear()` controller cũ khi cha đổi controller | low | Không nơi nào đổi controller; sửa thêm `didUpdateWidget` | reject |
| 11 | E, B | Nút mắt không có nhãn trợ năng | low | Có thật, nhưng EXPERIENCE.md:327-328 và UX-DR51 không đặt mức trợ năng riêng; sửa cần thêm microcopy mới | reject |
| 12 | E | Sau `CreateFailure` ô mất focus, Return không gửi lại ngay | low | Hiếm (chỉ sau lỗi hệ thống); người dùng bấm nút như `create.failed` gợi ý | reject |
| 13 | B, V | Không test KEK (và DEK) bị hủy ở mọi nhánh của `create` | medium | V đã kiểm: bỏ `_disposeQuietly(kek)` thì 13 test vẫn xanh | patch |
| 14 | B, V | Các nhánh fail closed của `_wireAccount` (blocklist lỗi/`parse` → `null`) không có test | medium | V đã kiểm: thay `blocklist == null` bằng filter rỗng hoặc bỏ `try/catch` thì CI vẫn xanh | patch |
| 15 | B | Inline-message không phải live region cho trình đọc màn hình | low | Như #11 (không có mức trợ năng riêng); thêm live region là quyết định UX (dòng độ mạnh đổi liên tục) | reject |
| 16 | B | Dòng độ mạnh cũ còn hiện 150 ms sau phím cuối; debounce không đưa ước lượng khỏi UI thread | low | Hệ quả có chủ đích của debounce trong spec; jank còn lại đã ghi trong deferred 1.5 (đo release) | reject |
| 17 | B | Spec `in-review` lệch sprint `in-progress` | false | Đúng thiết kế: bước trình bày đồng bộ sprint-status (như 1.4, 1.5) | reject |
| 18 | B | Ô đang hiện dùng `TextInputType.text` thay vì `visiblePassword`; bàn phím Android có thể gợi ý/học | maybe-false | `enableSuggestions`/`enableIMEPersonalizedLearning` = false đã gửi xuống; cần thử Gboard/Samsung Keyboard trên máy thật khi ô đang hiện. Nếu đúng: medium | defer |
| 19 | B | `ref.read` trong `build`, `policy.check` gọi hai lần mỗi build | low | Provider là giá trị override tĩnh, không đổi; tra Bloom rẻ | reject |
| 20 | B | Không có widget test tiếng Anh cho S1/S2 | low | `arb_test` kiểm tập key; placeholder được kiểm khi biên dịch code sinh ra | reject |
| 21 | B | `PakTabIcon` dự phòng màu cứng `0xFF000000` | low | Sửa trực tiếp: dự phòng bằng token `PakColors.inkTabInactive` | patch |
| 22 | B | Comment trùng trong `session_gate_test` | low | Xóa một dòng | patch |
| 23 | V | Không test sửa ô đầu sau lỗi thì `create.failed` ẩn | medium | V đã kiểm: bỏ `_failed = false` trong `_onMainChanged` thì test vẫn xanh | patch |

## Design Notes

- **Không có màn chờ:** `bootstrap()` chỉ kiểm tồn tại `header` (I/O nhỏ) nên chạy trước `runApp`; frame đầu đã là S1/S3 (UX-DR30).
- **Dọn `vault/` ở `create`, không ở `bootstrap`:** thiếu `header` nghĩa là chưa có tài khoản đã commit (AD-7), nhưng xóa lúc khởi động là xóa không cần người dùng thao tác; dọn ngay trước khi tạo cho cùng kết quả và an toàn hơn với Epic 2 ("dữ liệu hỏng không dẫn tới xóa").
- **Độ mạnh debounce, policy tức thì:** Bloom tra rất nhanh nên nút và thông báo cập nhật mỗi phím; chỉ `zxcvbnm` (tới ~99 ms với 128 ký tự) bị debounce.
- **Gate tự quản `Navigator`:** `CupertinoApp.builder` nằm trên navigator của app; gate thay cả cây bằng `Navigator` của riêng nó để khóa = thay cây (AD-23), cây sau đăng nhập có navigator gốc cho `ModalPresenter` về sau.

## Verification

**Commands (trong `pak_manager/`):**
- `flutter pub get --enforce-lockfile` -- resolve được.
- `flutter gen-l10n` -- không tạo diff ngoài file đã commit.
- `flutter analyze --fatal-infos --fatal-warnings` -- 0 issue.
- `dart tool/check_imports.dart` -- exit 0.
- `flutter test` -- mọi test pass (trên máy dev Windows thiếu VS Build Tools cho hook `sodium`: chạy test không phụ thuộc `sodium` trong bản sao tối giản như story 1.5, phần còn lại chờ CI).
