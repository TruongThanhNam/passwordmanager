---
title: 'Story 2.1: Đếm lần nhập sai bền vững'
type: 'feature'
created: '2026-11-21'
status: 'done'
route: 'dispatch'
review_loop_iteration: 0
baseline_commit: '92c25d2831bea93c8b025513853060efeb960c07'
context:
  - '{project-root}/_bmad-output/implementation-artifacts/epic-2-context.md'
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** Hiện `AccountService.unlock` cho thử mật khẩu chính bao nhiêu lần cũng được, không lưu lại lần sai nào, nên script dò được trên màn Login. S3 cũng không cho người dùng biết họ còn bao nhiêu lần thử (FR-4 lần 1–4, FR-5, FR-8). Ngoài ra, nếu gọi `unlock` lần hai khi lần một chưa xong thì lần hai nhận luôn kết quả của lần một, mật khẩu đưa vào là gì cũng vậy (retro Epic 1, B4).

**Approach:** Thêm `guard_codec` và máy trạng thái thuần `core/guard`, rồi thêm service `LockoutGuard` làm chủ duy nhất file `guard`. `AccountService` gọi guard trong `bootstrap()` và `unlock()` theo thứ tự AD-4/AD-8: ghi `failCount += 1` trước KDF, `kcv` khớp thì đặt lại về 0, nhập lại đúng chuỗi sai ngay trước thì báo sai mà không đếm. S3 luôn hiện dòng `login.attempts`.

## Boundaries & Constraints

**Always:**
- Thứ tự `unlock` như sau: đọc và decode header (hỏng → `UnlockCorrupt`, không chạm guard) → `ascii.encode` → so digest với chuỗi sai ngay trước (trùng → `UnlockWrongPassword`, không ghi, không KDF) → `failCount ≥ 10` → `UnlockLockedOut`, không ghi, không KDF → `recordAttempt()` ghi xuống đĩa (lỗi → `UnlockUnavailable`, không KDF) → KDF → `kcv` lệch thì nhớ digest và trả `UnlockWrongPassword` → `kcv` khớp thì gọi `recordSuccess()` trước khi mở bọc DEK.
- KDF lỗi (`null`) sau khi đã ghi trước: lần thử vẫn đã được đếm, trả `UnlockCorrupt` như hiện tại. Story 2.5 tách riêng trường hợp này.
- Digest là BLAKE2b 16 byte, khóa 32 byte ngẫu nhiên sinh khi dựng `LockoutGuard` và chỉ nằm trong RAM. So digest bằng phép so hằng thời gian. Mảng byte mật khẩu vẫn bị wipe như hiện tại.
- `recordSuccess()` bỏ digest, đặt `failCount = 0` và xóa mốc chờ trong RAM. Ghi đĩa lỗi thì vẫn mở khóa tiếp: lần ghi trước KDF kế tiếp sẽ ghi lại trạng thái đúng.
- `failCount` không vượt 10. Ba hằng số (`maxAttempts = 10`, `waitFromAttempt = 5`, `waitDuration = 30 phút`) đặt trong `core/guard` dạng `const`, không lấy từ cài đặt nào. Story này chưa dùng hai hằng số sau.
- Khi khởi động: có `header` mà `guard` thiếu hoặc không decode được → ghi lại `{failCount: 0}`. Ghi lỗi thì trong RAM vẫn là 0, `bootstrap` không đổi kết quả. Không có `header` thì không ghi `guard`.
- Gọi `unlock` chồng lên lần đang chạy → trả `UnlockBusy` ngay, không ghi guard, không KDF, không bao giờ chia phiên của lần đang chạy cho lần sau.
- `AccountService.attemptsLeft` (= 10 − `failCount`, đọc từ RAM) là nguồn số {N} cho UI. Features không import `core/guard` hay `LockoutGuard`.
- S3: dòng `login.attempts` luôn hiện, nằm cuối khối thông báo (`login.wrong`/`login.corrupt`/`pw.nonAscii` ở trên). `UnlockUnavailable` hiện chuỗi `createUnavailable` có sẵn. `UnlockBusy` thì bỏ qua. `attemptsLeft == 0` thì nút "Đăng nhập" bị vô hiệu.

**Never:**
- Chưa làm mốc chờ hay `normalize()` theo `bootId`/monotonic (story 2.2), chưa xóa dữ liệu ở lần thứ 10, chưa làm `WipeCoordinator` hay `wiping` (story 2.3), chưa làm nút "Xóa & Tạo tài khoản mới" (story 2.4). Codec vẫn đọc và ghi đủ mọi trường của schema, và máy trạng thái giữ nguyên `waitBootId`/`waitStartMono`/`wiping` khi đếm.
- Không mã hóa `guard`. Không ghi mật khẩu hay digest xuống đĩa. Không ghi gì vào Keychain/Keystore.
- `create()` không đọc, không ghi `guard`.
- Không thêm provider mới. Không truyền service qua constructor widget.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Sai lần đầu | failCount 0, chuỗi X sai | Đĩa có `failCount: 1` trước khi KDF chạy; trả `UnlockWrongPassword`; N = 9 | N/A |
| Lặp chuỗi sai | vừa sai bằng X, nhập lại X | `UnlockWrongPassword`, KDF không chạy, file không đổi, N giữ nguyên | N/A |
| Đúng sau khi sai | failCount 3, mật khẩu đúng | Đĩa có `failCount: 0` trước khi mở bọc DEK; `UnlockSuccess` | N/A |
| Đúng nhưng dữ liệu hỏng | `kcv` khớp, `cards` hỏng | `UnlockCorrupt`, failCount = 0 | N/A |
| Header hỏng | checksum lệch | `UnlockCorrupt`, `guard` không đổi, KDF không chạy | N/A |
| Tắt app giữa KDF | đã ghi trước, KDF chưa xong | Dựng service mới trên cùng thư mục, chạy `bootstrap` → N giảm 1 | N/A |
| Ghi trước lỗi | writer lỗi ở bất kỳ bước nào | `UnlockUnavailable`, KDF không chạy, N trong RAM giữ nguyên | không ném |
| Hết lượt | failCount 10 | `UnlockLockedOut`, không ghi, không KDF; nút vô hiệu | N/A |
| `guard` hỏng | có `header`, `guard` không phải JSON/sai kiểu/thiếu key/`v` ≠ 1/failCount ngoài 0–10 | `bootstrap` ghi lại failCount 0; N = 10 | ghi lỗi → RAM 0 |
| Gọi chồng | lần một đang chạy KDF | lần hai trả `UnlockBusy`; KDF chạy 1 lần, ghi trước 1 lần | N/A |

</frozen-after-approval>

## Code Map

- `pak_manager/lib/services/account_service.dart` -- `bootstrap()` :147 (đã chừa chỗ chèn ở :148-152), `unlock`/`_unlock` :268-336 (chỗ chèn :293, :302), cơ chế gọi chồng `_unlocking` :138 (lỗi B4 :269-271). Bổ sung `UnlockLockedOut`, `UnlockUnavailable`, `UnlockBusy` vào sealed `UnlockResult` (:76), xóa comment "Epic 2 thêm…" (:101). Constructor nhận thêm `required LockoutGuard guard`.
- `pak_manager/lib/core/format/settings_codec.dart` -- làm mẫu cho `guard_codec`: `abstract final class`, `decode` không bao giờ ném, `encode` JSON không khoảng trắng theo thứ tự key AD-20. Khác ở chỗ `guard` sai bất kỳ trường nào thì trả kết quả "không đọc được" cho cả file.
- `pak_manager/lib/services/settings_store.dart` -- `_readCapped`/`maxFileBytes` là mẫu đọc file có giới hạn kích thước. `guard` dùng giới hạn 4 KiB.
- `pak_manager/lib/core/io/atomic_file_writer.dart` -- `AtomicFileWriter.write(path, bytes)` → `AtomicWriteSuccess`/`AtomicWriteFailure`; hook `onStep(AtomicWriteStep)` dùng để giả lập crash. `PakPaths.guardFile` = `pak/guard`.
- `pak_manager/lib/main.dart` -- `_wireAccount` :154: dựng `LockoutGuard(sodium:, writer:, path: paths.guardFile)` rồi truyền vào `AccountService`.
- `pak_manager/lib/features/auth/login_screen.dart` -- `_UnlockMessage` :29, `_submit` :82 (switch kết quả), `_s3` :158 (khối thông báo, dùng `InlineMessage`).
- `pak_manager/lib/l10n/app_{vi,en}.arb` -- thêm `loginAttempts` có tham số `N` (int). VI: "Còn {N} lần thử trước khi dữ liệu bị xóa." EN: "{N} attempts left before your data is erased." Mô tả `@loginAttempts` ghi `login.attempts (FR-4)`.
- `pak_manager/test/services/account_service_test.dart` -- helper `service(...)` :136 (thêm guard), `installVault` :407, `realService` :437, `recordingWriter(failFile:)` :112. Test `ux_dr42_concurrent_unlock_returns_running_result` :583 phải viết lại theo `UnlockBusy`.
- `pak_manager/test/support/account_fakes.dart` -- `FakeAccountService` thêm `attemptsLeft` có setter. Fake dùng chung nằm ở `test/support/port_fakes.dart`, không chép fake inline.
- `pak_manager/test/core/format/settings_codec_test.dart` + `test/fixtures/settings/v1/` -- mẫu cho golden test viết tay.
- `pak_manager/lib/core/guard/.gitkeep` -- xóa khi thư mục đã có file thật.

## Tasks & Acceptance

**Execution:**
- [x] `pak_manager/lib/core/guard/guard_state.dart` -- `GuardState` bất biến (failCount, waitBootId, waitStartMono, wiping; `initial`; `==`), 3 hằng số, transition thuần `afterAttempt()` (+1, chặn ở 10) và `afterSuccess()` (0, xóa mốc), `attemptsLeft`, `exhausted` -- máy trạng thái thuần (AD-8).
- [x] `pak_manager/lib/core/format/guard_codec.dart` -- `GuardCodec.decode` → sealed `GuardOk(state)`/`GuardUnreadable`, không ném; `encode` theo schema AD-20 -- codec duy nhất của `guard`.
- [x] `pak_manager/lib/services/lockout_guard.dart` -- `normalize({required bool hasAccount})`, `state`, `isRepeatOfLastWrong(Uint8List)`, `rememberWrong(Uint8List)`, `recordAttempt()` → bool, `recordSuccess()`. Đọc có giới hạn kích thước, ghi qua `AtomicFileWriter`, chỉ cập nhật RAM khi ghi thành công (trừ trường hợp `recordSuccess`) -- chủ duy nhất của `guard`.
- [x] `pak_manager/lib/services/account_service.dart` -- chèn guard theo đúng thứ tự trong Always; `bootstrap` gọi `normalize` sau khi biết có header hay không; thêm 3 kết quả mới, `attemptsLeft`, sửa B4.
- [x] `pak_manager/lib/main.dart` -- nối `LockoutGuard`.
- [x] `pak_manager/lib/features/auth/login_screen.dart` + 2 ARB -- dòng `login.attempts`, xử lý kết quả mới; chạy `flutter gen-l10n`.
- [x] `pak_manager/test/fixtures/guard/v1/{initial,waiting}.json` + `test/core/format/guard_codec_test.dart` -- golden round-trip từng byte, mỗi trường sai thì ra `GuardUnreadable`.
- [x] `pak_manager/test/core/guard/guard_state_test.dart`, `test/services/lockout_guard_test.dart` -- transition, chặn ở 10, giữ nguyên trường chờ, crash ở từng `AtomicWriteStep`, tạo lại `guard`, digest chỉ nằm trong RAM (file không chứa mật khẩu).
- [x] `pak_manager/test/services/account_service_test.dart` -- các dòng của Matrix (KDF thật + fixture vault), thứ tự ghi trước KDF (đọc file bên trong `derive`).
- [x] `pak_manager/test/features/auth/login_screen_test.dart` + `account_fakes.dart` -- dòng attempts luôn hiện và nằm cuối khối, N giảm sau lần sai, `UnlockUnavailable`/`UnlockBusy`/hết lượt.

**Acceptance Criteria:**
- Given `lib/`, when grep `guardFile`, then chỉ thấy trong `pak_paths.dart`, `main.dart` (lúc nối) và `lockout_guard.dart`; ngoài `guard_codec.dart` không chỗ nào encode/decode `guard`.
- Given test mới, when đọc tên, then mỗi tên bắt đầu bằng id thật đệm 2 chữ số (`fr04_`, `fr05_`, `fr08_`, `ad08_`, `ad20_`, `ad22_`, `ux_dr42_`), ví dụ `fr05_same_wrong_string_not_counted`.
- Given S3 ở idle, when hiển thị, then ngay dưới ô có "Còn 10 lần thử trước khi dữ liệu bị xóa."; sau một lần sai thì "Sai mật khẩu." nằm trên và N = 9, ô vẫn giữ nội dung và nhập lại được ngay.

### Review Findings

Code review vòng 2 (2026-11-21). Lớp review: blind-hunter, edge-case-hunter, verification-gap, acceptance-auditor; không lớp nào lỗi. Chạy lại `flutter test` ở `83c6250`: 917 pass, 18 skip, 1 fail (errno 145 lúc `tearDown`, tức `DW-2.1-1`).

- [x] [Review][Patch] Test hết lượt không phát hiện được một lần ghi `guard` cùng byte: dời kiểm `exhausted` xuống sau `recordAttempt()` thì vẫn ghi `{"failCount":10,…}` y hệt nên `guardBytes() == before` vẫn qua; cần đếm `AtomicWriteStep.rename` qua `onStep` và đòi bằng 0 [pak_manager/test/services/account_service_test.dart:720]
- [x] [Review][Patch] Chưa có test mức `unlock` chứng minh chỉ `kcv` lệch mới nhớ digest: sau `UnlockUnavailable` và sau KDF lỗi (`null`/ném), thử lại đúng mật khẩu trên cùng service phải chạy KDF và ra `UnlockSuccess`; dời `rememberWrong` lên trên thì người dùng nhập đúng bị báo "Sai mật khẩu." mà không test nào fail (story 2.5 sửa đúng vùng này) [pak_manager/test/services/account_service_test.dart:807]
- [x] [Review][Patch] Chưa có test mức `unlock` cho Always "`recordSuccess()` ghi lỗi thì vẫn mở khóa tiếp": cho lần ghi thứ hai (sau khi `kcv` khớp) lỗi, đòi `UnlockSuccess`, phiên dùng được và `attemptsLeft == 10`; hiện chỉ `lockout_guard_test` kiểm trực tiếp guard [pak_manager/test/services/account_service_test.dart:646]
- [x] [Review][Defer] Tài liệu kế hoạch chưa phản ánh `UnlockUnavailable`/`UnlockBusy`: trạng thái S3 trong UX-DR42 (EXPERIENCE.md, epics.md) không có trạng thái "không ghi được lần thử", S3 dùng lại `create.unavailable` mà UX chưa chốt [pak_manager/lib/features/auth/login_screen.dart:123] — deferred: sửa chạm tài liệu kế hoạch (`docs(ux|planning)`), ghi `DW-2.1-4`

**Rejected:**

- `false`: AC3 chỉ chứng minh bằng `FakeAccountService` (acceptance-auditor). Phía service đã có `fr04_ad08_first_wrong_is_on_disk_before_kdf` (`attemptsLeft == 9`). S3 đọc `attemptsLeft` mỗi lần `build` và mọi kết quả `unlock` đều `setState`, nên không có chỗ nào để số bị cũ.
- `false`: dòng `login.attempts` ẩn khi provider `null` (acceptance-auditor). `main.dart` chỉ đặt service `null` cùng với `BootstrapUnavailable`, nên S3 không bao giờ hiện khi provider `null`.
- `false`: chuỗi EN khác Code Map (acceptance-auditor). Đây là patch có chủ ý #6 (ICU plural); Code Map nằm ngoài khối frozen, VI khớp spec.
- `low`: frontmatter `status: done`, `review_loop_iteration: 0` và Spec Change Log trống, lệch với sprint-status `review` (acceptance-auditor + blind-hunter). Sửa là sửa spec đang review; bước đồng bộ trạng thái của review này sẽ chỉnh `status`.
- `false`: `recordSuccess()` ghi cả khi `failCount` đã là 0 (acceptance-auditor). Hành vi này do Always/AD-4 quy định, không có hại.
- `low`: `pak/guard` là thư mục thì mọi `recordAttempt` lỗi vĩnh viễn, ra `UnlockUnavailable` (edge-case-hunter). Chỉ xảy ra khi có người sửa file từ ngoài (root/jailbreak), và sửa phải thêm nhánh xóa thư mục.
- `low`: `unlock` chạy trước `normalize` sẽ ghi đè `failCount` trên đĩa từ `GuardState.initial` (edge-case-hunter + blind-hunter). Ở production, `main.dart` chỉ đưa service ra sau khi `bootstrap()` thành công, nên đường này chưa với tới; sửa phải thêm cờ trạng thái. Story 2.3 phải chạy `normalize` sau mỗi lần xóa.
- `low`: bằng chứng verify ghi trước các patch review và còn 1 fail (blind-hunter). Đã chạy lại: chỉ còn đúng lỗi teardown `DW-2.1-1`; sửa là sửa spec.
- `false`: hết lượt (N = 0) bị kẹt mà không ai theo dõi (blind-hunter). Design Notes ghi rõ trạng thái tạm "fail closed", và 2.3/2.4 đã nằm trong backlog.
- `false`: `LockoutGuard` không hủy `_digestKey`/không wipe digest, thiếu `reset()` (blind-hunter). Khóa sống theo process. AD-22 cho service giữ digest, và digest không phải bản rõ. `reset()` là API của 2.3 theo AD-21.
- `low`: `lockout_guard_test` lặp teardown dễ fail và tự định nghĩa `_SimulatedCrash` (blind-hunter). Teardown đã nằm trong `DW-2.1-1`. `_SimulatedCrash` là kiểu lỗi cục bộ, không phải fake port, và hai file test cũ cũng làm vậy.
- `low`: `ad22_unlock_wipes_password_bytes` không phủ 3 đường trả sớm trước KDF (blind-hunter). `finally` đã wipe; muốn quan sát byte mà không qua `derive` thì phải thêm seam vào code.
- `false`: `ad08_guard_recreate_failure_keeps_zero_in_ram` yếu, có thể dẫn tới bypass (blind-hunter). Sau khi ghi lỗi, RAM là 0; lần `unlock` kế tiếp vẫn ghi trước KDF, hoặc ra `UnlockUnavailable` nếu writer vẫn lỗi. Không có bypass.

## Implementation Notes

- Subagent triển khai theo spec; không đổi gì ngoài Code Map. Tự chọn thêm: codec bỏ qua key lạ (giống `settings`), bắt `waitStartMono ≥ 0`, chưa kiểm chéo cặp `waitBootId`/`waitStartMono` (để 2.2); `normalize(hasAccount: false)` vẫn nạp `guard` đọc được vào RAM nhưng không ghi.
- `recordAttempt` lỗi ở bước `fsyncDirectory` (sau rename): đĩa đã mang số mới, RAM giữ số cũ, lần khởi động sau N giảm 1 (an toàn, có test ghi lại).
- `login.attempts` cách ô `inlineMessageGap` (6) khi đứng một mình, cách dòng trên `inlineMessageLineGap` (2) khi có thông báo khác.
- Kiểm tra (2026-11-21, Windows): `flutter analyze --fatal-infos --fatal-warnings` sạch; `check_imports: OK`; `gen-l10n` chạy lại không đổi file; `flutter test` 916 pass, 18 skip, 1 fail. Lần fail là lỗi `tearDown` `sandbox.deleteSync` báo errno 145 (thư mục chưa rỗng), không phải assert. Lỗi này có từ trước: baseline `92c25d2` cũng fail 2/8 lần ở `account_service_test`/`settings_store_test`; `lockout_guard_test` mới dọn thư mục theo cùng cách nên cũng dính. Ghi thành `DW-2.1-1`.

## Spec Change Log

## Review Triage Log

| # | Nguồn | Phát hiện | Verdict | Bằng chứng | Route |
|---|---|---|---|---|---|
| 1 | verification-gap, edge-case, blind | Tài khoản mới kế thừa `failCount` cũ: `normalize(hasAccount: false)` nạp `guard` còn sót, `create()` không đặt lại | medium | Đúng: nhánh `GuardOk` gán `_state` bất kể `hasAccount`, `create()` không gọi guard; chỉ xảy ra khi mất `header` mà còn `guard` (2.1 chưa tạo ra được). Cách sửa phải cho `create()` hoặc không-có-header ghi `guard`, điều mà intent cấm | defer (DW-2.1-2) |
| 2 | edge-case, blind | Digest chuỗi sai sống qua `create()` cùng process | low | Cùng gốc với #1 (guard không được đặt lại giữa hai tài khoản); S3 → S1 cùng process chưa tồn tại ở 2.1, sẽ có ở 2.3/2.4 | defer (gộp DW-2.1-2) |
| 3 | edge-case, blind | `recordSuccess()` ghi lỗi bị bỏ qua; khởi động lại thì đĩa còn số đã tăng, lần thứ 10 bị chặn dù đăng nhập đúng | medium | Đúng hậu quả, nhưng hành vi "ghi lỗi vẫn mở khóa" là quyết định trong frozen Always; cần chốt trước khi 2.3 nối xóa | defer (DW-2.1-3) |
| 4 | edge-case | Lỗi đọc tạm thời (quyền, I/O) bị coi là "không đọc được" và ghi lại `failCount = 0` | low | Đúng cơ chế, nhưng AD-8 chấp nhận rõ "thiếu hoặc không đọc được → tạo lại 0" (cùng lớp rủi ro root/jailbreak); sửa cần thêm trạng thái đọc lỗi riêng | reject |
| 5 | edge-case, blind | Codec nhận mốc chờ nửa vời (`waitBootId` có, `waitStartMono` null hoặc ngược lại) | low | 2.1 không dùng mốc chờ; chỉ xảy ra khi sửa tay file. 2.2 thêm mốc chờ và luật `normalize` sẽ quyết định cặp này | reject |
| 6 | edge-case, blind | EN không có số nhiều: N = 1 hiện "1 attempts left" | low | Đúng, chuỗi `loginAttempts` EN cố định; sửa trực tiếp bằng ICU plural | patch |
| 7 | edge-case | Spec nói RAM chỉ đổi khi ghi thành công (trừ `recordSuccess`) nhưng `normalize` cũng đổi RAM khi ghi lỗi | false | Mục Always ghi rõ "Ghi lỗi thì trong RAM vẫn là 0" cho bước khởi động; code khớp spec. Sửa sẽ là sửa spec | reject |
| 8 | blind | `UnlockBusy` mở lại ô và nút | false | `_submit` chỉ gọi `unlock` khi chính State này không busy; nhận `UnlockBusy` nghĩa là State này không có lần kiểm tra nào đang chạy, nên `_busy = false` là đúng; "bỏ qua" là không hiện thông báo | reject |
| 9 | blind | `attemptsLeft` đọc bằng `ref.read` trong `build`, không quan sát được | low | Chỉ cũ khi S3 dựng lại giữa lúc lần kiểm tra trước đang chạy (hiếm); mọi kết quả `unlock` đều `setState`. Sửa cần thêm provider/notifier; 2.2 làm đếm ngược sẽ xem lại | reject |
| 10 | blind | Kiểm lặp chuỗi sai đứng trước kiểm hết lượt, nên lúc hết lượt có thể trả `UnlockWrongPassword` | false | Thứ tự này do frozen Always quy định; không ghi, không KDF, nút đã vô hiệu, không có hại cụ thể | reject |
| 11 | blind | `snapshot()` bị thu hẹp từ `pak/` xuống `vault/`, không bắt ghi lạc dưới `pak/` | low | Đúng; sửa trực tiếp trong test: chụp `pak/` trừ riêng `guard` | patch |
| 12 | blind | `DW-2.1-1` được nhắc nhưng chưa có trong `deferred-work.md`; trạng thái tạm 5–9/10 chưa ghi | low | Mục DW được thêm ở bước triage này (thứ tự quy trình); trạng thái tạm đã là backlog story 2.2–2.4 | reject |
| 13 | blind | `_readCapped` chép từ `settings_store.dart` | low | Hai bản khác giới hạn, chưa thấy lệch hành vi; gom về `core/io` là refactor thêm API | reject |
| 14 | blind | `GuardState` không assert miền `failCount`/`waitStartMono` | low | Mọi chỗ dựng `GuardState` đi qua codec (đã kiểm miền) hoặc transition chặn ở 10; thêm assert là chặn trạng thái không với tới | reject |
| 15 | blind | Thiếu golden `wiping: true`; thiếu test `guard` là thư mục/symlink | low | `ad20_encode_uses_key_order_without_whitespace` đã encode `wiping: true`; thư mục/symlink cho `_readCapped` trả `null` rồi ghi lỗi, RAM 0, không ném | reject |
| 16 | blind | Diff review bỏ file l10n sinh, spec, sprint-status | false | Chủ ý theo quy trình: spec chỉ đưa cho lớp edge-case; file sinh được kiểm bằng chạy lại `gen-l10n` không đổi | reject |
| 17 | blind | `main_test` hard-code đường dẫn và JSON của `guard` | low | Chuỗi literal là kiểm định dạng độc lập với codec; không có hại cụ thể | reject |
| 18 | ngoài review | errno 145 khi `tearDown` xóa sandbox trên Windows | low | Có từ trước (baseline `92c25d2` fail 2/8 lần); `lockout_guard_test` mới dọn cùng cách | defer (DW-2.1-1) |

## Design Notes

`LockoutGuard` là service phạm vi app, sống lâu hơn phiên, nhận `SodiumSumo` để sinh khóa digest (`crypto.genericHash.keygen()`) và tính `genericHash(message, outLen: 16, key)`. Trạng thái trong RAM chỉ đổi sau khi ghi thành công, nên ghi lỗi ở `recordAttempt` thì giữ được số cũ và UI không giảm N. `UnlockBusy` thay cho việc trả lại `Future` đang chạy: chỉ người gọi đầu nhận `UnlockSuccess`, nên mỗi phiên chỉ có một chủ. Từ 2.1 tới khi xong 2.2/2.3 có một trạng thái tạm: lần sai 5–9 chưa phải chờ, lần thứ 10 chặn đăng nhập nhưng chưa xóa dữ liệu (fail closed).

## Verification

**Commands:**
- `cd pak_manager && flutter gen-l10n` -- expected: chạy lần hai không đổi file nào trong `lib/l10n/` (CI kiểm lệch)
- `cd pak_manager && flutter analyze --fatal-infos --fatal-warnings` -- expected: sạch
- `cd pak_manager && dart run tool/check_imports.dart` -- expected: không vi phạm (core/guard thuần Dart)
- `cd pak_manager && flutter test` -- expected: tất cả pass, số test tăng, không thêm skip
