---
title: 'Story 2.5: "Dữ liệu bị hỏng" không bao giờ dẫn tới xóa'
type: 'feature'
created: '2026-11-22'
status: 'done'
route: 'dispatch'
review_loop_iteration: 0
baseline_commit: 'd6eadf5a49747187c1406462ff2466e6fb262e5b'
context:
  - '{project-root}/_bmad-output/implementation-artifacts/epic-2-context.md'
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** `unlock` đã tách `corrupt` khỏi `wrongPassword` cho header hỏng, DEK/`cards`/`recent` hỏng, nhưng còn hai lỗ hổng làm lỗi của app dẫn tới xóa (FR-7, TC-6): (1) KDF lỗi (thiếu bộ nhớ Argon2, isolate lỗi) bị ánh xạ thành `UnlockCorrupt` trong khi `guard` đã ghi trước `failCount + 1`, nên ở lần thứ 10 lần mở app sau xóa vault dù mật khẩu chưa được kiểm (DW-2.3-3, retro Epic 1 B2); (2) `header`/`cards`/`recent` đọc không giới hạn kích thước (retro B5). Chưa có test nào ghim phiên bản vault mới hơn và "không bao giờ gọi `WipeCoordinator`".

**Approach:** Thêm kết quả `UnlockRetry` cho KDF lỗi (kể cả ném), hoàn lại lần thử đã ghi trước KDF bằng `LockoutGuard.revertAttempt()`, S3 hiện `login.retry`. Đọc `header`/`cards`/`recent` có trần kích thước, vượt trần là `corrupt`. Bổ sung test cho từng nguồn hỏng.

## Boundaries & Constraints

**Always:**
- KDF lỗi (`_deriveKek` trả `null` hoặc ném) → `UnlockRetry`, không bao giờ `UnlockCorrupt`. Ngay sau đó `revertAttempt()` ghi lại đúng trạng thái guard trước lần thử (cả `failCount` lẫn mốc chờ); ghi hoàn lượt lỗi thì RAM và đĩa giữ lần thử đã tính (fail closed), kết quả vẫn `UnlockRetry`. Tắt app trước khi hoàn lượt vẫn tính là sai (FR-5).
- Header sai kích thước (ngắn, dài, vượt trần), magic/version (kể cả version mới hơn, AD-25), `checksum`, tham số KDF ngoài khoảng → `corrupt` trước guard và KDF; bộ đếm giữ nguyên.
- Đọc header tối đa `HeaderCodec.length + 1` byte; `cards`/`recent` tối đa `maxDataFileBytes` (hằng có tên, 16 MiB). Vượt trần → `corrupt` (cards/recent: sau `recordSuccess`, như các lỗi giải mã khác). Không đọc cả file vào RAM rồi mới kiểm.
- `corrupt` và `retry` không bao giờ gọi `WipeCoordinator` và không xóa/ghi file vault; `UnlockCorrupt` không chạm bộ đếm sau khi `kcv` khớp (đã `recordSuccess`).
- S3: `UnlockRetry` hiện `login.retry` (key mới, vi/en, `flutter gen-l10n`) trên dòng `login.attempts`, ô giữ nội dung, bấm "Đăng nhập" lại ngay, `{N}` không giảm. Chữ `ink-secondary`, không màu đỏ (UX-DR21). `login.corrupt` giữ nguyên chữ và vị trí.

**Never:**
- Không sửa `WipeCoordinator`, `bootstrap`, codec header/cards/recent/guard hay fixture; không đổi `verify()`/migration. Không sửa tài liệu kế hoạch (DW-2.1-4 giữ mở). Features không import `core/guard`/`wipe_coordinator`.
- Không hoàn lượt cho `wrongPassword`; không thêm cơ chế tự thử lại KDF.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| KDF lỗi lần 1–9 | `derive` trả `null` hoặc ném | `UnlockRetry`; `failCount` về giá trị trước; `attemptsLeft` không đổi; có mốc chờ thì khôi phục | N/A |
| KDF lỗi lần 10 | `failCount` 9, KDF lỗi | `UnlockRetry`, `failCount` 9 trên đĩa; mở app lại không xóa | N/A |
| Hoàn lượt ghi lỗi | KDF lỗi, ghi guard lỗi | `UnlockRetry`; lần thử vẫn tính | Không ném |
| Header vượt trần / version mới | file > 156 byte, hoặc `version = 2` + checksum đúng | `UnlockCorrupt`, guard và file không đổi, KDF 0 lần | N/A |
| Mật khẩu đúng, `cards`/`recent` quá lớn hoặc `v` mới | `kcv` khớp | `UnlockCorrupt`, `failCount` = 0 | N/A |
| S3 nhận `UnlockRetry` | — | `login.retry` trên `login.attempts`, N giữ nguyên, ô giữ chữ | N/A |

</frozen-after-approval>

## Code Map

- `pak_manager/lib/services/account_service.dart` -- `UnlockResult` :92 (thêm `UnlockRetry`), `_unlock` :382: đọc header :387, `_deriveKek` :411 (bọc try/catch, `null`/ném → `revertAttempt` + `UnlockRetry`), đọc `cards`/`recent` :435-441 (đọc có trần). Sửa doc `unlock` :345 (bỏ "story 2.5 tách riêng"). Hàm đọc có trần theo mẫu `_readCapped` của `settings_store.dart:185`.
- `pak_manager/lib/services/lockout_guard.dart` -- `recordAttempt` :188: lưu trạng thái trước lần thử; thêm `Future<bool> revertAttempt()` (qua `_serial`, ghi lại trạng thái đó, chỉ cập nhật RAM khi ghi được; không đụng digest chuỗi sai).
- `pak_manager/lib/features/auth/login_screen.dart` -- `_UnlockMessage` :37 (thêm `retry`), `switch` :191-224 và :324-329 ánh xạ sang `l10n.loginRetry`; cập nhật doc đầu class.
- `pak_manager/lib/l10n/app_{vi,en}.arb` -- thêm `loginRetry` (en có `@loginRetry`); `flutter gen-l10n`.
- `pak_manager/test/services/account_service_test.dart` -- sửa `fr07_fr04_tenth_attempt_with_kdf_failure_stays_corrupt` :905 và `fr07_kdf_failure_is_corrupt_not_a_throw_and_still_counts` :1313 theo hành vi mới; thêm vào `corruptHeaders` :1255 (`oversize`, `version_newer` có checksum đúng) và `corruptData` :1282 (`cards_oversize`, `recent_oversize`, `cards_version_newer`, `recent_version_newer`); khẳng định `WipeCoordinator` (fake/spy) không bị gọi và không có `wiping` trên đĩa.
- `pak_manager/test/services/lockout_guard_test.dart` -- test `revertAttempt` (khôi phục `failCount` và mốc chờ, ghi lỗi giữ lần thử, không chạm digest).
- `pak_manager/test/features/auth/login_screen_test.dart`, `pak_manager/test/support/account_fakes.dart` -- case `UnlockRetry` (`completeUnlock`); mẫu `fr07_ux_dr21_corrupt_is_above_attempts_and_n_kept` :274.

## Tasks & Acceptance

**Execution:**
- [x] `lib/services/lockout_guard.dart` -- thêm `revertAttempt()` -- hoàn lượt khi KDF lỗi (AD-8, FR-7)
- [x] `lib/services/account_service.dart` -- `UnlockRetry`, bọc KDF, đọc có trần, sửa doc -- TC-6, retro B2/B5
- [x] `lib/l10n/app_{vi,en}.arb` -- `loginRetry`; `flutter gen-l10n` -- UX-DR42
- [x] `lib/features/auth/login_screen.dart` -- ánh xạ `UnlockRetry` → `login.retry` -- UX-DR21
- [x] `test/services/*`, `test/features/auth/login_screen_test.dart` -- các dòng Matrix và từng nguồn hỏng (header, DEK, `cards`, `recent`, phiên bản mới): bộ đếm không tăng, `WipeCoordinator` không bao giờ được gọi

**Acceptance Criteria:**
- Given test mới, when đọc tên, then mỗi tên bắt đầu bằng id thật đệm 2 chữ số (`fr07_`, `ad04_`, `ad08_`, `ad25_`, `tc06_`, `ux_dr21_`, `ux_dr42_`).
- Given `lib/`, when chạy `check_imports` và `gen-l10n` lần hai, then OK, không file sinh nào lệch.
- Given vault nguyên vẹn đã sai 9 lần và KDF lỗi ở lần 10, when người dùng bấm "Đăng nhập" rồi mở lại app, then S3 hiện `login.retry`, vẫn "Còn 1 lần thử…", và app không vào S5.

## Implementation Notes

- `LockoutGuard` giữ `_beforeAttempt` (trạng thái trước lần `recordAttempt` gần nhất); `revertAttempt()` ghi lại đúng trạng thái đó qua `_serial`, chỉ đổi RAM khi ghi được. `recordSuccess`/`reset` xóa nó. Lỗi ghi sau rename (fsync thư mục) có thể khiến đĩa đã hoàn còn RAM giữ lần thử; đã sửa doc cho đúng.
- `UnlockRetry` cho cả KDF trả `null` lẫn ném; chữ `login.retry` không hứa "không bị tính" vì hoàn lượt có thể ghi lỗi.
- `_readCapped` (đọc tối đa `maxBytes + 1` byte) theo mẫu `SettingsStore`; `maxDataFileBytes` 16 MiB là số tự chọn (xem `DW-2.5-2`). Test oversize dùng payload AEAD hợp lệ dài đúng `maxDataFileBytes + 1`, đã kiểm đột biến (tắt kiểm trần thì fail). `WipeCoordinator` là `final` nên spy qua `onStep`.
- Kiểm chứng: `flutter analyze --fatal-infos --fatal-warnings` sạch, `check_imports` OK, `gen-l10n` lần hai không đổi, `flutter test -j 1` 1115 pass, 20 skip, 0 fail. Chạy song song vẫn dính teardown Windows `DW-2.1-1` (errno 145). Chưa chạy trên máy/emulator.
- Ba mục defer: `DW-2.5-1` (KDF hỏng vĩnh viễn), `DW-2.5-2` (trần ghi), `DW-2.5-3` (lỗi I/O tạm thời thành `corrupt`). `DW-2.3-3` được đóng ở mức code; ghi `status: done` sau khi có CI run.

## Spec Change Log

## Review Triage Log

Review vòng 1 (2026-11-22): blind-hunter, edge-case-hunter, verification-gap; không lớp nào lỗi. Trước review: `flutter analyze` sạch, `check_imports` OK, `gen-l10n` lần hai không đổi, 204 test của `account_service`/`lockout_guard`/`login_screen` pass; `flutter test` cả bộ chỉ fail teardown Windows errno 145 (`DW-2.1-1`, test fail khác nhau mỗi lần, pass khi chạy lại).

| # | Nguồn | Phát hiện | Verdict | Bằng chứng | Route |
|---|---|---|---|---|---|
| 1 | blind | `unlock` bỏ qua kết quả `revertAttempt()`; `login.retry` ghi "lần thử này không bị tính" dù hoàn lượt ghi lỗi thì lần thử vẫn tính và N giảm | low | Đúng: `account_service.dart` `await _guard.revertAttempt(); return UnlockRetry` và chữ vi/en hứa không tính; chỉ xảy ra khi KDF lỗi rồi ghi guard lỗi | patch (bỏ câu hứa khỏi chuỗi) |
| 2 | blind, edge-case | Hoàn lượt lỗi ở `fsyncDirectory`: đĩa đã hoàn (rename xong) còn RAM giữ lần thử; doc `revertAttempt` nói cả hai giữ lần thử đã tính | low | Đúng: `AtomicFileWriter` fsync thư mục sau rename; test hiện có khẳng định `diskState().failCount` 2 còn RAM 3. Chỉ sai lời doc, không sai code (đường `recordAttempt` có sẵn hành vi tương tự) | patch (sửa doc) |
| 3 | verification-gap | Test `cards_oversize`/`recent_oversize`/`at_cap` dùng blob toàn 0 nên AEAD lỗi cũng ra `corrupt`: bỏ trần vẫn xanh; test "at_cap" khẳng định `corrupt` trái tên | medium | Đúng: `kcv` khớp nên `failCount` 0 ở mọi nhánh; không test nào phân biệt từ chối do kích thước với lỗi giải mã (cũng là Matrix row 5) | patch (payload AEAD hợp lệ vượt/dưới trần) |
| 4 | blind | `_beforeAttempt` không được xóa khi `kcv` lệch, khi ghi `recordAttempt` lỗi hay `normalize`; `revertAttempt` sai trạng thái nếu bị gọi lạc | low | Chưa chứng minh: `revertAttempt` chỉ gọi ngay sau `recordAttempt` thành công trong cùng `unlock`; ghi lỗi thì `unlock` trả `UnlockUnavailable` trước KDF; `recordAttempt` luôn ghi đè | reject (không có đường gọi; sửa thêm guard cho trạng thái chưa chứng minh) |
| 5 | blind | Hai `unlock` chồng nhau làm `revertAttempt` hoàn sai lượt | false | `_unlocking` đặt trước `await` đầu tiên, lần chồng nhận `UnlockBusy` không chạm guard (`account_service.dart:390-397`, test `ux_dr42_concurrent_unlock_is_busy…`) | reject |
| 6 | blind, edge-case | KDF hỏng vĩnh viễn (máy không cấp phát đủ bộ nhớ Argon2) thì người dùng lặp `login.retry` mãi, không có lối thoát hay thông báo khác | medium | Có thật nhưng hiếm: `unlock` luôn trả `UnlockRetry` không đếm; trước story này người dùng cũng kẹt ở `corrupt`. Cần quyết định UX (đếm lần liên tiếp, thông báo khác) | defer → `DW-2.5-1` |
| 7 | blind | `on Object` nuốt mọi lỗi KDF, nên bắt `Exception` | false | `on Object` là quy ước của cả codebase (ranh giới "không ném"); `deriveKek` cũng bắt `Object` và test ghim việc ném `StateError` | reject |
| 8 | edge-case | Hoàn lượt khi KDF lỗi làm yếu khóa: kẻ tấn công gây KDF lỗi để thử mật khẩu không tốn lượt | false | KDF lỗi thì không có `kcv` để so, không có thông tin nào về mật khẩu bị lộ; một lần thử "miễn phí" không cho biết gì | reject |
| 9 | blind, edge-case | Trần 16 MiB một chiều: không có trần ghi, vault lớn hơn 16 MiB ghi được rồi bị `corrupt` vĩnh viễn khi mở; hằng không có căn cứ AD/NFR | medium | Chưa xảy ra: chưa có đường ghi `cards` (Epic 3) và import (Epic 6, ≤ 10 000 card, chuỗi ≤ 64 KiB nên có thể vượt 16 MiB về lý thuyết). Cần ràng buộc trần ghi hoặc nâng trần khi dựng hai epic đó | defer → `DW-2.5-2` |
| 10 | blind, edge-case | `_readCapped` đọc ngắn (`read(n)` có thể trả ít hơn) biến file hợp lệ thành `corrupt` | low | Chưa chứng minh: file thường đọc đủ ở Windows/Linux/iOS/Android, cùng mẫu `SettingsStore._readCapped` đã chạy; sửa thêm vòng lặp đọc | reject |
| 11 | blind, edge-case | Lỗi I/O tạm thời khi đọc (EIO, khóa file) hiện thành `login.corrupt`, đẩy người dùng tới "Xóa & Tạo tài khoản mới" | medium | Có thật nhưng có từ trước story này (`readAsBytes` ném thì cũng `UnlockCorrupt`); `login.corrupt` không tự xóa gì. Tách "đọc không được lúc này" khỏi "hỏng" là quyết định UX | defer → `DW-2.5-3` |
| 12 | edge-case | Ngoại lệ sau `recordAttempt` nhưng ngoài `_deriveKek` (`kcvMatches`, `recordSuccess`…) rơi vào `UnlockCorrupt` và lần thử vẫn tính | low | Chưa có đường kích hoạt: các bước đó là phép tính thuần trên khóa hợp lệ; `recordSuccess` không ném (`_write` bắt `Object`) | reject |
| 13 | edge-case | `ascii.encode` ném với chuỗi không ASCII thì ra `UnlockCorrupt` | false | S3 chặn chuỗi không ASCII ở nút "Đăng nhập", không bao giờ tới `unlock` (epic-2-context: "không bao giờ tới `LockoutGuard`") | reject |
| 14 | blind | Test `fr06_tc06_app_killed_before_revert_still_counts` yếu, instance đầu còn chạy và ghi guard lúc teardown | low | Sai: test `await pending` đến khi `unlock` xong trước khi kết thúc; bản sao thứ hai kiểm đúng `attemptsLeft` 9 khi KDF còn treo | reject |
| 15 | blind | Diff không cập nhật ARCHITECTURE-SPINE (AD-8/AD-5) hay `deferred-work.md` | false | Spec (Never) cấm sửa tài liệu kế hoạch; các mục defer đã ghi `DW-2.5-1..3` ở bước này | reject |
| 16 | verification-gap | `revertAttempt` có thể khôi phục mốc chờ cũ nếu `_reanchorIfNeeded` chạy giữa KDF | low | Không có đường: lần thử 5–9 vừa đặt mốc mới ngay trước KDF, neo lại chỉ xảy ra khi `bootId` đổi (khởi động lại máy), tức app đã tắt | reject |
| 17 | verification-gap | Nhánh `reset` rồi `revertAttempt`, và nhánh file không phải file thường/đọc lỗi của `_readCapped` chưa có test | low | Không có người gọi `reset` rồi `revertAttempt`; nhánh đọc lỗi cho cùng kết quả `UnlockCorrupt` như trước | reject |

## Verification

**Commands:**
- `cd pak_manager && flutter gen-l10n` -- expected: chạy lần hai không đổi file trong `lib/l10n/`
- `cd pak_manager && flutter analyze --fatal-infos --fatal-warnings` -- expected: sạch
- `cd pak_manager && dart run tool/check_imports.dart` -- expected: không vi phạm
- `cd pak_manager && flutter test` -- expected: tất cả pass (trừ teardown Windows `DW-2.1-1` đã biết), số test tăng, không thêm skip
