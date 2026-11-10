---
title: 'Story 1.9 — Tự khóa khi chạy nền và giới hạn phiên'
type: 'feature'
created: '2026-11-10'
status: 'done'
baseline_commit: '322714046fc52c30ef44577dfe8e01abadbe6a3d'
route: 'dispatch'
review_loop_iteration: 0
context:
  - '{project-root}/_bmad-output/implementation-artifacts/epic-1-context.md'
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** Vault chỉ khóa khi bấm "Khóa Vault"; quên khóa thì DEK nằm trong RAM mãi, kể cả khi app chạy nền hay phiên kéo dài (FR-14, FR-15, FR-16; `epics.md:708`).

**Approach:** `SessionController` nhận `ClockPort` và nguồn giới hạn từ `SettingsStore`, giữ mốc đăng nhập và mốc vào nền (đều theo `monotonicMs`), `evaluate()` khóa khi một trong hai hạn đã qua; `Timer` chỉ đánh thức `evaluate()`. Gate chuyển `AppLifecycleState` thành `enteredBackground()`/`evaluate()` và lấy controller qua provider factory do `main.dart` nối.

## Boundaries & Constraints

**Always:**
- Nguồn sự thật duy nhất là `ClockPort.monotonicMs()`; không `Stopwatch`/`DateTime.now()` trong controller. `Timer` (qua tham số factory để test thay được) chỉ gọi `evaluate()`.
- `enter(session)`: chụp `sessionMin` hiện tại, đọc clock, đặt hạn phiên = mốc + `sessionMin`; hẹn timer. Đọc clock xong mà epoch đã đổi thì bỏ.
- Vào nền = lần đầu `hidden` (hoặc `paused`) sau `resumed`; `inactive` không tính; gate theo dõi cờ này. `enteredBackground()` chụp `autolockMin` hiện tại và mốc nền; hẹn timer.
- `resumed` → `evaluate()`; nếu không khóa thì xóa mốc nền (giữ nguyên màn hình/state).
- `evaluate({foreground})`: đọc clock; epoch đổi trong lúc chờ thì bỏ; `now ≥ hạn phiên` hoặc `now - mốc nền ≥ autolock` → `lock(foreground: ...)`. Gọi từ `resumed` là tiền cảnh; gọi từ timer khi đang ở nền là `foreground: false`. Clock lùi so với mốc (máy khởi động lại) → khóa (fail closed). Đọc clock ném lỗi → khóa.
- Thay đổi `SettingsStore` không ảnh hưởng lần đếm đang chạy; chỉ lần chụp kế tiếp.
- Khóa vẫn đi qua trình tự 1.8 (chờ op ghi đang chạy). Khóa/`dispose` hủy mọi timer.
- Provider `sessionControllerFactoryProvider` (`SessionController Function()`, mặc định `SessionController.new` không clock = không tự khóa) trong `providers.dart`; `main.dart`/`runPakApp` nối `ClockPort` + `() => settings.current`. Features không import `core/ports`.
- Tên test gắn FR/AD; chỉ fake tự viết (fake clock, fake timer).

**Never:** không cảnh báo trước khi khóa; không state restoration; không picker cài đặt (Epic 5); không đổi trình tự khóa của 1.8; không dùng `bootId` ở story này.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected | Error Handling |
|----------|---------------|----------|----------------|
| Quay lại kịp | nền 2:59, autolock 3 | không khóa, giữ state | — |
| Quay lại trễ | nền 3:00 | `resumed` → khóa tiền cảnh, S3 | — |
| Hết phiên khi đang dùng | 10:00 từ `enter` | timer → khóa, không cảnh báo | — |
| Hai điều kiện | phiên hết trước autolock | khóa theo cái đến trước | — |
| `inactive` | resumed → inactive → resumed | không phải vào nền | — |
| Đổi cài đặt giữa chừng | `sessionMin` 10 → 1 sau `enter` | hạn vẫn 10 | — |
| Ghi đang chạy | op chậm khi hết hạn | khóa sau khi op xong | — |
| Clock lùi / lỗi | now < mốc, hoặc throw | khóa | fail closed |
| OS kill ở nền | mở lại | S3 | không restoration |

</frozen-after-approval>

## Code Map

- `pak_manager/lib/services/session_controller.dart` -- thêm `clock`, `limits` (`Settings Function()`), `timerFactory`, `enteredBackground()`, `evaluate()`, hủy timer trong `_runLock`/`dispose`. Giữ nguyên trình tự `_runLock`, `lock` gọi chồng, `isCurrent`.
- `pak_manager/lib/core/ports/clock_port.dart` -- tái dùng, không đổi. `PigeonPlatformPorts` (`lib/platform/pigeon_ports.dart`) đã cài `ClockPort`.
- `pak_manager/lib/core/model/settings.dart:81-94` -- `autolockMin`/`sessionMin` (mặc định 3/10).
- `pak_manager/lib/features/shared/providers.dart` -- thêm `sessionControllerFactoryProvider`.
- `pak_manager/lib/features/shared/session_gate.dart` -- `_controller` lấy từ factory trong `initState`; đã là `WidgetsBindingObserver` → thêm `didChangeAppLifecycleState` (cờ `_resumedSinceBackground`).
- `pak_manager/lib/main.dart:34,51,90` -- `runPakApp` thêm `required ClockPort clock`; override factory dùng `settings` đã nạp. `test/app_test.dart:48,440,483,515,525` gọi `runPakApp` → truyền fake clock.
- `pak_manager/test/support/account_fakes.dart` -- thêm `FakeClock` (ms đặt tay), `FakeTimers`; `pumpGateApp` nhận factory tùy chọn.

## Tasks & Acceptance

**Execution:**
- [x] `lib/services/session_controller.dart` -- đo hạn, `evaluate`, `enteredBackground`, timer -- FR-14/15, AD-8/9.
- [x] `lib/features/shared/providers.dart`, `session_gate.dart` -- factory + lifecycle -- FR-16.
- [x] `lib/main.dart`, `test/app_test.dart` -- nối clock + settings.
- [x] `test/support/account_fakes.dart` -- `FakeClock`, `FakeTimers`.
- [x] `test/services/session_controller_test.dart` -- mọi dòng I/O Matrix bằng fake clock (trừ OS kill).
- [x] `test/features/shared/session_gate_test.dart` -- hidden/paused/inactive → đúng mốc; resumed trễ → S3, resumed kịp → giữ tab/route; OS kill → S3 (pump mới với `BootstrapHasAccount`).

**Acceptance Criteria:**
- Given `lib/services/session_controller.dart`, then không có `Stopwatch`, `DateTime.now` hay `dart:io`.
- Given toàn repo, then `flutter analyze --fatal-infos --fatal-warnings` 0 issue và `dart tool/check_imports.dart` exit 0.


### Review Findings

- [x] [Review][Patch] Thiếu test: `resumed` vô hiệu `_markBackground` đang treo (giữ clock trong `enteredBackground()`, gọi `evaluate(resumed: true)`, nhả clock, tiến quá `autolockMin` → không khóa). Xóa `_backgroundGen++` hiện không test nào bắt được [pak_manager/test/services/session_controller_test.dart]
- [x] [Review][Patch] Gate dựng khi `lifecycleState == inactive` (đang tiền cảnh) đặt `_resumedSinceBackground = false` → vào phiên ghi mốc nền dù user đang dùng; thêm `inactive` vào điều kiện + test [pak_manager/lib/features/shared/session_gate.dart:93]
- [x] [Review][Patch] Matrix "Hai điều kiện" chỉ test hạn phiên đến trước; thêm case hạn nền đến trước khi có hạn phiên [pak_manager/test/services/session_controller_test.dart]
- [x] [Review][Defer] Không che màn hình khi `hidden`/ảnh app-switcher và 1 frame HomeShell trước khi khóa lúc `resumed` [pak_manager/lib/features/shared/session_gate.dart:102] — deferred: ngoài phạm vi 1.9, cần story riêng về privacy screen

**Rejected:**
- `false`: Đồng hồ dừng khi ngủ sâu: native dùng `SystemClock.elapsedRealtime()` / `mach_continuous_time`, vẫn đếm khi máy ngủ.
- `false`: Không kiểm tra `sessionMin`/`autolockMin` ≤ 0: `settings_codec` chỉ nhận 1|3|5|10.
- `false`: `lock()` ở nhánh lỗi clock thiếu kiểm `_session == null`: `lock()` tự trả về khi `_session == null`.
- `false`: `inactive → resumed` làm mất mốc nền đang treo: không có `hidden` thì không có mốc nào đang treo; còn `hidden → inactive → resumed` vô hiệu mốc là đúng ý.
- `false`: Launch thẳng vào nền với lifecycle `null`: không có UI đăng nhập nên không có phiên nào để tính.
- `low`: Default `SessionController.new` không tự khóa: spec chủ đích (AD-8, test `ad8_*`), `main.dart` đã nối.
- `low`: Bỏ qua `detached`: spec quy định; engine detach thì process sắp bị kill (FR-16).
- `low`: Khóa từ timer/nhánh lỗi chạy với `foreground:false` bỏ xóa clipboard: hook clipboard hiện là no-op (cùng triage #9).
- `low`: Timer được hẹn lại trong lúc `_runLock` await hook: `finally` gọi `_resetTiming()` hủy timer; nhánh đổi phiên giữa lúc khóa không xảy ra từ UI.
- `low`: `fr16_os_kill_reopens_at_s3` tautological; `ad8_without_clock_never_autolocks` yếu; thiếu e2e FR-15 qua `runPakApp`; thiếu test gate cho `paused`-only (cùng code path, triage cũ đã bác); write đang chạy khi hết hạn nền: chung `_runLock` đã test.
- `low`: Lệch status spec `done` và sprint `review`: được đồng bộ ở bước cập nhật trạng thái của review này.

## Implementation Notes

- `evaluate` có thêm cờ `resumed` (chỉ `resumed` mới xóa mốc nền, và chỉ khi `_backgroundGen` không đổi trong lúc chờ clock) để lần resumed cũ không xóa mốc nền mới.
- `SessionController` là `final class`: test gate đếm số lần đọc `limits` để xác nhận vào nền đúng một lần; OS kill mô phỏng bằng pump lại app với `BootstrapHasAccount`.
- `ad9_clock_result_after_epoch_change_is_dropped` yếu: fake clock trả ngay.

## Spec Change Log

## Review Triage Log

Review 2026-11-10 (diff `3227140..` cây làm việc; 3 lớp: blind (B), edge (E), verif-gap (V)).

| # | Nguồn | Phát hiện | Verdict | Bằng chứng | Route |
|---|-------|-----------|---------|------------|-------|
| 1 | E, B | Phiên vào khi app đã ở nền (KDF xong sau khi rời app) không có mốc nền; gate giả định khởi động ở tiền cảnh | medium | `hidden` đến khi chưa có phiên làm cờ gate thành false, `enteredBackground` no-op; `enter` reset timing → chỉ còn hạn phiên | patch |
| 2 | B | Resumed nhanh không vô hiệu `_markBackground` còn chờ → mốc nền cũ ghi ở tiền cảnh | low | chỉ xảy ra nếu clock trả lệch thứ tự; sửa một dòng (`_backgroundGen++`) | patch |
| 3 | V, B | Nối factory trong `runPakApp` không có test; bỏ override thì mất autolock mà suite vẫn xanh | medium | `app_test` chỉ truyền `FakeClock()`, không test nào tiến clock | patch |
| 4 | V, E, B | Test bỏ kết quả clock sau đổi epoch không quan sát được race | low | FakeClock trả ngay; xóa guard test vẫn pass | patch |
| 5 | V | Clock lùi dưới mốc nền chưa có test riêng | low | `ad8_clock_backwards_fails_closed` chỉ chạm nhánh `enteredAt` | patch |
| 6 | B | Đổi `autolockMin` khi đang ở nền chưa có test | low | dòng matrix chỉ test `sessionMin` | patch |
| 7 | B | `FakeClock.error` kiểu `Error?` | low | không mô phỏng được `PlatformException` | patch |
| 8 | B | Tên test `fr16_settings_change...` gắn sai FR | low | quy tắc chụp cài đặt là FR-14/15 | patch |
| 9 | B, E | Timer và resumed chạy chồng → khóa `foreground:false` bỏ xóa clipboard | low | hook clipboard hiện no-op; sửa cần nâng cấp foreground cho lock đang chạy (thêm nhánh) | reject |
| 10 | E | `limits()` ném trong `enter`/`enteredBackground` | false | `settings.current` là getter trả field, không ném | reject |
| 11 | B | Khoảng sau `enter` chưa có hạn phiên | false | hạn chưa tồn tại thì cũng chưa thể qua; `_startSession` hẹn lại timer | reject |
| 12 | B | Factory mặc định không clock = fail-open | low | spec quy định mặc định `SessionController.new`; sửa là sửa spec | reject |
| 13 | B | Status spec `in-review` khác sprint `in-progress` | false | đúng quy trình: sprint cập nhật ở bước trình bày | reject |
| 14 | B | Thiếu gate test chỉ `paused`, giữ route, hạn phiên qua cây | low | nhánh `paused` dùng chung case với `hidden`; hạn phiên đã test ở controller | reject |
| 15 | V | `ad8_without_clock_never_autolocks` không tiến clock | low | controller không clock không có đường hết hạn nào | reject |

## Design Notes

- **Vì sao factory provider:** features không được import `core/ports`, nên gate không tự dựng clock; factory còn cho test (và Epic 3/5/6) tiêm hook vào gate — giải quyết mục deferred của 1.8.
- **Timer chỉ đánh thức:** `Timer(remaining, evaluate)`; nếu `evaluate` thấy chưa tới hạn (timer sớm/máy ngủ lệch) thì hẹn lại theo phần còn lại tính từ clock.

## Verification

**Commands (trong `pak_manager/`):**
- `flutter analyze --fatal-infos --fatal-warnings` -- 0 issue.
- `dart tool/check_imports.dart` -- exit 0.
- `NIX_SKIP_SODIUM_BUILD_HOOKS=1 flutter test` -- pass trừ `setUpAll` cần libsodium.
