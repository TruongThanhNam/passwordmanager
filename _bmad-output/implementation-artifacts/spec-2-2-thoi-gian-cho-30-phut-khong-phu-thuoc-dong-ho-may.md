---
title: 'Story 2.2: Thời gian chờ 30 phút không phụ thuộc đồng hồ máy'
type: 'feature'
created: '2026-11-21'
status: 'done'
route: 'dispatch'
review_loop_iteration: 1
baseline_commit: '16632cb34188d318aaa713b803b216799bf9a66d'
context:
  - '{project-root}/_bmad-output/implementation-artifacts/epic-2-context.md'
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** Sau story 2.1, lần sai 5–9 vẫn thử lại được ngay, nên kẻ dò chỉ cần 10 lần liên tiếp. S3 cũng chưa có trạng thái chờ hay đồng hồ đếm ngược (FR-4 lần 5–9, FR-6, TC-3).

**Approach:** Thêm mốc chờ `(bootId, monotonicMs)` vào máy trạng thái `core/guard` và vào `LockoutGuard` (nhận `ClockPort`). Mốc được ghi cùng lần ghi trước KDF khi `failCount` mới nằm trong 5–9, và được neo lại khi khởi động lại máy hoặc đồng hồ đơn điệu lùi. `AccountService` từ chối lần thử khi đang chờ. S3 vô hiệu ô và nút, hiện `login.lockout` đếm ngược từng giây.

## Boundaries & Constraints

**Always:**
- Đang chờ = `failCount` 5–9, có đủ cặp mốc, và còn lại = `waitDuration − (nowMono − waitStartMono)` > 0. Còn lại luôn nằm trong `[0, 30 phút]`. Mọi phép đo dùng `ClockPort.monotonicMs` + `bootId`; không `DateTime.now()`, không `Stopwatch`.
- `recordAttempt()`: `failCount` mới trong 5–9 → đọc đồng hồ, đặt mốc = bây giờ trong **cùng một lần ghi**. Đọc đồng hồ lỗi → trả `false` (`UnlockUnavailable`), không ghi, không KDF. `failCount` mới 1–4 hoặc 10 thì không đọc đồng hồ.
- Neo lại (pure, trong `core/guard`): `failCount` 5–9 và (mốc thiếu hoặc nửa vời, `waitBootId` ≠ `bootId` hiện tại, hoặc `nowMono < waitStartMono`) → mốc = bây giờ. Áp ở `normalize(hasAccount: true)`, theo đúng thứ tự AD-8 (2) rồi (3), ghi xuống đĩa và `await` xong trước khi `bootstrap` trả kết quả. Ghi lỗi thì RAM vẫn mang mốc mới (chỉ kéo dài, không rút ngắn).
- `LockoutGuard.waitRemaining()` → `Future<Duration>`, không ném: ngoài 5–9 → `Duration.zero`, không đọc đồng hồ; đọc đồng hồ lỗi → `waitDuration` (fail closed); cần neo lại → cập nhật RAM, ghi (bỏ qua lỗi), rồi tính.
- `unlock`: sau kiểm hết lượt, trước `recordAttempt()`: `waitRemaining() > 0` → `UnlockLockedOut`, không ghi, không KDF. `UnlockLockedOut` từ nay nghĩa là "không được thử lúc này" (đang chờ hoặc hết lượt).
- `AccountService.lockoutRemaining()` → `Future<Duration>` là nguồn đếm ngược duy nhất cho UI. Features không import `core/guard`, `LockoutGuard` hay `ClockPort`.
- S3 hỏi `lockoutRemaining()` khi mở màn và sau mỗi kết quả `unlock` (trừ `UnlockSuccess`/`UnlockBusy`). Còn lại > 0: ô (`enabled: false`, icon `ink-disabled` sẵn có) và nút vô hiệu, ô giữ nội dung, dòng `login.lockout` thay chỗ `login.wrong` và nằm trên `login.attempts`. Một `Timer` 1 giây hỏi lại và cập nhật; về 0 thì hủy timer, bỏ `login.lockout`, về idle (chỉ còn `login.attempts`). `dispose` hủy timer.
- `{mm:ss}` làm tròn lên theo giây, 2 chữ số mỗi phần: vừa bắt đầu hiện `30:00`, giây cuối hiện `00:01`. ARB: `loginLockout` có tham số `time` (String); VI "Thử lại sau {time}", EN "Try again in {time}" (EXPERIENCE.md, không dấu chấm cuối).

**Never:**
- Không đổi schema hay codec `guard`, không đổi fixture golden. Không thêm provider. Không truyền service qua constructor widget.
- Chưa xóa dữ liệu ở lần 10, chưa `wiping`/`WipeCoordinator` (2.3), chưa nút "Xóa & Tạo tài khoản mới" (2.4).
- Không bao giờ rút ngắn thời gian chờ: không có nhánh nào đặt mốc về quá khứ hay xóa mốc khi `failCount` còn 5–9, trừ `recordSuccess()`.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Lần sai thứ 5 | failCount 4, sai | Đĩa có `failCount: 5` + mốc (boot, mono) trước KDF; `lockoutRemaining` = 30:00 | đồng hồ lỗi → `UnlockUnavailable`, failCount giữ 4 |
| Thử khi đang chờ | failCount 5, mới qua 10 phút | `UnlockLockedOut`, không ghi, không KDF | N/A |
| Hết giờ | qua đủ 30 phút | `lockoutRemaining` = 0; lần thử kế đếm lên 6, đặt mốc mới | N/A |
| Tắt app, mở lại | cùng boot, đã qua 12 phút | `bootstrap` không ghi; còn 18:00 | N/A |
| Chỉnh đồng hồ máy | wall clock nhảy +1 giờ, mono +1 phút | còn 29:00 (không có đầu vào wall clock nào) | N/A |
| Khởi động lại máy | `bootId` khác | `bootstrap` ghi mốc mới; còn 30:00 | ghi lỗi → RAM vẫn 30:00 |
| Mono lùi | `nowMono < waitStartMono` | như khởi động lại | như trên |
| Thiếu / nửa vời mốc | failCount 7, một hoặc cả hai trường mốc null | `bootstrap` neo mốc = bây giờ, còn 30:00 | như trên |
| Đúng sau khi chờ | hết giờ, mật khẩu đúng | mốc bị xóa, failCount 0 | N/A |
| Lần 10 | failCount 9, hết giờ, sai | failCount 10, không đọc đồng hồ, `lockoutRemaining` = 0, `UnlockLockedOut` lần sau | N/A |
| Đồng hồ lỗi lúc chờ | failCount 6, `monotonicMs` ném | `lockoutRemaining` = 30:00, `unlock` → `UnlockLockedOut` | không ném |

</frozen-after-approval>

## Code Map

- `pak_manager/lib/core/guard/guard_state.dart` -- thêm `inWaitRange` (5–9), `withWaitMark(bootId, mono)`, `reanchored(bootId, nowMono)` → `GuardState?` (`null` = không đổi), `waitRemaining(nowMono)` → `Duration`. Giữ `afterAttempt()`/`afterSuccess()` như cũ; sửa doc comment "Story 2.2 dùng".
- `pak_manager/lib/services/lockout_guard.dart` -- constructor thêm `required ClockPort clock`. `normalize` :57 (sửa comment "Story 2.2 thêm…"), `recordAttempt` :96. Giữ cơ chế `_write`/`_readCapped`, giữ quy tắc RAM chỉ đổi khi ghi thành công ở `recordAttempt`.
- `pak_manager/lib/services/account_service.dart` -- `unlock`/`_unlock` :308-390, chèn kiểm chờ sau `exhausted` :339; doc `UnlockLockedOut` :109; thêm `lockoutRemaining()` cạnh `attemptsLeft` :170; doc `unlock` :293.
- `pak_manager/lib/main.dart` -- `_wireAccount` (:141) nhận thêm `clock` từ `runPakApp`, truyền vào `LockoutGuard` (:172).
- `pak_manager/lib/features/auth/login_screen.dart` -- `_UnlockMessage` :29, `_submit` :88, `_s3` :174. Cần `initState` để hỏi lần đầu; `_canSubmit` :79 thêm điều kiện không đang chờ.
- `pak_manager/lib/l10n/app_{vi,en}.arb` -- thêm `loginLockout`, mô tả `login.lockout (FR-4)`; chạy `flutter gen-l10n`.
- `pak_manager/test/support/port_fakes.dart` -- `FakeClock` :47: thêm `String boot = 'fake-boot'` và `Object? bootError` cho `bootId()`. Không chép fake inline.
- `pak_manager/test/support/account_fakes.dart` -- `FakeAccountService` thêm `Duration lockout = Duration.zero` (đặt tay) và `lockoutRemaining()`.
- Mọi chỗ dựng `LockoutGuard` trong test: `test/services/lockout_guard_test.dart:62`, `test/services/account_service_test.dart:169,693,726,756,812,965`. Thêm `clock: FakeClock()`.

## Tasks & Acceptance

**Execution:**
- [x] `pak_manager/lib/core/guard/guard_state.dart` -- transition thuần cho mốc chờ -- AD-8 thuần, test không cần I/O.
- [x] `pak_manager/lib/services/lockout_guard.dart` -- nhận `ClockPort`; đặt mốc trong `recordAttempt`, neo lại trong `normalize`, thêm `waitRemaining()` -- chủ duy nhất của `guard`.
- [x] `pak_manager/lib/services/account_service.dart` -- kiểm chờ trong `unlock`, `lockoutRemaining()` -- ranh giới cho UI.
- [x] `pak_manager/lib/main.dart` -- nối `clock` vào `LockoutGuard`.
- [x] `pak_manager/lib/features/auth/login_screen.dart` + 2 ARB -- trạng thái chờ và đếm ngược; chạy `flutter gen-l10n`.
- [x] `pak_manager/test/support/{port_fakes,account_fakes}.dart` -- fake như Code Map.
- [x] `pak_manager/test/core/guard/guard_state_test.dart` -- `withWaitMark`, `reanchored` (mỗi điều kiện, ngoài 5–9 trả `null`), `waitRemaining` (biên 0, 30:00, mono lùi chưa neo).
- [x] `pak_manager/test/services/lockout_guard_test.dart` -- các dòng Matrix ở mức guard: mốc ghi cùng lần ghi trước KDF (đọc file), tắt app = dựng guard mới trên cùng thư mục, reboot = đổi `FakeClock.boot`, mono lùi, đồng hồ lỗi, crash ở từng `AtomicWriteStep` khi neo lại.
- [x] `pak_manager/test/services/account_service_test.dart` -- lần 5 đặt mốc trước KDF (đọc file trong `derive`), `UnlockLockedOut` khi chờ không gọi `derive` và không đếm `rename`, hết giờ thì thử được.
- [x] `pak_manager/test/features/auth/login_screen_test.dart` -- ô và nút vô hiệu, `login.lockout` nằm trên `login.attempts`, `30:00` → `29:59` sau `pump(1s)`, về idle khi 0, timer bị hủy khi rời màn.

**Acceptance Criteria:**
- Given `lib/`, when grep `DateTime.now\|Stopwatch` trong `core/guard` và `lockout_guard.dart`, then không có kết quả; features không import `ClockPort`/`core/guard`; `check_imports` OK.
- Given test mới, when đọc tên, then mỗi tên bắt đầu bằng id thật đệm 2 chữ số (`fr04_`, `fr06_`, `tc03_`, `ad08_`, `ad09_`, `ux_dr21_`, `ux_dr42_`).
- Given S3 ngay sau lần sai thứ 5 (VI), when hiển thị, then thấy "Thử lại sau 30:00" ở trên "Còn 5 lần thử trước khi dữ liệu bị xóa.", ô và nút vô hiệu; hết giờ thì chỉ còn dòng số lần thử và nút bật lại khi ô đủ điều kiện.

### Review Findings

Code review 2026-11-21 (`bmad-code-review`, diff `16632cb..2da130e`): blind-hunter, edge-case-hunter, verification-gap, acceptance-auditor; không lớp nào lỗi. 24 phát hiện: 1 decision (chọn hướng a, thành patch), 7 patch (gom thành 6 mục), 1 defer, 15 bác. Sau patch: `flutter analyze --fatal-infos --fatal-warnings` sạch, `check_imports` OK, `flutter test` 979 pass, 18 skip, 0 fail (một lần chạy khác fail 1 test teardown errno 145, `DW-2.1-1`).

- [x] [Review][Patch] Mật khẩu đang hiện bị kẹt trên màn suốt 30 phút chờ — `SecretField` tắt nút mắt khi `enabled: false` và không đặt lại `_obscured`; chuỗi vừa nhập (thường gần đúng mật khẩu thật) nằm rõ trên màn tới khi hết giờ. Quyết định 2026-11-21 (namtruong): hướng (a), `SecretField` tự che lại khi `enabled` chuyển `false`, giữ nội dung đúng spec; không xóa ô theo mock [pak_manager/lib/features/shared/secret_field.dart:134]
- [x] [Review][Patch] Doc `unlock` vẫn ghi "[UnlockLockedOut] (không ghi, không KDF)", lệch doc lớp `UnlockLockedOut` (có thể ghi mốc neo lại) [pak_manager/lib/services/account_service.dart:307]
- [x] [Review][Patch] Không test nào kiểm nhịp thứ hai trở đi của timer: đổi `Timer.periodic` thành `Timer` một lần (đông cứng ở 29:59) mà mọi test vẫn qua. Thêm bước 29:58 và `lockoutQueries == 3` vào `fr04_ux_dr42_lockout_counts_down_every_second` [pak_manager/test/features/auth/login_screen_test.dart:450]
- [x] [Review][Patch] Vào chờ qua `_submit` (lần sai thứ 5) không có test nào cho thời gian chạy tiếp: bỏ `_applyLockout` trong `_submit` thì đông cứng ở 30:00 mà test vẫn qua; nửa sau AC3 (hết giờ → nút bật lại khi ô vẫn giữ mật khẩu hợp lệ, không gõ thêm) chưa được kiểm trên đường này (verification-gap + acceptance-auditor) [pak_manager/test/features/auth/login_screen_test.dart:420]
- [x] [Review][Patch] `FakeClock.reads` chỉ đếm `monotonicMs()`, nên các assert "không đọc đồng hồ" bỏ lọt `bootId()` (`ad08_normalize_without_account_never_reanchors`, `ad08_wait_query_outside_range_never_reads_clock`, lần 9→10). Thêm bộ đếm `bootReads` và assert nó [pak_manager/test/support/port_fakes.dart:47]
- [x] [Review][Patch] Chưa test phục hồi sau khi đồng hồ lỗi lúc `normalize`: Implementation Notes hứa neo lại ở lần đọc thành công kế tiếp, nhưng `ad08_normalize_clock_failure_keeps_mark_without_write` dừng ở 30:00. Nối thêm: hết lỗi → `waitRemaining` ghi mốc, tiến 1 phút → 29:00 [pak_manager/test/services/lockout_guard_test.dart:476]
- [x] [Review][Patch] Assert bàn phím trong `fr04_ux_dr42_lockout_on_open_disables_field_and_button` không chứng minh gì: ô chưa focus nên `receiveAction` gửi client `-1` và bị bỏ qua. Xóa hai dòng đó (nút và ô vô hiệu đã được assert) [pak_manager/test/features/auth/login_screen_test.dart:402]
- [x] [Review][Defer] Guard cũ sót lại khi mất `header` làm tài khoản mới tạo bị chờ 30:00 ngay ở S3 [pak_manager/lib/services/lockout_guard.dart:75] — deferred: có từ trước (DW-2.1-2); story 2.2 mở rộng hậu quả từ "ít lượt hơn" sang "bị chờ 30 phút", ghi thành DW-2.2-1

**Bác (rejected):**

- blind: ô giữ nội dung lệch mock (ô trống) — sửa là sửa dòng Always frozen; đưa vào làm hướng (b) của mục Decision.
- blind + edge-case: `bootId` chập chờn lúc chạy (`""` ↔ id thật) làm mỗi nhịp 1 giây neo lại và ghi đĩa, chờ vô hạn — có thật về logic (Design Notes "không bao giờ treo vô hạn" chỉ đúng khi `bootId` ổn định), nhưng `Settings.Global.BOOT_COUNT` đọc qua cache, gần như không lỗi chập chờn; sửa cần cache `bootId` theo process, tức thêm trạng thái và nhánh. Low, hiếm.
- blind: `GuardState.waitRemaining(nowMono)` không so `bootId`, gọi thiếu `reanchored` thì rút ngắn — caller duy nhất (`LockoutGuard.waitRemaining`) luôn neo lại trước trong cùng tác vụ `_serial`; sửa là thêm tham số.
- blind: các mục bác ở vòng 1 không có trong `deferred-work.md` — mục bị bác là hành vi chủ ý, không phải việc hoãn.
- blind: frontmatter spec lệch (`status`, `review_loop_iteration`, Spec Change Log trống) — sửa là sửa spec; bước 6 của review này đặt lại `status`.
- blind: không có bằng chứng chạy lại test sau patch vòng 1 — quy trình, không hại code; CI của PR cung cấp bằng chứng.
- blind: timer 1 giây không theo vòng đời app — chỉ là một lời gọi Pigeon đồng bộ mỗi giây khi ở nền; thêm `WidgetsBindingObserver` là thêm nhánh.
- blind: trình đọc màn hình không được báo đếm ngược — EXPERIENCE.md:328 ghi spine không yêu cầu bổ sung ngữ nghĩa; `login.wrong` có sẵn cũng vậy.
- blind: `lockoutClock`/`lockoutTick` public trong file màn hình — cùng kiểu với `loginTitleTop` có sẵn; không có hại cụ thể.
- edge-case: `UnlockCorrupt` sau lần thử đã đếm (KDF lỗi) ở 5–9 bị đếm ngược che mất — chỉ xảy ra khi KDF lỗi sau khi đọc `header` thành công (story 2.5 tách riêng); sửa cần quyết định UX và thêm nhánh.
- edge-case: `bootId` `""` ở cả hai lần khởi động thì chờ sau reboot ngắn hơn 30:00 tính lại — đã bác ở vòng 1 (#6): tổng thời gian thật vẫn ≥ 30 phút.
- acceptance: nhập lại đúng chuỗi sai trước khi đang chờ trả `UnlockWrongPassword` — UI không với tới (ô vô hiệu); FR-5 yêu cầu báo sai ngay khi trùng chuỗi trước.
- acceptance: nhánh từ chối khi chờ có thể ghi đĩa, trái "không ghi" — spec tự mâu thuẫn với dòng `waitRemaining` (bắt ghi khi neo lại); sửa là sửa spec. Phần doc code nằm ở mục Patch đầu tiên.
- acceptance: đồng hồ lỗi lúc khởi động thì không ghi mốc trước S3 — Implementation Notes chấp nhận (fail closed 30:00, neo lại sau); sửa là sửa intent.

## Implementation Notes

- `LockoutGuard` thêm hàng đợi nội bộ (`_serial`) cho `normalize`, `waitRemaining`, `recordAttempt`, `recordSuccess`. Lý do: S3 hỏi `lockoutRemaining()` khi mở màn và theo timer, nên có thể chạy chồng với `unlock`. Không có hàng đợi thì `waitRemaining` có thể neo lại từ trạng thái cũ, ghi đè số lần sai vừa tăng, hoặc ghi cùng file tạm với `recordAttempt`. `_write`/`_readCapped` giữ nguyên. Test: `ad08_wait_query_waits_for_pending_attempt`.
- `normalize(hasAccount: true)` đọc đồng hồ lỗi thì giữ nguyên mốc và không ghi; `waitRemaining()` neo lại ở lần đọc đồng hồ thành công kế tiếp, còn trong lúc đó trả 30:00 (fail closed).
- `GuardState.waitRemaining(nowMono)` trả `waitDuration` khi mốc thiếu hoặc `nowMono` nhỏ hơn mốc, đúng giá trị sau khi neo lại; `LockoutGuard` luôn neo lại trước khi tính.
- Test service/guard đặt `FakeClock` ở 10 giờ, vì codec từ chối `waitStartMono` âm khi dựng mốc cũ trước thời điểm hiện tại.

## Spec Change Log

## Review Triage Log

Review vòng 1 (2026-11-21): blind-hunter, edge-case-hunter, verification-gap; không lớp nào lỗi. Trước review: `flutter test` 977 pass, 18 skip, 0 fail.

| # | Nguồn | Phát hiện | Verdict | Bằng chứng | Route |
|---|---|---|---|---|---|
| 1 | verification-gap | Không test nào chứng minh `_submit` chờ `lockoutRemaining()` rồi mới vẽ; quay về hai `setState` thì chớp "Sai mật khẩu." mà test vẫn qua | low | Đến từ lớp verification-gap (đã kiểm sẵn): fake trả trong cùng microtask nên `pump()` chỉ thấy trạng thái cuối | patch |
| 2 | verification-gap (khác) | Nhánh `wasLocked → _message = null` trong `_applyLockout` là code chết | low | Đúng: vào trạng thái chờ đã xóa `_message`; khi đang chờ thì ô vô hiệu, `_submit` không chạy, nên `_message` luôn null lúc hết chờ. Sửa = xóa | patch |
| 3 | blind | Doc `recordSuccess` ("RAM đổi ngay") và `UnlockLockedOut` ("Không ghi") lệch code | low | Đúng: `_state` đổi trong `_serial`; `waitRemaining()` có thể ghi mốc neo lại trước khi trả `UnlockLockedOut` | patch |
| 4 | blind | Tên `tc03_ad08_reboot_while_running_…` mô tả việc không xảy ra được | low | Đúng: process không sống qua reboot; test thật ra phủ `bootId` đổi giữa hai lần đọc lúc chạy. Sửa = đổi tên | patch |
| 5 | blind | `tc03_ad09_only_monotonic_time_counts` không có đồng hồ tường để chỉnh | low | Lớp đúng không có đầu vào đồng hồ tường nào (AC grep `DateTime.now`/`Stopwatch` rỗng); test vẫn chứng minh chỉ mono quyết định. Đề xuất cổng tĩnh kiểu `check_imports` là thêm công cụ | reject |
| 6 | edge-case, blind | `bootId` rỗng (`""` khi không đọc được) coi như cùng lần khởi động, nên reboot không làm chờ lại từ 30:00 nếu mono sau reboot lớn hơn mốc | low | Có thật, nhưng hiếm: `BOOT_COUNT` có từ API 24 = `minSdk`, iOS có `kern.bootsessionuuid`. Thời gian chờ thật không bao giờ dưới 30 phút, vì `nowMono ≥ mốc + 30 phút` đòi ít nhất 30 phút uptime sau reboot. Sửa bằng cách coi `""` là reboot thì neo lại ở mọi lần hỏi, làm chờ vô hạn; cần trạng thái mới. Epic 7 kiểm `bootId` trên máy thật | reject |
| 7 | edge-case, blind | Đồng hồ lỗi mãi thì S3 đứng ở "Thử lại sau 30:00", không giải thích | low | Đúng hành vi frozen Always (fail closed) và Design Notes (lối thoát là 2.4); sửa là sửa intent | reject |
| 8 | edge-case | Đồng hồ lỗi ở lần 5 ra `UnlockUnavailable`, khi đang chờ ra `UnlockLockedOut`, không nhất quán | false | Cả hai đúng Matrix frozen (dòng "Lần sai thứ 5" và "Đồng hồ lỗi lúc chờ") | reject |
| 9 | edge-case, blind | Lời gọi Pigeon đồng hồ treo thì hàng đợi `_serial` và spinner Login treo theo | low | `bootId`/`monotonicMs` là lời gọi native đồng bộ (`elapsedRealtime`, `sysctlbyname`), không có I/O để treo; thêm timeout là thêm nhánh | reject |
| 10 | edge-case, blind | Timer 1 giây chạy chồng khi lần hỏi trước chưa xong; không căn theo giây nên có thể nhảy hoặc lặp một giây | low | Chỉ khi một lần hỏi lâu hơn 1 giây (không thực tế); phần lẻ của thời gian còn lại cố định trong phiên, jitter vài ms nên xác suất nhảy giây < 1%. Sửa cần cờ hoặc lịch one-shot | reject |
| 11 | edge-case | `monotonicMs` âm thì mốc âm bị codec từ chối, lần sau `failCount` về 0 | low | Không với tới: `elapsedRealtime` và `mach_continuous_time` không âm; sửa là thêm guard cho trạng thái chưa chứng minh được | reject |
| 12 | blind | S3 không fail closed ở frame đầu: `_lockout` = 0 cho tới khi lần hỏi đầu xong | low | Đúng: ô bật trong 1–2 frame khi mở S3 lúc đang chờ; service vẫn từ chối (`UnlockLockedOut`). Đoán trước theo `attemptsLeft` lại gây chớp ngược lúc hết chờ; AC "ghi trước khi hiện S3" nói về `bootstrap`, đã đạt | reject |
| 13 | blind | Chờ đã hết vẫn bị tính lại 30:00 sau reboot | low | Đúng AD-8 bước (3) và frozen Always; không phân biệt được mốc đã hết hạn qua hai lần khởi động mà không đổi schema `guard` (Never) | reject |
| 14 | blind | `recordAttempt` không tự kiểm chờ; kiểm và ghi là hai thao tác riêng | low | Chỉ `AccountService.unlock` gọi `recordAttempt`, đúng thứ tự Always; giữa hai thao tác không gì đổi được `failCount`. Đây là refactor | reject |
| 15 | blind | Patch thiếu file l10n sinh, spec, sprint-status | false | Chủ ý như story 2.1; đã chạy lại `gen-l10n`, không đổi file nào | reject |
| 16 | verification-gap (khác) | `ValueKey('login.lockout')` không test nào dùng | low | Không có hại cụ thể; key vô hại | reject |

## Design Notes

Neo lại dùng chung một hàm thuần cho `normalize` và `waitRemaining`, nên mốc hỏng (reboot, mono lùi, thiếu) luôn được sửa theo một luật, kể cả khi `bootId` đọc chập chờn lúc chạy: thời gian chờ chỉ bị kéo dài, không bao giờ treo vô hạn. Mốc đã hết hạn không bị xóa: lần thử kế tiếp ghi đè. Mốc đặt ở thời điểm ghi trước KDF (sớm hơn kết quả sai khoảng 1 giây) là chấp nhận được và đúng AD-8. Đồng hồ hỏng vĩnh viễn thì người dùng kẹt ở trạng thái chờ (fail closed); lối thoát là "Xóa & Tạo tài khoản mới" của 2.4.

## Verification

**Commands:**
- `cd pak_manager && flutter gen-l10n` -- expected: chạy lần hai không đổi file trong `lib/l10n/`
- `cd pak_manager && flutter analyze --fatal-infos --fatal-warnings` -- expected: sạch
- `cd pak_manager && dart run tool/check_imports.dart` -- expected: không vi phạm
- `cd pak_manager && flutter test` -- expected: tất cả pass (trừ lỗi teardown `DW-2.1-1` đã biết), số test tăng, không thêm skip
