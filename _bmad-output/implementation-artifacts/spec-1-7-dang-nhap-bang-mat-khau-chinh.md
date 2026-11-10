---
title: 'Story 1.7 — Đăng nhập bằng mật khẩu chính'
type: 'feature'
created: '2026-11-10'
status: 'done'
baseline_commit: '2cae4a62807f26a594c4438baa20fef28d6ad9f2'
route: 'dispatch'
review_loop_iteration: 0
context:
  - '{project-root}/_bmad-output/implementation-artifacts/epic-1-context.md'
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** Máy đã có `vault/header` thì S3 chỉ có tiêu đề: người dùng không mở được vault đã tạo (FR-3; `epics.md:641`).

**Approach:** Thêm `AccountService.unlock(String)` trả sealed `UnlockResult` (`UnlockSuccess(VaultSession) | UnlockWrongPassword | UnlockCorrupt`) theo AD-5; S3 có `SecretField` + "Đăng nhập"; `SessionGate` dùng chung đường vào phiên với `create` (tăng epoch, thay cây bằng `HomeShell`).

## Boundaries & Constraints

**Always:**
- `unlock` theo thứ tự: đọc `header` → `HeaderCodec.decode` (`HeaderCorrupt` → `UnlockCorrupt`, **không** chạy KDF) → `ascii.encode` → KDF qua `KekDeriver` (isolate; `null` → `UnlockCorrupt`) → `kcvMatches` (lệch → `UnlockWrongPassword`) → `unwrapDek` → đọc + `decodeCards`/`decodeRecent`; mọi lỗi sau `kcv` khớp, thiếu `cards`/`recent` → `UnlockCorrupt`. Không ghi, không xóa file nào. Wipe `Uint8List` mật khẩu, dispose KEK, dispose DEK trừ khi chuyển cho `VaultSession`, trong `finally`. Không ném qua ranh giới lớp; gọi chồng khi lần trước chưa xong thì trả lại `Future` đang chạy (không chạy KDF lần hai).
- Chừa comment cho Epic 2 trong `unlock`: `LockoutGuard` ghi trước KDF, reset sau khi `kcv` khớp; `lockedOut` là lớp con mới.
- S3 (UX-DR31/42 phần Epic 1): ô `SecretField` biến thể login (không placeholder, cách tên 48) → inline-message cách 6 → nút `login.submit` cách 24. Nút vô hiệu khi < 15 ký tự hoặc có ký tự không ASCII (hiện `pw.nonAscii`); chuỗi đó không bao giờ tới `unlock`. Không kiểm blocklist/độ dài tối đa/lặp ở S3. Return gửi nếu nút bật.
- Đang kiểm tra: spinner trên nút, khóa ô và nút, chặn bấm lặp (đúng một lần `unlock`).
- `UnlockWrongPassword` → `login.wrong`, giữ nội dung ô; `UnlockCorrupt` → `login.corrupt`, giữ ô, không xóa gì. Thông báo ẩn khi người dùng sửa ô.
- `UnlockSuccess` → gate vào phiên, tab 0; `!mounted` thì dispose phiên (như 1.6).
- `BootstrapUnavailable` giữ hành vi 1.6 (S1, nút vô hiệu); S3 chỉ hiện khi `BootstrapHasAccount` và `accountServiceProvider` khác `null`.
- Chuỗi qua ARB vi/en (`loginSubmit`, `loginWrong`, `loginCorrupt`) đúng `EXPERIENCE.md:138,151,154`; chỉ token theme; tên test gắn FR/AD/UX-DR; chỉ fake tự viết.

**Never:** Không làm `LockoutGuard`, `login.attempts`/`login.lockout`, nút "Xóa & Tạo tài khoản mới", S4/S5 (Epic 2); không `lock()`/`SessionController`/timer (1.8–1.9); không `verify()` (chưa có người dùng — thêm ở story đổi mật khẩu/export). Không sửa codec, KDF, `create`. Không thêm package.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Đúng mật khẩu | header + cards + recent hợp lệ | `UnlockSuccess`, phiên giữ cards/recent đã giải mã; vào tab Quản lý mật khẩu | — |
| Sai mật khẩu | kcv lệch | `login.wrong`, ô giữ nội dung, nút bật lại | không giải mã gì |
| Header hỏng | sai độ dài/magic/checksum/tham số ngoài khoảng | `login.corrupt` | KDF không chạy; không xóa |
| Đúng mật khẩu, dữ liệu hỏng | AEAD lỗi / JSON sai / thiếu `cards` hoặc `recent` / unwrap lỗi | `login.corrupt` | DEK bị dispose; không xóa |
| Không đọc được header | I/O lỗi | `login.corrupt` | không ném |
| Ngắn / non-ASCII | 14 ký tự; `mậtkhẩu…` | nút vô hiệu; non-ASCII hiện `pw.nonAscii` | `unlock` không được gọi |
| Bấm đúp / Return khi bận | — | `unlock` chạy một lần | — |

## Decisions

Người dùng chọn 2026-11-10:
- **`login.corrupt`:** dùng nguyên chuỗi đầy đủ của EXPERIENCE.md ngay ở Epic 1 (kể cả phần nhắc "Xóa & Tạo tài khoản mới").
- **Độ dài spec:** giữ một spec (~2.600 token) dù vượt mức 1.600.

</frozen-after-approval>

## Code Map

- `pak_manager/lib/services/account_service.dart` -- thêm sealed `UnlockResult` + `unlock()`; tái dùng `_deriveKek`, `_disposeQuietly`, mẫu cờ `_creating`, `wipe`. Cập nhật doc lớp (bỏ "unlock thuộc 1.7"). `bootstrap`/`create` không đổi.
- `pak_manager/lib/core/format/header_codec.dart` -- `decode` :109 → `HeaderOk(header)`/`HeaderCorrupt`; `kcvMatches` :218 (so hằng thời gian); `unwrapDek` :229 → `SecureKey?`. Không sửa.
- `pak_manager/lib/core/format/vault_file_codec.dart` -- `decodeCards`/`decodeRecent` :93,98 → `VaultFileOk`/`VaultFileCorrupt`. Không sửa.
- `pak_manager/lib/core/crypto/kdf.dart` -- `KdfParams.isAllowed`; `deriveKek` trả `null` khi ngoài khoảng (đã chạy isolate).
- `pak_manager/lib/services/vault_session.dart` -- constructor `VaultSession(dek, cards, recent)`; không sửa.
- `pak_manager/lib/features/auth/login_screen.dart` -- hiện `StatelessWidget`; S3 thành stateful (controller, `_busy`, thông báo). Hằng `loginTitleTop/ToField` tái dùng.
- `pak_manager/lib/features/auth/create_account_screen.dart` -- mẫu: `_busy`, `PopScope`, gọi service qua `ref.read(accountServiceProvider)`, key cố định cho hàng `Column` (lỗi 1.6: thiếu key làm `SecretField` dựng lại và `clear()` controller).
- `pak_manager/lib/features/shared/session_gate.dart` -- `_onCreated` → đổi thành `_enterSession` dùng cho cả create và unlock; `_loginFor` truyền `onUnlocked` cho S3.
- `pak_manager/lib/features/shared/{secret_field,pak_buttons,inline_message}.dart` -- tái dùng nguyên.
- `pak_manager/lib/l10n/app_{en,vi}.arb` -- thêm 3 key; chạy `flutter gen-l10n`.
- `pak_manager/test/support/account_fakes.dart` -- fake `AccountService`/phiên của 1.6; mở rộng cho `unlock` (Completer điều khiển kết quả).
- `pak_manager/test/core/vault_fixture.dart`, `test/fixtures/vault/v1/{header,cards,recent}` -- fixture thật cho test `unlock` (cần libsodium → chờ CI như 1.6).
- `pak_manager/test/app_test.dart` -- test `main()` thật; thêm nhánh có header → S3 có ô và nút.

## Tasks & Acceptance

**Execution:**
- [x] Nhánh `feat/1-7-login` từ `main` (`2cae4a6`).
- [x] `pak_manager/lib/services/account_service.dart` -- `UnlockResult` + `unlock()` theo Always.
- [x] `pak_manager/lib/l10n/app_{en,vi}.arb` + gen-l10n -- `loginSubmit`, `loginWrong`, `loginCorrupt`.
- [x] `pak_manager/lib/features/auth/login_screen.dart` -- S3 đầy đủ (S1 giữ nguyên).
- [x] `pak_manager/lib/features/shared/session_gate.dart` -- đường vào phiên dùng chung.
- [x] Test: `test/services/account_service_test.dart` (mọi dòng Matrix phía service với fixture/codec thật: KDF không chạy khi header hỏng, wipe/dispose, không file nào đổi), `test/features/auth/login_screen_test.dart` (nút vô hiệu, unlock không được gọi, spinner + bấm đúp, wrong/corrupt giữ ô, ẩn thông báo khi sửa, Return), `session_gate_test` (S3 → HomeShell tab 0, `!mounted` dispose), `app_test`.

**Acceptance Criteria:**
- Given máy có `vault/header`, when app mở, then S3 có "PAK Manager", ô mật khẩu không placeholder và nút "Đăng nhập", không có ô/nút nào khác.
- Given `unlock` trả bất kỳ kết quả nào, then UI chỉ nhận một trong ba lớp sealed, không exception nào ra khỏi service.
- Given `UnlockSuccess`, when gate dựng lại, then thấy `CupertinoTabScaffold` tab 0 và `SecretField` của S3 đã bị gỡ.
- Given toàn repo, then `flutter analyze --fatal-infos --fatal-warnings` 0 issue và `dart tool/check_imports.dart` exit 0.

### Review Findings

- [x] [Review][Patch] `last_updated` đổi định dạng (`11-10-2026 15:17` → `2026-11-10`), lệch với `generated` [_bmad-output/implementation-artifacts/sprint-status.yaml:32]

**Rejected:**
- (edge+blind) Gọi chồng `unlock` chia sẻ một `UnlockSuccess` / race trước `whenComplete` — low: UI chặn bằng `_busy`; hành vi trả `Future` đang chạy là quyết định spec (Design Notes); sửa là sửa spec.
- (edge+blind) `_submit` không `try/finally` quanh `unlock` — low: `_unlock` bắt `on Object`, hợp đồng không ném; thêm chốt phòng thủ.
- (auditor) Nút "Đăng nhập" không vô hiệu khi bận — false: `PakPrimaryButton.enabled` = `onPressed != null && !busy`.
- (edge+auditor) S3 hiện khi `accountServiceProvider` null — false: `BootstrapHasAccount` chỉ do chính `AccountService` trả (`account_service.dart:160`).
- (blind) `login.corrupt` nói "mật khẩu đúng" cả khi header hỏng / nhắc nút chưa có — sửa là sửa spec (Decisions đã chọn).
- (blind) Spec `status: done` lệch sprint `review` — sửa là sửa spec; bước review cập nhật trạng thái.
- (blind) `on Object` nuốt lỗi không log — low: thêm logging là thêm độ phức tạp.
- (blind) Mật khẩu còn trong `_password` tới khi dispose — low: `SecretField` con `clear()` khi bị gỡ.
- (blind) `app_test` khôi phục global không qua `addTearDown`, vòng chờ dừng theo `CupertinoApp` — low: mẫu có sẵn từ 1.6.
- (blind+auditor) Thiếu test DEK dispose nhánh corrupt, UI khi `unlock` ném, reset `_unlocking` sau wrong — low: đã ghi nhận ở Implementation Notes; code dispose trong `finally`.
- (blind) Test so danh sách `Text` chính xác — low: cố ý để chứng minh không có ô/nút thừa (AC1).
- (blind) Không autofocus ô mật khẩu — sửa là sửa spec.
- (edge) Đổi định dạng `last_updated` — gộp vào patch trên.

## Implementation Notes

- Thêm `PasswordPolicy.isPrintableAscii` (static, `core/policy`) để S3 hiện `pw.nonAscii` mà không chạy cả luật; cổng nút dùng `meetsLoginGate` có sẵn.
- S1 dùng chung hàng có key cố định với S3 (`row.create`), khoảng 48 dưới tên giữ nguyên.
- Gọi chồng `unlock`: lần sau trả `Future` của `_unlock` đang chạy (cùng đối tượng kết quả), KDF chạy một lần.
- Kiểm (Windows): analyze 0 issue; `check_imports` OK; gen-l10n chỉ đổi 3 key mới. `NIX_SKIP_SODIUM_BUILD_HOOKS=1 flutter test`: 319 pass, 1 skip, 7 lỗi `setUpAll` cần libsodium (như 1.6). Bọc tạm nạp `libsodium.dll` cho `account_service_test` + `app_test`: 38/38 pass (file tạm đã xóa). Suite đầy đủ với build hook thật chờ CI.
- Chưa test trực tiếp DEK bị dispose ở nhánh corrupt sau unwrap (DEK do `HeaderCodec.unwrapDek` tạo, không chèn được fake); code dispose trong `finally`.

## Spec Change Log

## Review Triage Log

Review 2026-11-10 (diff `2cae4a6..` cây làm việc, bỏ code l10n sinh ra; 3 lớp: blind (B), edge (E), verif-gap (V)). V: không có lỗ hổng kiểm chứng.

| # | Nguồn | Phát hiện | Verdict | Bằng chứng | Route |
|---|-------|-----------|---------|------------|-------|
| 1 | E, B | `unlock` gọi chồng trả cùng `UnlockSuccess` cho hai người gọi (hai chủ phiên), bỏ qua mật khẩu của lần gọi sau | low | Chỉ S3 gọi `unlock` và đã chặn bằng `_busy`; hành vi đúng như Always/Design Notes. Sửa là sửa spec | reject |
| 2 | E, B | Chuỗi non-ASCII/ngắn lọt tới `unlock` → `ascii.encode` ném → `corrupt` | low | UI chặn bằng `meetsLoginGate` (test `fr02_fr03_non_ascii…never_unlocks`); sửa là thêm chốt | reject |
| 3 | E | Header hỏng hiện `login.corrupt` dù chưa kiểm mật khẩu | low | AC story (`epics.md:667-669`) và Decision của người dùng chọn đúng chuỗi này; sửa là sửa spec | reject |
| 4 | E | `unlock` chạy song song `create` | false | `create` chỉ tới từ S2 (máy chưa có header), `unlock` chỉ từ S3 (đã có header); gate không hiện cả hai | reject |
| 5 | E, B | `ref.read(accountServiceProvider)` trong `build` không dựng lại khi provider đổi | false | Provider là giá trị override tĩnh trong `main.dart`, không đổi lúc chạy (trùng triage 1.6 #19) | reject |
| 6 | E | Sau `onUnlocked` màn S3 có thể còn sống với spinner | false | `_enterSession` luôn tăng epoch và thay cả cây bằng `HomeShell` (test `fr03_ad23_unlock_success_replaces_s3…`) | reject |
| 7 | B | Lỗi I/O thoáng qua bị báo `corrupt`, có thể khiến người dùng xóa dữ liệu | low | Spec (Design Notes) gộp I/O vào `corrupt` theo AC ba kết quả; nút xóa chưa có ở Epic 1; sửa là sửa spec | reject |
| 8 | B | `login.corrupt` nhắc nút chưa tồn tại | false | Người dùng đã chọn (a) ở Decisions 2026-11-10 | reject |
| 9 | B | Nhánh `onUnlocked == null`, `!mounted` của màn, ký tự 0x20/0x7E chưa có test riêng | low | `onUnlocked` luôn có ở gate; `!mounted` phủ qua `ad22_unlock_finishing_after_tree_is_gone…`; biên ASCII phủ ở test policy 1.5 | reject |
| 10 | B | Offset byte cứng trong test header | low | Chỉ trong test; header có golden test, đổi định dạng thì golden đỏ trước | reject |
| 11 | B | Thông báo inline không là live region | low | Trùng triage 1.6 #15 (chưa có mức trợ năng riêng) | reject |
| 12 | B | Không giới hạn số lần thử ở Epic 1 | false | Ngoài phạm vi theo intent: `LockoutGuard` thuộc Epic 2 (Never), đã ghi ở epic context | reject |
| 13 | B | Diff thiếu file l10n sinh ra, spec, sprint-status | false | Cố ý loại khỏi diff review; code sinh ra được `flutter analyze` và test `fr03_en_strings` kiểm | reject |

## Design Notes

- **Gọi chồng `unlock`:** UI đã chặn bằng `_busy`; service vẫn có cờ phòng thủ như `create`. Trả `UnlockCorrupt` sẽ hiện thông báo sai, nên lần gọi chồng trả kết quả của lần đang chạy (giữ `Future` đang chạy và trả lại nó) — không chạy KDF lần hai.
- **Header không đọc được (I/O)** gộp vào `corrupt` vì `UnlockResult` chỉ có ba lớp (AC story); không xóa gì nên an toàn.

## Verification

**Commands (trong `pak_manager/`):**
- `flutter pub get --enforce-lockfile` -- resolve được.
- `flutter gen-l10n` -- không diff ngoài file đã commit.
- `flutter analyze --fatal-infos --fatal-warnings` -- 0 issue.
- `dart tool/check_imports.dart` -- exit 0.
- `NIX_SKIP_SODIUM_BUILD_HOOKS=1 flutter test` -- mọi test pass trừ `setUpAll` cần libsodium; chạy thêm `account_service_test` + `app_test` qua file bọc tạm nạp `libsodium.dll` (như 1.6), xóa sau khi chạy.
