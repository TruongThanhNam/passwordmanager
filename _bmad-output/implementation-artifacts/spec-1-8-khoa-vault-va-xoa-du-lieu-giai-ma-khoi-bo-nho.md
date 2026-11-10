---
title: 'Story 1.8 — Khóa Vault và xóa dữ liệu giải mã khỏi bộ nhớ'
type: 'feature'
created: '2026-11-10'
status: 'done'
baseline_commit: '1fa793138581a4c62a7c2c8ae2a285abaa48c5fd'
route: 'dispatch'
review_loop_iteration: 0
context:
  - '{project-root}/_bmad-output/implementation-artifacts/epic-1-context.md'
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** Đã đăng nhập thì không có cách nào khóa vault: tab Cài đặt trống, DEK và dữ liệu giải mã nằm trong RAM tới khi app bị kill (FR-49, NFR-4; `epics.md:675`).

**Approach:** Thêm `SessionController` (services) là nơi duy nhất gọi `VaultSession.lock()`, chạy trình tự khóa AD-9 với hook rỗng và giữ epoch; tab Cài đặt có khối "Khóa Vault"; `SessionGate` lấy epoch từ controller và thay cả cây bằng S3.

## Boundaries & Constraints

**Always:**
- `VaultSession.lock()` (thay `dispose()`): hủy `SecureKey`, bỏ `cards`/`recent`; idempotent. Sau `lock()`, mọi method đọc/thao tác trả `SessionLocked` (sealed `SessionResult<T>` = `SessionOk(value) | SessionLocked`), không I/O. Có hàng đợi tuần tự `run(op)` (op nhận DEK) và `idle()` chờ op đang chạy xong; op đã xếp hàng nhưng chưa chạy khi lock thì trả `SessionLocked`.
- `SessionController`: `enter(VaultSession)` (khóa phiên cũ nếu có, epoch++), `lock({foreground = true})` theo đúng thứ tự: `flushDraft` → `session.idle()` + hook `awaitPendingWrites` → `cancelUnstarted` → `session.lock()` → `clearClipboardIfOurs` (chỉ khi `foreground`) → epoch++ → báo listener. Hook là `Future<void> Function()` mặc định no-op. Gọi `lock` chồng trả cùng `Future`; không có phiên thì no-op. Lỗi trong hook không chặn `session.lock()` (khóa luôn hoàn tất). `isCurrent(int epoch)` cho luật "await trên port so epoch".
- Không import `dart:io`/plugin/feature trong controller; không timer, không `ClockPort` (1.9).
- Gate: tạo một `SessionController`, dựng lại khi controller báo; cây sau đăng nhập bọc `KeyedSubtree(ValueKey(epoch))` + `ProviderScope` con override `sessionControllerProvider` và `vaultSessionProvider` — khóa là gỡ cả scope này. Sau khóa luôn hiện S3 (`BootstrapHasAccount`), kể cả khi phiên vào qua S2. `dispose` gate khóa phiên.
- S18 tối thiểu: nền `surfaceGrouped`, nav-bar `tab.settings`, một ô riêng inset-grouped (`surfaceRaised`, bo `md`, cao `rowHeight`, lề `margin`, cách nav-bar `sectionGap`) chứa `PakTextButton` "Khóa Vault"/"Lock Vault" (`settings.rows`, ARB `settingsLockVault`). Bấm → `ref.read(sessionControllerProvider).lock()` ngay, không hỏi.
- Khóa: không thông báo lý do, không sheet/dialog/`SecretField` nào sót; tên test gắn FR/AD/UX-DR; chỉ fake tự viết.

**Never:** Không autolock/giới hạn phiên/lifecycle/`ClockPort` (1.9); không cài đặt khác trên S18 (Epic 5); không `ModalPresenter`, toast, clipboard, bản nháp thật (hook rỗng). Không nút Sign out. Không sửa codec/KDF/`unlock`/`create` ngoài đổi `dispose`→`lock`. Không thêm package.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Bấm Khóa Vault | đang ở tab Cài đặt | về S3 ngay, ô mật khẩu trống, không dialog | — |
| Phiên vào từ S2 rồi khóa | bootstrap ban đầu `NoAccount` | hiện S3 (không phải S1) | — |
| Method sau lock | `cards`/`run` trên phiên đã khóa | `SessionLocked`, op không chạy | — |
| Op đang chạy khi lock | `run` chưa xong | lock chờ op xong rồi mới hủy DEK | — |
| Bấm khóa 2 lần | lock đang chạy | trình tự chạy một lần, epoch +1 | — |
| Hook ném lỗi | `flushDraft` throw | vẫn `session.lock()` + epoch++ | nuốt lỗi |
| Kết quả port sau khóa | epoch đổi giữa `await` | `isCurrent(old)` = false → bỏ | — |

</frozen-after-approval>

## Code Map

- `pak_manager/lib/services/vault_session.dart` -- hiện chỉ có getter `cards`/`recent`, `dispose()`, `isDisposed`; đổi thành `lock()`/`isLocked`, `readCards()`/`readRecent()` → `SessionResult`, `run`/`idle`. Giữ `toString` che dữ liệu.
- `pak_manager/lib/services/session_controller.dart` -- MỚI. Dart thuần (cho phép `dart:async`); listener kiểu `void Function()` (không cần `ChangeNotifier`).
- `pak_manager/lib/services/account_service.dart` -- `:244`, `:320` tạo `VaultSession`; các nhánh hủy dùng `dispose` → `lock`.
- `pak_manager/lib/features/shared/session_gate.dart` -- `_epoch`, `_session`, `_enterSession` → chuyển cho controller; `_loginFor` đọc `bootstrapResultProvider` một lần → giữ `_bootstrap` cục bộ, đặt `BootstrapHasAccount` sau khi vào phiên.
- `pak_manager/lib/features/shared/providers.dart` -- thêm `sessionControllerProvider`, `vaultSessionProvider` (mặc định ném `UnimplementedError`: chỉ có trong scope phiên).
- `pak_manager/lib/features/shared/home_shell.dart` -- tab 2 dùng `SettingsScreen` thay `_TabPage`.
- `pak_manager/lib/features/settings/settings_screen.dart` -- MỚI (S18 tối thiểu); tái dùng `PakTextButton` (`pak_buttons.dart:80`), `ContentColumn`, token `PakSpacing.sectionGap/rowHeight/margin`, `PakRadius.md`, `PakColors.surfaceRaised/surfaceGrouped`.
- `pak_manager/lib/features/auth/{login_screen,create_account_screen}.dart` -- `:94,102` / `:140` `dispose` → `lock`.
- `pak_manager/lib/l10n/app_{en,vi}.arb` -- `settingsLockVault`; `flutter gen-l10n`.
- `pak_manager/test/support/account_fakes.dart` -- `pumpGateApp`, `FakeAccountService` (Completer) tái dùng.
- `pak_manager/test/services/vault_session_test.dart`, `test/services/account_service_test.dart` -- đổi `dispose`→`lock`.

## Tasks & Acceptance

**Execution:**
- [x] Nhánh `feat/1-8-lock-vault` từ `main` (`1fa7931`).
- [x] `vault_session.dart` -- `lock`, `SessionResult`, `run`/`idle` -- AC VaultSession.
- [x] `session_controller.dart` -- trình tự + epoch + `isCurrent` -- AD-9.
- [x] `providers.dart`, `session_gate.dart` -- scope phiên, S3 sau khóa -- AD-23.
- [x] `settings_screen.dart`, `home_shell.dart`, ARB + gen-l10n -- UX-DR36 khối 5.
- [x] Đổi gọi `dispose` → `lock` ở service/auth/test.
- [x] Test: `test/services/session_controller_test.dart` (thứ tự hook bằng log, gọi chồng, hook ném, `foreground=false` bỏ clipboard, `isCurrent`, không phiên); `vault_session_test` (locked sau lock, op chờ/hủy); `test/features/settings/settings_screen_test.dart` (thị giác ô, text accent); `session_gate_test` (khóa → S3, không `SecretField`/`HomeShell`/`CupertinoTabScaffold`, không còn `ProviderScope` phiên, dialog đang mở bị gỡ, S2→khóa→S3, epoch +1).

**Acceptance Criteria:**
- Given đã đăng nhập, when mở tab Cài đặt, then chỉ thấy nav-bar "Cài đặt" và một ô chứa "Khóa Vault", không nút Sign out.
- Given `lib/`, then chỉ `session_controller.dart` gọi `VaultSession.lock()` ngoài các nhánh hủy phiên chưa trao cho gate (auth screen `!mounted`, account service lỗi).
- Given toàn repo, then `flutter analyze --fatal-infos --fatal-warnings` 0 issue và `dart tool/check_imports.dart` exit 0.

## Implementation Notes

- `account_service.dart` không gọi `dispose` nên không đổi. Gate `_enterSession` khi `!mounted` gọi `session.lock()` trực tiếp (phiên chưa trao cho controller) — cùng tinh thần ngoại lệ ở AC.
- `idle()` giữ hàng đợi (op chưa chạy không bắt đầu) tới lượt event-loop kế để trình tự khóa kịp hủy chúng; khi Epic 3/5/6 lấp hook `awaitPendingWrites`/`cancelUnstarted` dài hơn thì cần xem lại.
- `test/support/account_fakes.dart`: thêm `createAndEnterShell`; `openCreateScreen` bấm theo kiểu nút (chạy được cả tiếng Anh).
- Kiểm (Windows): analyze 0 issue; `check_imports` OK; `session_controller_test`, `vault_session_test`, `test/features`: 129 pass. `account_service_test` cần libsodium — chỉ analyzer kiểm, chờ CI.

## Spec Change Log

- 2026-11-10 (code review): trình tự khóa thực tế là `flushDraft` → `holdQueue()` → `awaitPendingWrites` → `cancelUnstarted` → `session.idle()` → `session.lock()` → `clearClipboardIfOurs` → epoch++ → báo listener. `idle` dời ra sau `cancelUnstarted` (triage #1) để op xếp hàng không chạy khi DEK còn sống; `holdQueue()` đặt sau `flushDraft` để draft ghi qua `session.run` không bị kẹt. Người dùng chấp thuận.

## Review Triage Log

Review 2026-11-10 (diff `1fa7931..` cây làm việc, bỏ code l10n sinh ra; 3 lớp: blind (B), edge (E), verif-gap (V)). V: không có lỗ hổng kiểm chứng.

| # | Nguồn | Phát hiện | Verdict | Bằng chứng | Route |
|---|-------|-----------|---------|------------|-------|
| 1 | B, E | `idle()` nhả hàng đợi ở lượt event-loop kế; hook `cancelUnstarted` bất đồng bộ thật thì op xếp hàng chạy khi DEK còn sống | medium | `_runLock` await `cancelUnstarted` sau `idle`, trước `lock()`; hiện hook no-op nên test không lộ | patch |
| 2 | B | Rebuild giữa `session.lock()` và epoch++ dựng Navigator đăng nhập cùng `ValueKey(epoch)` và cùng GlobalKey của navigator `HomeShell` → state navigator bị chuyển sang | medium | `build` hiện login khi `isLocked`; `_navigator` chỉ đổi ở listener | patch |
| 3 | B | Test S18 dùng số cứng 35 | low | `settings_screen_test.dart`; sửa trực tiếp | patch |
| 4 | B, E | `SessionController.dispose()` khóa DEK khi op đang chạy | low | Chỉ khi gỡ gate (tắt app); op lỗi được trả qua Future; sửa cần chờ bất đồng bộ trong `dispose` | reject |
| 5 | B, E | `enter()` khi đang khóa | false | Trong lúc khóa UI vẫn là `HomeShell`; `enter` chỉ tới từ S2/S3 | reject |
| 6 | E | Hook không bao giờ xong → khóa treo | low | Mọi hook hiện no-op; timeout là thêm độ phức tạp, xét khi epic sau lấp hook | reject |
| 7 | E | Controller bị dispose khi `_runLock` đang chạy | low | Listener đã xóa, hook no-op; không hại | reject |
| 8 | B, E | Nút Khóa Vault bấm được khi đang khóa | low | `lock` gọi chồng trả cùng Future (test `ad9_double_tap…`) | reject |
| 9 | E | Danh sách ngoại lệ trong AC "chủ duy nhất `lock()`" thiếu nhánh `!mounted` của gate | low | Sửa là sửa spec; đã ghi ở Implementation Notes | reject |
| 10 | B | `readCards` trả tham chiếu list thật | low | List `unmodifiable`; người dùng list nằm trong scope phiên bị gỡ khi khóa | reject |
| 11 | B | Listener ném chặn listener khác | false | Listener duy nhất là `setState` của gate, có kiểm `mounted` | reject |
| 12 | B | Không có chỗ tiêm hook ở gate | low | Hook thuộc Epic 3/5/6 (Never của spec); thêm khi có hook thật | reject |
| 13 | B | `lock(foreground: false)` chưa có người gọi | false | Nhánh nền thuộc 1.9 (lifecycle) | reject |
| 14 | B | Guard `UnimplementedError` của provider chưa có test | low | Test gate đã kiểm scope phiên bị gỡ sau khóa | reject |
| 15 | B | Override `ProviderScope` cũ khi rebuild cùng epoch | false | Mỗi epoch đúng một phiên; giá trị override không đổi trong epoch | reject |
| 16 | B | `app_vi.arb` thiếu description | false | `app_en.arb` là template; l10n sinh bằng `flutter gen-l10n` | reject |

## Design Notes

- **Vì sao gate giữ `_bootstrap` cục bộ:** `bootstrapResultProvider` tính một lần trước `runApp`; phiên tạo qua S2 rồi khóa sẽ rơi về S1 nếu đọc lại provider.
- **`run`/`idle` ngay ở 1.8:** bước 2 trình tự cần điểm chờ thật; Epic 3/5/6 chỉ việc đưa thao tác ghi qua `run`.

## Verification

**Commands (trong `pak_manager/`):**
- `flutter gen-l10n` -- chỉ thêm `settingsLockVault`.
- `flutter analyze --fatal-infos --fatal-warnings` -- 0 issue.
- `dart tool/check_imports.dart` -- exit 0.
- `NIX_SKIP_SODIUM_BUILD_HOOKS=1 flutter test` -- pass trừ `setUpAll` cần libsodium (như 1.7).

### Review Findings

- [x] [Review][Patch] (từ Decision → phương án 1: dời `holdQueue()` sau `flushDraft`, ghi Spec Change Log, sửa comment test) Thứ tự khóa lệch spec và `holdQueue()` chặn `flushDraft` — `_runLock` gọi `holdQueue()` trước `flushDraft` và chạy `idle` sau `cancelUnstarted`. Spec quy định `flushDraft` → `idle()`+`awaitPendingWrites` → `cancelUnstarted`. Nếu `flushDraft` (Epic 3/5/6) ghi qua `session.run`, op bị chặn tới `lock()`: hoặc lock treo, hoặc draft bị hủy. Spec Change Log trống; comment test thứ tự đã cũ.
- [x] [Review][Patch] Test thứ tự không log `idle` và `session.lock()` [pak_manager/test/services/session_controller_test.dart]
- [x] [Review][Patch] Test S18 còn số cứng 44/16 thay vì `PakSpacing.rowHeight`/`PakSpacing.margin` [pak_manager/test/features/settings/settings_screen_test.dart:80]
- [x] [Review][Patch] ~~Thiếu test widget "dispose gate khóa phiên"~~ — false khi áp dụng: đã có `fr45_gate_disposes_session_with_tree`
- [x] [Review][Patch] `ad9_double_tap_lock_bumps_epoch_once` không bấm nút thật lần nào [pak_manager/test/features/shared/session_gate_test.dart:488]
- [x] [Review][Patch] Doc comment `_TabPage` gãy câu ("các / tab Cài đặt là") [pak_manager/lib/features/shared/home_shell.dart:98]
- [x] [Review][Defer] Cửa sổ giữa `session.lock()` và `_notify()` (await `clearClipboardIfOurs`): HomeShell còn hiện với phiên đã khóa; nhánh reset navigator `_lastInSession` không có test [pak_manager/lib/services/session_controller.dart, pak_manager/lib/features/shared/session_gate.dart:447] — deferred: hook hiện no-op; cần cách inject hook vào gate khi có hook clipboard thật (Epic 3/5/6)

**Rejected:**
- `enter()` khi lock đang chạy / `lock()` trả future cũ — low: khi đang khóa, HomeShell vẫn hiện nên không thể vào màn đăng nhập để gọi `enter`.
- Dispose gate khi op đang chạy hủy DEK giữa chừng; op đang chạy trả `SessionOk` sau lock — low: chỉ xảy ra khi teardown app, cần thêm nhánh guard.
- Listener ném lỗi / lỗi `unawaited` ở Settings — low: listener chỉ là `setState` của gate, hook đã bọc `_guard`.
- `holdQueue()` public không có release — low: hiện chỉ controller gọi; thêm API release là tăng bề mặt.
- `idle()` dùng `Timer.run` — false: luật "không timer" áp cho controller (autolock 1.9), không phải event-loop yield.
- Status spec `done` vs sprint `review`, AC2 thiếu ngoại lệ gate `!mounted` — reject: fix là sửa spec.
- Key `settings.rows` — low: chỉ đặt tên.
- Chiều cao ô cố định khi text scale lớn — false so với spec: spec yêu cầu cao `rowHeight`.
- Không có công cụ cưỡng chế nơi gọi `lock()`; `enter` cùng instance tăng epoch; test account_service chưa chạy — low/quy trình.
