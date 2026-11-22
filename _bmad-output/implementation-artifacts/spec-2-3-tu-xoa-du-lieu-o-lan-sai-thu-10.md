---
title: 'Story 2.3: Tự xóa dữ liệu ở lần sai thứ 10'
type: 'feature'
created: '2026-11-22'
status: 'done'
route: 'dispatch'
review_loop_iteration: 0
baseline_commit: '6c720d4c817bd16b87b6893237812ba5e9a506c6'
context:
  - '{project-root}/_bmad-output/implementation-artifacts/epic-2-context.md'
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** Sau story 2.2, lần sai thứ 10 chỉ chặn đăng nhập (`UnlockLockedOut`), chưa xóa gì; xóa dở dang (tắt app, hết pin) chưa được xóa nốt; `guard` và file còn sót làm tài khoản mới kế thừa trạng thái cũ (DW-2.1-2, DW-2.2-1) (FR-4 lần 10, FR-12, UJ-4).

**Approach:** Dựng `services/wipe_coordinator.dart` (AD-21) làm chủ duy nhất của quy trình xóa, `AccountService` sở hữu và lộ `wipe()`. Lần sai thứ 10 trả `UnlockWipeRequired`; `SessionGate` chuyển sang S5 (`WipingScreen`) rồi S1. `bootstrap()` phát hiện xóa dở thì trả `BootstrapWiping` để hiện S5 xóa nốt.

## Boundaries & Constraints

**Always:**
- Thứ tự `WipeCoordinator.run()`, mỗi bước idempotent, bước nào lỗi thì dừng và trả `WipeFailed` (không ném): `LockoutGuard.markWiping()` → hook vô hiệu `VaultSession` (rỗng; mọi lối vào hiện tại đều chưa có phiên) → xóa `vault/header` rồi fsync `vault/`, rồi mọi entry còn lại của `vault/` (không theo symlink), rồi thư mục `vault/`, rồi fsync `pak/` → xóa `pak/tmp/` → `SettingsStore.clearLastExport()` (ghi xong xuống file, ghi lỗi = lỗi bước) → hook xóa clipboard (rỗng, Epic 3 nối) → `LockoutGuard.reset()` (ghi `failCount` 0, không mốc, `wiping` false; xóa digest chuỗi sai trong RAM; RAM luôn về `initial`).
- `LockoutGuard.markWiping()` ghi `wiping = true`, giữ `failCount`; ghi lỗi → `false`, chưa xóa gì. `LockoutGuard.load()` chỉ đọc `guard` vào RAM, không ghi, không đọc đồng hồ. Cả hai đi qua hàng đợi `_serial`.
- `unlock`: sau `kcv` lệch, nếu `failCount` (RAM) = 10 thì trả `UnlockWipeRequired` (mật khẩu đúng ở lần thứ 10 vẫn đăng nhập bình thường). Chỉ trả khi đã ghi `failCount` 10 trước KDF; chưa chạy xóa trong `unlock`. `UnlockCorrupt` ở lần 10 giữ nguyên (`failCount` 10 còn trên đĩa, lần mở sau xóa; story 2.5 tách ranh giới).
- `recordSuccess()` trả `bool` (ghi xuống đĩa thành công). Ghi lỗi mà `failCount` trước đó là 10 thì `unlock` trả `UnlockUnavailable` và hủy phiên vừa mở (đóng DW-2.1-3: không xóa dữ liệu của người vừa nhập đúng); RAM vẫn về 0 như cũ. Các giá trị khác giữ hành vi hiện tại.
- `AccountService.bootstrap()` theo thứ tự: kiểm `header` → `WipeCoordinator.resumeIfNeeded(hasAccount)` (gọi `guard.load()` trước) → `guard.normalize()`. Có `wiping = true` hoặc `failCount ≥ 10` → trả `BootstrapWiping` (chưa xóa, để S5 chạy `wipe()`; không gọi `normalize`). Không có `header` mà `vault/` còn entry hoặc `guard` khác trạng thái `initial` → chạy `run()` ngay, im lặng, rồi trả `BootstrapNoAccount` (đóng DW-2.1-2, DW-2.2-1); `run()` lỗi → `BootstrapUnavailable`. Không có `header`, `vault/` sạch, `guard` `initial` thì không làm gì.
- `AccountService.wipe()` → `Future<WipeResult>` là lối duy nhất UI gọi xóa (2.4 dùng lại). Features không import `WipeCoordinator`.
- `SessionGate`: `UnlockWipeRequired` (LoginScreen gọi `onWipe`) hoặc `BootstrapWiping` → dựng S5; `WipeDone` → `BootstrapNoAccount` (S1, navigator key mới); `WipeFailed` → `BootstrapUnavailable` (S1 vô hiệu + `create.unavailable`, fail closed; lần mở sau xóa nốt vì `wiping` còn trên đĩa). Không dialog giữa S3 và S5. S3 bị gỡ cùng ô mật khẩu (`SecretField` tự `clear()`).
- S5 `WipingScreen` (UX-DR32): `CupertinoPageScaffold` nền `surface-base`, `CupertinoActivityIndicator` và `wiping` căn giữa, khe 14, không nút, `PopScope(canPop: false)` chặn Back. Tự gọi `wipe()` đúng một lần ở `initState` (không chạy lại khi rebuild), `dispose` an toàn khi gate đã gỡ. ARB `wiping`: VI "Đang xóa dữ liệu…", EN "Erasing data…".
- `SettingsStore.clearLastExport()` → `Future<bool>`: `update(clearLastExportAt: true)` rồi `flush()`; `true` khi không còn `dirty`. `main.dart` truyền `settings` vào `_wireAccount` để dựng coordinator.

**Never:**
- Không đổi schema/codec `guard` hay fixture golden (`wiping` đã có). Không thêm provider. Không truyền service qua constructor widget (callback `onWipe` của màn là ngoại lệ như `onUnlocked`).
- Chưa nút "Xóa & Tạo tài khoản mới", hộp thoại, hold-confirm (2.4); chưa tách `corrupt`/KDF lỗi (2.5); chưa nối clipboard (Epic 3).
- Không xóa gì ở nhánh `UnlockCorrupt`/`UnlockUnavailable`/`UnlockWrongPassword` khi `failCount` < 10. `DateTime.now()`/`Stopwatch` không có trong `core/guard`, `lockout_guard.dart`, `wipe_coordinator.dart`.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Sai lần thứ 10 | failCount 9, hết giờ chờ, sai | đĩa `failCount: 10` trước KDF; `UnlockWipeRequired` → S5 → xóa → S1 | `markWiping`/bước lỗi → `WipeFailed` → S1 vô hiệu |
| Đúng ở lần thứ 10 | failCount 9, đúng | `failCount` 0, đăng nhập thường | `recordSuccess` ghi lỗi → `UnlockUnavailable`, phiên hủy |
| Tắt app giữa xóa | `wiping: true`, còn một phần file | mở lại: `BootstrapWiping` → S5 → `run()` xóa nốt → S1 | idempotent mọi bước |
| Tắt app lúc kiểm lần 10 | `failCount: 10`, còn đủ file | mở lại như dòng trên | N/A |
| Mất `header`, còn file | không `header`, `vault/` còn `cards`/`recent`/`draft` | `bootstrap` dọn sạch, trả `BootstrapNoAccount` | lỗi → `BootstrapUnavailable` |
| Guard sót, mất `header` | không `header`, `failCount` 6 | `run()` đặt `guard` về `initial`; tài khoản mới không bị chờ | như trên |
| Cài mới | không `header`, không `vault/`, `guard` thiếu | không xóa, `BootstrapNoAccount` | N/A |
| Sau xóa, tạo mới | `create()` | không card, Recent, draft, bộ đếm, `lastExportAt` cũ | N/A |
| Crash sau từng bước | dừng sau bước k, dựng lại coordinator trên cùng thư mục | `resumeIfNeeded` + `run()` về trạng thái chưa có tài khoản, không sót file cạnh tài khoản mới | N/A |
| Back ở S5 | Android Back | không đóng, không pop | N/A |

</frozen-after-approval>

## Code Map

- `pak_manager/lib/services/wipe_coordinator.dart` -- **mới**. `WipeCoordinator(paths, guard, settings, fileSync, {invalidateSession, clearClipboard, onStep})`; `run()`, `resumeIfNeeded({hasAccount})`; sealed `WipeResult` (`WipeDone`/`WipeFailed`); enum `WipeStep` + `onStep` (test crash). Xóa entry bằng `FileSystemEntity.type(followLinks: false)`.
- `pak_manager/lib/services/lockout_guard.dart` -- thêm `load()`, `markWiping()`, `reset()` (qua `_serial`); `recordSuccess()` trả `bool`; sửa doc `normalize` ("Story 2.3 thêm…", :74). Giữ `_write`/`_readCapped`.
- `pak_manager/lib/core/guard/guard_state.dart` -- thêm `withWiping()`, `isInitial`; sửa comment "story 2.3" ở :16.
- `pak_manager/lib/services/account_service.dart` -- ctor nhận `required WipeCoordinator _wipe`; `bootstrap` :189 (comment :190 là chỗ chèn); `_unlock` :333 (kcv lệch :366, `recordSuccess` :372); thêm `UnlockWipeRequired` cạnh :113, `BootstrapWiping` cạnh :44, `wipe()`.
- `pak_manager/lib/services/settings_store.dart` -- thêm `clearLastExport()`. `core/model/settings.dart` đã có `clearLastExportAt`.
- `pak_manager/lib/main.dart` -- `_wireAccount` :142 nhận `settings`, dựng `WipeCoordinator`, truyền vào `AccountService` :183.
- `pak_manager/lib/features/auth/wiping_screen.dart` -- **mới**, S5. `login_screen.dart` -- thêm `onWipe` (`VoidCallback?`), `switch` :171 thêm `UnlockWipeRequired`. `shared/session_gate.dart` -- `_loginFor` :177 thêm `BootstrapWiping`; `_startWipe`.
- `pak_manager/lib/l10n/app_{vi,en}.arb` -- thêm `wiping`; chạy `flutter gen-l10n`.
- `pak_manager/test/support/{port_fakes,account_fakes}.dart` -- `FakeAccountService.wipe()` (treo tới `completeWipe`), kết quả mặc định; fake file sync nếu chưa có. Mọi chỗ dựng `AccountService` trong test thêm coordinator: `test/services/account_service_test.dart`, `test/features/shared/session_gate_test.dart`.

## Tasks & Acceptance

**Execution:**
- [x] `core/guard/guard_state.dart` + `services/lockout_guard.dart` -- `withWiping`, `isInitial`, `load`, `markWiping`, `reset`, `recordSuccess` → `bool` -- guard là chủ duy nhất của file.
- [x] `services/settings_store.dart` -- `clearLastExport()`.
- [x] `services/wipe_coordinator.dart` -- quy trình xóa và `resumeIfNeeded` -- AD-21.
- [x] `services/account_service.dart` + `main.dart` -- `UnlockWipeRequired`, `BootstrapWiping`, `wipe()`, `bootstrap` mới, nối coordinator, `recordSuccess` lỗi ở lần 10.
- [x] `features/auth/wiping_screen.dart`, `login_screen.dart`, `shared/session_gate.dart`, 2 ARB -- S5 và chuyển cảnh S3 → S5 → S1; `gen-l10n`.
- [x] `test/support/*` -- fake như Code Map.
- [x] `test/services/wipe_coordinator_test.dart` -- thứ tự bước, header xóa trước, idempotent, crash sau từng `WipeStep` rồi chạy lại, symlink không bị theo, `settings` ghi lỗi → `WipeFailed`, sau xóa `create()` sạch, `guard` reset (kể cả digest).
- [x] `test/services/lockout_guard_test.dart`, `test/core/guard/guard_state_test.dart`, `test/services/account_service_test.dart`, `test/services/settings_store_test.dart` -- các dòng Matrix ở mức guard, service, store (lần 10 đúng/sai, bootstrap 4 nhánh, không `derive` khi xóa).
- [x] `test/features/auth/login_screen_test.dart`, `test/features/shared/session_gate_test.dart`, `test/features/auth/wiping_screen_test.dart` -- `UnlockWipeRequired` → S5 không dialog, Back bị chặn, `wipe()` gọi một lần, xong → S1, lỗi → S1 vô hiệu, `BootstrapWiping` → S5.

**Acceptance Criteria:**
- Given `lib/`, when grep `DateTime.now\|Stopwatch` trong `core/guard`, `lockout_guard.dart`, `wipe_coordinator.dart`, then không có kết quả; features không import `wipe_coordinator`/`core/guard`; `check_imports` OK.
- Given test mới, when đọc tên, then mỗi tên bắt đầu bằng id thật đệm 2 chữ số (`fr04_`, `fr12_`, `ad08_`, `ad21_`, `ad26_`, `ux_dr32_`, `uj04_` nếu có id).
- Given S3 ở lần sai thứ 10 (VI), when kiểm xong, then thấy "Đang xóa dữ liệu…" một mình giữa màn, không nút, rồi S1; mở lại app thấy S1, tạo tài khoản mới không còn dữ liệu cũ.

## Implementation Notes

- `AccountService` re-export `WipeResult`/`WipeDone`/`WipeFailed` để UI dùng kết quả của `wipe()` mà không import `wipe_coordinator`; import `core/crypto/wipe.dart` đặt tiền tố `zero` vì method `wipe()` che hàm cùng tên.
- `WipeCoordinator.run()` dùng chung một future khi gọi chồng. Nó giả định `guard` đã nạp vào RAM (`bootstrap` gọi `load()` trước; `unlock` có sẵn trạng thái); người gọi mới phải giữ điều này, nếu không `markWiping` ghi `failCount: 0, wiping: true`.
- `WipingScreen` không có `AccountService` thì chờ một microtask rồi báo `WipeFailed` (fail closed), tránh gọi `onFinished` giữa lúc dựng cây.
- Ba test cũ đổi theo hành vi mới: `fr01_ad07_no_header_means_no_account` (bootstrap nay dọn file sót), `fr04_ad08_tenth_wrong_exhausts_attempts` (ra `UnlockWipeRequired`), nhánh `missing` của `fr07_ad05_ad08_corrupt_header_skips_guard_and_kdf_*` (guard sót được đặt lại nên `attemptsLeft` 10).
- Hai test symlink của `wipe_coordinator_test.dart` tự bỏ qua khi máy không tạo được symlink (Windows, lỗi 1314); CI ubuntu chạy.
- Chưa đóng DW-2.1-2, DW-2.1-3, DW-2.2-1 trong `deferred-work.md`: cần id CI run hoặc SHA sau khi có PR.
- Kiểm chứng trước review: `flutter analyze --fatal-infos --fatal-warnings` sạch, `check_imports` OK, `flutter test` 1043 pass, 20 skip (18 cũ + 2 symlink), 2 fail đều là teardown errno 145 (`DW-2.1-1`).
- Sau review (2 patch: test nối `main.dart`, gom fake dùng chung): `flutter analyze --fatal-infos --fatal-warnings` sạch, `check_imports` OK, `gen-l10n` lần hai không đổi, `flutter test` 1045 pass, 20 skip, 1 fail là teardown errno 145 (`DW-2.1-1`).

## Spec Change Log

## Review Triage Log

Review vòng 1 (2026-11-22): blind-hunter, edge-case-hunter, verification-gap; không lớp nào lỗi. Trước review: `flutter test` 1043 pass, 20 skip, 2 fail (teardown errno 145, `DW-2.1-1`).

| # | Nguồn | Phát hiện | Verdict | Bằng chứng | Route |
|---|---|---|---|---|---|
| 1 | verification-gap | Không test nào kiểm `main.dart` nối `WipeCoordinator` với đúng `guard`/`settings` dùng chung; nối nhầm instance thì mọi test vẫn qua | medium | Lớp verification-gap đã kiểm sẵn: mọi `WipeCoordinator(` trong test tự dựng và chia sẻ instance; `main_test` không tới `BootstrapWiping` | patch |
| 2 | blind | `_CountingRandom`, `_kdfClock`, `_SimulatedCrash` chép lại trong `wipe_coordinator_test.dart`, trái quy ước fake dùng chung ở `test/support/` | low | Đúng: `_CountingRandom` có sẵn ở `account_service_test.dart:34`, `_kdfClock` mới chép; AGENTS cấm chép fake inline | patch |
| 3 | blind | `bootstrap` dựa vào một lần `FileSystemEntity.type(header)` (lỗi → `notFound`) rồi dọn im lặng `vault/` | maybe-false | Cần xác minh `stat` trên `header` có thể trả `notFound` khi file còn (EIO/EACCES/file protection iOS); nếu có thì medium (mất vault không hỏi) | defer |
| 4 | blind, edge-case | `recordSuccess` ghi lỗi ở lần 10: RAM về 0 nhưng đĩa còn 10; tắt app thì lần mở sau xóa, thử lại cùng phiên thì ghi đè về 1 | medium | Đúng như spec chốt (Design Notes); chỉ giảm nhẹ DW-2.1-3, không đóng hẳn; sửa triệt để cần quyết định UX | defer |
| 5 | edge-case | `service.wipe()` ném thì kẹt ở S5 | false | `AccountService.wipe` → `WipeCoordinator.run` bắt mọi `Object` và trả `WipeFailed`, không ném | reject |
| 6 | edge-case, blind, verification-gap | `LoginScreen.onWipe == null` không làm gì, không thông báo | false | `SessionGate` luôn truyền `onWipe`; cùng kiểu `onUnlocked == null` có sẵn; không với tới | reject |
| 7 | edge-case | `guard` đọc lỗi thoảng qua (đang `wiping`/≥10) thì `load` coi là `initial`, `normalize` ghi lại 0 | false | Đúng luật AD-8 "có `header` mà `guard` không đọc được → tạo lại `failCount = 0`", rủi ro đã chấp nhận | reject |
| 8 | edge-case | `clearLastExport` no-op khi file `settings` hỏng (RAM là mặc định) | false | File hỏng thì lần nạp sau cũng ra mặc định, không đọc được `lastExportAt` cũ | reject |
| 9 | edge-case, blind | `clearLastExport` trả `false` khi có ghi `settings` khác chen giữa lúc flush | low | Lúc xóa đang ở S3/S5, không có đường nào đổi cài đặt; sửa cần vòng lặp/nhánh | reject |
| 10 | edge-case | Không fsync `pak/` sau khi xóa `pak/tmp/` | false | `clearLastExport` và `guard.reset()` ghi qua `AtomicFileWriter` trong cùng `pak/` và fsync `pak/`, làm bền cả việc xóa `tmp` | reject |
| 11 | edge-case | Không có tài khoản, `guard` initial, `pak/tmp` hay `lastExportAt` sót thì `resumeIfNeeded` bỏ qua | false | Xóa dở luôn để `wiping = true` tới bước cuối, nên rơi vào `pending`; sót ngoài quy trình xóa không với tới | reject |
| 12 | edge-case, blind | `WipeFailed` → S1 vô hiệu, không retry, thông báo chung | low | Đúng như spec đã duyệt (chốt ở checkpoint); sửa là sửa intent/spec | reject |
| 13 | blind | Không báo "đã xóa", S5 có thể chớp, `WipingScreen` thiếu `Semantics` | false | UX-DR32/EXPERIENCE chốt S5 chỉ một dòng, spine không yêu cầu bổ sung ngữ nghĩa (như đã bác ở 2.2) | reject |
| 14 | blind | `header` chỉ `unlink`, không ghi đè | low | AD-21 chỉ yêu cầu xóa; flash có wear-leveling nên ghi đè không bảo đảm, lớp bảo vệ thật là KDF (AD-8); thêm bước là thêm nhánh | reject |
| 15 | blind | Hook `invalidateSession`/`clearClipboard` chưa nối, không có DW | false | Spec chốt hook rỗng, Epic 3 nối clipboard (epic-2-context); chưa lối vào nào có phiên | reject |
| 16 | blind | `wipe()` không tuần tự với `unlock`/`create` | low | UI chỉ gọi `wipe()` sau khi `unlock` trả; không đường nào chạy chồng | reject |
| 17 | blind | Test crash chỉ ném giữa các bước | low | Mỗi bước đã có test idempotent riêng; ném trong bước là thêm hạ tầng | reject |
| 18 | blind | Doc `wipe()` "lối duy nhất để UI gọi" trong khi `resumeIfNeeded` gọi `run()` | false | Câu doc nói về UI; `resumeIfNeeded` là service, không mâu thuẫn | reject |
| 19 | blind | Alias `zero` và `_forgetLastWrong()` gọi hai lần trong `reset()` | low | Alias do `wipe()` che hàm cùng tên; lời gọi ngoài/trong `_serial` chủ ý (bỏ digest ngay) | reject |

## Design Notes

`bootstrap` không xóa tại chỗ khi xóa dở vì S5 phải hiện trong lúc xóa (UX-DR32) mà bootstrap chạy trước `runApp` không có màn chờ (UX-DR30); nó chỉ báo `BootstrapWiping`. Ngược lại file sót khi mất `header` thì dọn im lặng: việc nhỏ, không đáng một màn. `recordSuccess` lỗi chỉ đổi kết quả ở `failCount` 10 vì chỉ giá trị đó mới dẫn tới xóa ở lần mở sau; các giá trị thấp hơn vẫn đăng nhập tiếp như story 2.1 đã chọn.

## Verification

**Commands:**
- `cd pak_manager && flutter gen-l10n` -- expected: chạy lần hai không đổi file trong `lib/l10n/`
- `cd pak_manager && flutter analyze --fatal-infos --fatal-warnings` -- expected: sạch
- `cd pak_manager && dart run tool/check_imports.dart` -- expected: không vi phạm
- `cd pak_manager && flutter test` -- expected: tất cả pass (trừ lỗi teardown `DW-2.1-1` đã biết), số test tăng, không thêm skip

### Review Findings

Review vòng 2 (2026-11-22, `/bmad-code-review`): blind-hunter, edge-case-hunter, verification-gap, acceptance-auditor; không lớp nào lỗi. Verification-gap không nêu lỗ hổng kiểm chứng, chỉ có mục `Other findings`.

- [x] [Review][Patch] Doc `resumeIfNeeded` nói "Đọc đĩa lỗi thì coi như còn sót (dọn lại là an toàn)" nhưng mã không dọn: `on Object` trả `WipeResume.failed`, `bootstrap` ra `BootstrapUnavailable` (fail closed). Sửa doc cho đúng mã [pak_manager/lib/services/wipe_coordinator.dart:134]
- [x] [Review][Defer] `bootstrap` suy ra "không có tài khoản" từ một lần `FileSystemEntity.type(header)` rồi dọn im lặng `vault/` — deferred: chưa xác minh (maybe-false, nếu đúng là medium); đã ghi ở DW-2.3-1 từ vòng 1, cần kiểm `stat` có trả `notFound` khi file còn sống không [pak_manager/lib/services/account_service.dart:224-231]
- [x] [Review][Defer] Mật khẩu đúng ở lần thứ 10 mà `recordSuccess` ghi lỗi: đĩa còn `failCount` 10, lần mở sau xóa vault của người vừa nhập đúng — deferred: medium, hiếm; đã ghi ở DW-2.3-2 từ vòng 1, cần quyết định UX [pak_manager/lib/services/account_service.dart:424-429]
- [x] [Review][Defer] Lần thứ 10 mà KDF lỗi (`_deriveKek` trả `null`) → `UnlockCorrupt`; `failCount` 10 đã nằm trên đĩa nên lần mở sau xóa vault dù mật khẩu chưa được kiểm; trong phiên đó S3 chỉ còn `UnlockLockedOut`. Hành vi do spec chốt và `fr07_fr04_tenth_attempt_with_kdf_failure_stays_corrupt` ghim — deferred: medium, thuộc story 2.5 (kết quả "thử lại" cho KDF lỗi); ghi ở DW-2.3-3 [pak_manager/lib/services/account_service.dart:411-414]

#### Rejected

- `run()` giả định `guard` đã nạp (blind): low. `AccountService.wipe()` chỉ chạy sau `bootstrap`/`unlock`; thêm cờ "đã nạp" là thêm trạng thái cho đường chưa với tới, điều kiện đã ghi ở Implementation Notes.
- DW-2.1-2, DW-2.1-3, DW-2.2-1 chưa được ghi chú (blind): sửa đổi trái chính sách AGENTS (chỉ đóng mục khi có CI run hoặc SHA); spec đã ghi lý do ở Implementation Notes.
- Spec `done` lệch `sprint-status` `review` (blind, acceptance-auditor): sửa là sửa spec; bước 6 của review đồng bộ lại hai chỗ.
- Mâu thuẫn chữ DW-2.1-3 giữa Boundaries và DW-2.3-2 (blind, acceptance-auditor): phần hành vi đã ở DW-2.3-2; phần còn lại là sửa spec đã đóng băng.
- Không có đường thử lại sau `WipeFailed` (blind): low. Trùng #12 vòng 1, đúng như spec đã duyệt.
- Hai test symlink có thể bỏ qua, "không thêm skip" không đạt (blind, acceptance-auditor): low. Chỉ bỏ qua khi máy không tạo được symlink; spec ghi rõ CI ubuntu chạy; sửa là sửa dòng Verification.
- `main_test` thoát sớm khi thiếu libsodium (blind): low. Cùng quy ước các case `main_test` khác.
- Khoảng trống test của `WipeCoordinator` (nhánh `default`, `resumeIfNeeded` ném, crash sau `resetGuard`) (blind): low. Các nhánh chính đã có test, thêm test cho đường hiếm không đáng.
- `*.tmp` cạnh `guard`/`settings` không bị xóa; `bootstrap` không dọn `*.tmp`, `pak/tmp/` (blind, acceptance-auditor): false. `storage_bootstrap` quét `*.tmp` (TmpSweeper) trước `runApp` ở mọi lần mở; chưa có đoạn mã nào ghi vào `pak/tmp/` ngoài `wipe`.
- Chi tiết test dễ gãy (so `double` chính xác, `port_fakes` import fixture, `kdfClock` có trạng thái) (blind): low. Test đang xanh, không có tình huống làm hỏng.
- `LoginScreen.onWipe == null` không làm gì (blind, acceptance-auditor): false. Trùng #6 vòng 1, `SessionGate` luôn truyền `onWipe`.
- S5 thiếu `Semantics`/thông báo hoàn tất (blind): false. Trùng #13 vòng 1, UX-DR32 chốt S5 một dòng.
- Thiếu assertion "`wipe()` không `derive`" (acceptance-auditor): low. `fr05_ad22_wrong_string_forgotten_after_wipe` kết thúc với `derives == 2` sau một lần `unlock` nữa, nên `wipe()` đã không derive.
- `LoginScreen` bỏ rơi `UnlockWipeRequired` khi `!mounted` (edge-case): low. Màn S3 chỉ bị gỡ khi gate đổi kết quả, không xảy ra giữa lúc `unlock` chạy; `failCount` 10 trên đĩa vẫn dẫn tới xóa ở lần mở sau.
- `guard` đọc lỗi thoảng qua thì `load` coi là `initial` và `normalize` hủy lần xóa (edge-case): false. Trùng #7 vòng 1, đúng luật AD-8 đã chấp nhận.
- Xóa dở, `guard` không đọc được, còn `pak/tmp` hay `lastExportAt` (edge-case): false. Trùng #11 vòng 1; cần hai lỗi đĩa chồng nhau, xóa dở luôn để `wiping = true`.
- `clearLastExport` không ghi khi file `settings` đọc lỗi lúc nạp, doc `WipeDone` nói quá (edge-case): low. Cần lỗi đọc thoảng qua đúng file 4 KiB; sửa cần đường ép ghi mới.
- `clearLastExport` bỏ qua giá trị trả của `update`, phụ thuộc ghi chen (edge-case): low. Trùng #9 vòng 1, lúc xóa không đường nào đổi cài đặt.
- `header` là thư mục hay liên kết bị coi là "không có tài khoản" (verification-gap): false. `hasAccount = type != notFound`, nên mọi loại entry đều tính là có tài khoản.
- `bootstrap` chặn khung hình đầu vì xóa đệ quy và fsync, doc `main.dart` cũ (edge-case): false. Spec chủ ý dọn im lặng "việc nhỏ" và doc `main.dart` đã cập nhật (`BootstrapWiping`).
