---
title: 'Retro Epic 1 action item 9: gom fake port/timer/SecureKey vào test/support, tách test composition root'
type: 'refactor'
created: '2026-11-19'
status: 'done'
route: 'dispatch'
review_loop_iteration: 0
baseline_commit: '75c9db2c3886ab95682f82d1442502a0b6477861'
context:
  - '{project-root}/_bmad-output/implementation-artifacts/epic-1-retro-2026-11-18.md'
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** Retro Epic 1 (C2, C3) ghi nhận fake bị chép nhiều nơi: FileSyncPort 5 bản, Timer 3, SecureKey 3, AppDirectoryPort 3, BackupPort 2. `test/support/account_fakes.dart` trộn fake port thuần Dart với helper dựng UI, nên test core/service không dùng lại được. `test/app_test.dart` (635 dòng) gom test `PakApp` và 8 test composition root (`main()`/`runPakApp`), mỗi story lại thêm fake inline ở cuối file. Epic 2 sắp thêm `LockoutGuard` và `WipeCoordinator`, cũng cần fake clock, timer và file.

**Approach:** Tạo `test/support/port_fakes.dart` thuần Dart, chứa fake dùng chung cho port, timer và `SecureKey`; thay các bản chép trùng có cùng hành vi bằng bản chung. Chuyển test composition root sang `test/main_test.dart`, chuyển test `PakApp` sang `pak_app_test.dart`, rồi xóa `app_test.dart`.

## Boundaries & Constraints

**Always:**
- Chỉ sửa trong `pak_manager/test/`. Không đổi `lib/`.
- Mọi test hiện có vẫn chạy, giữ nguyên tên (tag 2 chữ số) và giữ nguyên điều nó assert. Số test case khi chạy không giảm.
- `port_fakes.dart` không import `package:flutter*` hay widget. Fake dùng chung là public, có doc comment tiếng Việt.
- Fake chung đủ "núm chỉnh" cho mọi chỗ dùng: `RecordingFileSync` có `calls`, `failAt` (ném ở lần gọi thứ N), `failAlways` và hook `onCall(path)`; `FakeSecureKey` nhận `length` (mặc định 32).
- `flutter analyze --fatal-infos --fatal-warnings` sạch; `dart format` không đổi file nào.

**Never:**
- Không gom các fake khác hành vi chỉ để giảm số bản. Các fake sau giữ cục bộ: `_FakeDirectory`/`_FakeBackup` ghi log thứ tự trong `storage_bootstrap_test`; `_TrackedKey` bọc key libsodium thật; hai `_SimulatedCrash` (một bản là `Error`, một bản là `Exception`, có chủ ý); `_FakeWrite` của `settings_store_test`; harness `derive` của KDF.
- Không re-export `port_fakes.dart` từ `account_fakes.dart`. File test import trực tiếp thứ nó dùng.
- Không viết lại logic test, không tách test 170 dòng `ad18_nfr08_real_main_…`, không đổi CI.

</frozen-after-approval>

## Code Map

- `pak_manager/test/support/account_fakes.dart` -- hiện chứa `FakeSecureKey` (:26), `FakeClock` (:175), `FakeTimer`/`FakeTimers` (:208, :233) lẫn helper UI (`pumpGateApp`, `FakeAccountService`…). Chuyển 4 fake port sang `port_fakes.dart`; file này import lại để `fakeSession` dùng.
- `pak_manager/test/app_test.dart` -- test `ad01_pak_app_builds_cupertino_app` (:32) thuộc PakApp; 8 test composition root (:45–576); helper inline :581–635 gồm `_sodiumAvailable`, `_FakeSystemInfo`, `_FailingDirectory`, `_PendingDirectory`, `_RecordingFileSync`, `_RecordingBackup`, `_unavailableStorage`.
- `pak_manager/test/features/shared/pak_app_test.dart` -- `_NoopFileSync` (:19), `_IdleTimer` (:25), dùng ở :355–356 (`createTimer: (_, _) => _IdleTimer()`); nơi nhận test ad01.
- `pak_manager/test/services/settings_store_test.dart` -- `_FakeTimer`/`_Timers` (:12, :36) cùng hành vi với `FakeTimers`, chỉ khác tên (`call` ↔ `create`, `active` trả Iterable); `_NoopFileSync` (:81) thực ra ghi `calls` (assert ở :244, :469).
- `pak_manager/test/services/account_service_test.dart` -- `_RecordingFileSync({failAt})` (:27).
- `pak_manager/test/core/io/atomic_file_writer_test.dart` -- `_FakeFileSync({target, fail})` (:8) ghi `targetAtCall` (bytes file đích lúc gọi) → dùng `RecordingFileSync(onCall:)`.
- `pak_manager/test/core/crypto/kdf_calibration_test.dart` -- `_FakeKey(run)` (:13), độ dài `kekBytes`; `run` chỉ là chỉ số trong `_Harness.keys` (:73) và dùng cho `reason` (:91).
- Importer của `account_fakes.dart`: `app_test`, `create_account_screen_test`, `login_screen_test`, `settings_screen_test`, `session_gate_test`, `session_controller_test`, `vault_session_test`.
- Không đụng: `test/core/vault_fixture.dart`, `test/core/policy/policy_test_support.dart`, `test/tool/shell_harness.dart`. Không file CI/tool nào nhắc đường dẫn test.

## Tasks & Acceptance

**Execution:**
- [x] `pak_manager/test/support/port_fakes.dart` -- tạo mới: `FakeSecureKey({int length = 32})`, `FakeClock`, `FakeTimer`, `FakeTimers` (chuyển nguyên từ account_fakes), `RecordingFileSync`, `RecordingBackup`, `FakeSystemInfo`, `FailingDirectory`, `PendingDirectory` -- một chỗ cho fake port thuần Dart.
- [x] `pak_manager/test/support/account_fakes.dart` -- bỏ 4 fake đã chuyển, import `port_fakes.dart` -- tách UI khỏi port.
- [x] `pak_manager/test/main_test.dart` -- tạo mới với 8 test composition root, `_sodiumAvailable` và `_unavailableStorage`, dùng fake chung -- composition root có file riêng.
- [x] `pak_manager/test/features/shared/pak_app_test.dart` -- nhận test ad01; thay `_NoopFileSync` bằng `RecordingFileSync`, `_IdleTimer` bằng `FakeTimers().create` (không bắn) -- bỏ bản chép.
- [x] `pak_manager/test/app_test.dart` -- xóa sau khi đã chuyển hết.
- [x] `settings_store_test.dart`, `account_service_test.dart`, `atomic_file_writer_test.dart`, `kdf_calibration_test.dart` -- thay bản chép bằng fake chung (`run` → chỉ số trong `keys`) -- bỏ trùng lặp.
- [x] Các file đang import `account_fakes.dart` chỉ để lấy `FakeClock`/`FakeTimers`/`FakeSecureKey` -- chuyển sang import `port_fakes.dart`.

**Acceptance Criteria:**
- Given refactor xong, when chạy `flutter test`, then số test pass bằng baseline, số skip không tăng, và tên test giữ nguyên.
- Given `test/`, when grep `implements FileSyncPort|implements Timer|implements SecureKey|implements BackupPort|implements SystemInfoPort`, then ngoài `test/support/` chỉ còn các fake cục bộ đã liệt kê trong Never.
- Given `port_fakes.dart`, when xem import, then không có `package:flutter`.
- Given `test/app_test.dart`, then file không còn tồn tại.

## Spec Change Log

## Review Triage Log

| # | Nguồn | Phát hiện | Verdict | Bằng chứng | Route |
|---|---|---|---|---|---|
| 1 | edge-case, verification-gap, blind | `kdf_calibration_test`: nhãn `KEK lần ${i + 1}` lệch số lần `derive` khi có lần lỗi trước lần thành công; Code Map ghi sai "`run` chỉ là chỉ số trong `keys`" | low | `_Harness.derive` thêm vào `calls` trước khi `return null`/ném, chỉ lần thành công mới thêm vào `keys`; `_FakeKey.run` cũ = `calls.length`. Chỉ ảnh hưởng thông điệp khi test fail. Sửa trực tiếp, khôi phục nhãn cũ | patch |
| 2 | edge-case, blind | `RecordingFileSync(failAt: 0)`/âm không bao giờ ném; `failAt` + `failAlways`, `FakeSystemInfo(35, error:)` không được kiểm | low | Đúng, nhưng không caller nào truyền giá trị như vậy; sửa = thêm assert/nhánh | reject |
| 3 | blind | Test `ad01_pak_app_builds_cupertino_app` không qua `_pumpApp`, thiếu `dispose` store, lặp assert với `ad01_home_sits_in_content_column` | false | Code chuyển nguyên từ `app_test.dart`; `SettingsStore.inMemory` không có file và chỉ dựng timer khi ghi, test không ghi nên không rò; lặp assert là có sẵn từ trước | reject |
| 4 | blind | Mục 9 chưa đóng trong sprint-status, spec chưa được track | false | Không phải lỗi của diff: sprint-status và spec được cập nhật, commit ở bước trình bày/commit | reject |
| 5 | blind | AGENTS.md chưa có luật "fake port/timer/`SecureKey` vào `port_fakes.dart`, không chép inline" | medium | Thiếu luật thì Epic 2 dễ lặp lại C2/C3 của retro; sửa chạm file ngữ cảnh agent | defer |
| 6 | blind | Bất biến "`port_fakes.dart` không import Flutter" và "fake port chỉ trong `test/support/`" chỉ kiểm bằng grep tay | low | Đúng, không check tự động; `check_imports` chỉ quét `lib/`. Thêm test kiểm là việc mới, không do diff gây ra | defer |
| 7 | blind | `FakeSystemInfo` mặc định ném `StateError` thay vì `PlatformException` | false | Caller duy nhất truyền `null` (`main_test`) truyền tường minh `PlatformException`; không test nào dựa vào lỗi mặc định | reject |
| 8 | blind | `FakeSecureKey` không mô phỏng dùng-sau-dispose, `copy()` không được theo dõi | maybe-false | Hành vi chuyển nguyên từ bản cũ. Cần xem có code `lib/` nào dùng key sau `dispose` mà test hiện tại không bắt; nếu có thì là medium | defer |
| 9 | blind | Fake chung không có test riêng | low | Hơn 800 test dùng các fake này; thêm file test là phức tạp thêm, khả năng gặp lỗi thấp | reject |
| 10 | blind | `pak_app_test` bỏ instance `FakeTimers`, mất khả năng assert timer không chạy | false | Bản cũ `(_, _) => _IdleTimer()` cũng bỏ instance và không assert timer; không mất assert nào | reject |

## Design Notes

`RecordingFileSync` gộp 5 bản: mỗi lần gọi thì thêm `path` vào `calls`, gọi `onCall?.call(path)`, rồi ném nếu `failAlways` hoặc `calls.length == failAt`. Bản của `atomic_file_writer_test` chuyển `targetAtCall` vào closure `onCall`. Lỗi ném ra giữ đúng kiểu mà bản cũ ném; bản chung nhận `error` để test chọn kiểu.

## Verification

**Commands:**
- `cd pak_manager && flutter test` -- expected: số pass/skip trùng baseline đo trước khi sửa
- `cd pak_manager && flutter analyze --fatal-infos --fatal-warnings` -- expected: No issues found
- `cd pak_manager && dart format --output=none --set-exit-if-changed test` -- expected: exit 0
- `cd pak_manager && git grep -nE "implements (FileSyncPort|Timer|SecureKey|BackupPort|SystemInfoPort)" -- test` -- expected: chỉ các fake trong Never ngoài `test/support/`

## Implementation Notes

- Baseline (75c9db2) và sau refactor: 837 test (`flutter test -r json`), 819 pass + 18 skip; tập tên test trùng khớp. Ở worktree baseline, `ad07_fsync_failure_after_header_rename_removes_header` một lần lỗi `deleteSync` thư mục tạm trong `tearDown` (errno 145, Windows giữ khóa file) — flake môi trường, không liên quan refactor; chạy lại ở nhánh này pass.
- `FakeSystemInfo(null)` mặc định ném `StateError` để `port_fakes.dart` không phụ thuộc Flutter; `main_test` truyền `error: PlatformException(code: 'unavailable')` để giữ đúng hành vi cũ.
- `atomic_file_writer_test` truyền `error: FileSystemException('fsync thư mục lỗi (giả)')` để giữ nguyên thông điệp bản cũ; `account_service_test` dùng mặc định `FileSystemException('fsync giả lỗi')`, trùng bản cũ.
- `kdf_calibration_test`: `_Harness` ghi `runs` (số lần `derive` = `calls.length` lúc tạo key) song song với `keys`, để `reason` của `expectOnlyReturnedAlive` giữ đúng nhãn `KEK lần N` như `_FakeKey.run` cũ.
- `dart format --output=none --set-exit-if-changed test` exit 1 ở cả baseline lẫn sau sửa, chỉ vì 5 file mẫu cố ý trong `test/fixtures/check_imports/**` (analyzer đã exclude). Mọi file khác trong `test/` đã format; không đụng fixture.
