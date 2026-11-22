---
title: 'Story 2.4: Xóa & Tạo tài khoản mới khi quên mật khẩu chính'
type: 'feature'
created: '2026-11-22'
status: 'done'
route: 'dispatch'
review_loop_iteration: 0
baseline_commit: 'c662739d0f163d6ebbccfbcb4de722faec58064a'
context:
  - '{project-root}/_bmad-output/implementation-artifacts/epic-2-context.md'
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** Người quên mật khẩu chính chưa có lối thoát cố ý: S3 không có nút xóa, chưa có S4 (hộp thoại xác nhận) hay hold-confirm-button, nên chỉ còn cách sai 10 lần hoặc gỡ app (FR-9, UJ-4 nhánh A).

**Approach:** Thêm nút "Xóa & Tạo tài khoản mới" ở đáy S3, hộp thoại S4 dáng iOS với hold-confirm-button giữ 3 giây. Đủ 3 giây thì dùng lại đường S5 của story 2.3 (`LoginScreen.onWipe` → `SessionGate._startWipe` → `WipingScreen` → `AccountService.wipe()` → S1). Không đổi service, codec hay `WipeCoordinator`.

## Boundaries & Constraints

**Always:**
- Chỉ ở S3 (`hasAccount`), không có ở S1/S5. Nút là button-text cao 44, đáy cách mép màn 42, nằm dưới và xa nút "Đăng nhập" (UX-DR31); màn thấp hoặc có bàn phím thì cuộn được, không đè lên ô/nút. Bấm được ở idle, sai, đang chờ đếm ngược và dữ liệu hỏng (UX-DR42). Riêng lúc đang kiểm tra mật khẩu (`_busy`, vài giây KDF) nút vô hiệu, để `wipe()` không chạy chồng `unlock` (`unlock` thành công sẽ ghi lại `guard` sau khi xóa).
- Bấm nút → S4 mở từ S3, không yêu cầu mật khẩu. S4 là alert-dialog (UX-DR13): rộng 270, `rounded.alert`, nền `surface-raised` trên `scrim`; tiêu đề `erase.title` body-emphasis, thân `erase.body` footnote `ink-primary`, hold-confirm-button cách thân 16, nhãn `erase.hold` footnote `ink-secondary` cách nút 8; hàng nút cao 44 ngăn bởi hairline `separator`, **chỉ** "Hủy" (`common.cancel`, body-emphasis `accent`). Không đóng khi chạm ra ngoài.
- hold-confirm-button (UX-DR14): nút tròn 72 không nền, icon thùng rác `accent`, vòng dày 4 (nền `track`, phần đã giữ `accent`) chạy đều theo chiều kim đồng hồ từ 12 giờ trong 3 giây kể từ lúc nhấn. Nhả (hoặc hủy chạm) trước 3 giây: vòng chạy ngược về 0, không gọi gì; tap nhanh không làm gì, không thông báo. Đủ 3 giây: gọi xác nhận đúng một lần.
- Xác nhận → dialog đóng, rồi gọi `LoginScreen.onWipe` (callback sẵn có của 2.3) để gate sang S5 → `wipe()` → S1 hoặc S1 vô hiệu khi lỗi, như lần sai thứ 10. Không thêm kết quả, provider hay API service.
- "Hủy", hoặc Back Android (kể cả lúc đang giữ) đóng dialog và hủy lần giữ, không xóa gì. Back đi qua `PopScope` trong chính S4, không qua `ModalPresenter` (Epic 3). Hủy hay đóng dialog không đổi nội dung ô mật khẩu, thông báo hay đếm ngược của S3.
- Chuỗi mới `loginErase`, `eraseTitle`, `eraseBody`, `eraseHold`, `commonCancel` có đủ vi/en trong 2 ARB, theo microcopy EXPERIENCE.md; sinh lại bằng `flutter gen-l10n`.
- Không màu đỏ hay token mới; icon, vòng, nút chỉ dùng `accent`/`track`/`ink-*` (UX-DR2). Vòng và `AnimationController` được hủy trong `dispose`, không gọi xác nhận sau khi dialog đã gỡ.

**Never:**
- Không sửa `account_service`, `wipe_coordinator`, `lockout_guard`, `session_gate` (đã đủ đường S5), codec hay fixture. Features không import `wipe_coordinator`/`core/guard`.
- Không dựng `ModalPresenter`, không nối clipboard (Epic 3), không tách `corrupt`/KDF lỗi (2.5).
- Không xóa trực tiếp trong widget; mọi xóa đi qua `wipe()` của S5.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Mở S4 | S3 idle/sai/chờ/hỏng, bấm nút | Dialog hiện đủ title, body, vòng, nhãn, "Hủy"; không ô mật khẩu | N/A |
| Giữ đủ | Nhấn giữ 3 giây | Dialog đóng, S5 hiện, `wipe()` gọi 1 lần, xong S1 | `WipeFailed` → S1 vô hiệu (như 2.3) |
| Nhả sớm | Giữ 1,5 giây rồi nhả | Vòng ngược về 0, dialog còn, không `wipe()` | N/A |
| Tap nhanh | Chạm < 3 giây | Không làm gì, không thông báo | N/A |
| Hủy | Bấm "Hủy" (có thể lúc đang giữ) | Dialog đóng, S3 nguyên trạng, không `wipe()` | N/A |
| Back Android | Back khi mở, hoặc đang giữ | Đóng dialog, hủy giữ, không `wipe()`; S3 không bị pop | N/A |
| Chạm ngoài | Chạm vùng scrim | Dialog không đóng | N/A |
| Đang kiểm tra | `_busy` | Nút xóa vô hiệu | N/A |
| Đang chờ 5–9 | `login.lockout` đếm ngược | Nút xóa bấm được; đếm ngược vẫn chạy dưới dialog | N/A |

</frozen-after-approval>

## Code Map

- `pak_manager/lib/features/auth/login_screen.dart` -- `build` :226 + `_s3` :263: thay `SingleChildScrollView` bằng bố cục có hàng xóa ghim đáy (đáy cách 42, cao 44; gợi ý `CustomScrollView` + `SliverFillRemaining(hasScrollBody: false)` để dồn xuống đáy mà vẫn cuộn được); thêm `_openErase()` mở S4, nhận `true` thì gọi `widget.onWipe`. Giữ `_row` và key hàng (dựng lại `SecretField` sẽ `clear()` ô). Sửa doc đầu class. `onWipe` :86 dùng lại, cập nhật doc.
- `pak_manager/lib/features/auth/erase_dialog.dart` -- **mới**: S4. Hàm mở dialog trả `Future<bool>`; barrier `scrim`, không đóng khi chạm ngoài; `PopScope` hủy giữ.
- `pak_manager/lib/features/shared/hold_confirm_button.dart` -- **mới**: `HoldConfirmButton(onConfirmed, semanticLabel)`; `AnimationController` 3 giây, `Listener` pointer down/up/cancel, `CustomPainter` vòng; xác nhận một lần khi `completed`.
- `pak_manager/lib/features/shared/pak_buttons.dart` -- `PakTextButton` :80 (rowHeight 44, `accent`) dùng cho nút xóa và có thể cho "Hủy"; không đổi trừ khi cần `Semantics`.
- `pak_manager/lib/features/shared/theme/{pak_spacing,pak_radius,pak_colors,pak_text_styles}.dart` -- đã có `holdButton` 72, `rowHeight`, `alert` 14, `track`, `scrim`, `surfaceRaised`, `separator`; không thêm.
- `pak_manager/lib/features/shared/session_gate.dart` -- `didPopRoute` :156 đã chuyển Back cho navigator (`maybePop` đóng route dialog); `_startWipe` :84 đã dựng S5. Chỉ đọc.
- `pak_manager/lib/l10n/app_{vi,en}.arb` -- thêm 5 key (en có `@key` description); chạy `flutter gen-l10n`.
- `pak_manager/test/support/account_fakes.dart` -- `pumpGateApp`, `FakeAccountService.wipe/completeWipe/wipeCalls` đã có; dùng lại.
- `pak_manager/test/features/auth/login_screen_test.dart` -- thêm case S3/S4; `test/features/shared/hold_confirm_button_test.dart`, `test/features/auth/erase_dialog_test.dart` -- mới. `ux_dr31_s3_spacing_*` :85 phải còn xanh.

## Tasks & Acceptance

**Execution:**
- [x] `lib/l10n/app_{vi,en}.arb` -- thêm `loginErase`, `eraseTitle`, `eraseBody`, `eraseHold`, `commonCancel`; `flutter gen-l10n` -- chuỗi vi/en
- [x] `lib/features/shared/hold_confirm_button.dart` -- nút giữ 3 giây, vòng chạy xuôi/ngược, xác nhận một lần -- UX-DR14
- [x] `lib/features/auth/erase_dialog.dart` -- S4 alert-dialog, chỉ "Hủy", `PopScope`, không đóng khi chạm ngoài -- UX-DR13, UX-DR50
- [x] `lib/features/auth/login_screen.dart` -- hàng "Xóa & Tạo tài khoản mới" ghim đáy, vô hiệu khi `_busy`, nối S4 → `onWipe` -- UX-DR31, UX-DR42
- [x] `test/features/shared/hold_confirm_button_test.dart` -- vòng 0 → 1 trong 3 giây (giữa chừng ~0,5 ở 1,5 giây), nhả sớm chạy ngược, tap nhanh, xác nhận đúng một lần, hủy chạm, dispose giữa lúc giữ không gọi
- [x] `test/features/auth/erase_dialog_test.dart` -- nội dung, kích thước 270, chỉ một nút "Hủy", chạm ngoài không đóng, Back đóng (cả lúc giữ), en
- [x] `test/features/auth/login_screen_test.dart` -- các dòng Matrix ở mức S3: nút ở đáy cao 44/cách mép 42 và dưới nút Đăng nhập, bấm được ở idle/sai/chờ/hỏng, vô hiệu khi busy, giữ đủ → S5 + `wipeCalls` 1 → S1, hủy/nhả sớm → `wipeCalls` 0 và ô giữ nội dung

**Acceptance Criteria:**
- Given test mới, when đọc tên, then mỗi tên bắt đầu bằng id thật đệm 2 chữ số (`fr09_`, `ux_dr13_`, `ux_dr14_`, `ux_dr31_`, `ux_dr42_`, `ux_dr50_`, `uj04_`).
- Given `lib/`, when chạy `check_imports`, then OK; features không import `wipe_coordinator`/`core/guard`; không file sinh nào lệch sau `gen-l10n`.
- Given S3 (VI) có tài khoản, when bấm "Xóa & Tạo tài khoản mới" rồi giữ đủ 3 giây, then thấy S4 đúng nội dung, sau đó "Đang xóa dữ liệu…" một mình giữa màn, rồi S1; mở lại app thấy S1 và tạo tài khoản mới không còn dữ liệu cũ (UJ-4 nhánh A).

## Implementation Notes

- S4 mở bằng `showGeneralDialog` (`useRootNavigator: false`, `barrierDismissible: false`, barrier `scrim`, mờ dần 150 ms) trên navigator của gate. `PopScope(canPop: false)` đổi Back thành "Hủy", kể cả lúc đang giữ; gỡ dialog hủy lần giữ vì `AnimationController` bị `dispose`.
- `HoldConfirmButton`: `Listener` pointer down/up/cancel, một con trỏ duy nhất; nhả sớm chạy ngược trong 600 ms (`reverseDuration`), mỗi lần nhấn (kể cả nhấn lại khi vòng còn đang lùi) chạy lại từ 0 bằng `forward(from: 0)`, nên một lần giữ luôn là 3 giây liên tục. `AnimationController` báo `completed` ở khung hình sau mốc 3 giây (test pump 3001 ms).
- Các khoảng đệm trong dialog (20 trên, 16 hai bên, 4 giữa tiêu đề và thân, 16 trên hairline) do triển khai chọn vì spec và DESIGN.md không cho số; hằng số có tên trong `erase_dialog.dart`.
- Hàng xóa dùng `CustomScrollView` + `SliverFillRemaining(hasScrollBody: false)`: đáy cách 42, cách nút "Đăng nhập" tối thiểu 24 khi màn thấp hoặc có bàn phím.
- Hai assertion danh sách chữ trong `login_screen_test.dart` được thêm chữ của nút mới.
- Chưa chạy trên máy/emulator (AC3 kiểm bằng widget test `fr09_uj04_hold_full_goes_s4_to_s5_to_s1_with_one_wipe`). Chưa có hành động thay thế trợ năng cho hold-confirm-button: đã ghi `DW-2.4-1` ở review.
- Kiểm chứng trước review: `flutter analyze --fatal-infos --fatal-warnings` sạch, `check_imports` OK, `gen-l10n` lần hai không đổi, `flutter test` 1081 test: 1 fail là teardown của Windows chỉ xuất hiện khi chạy cả bộ (`lockout_guard_test`, pass khi chạy riêng; `DW-2.1-1`), 20 skip như cũ.

## Spec Change Log

## Review Triage Log

Review vòng 1 (2026-11-22): blind-hunter, edge-case-hunter, verification-gap; không lớp nào lỗi. Trước review: `flutter test` 1081 pass, 20 skip, 1 fail (teardown Windows `DW-2.1-1`, pass khi chạy riêng).

| # | Nguồn | Phát hiện | Verdict | Bằng chứng | Route |
|---|---|---|---|---|---|
| 1 | blind, edge-case | Nhấn lại khi vòng còn đang lùi chạy xuôi tiếp từ giá trị hiện tại, nên giữ rời rạc dưới 3 giây vẫn xác nhận xóa | medium | Đúng: `_down` gọi `forward()` không `from`; trái "3 giây kể từ lúc nhấn" của spec, và hành động không hoàn tác | patch (`forward(from: 0)` + test nhấn lại) |
| 2 | verification-gap | Không test nút xóa khi `attemptsLeft` 0; gắn nút vào `attemptsLeft` vẫn qua CI, người dùng hết lượt chỉ còn nút vô hiệu | low | Đã tìm: mọi test mở S4 dùng `attemptsLeft` ≥ 5 | patch (thêm test) |
| 3 | blind, edge-case, verification-gap | Hold-confirm-button không có hành động trợ năng (VoiceOver/TalkBack); dialog thiếu `Semantics(scopesRoute/namesRoute)`, `barrierLabel`; nhãn và chữ `erase.hold` bị đọc hai lần | medium | Đúng: chỉ `Semantics(button, label)` và `Listener`; spec (Design Notes) chủ ý chưa làm và dặn ghi DW; planning không có NFR trợ năng riêng cho nút | defer → `DW-2.4-1` |
| 4 | blind | Mục DW trợ năng chưa ghi | low | Hệ quả của #3, đã ghi `DW-2.4-1` | defer (gộp #3) |
| 5 | blind, edge-case, verification-gap | Kéo ngón ra khỏi nút vẫn tiếp tục đếm 3 giây và có thể xác nhận | low | Đúng nhưng người dùng đã chủ động mở S4 và đang giữ; spec chỉ nói "nhả hoặc hủy chạm"; sửa thêm nhánh `onPointerMove` và kiểm biên | reject |
| 6 | blind, edge-case | Ứng dụng vào nền giữa lúc giữ mà không có `PointerCancel` thì khi quay lại controller có thể báo `completed` | low | Chưa chứng minh: iOS/Android thường gửi cancel khi mất focus; cần hai điều kiện hiếm cùng lúc; sửa cần `WidgetsBindingObserver` | reject |
| 7 | blind, edge-case | Dialog là `Column` cố định, không cuộn: chữ rất lớn hoặc màn thấp có thể tràn | low | Dialog cao khoảng 250 pt ở cỡ chữ thường; điện thoại khóa dọc theo `orientation.dart`; sửa thêm cuộn/ràng buộc | reject |
| 8 | edge-case | Nút xóa trong `SizedBox` cao 44 cố định, chữ lớn bị cắt | low | Chiều cao 44 do UX-DR31 chốt; `Text` không ném lỗi tràn | reject |
| 9 | blind, edge-case | `onWipe == null` hoặc `!mounted` thì kết quả xác nhận bị bỏ im lặng | false | `SessionGate` luôn truyền `onWipe`; S3 chỉ bị gỡ khi gate đổi kết quả, không xảy ra khi dialog modal đang mở. Trùng #6 của 2.3 | reject |
| 10 | blind | Xóa thủ công lỗi thì S1 vô hiệu, không retry, không về S3 | false | Đúng như spec đã duyệt ("như lần sai thứ 10"); `markWiping` chạy đầu nên lần mở sau xóa nốt. Trùng #12 của 2.3 | reject |
| 11 | edge-case | `onWipe` chạy khi S4 còn đang mờ dần 150 ms, S5 chồng lên dialog | false | `_startWipe` đặt navigator key mới, gỡ cả `Navigator` cũ cùng route dialog ngay khung đó; test `fr09_uj04_hold_full_goes_s4_to_s5_to_s1_with_one_wipe` không thấy `EraseDialog` | reject |
| 12 | blind | Màu text không qua `CupertinoDynamicColor.resolve`, chưa test chế độ tối | low | Cùng quy ước với `LoginScreen`/`WipingScreen` hiện có; theme test có sẵn; thêm test tối là hạ tầng mới | reject |
| 13 | blind | Test trùng helper (`_erase`, pump S3), `scrollToEnd` dùng `Scrollable.first`, kích thước mặc định 800x600 | low | Test đang xanh, không có tình huống làm hỏng; gom helper là việc cấp epic | reject |
| 14 | blind | Không có haptic/âm khi bắt đầu và khi xác nhận | false | UX-DR51: "không có haptic tùy biến" | reject |

Sau patch: `flutter analyze --fatal-infos --fatal-warnings` sạch, `check_imports` OK, `gen-l10n` lần hai không đổi, `flutter test` 1084 pass, 20 skip, 0 fail.

## Design Notes

Nút xóa vô hiệu lúc `_busy` là ngoại lệ có chủ ý của "luôn bấm được": `unlock` đang chạy KDF có thể ghi `recordSuccess` sau khi xóa, nên không cho hai việc chạy chồng. Mở S4 khi nút đang bấm được thì `unlock` không thể bắt đầu (dialog là modal), nên chiều ngược lại không cần chặn thêm. Hold-confirm-button không có hành động thay thế cho trợ năng (VoiceOver/TalkBack); nếu cần, ghi thành mục `deferred-work.md` khi review.

## Verification

**Commands:**
- `cd pak_manager && flutter gen-l10n` -- expected: chạy lần hai không đổi file trong `lib/l10n/`
- `cd pak_manager && flutter analyze --fatal-infos --fatal-warnings` -- expected: sạch
- `cd pak_manager && dart run tool/check_imports.dart` -- expected: không vi phạm
- `cd pak_manager && flutter test` -- expected: tất cả pass (trừ teardown `DW-2.1-1` đã biết), số test tăng, không thêm skip

### Review Findings

Review vòng 2 (2026-11-22, `bmad-code-review`): blind-hunter, edge-case-hunter, verification-gap, acceptance-auditor; không lớp nào lỗi.

- [x] [Review][Patch] Khóa hành vi "42 tính từ safe-area" bằng test có padding đáy (quyết định: giữ nguyên, 42 đo từ safe-area như phần đầu màn đo từ status bar) — thêm biến thể của `ux_dr31_fr09_erase_button_pinned_bottom_44_inset_42` với `view.padding`/`viewPadding` đáy 34, khẳng định `safeBottom - erase.bottom == 42` [pak_manager/test/features/auth/login_screen_test.dart]
- [x] [Review][Dismiss] Hoạt ảnh mờ dần 150 ms của S4 trái UX-DR51 — quyết định: giữ hiệu ứng như spec 2.4 đã duyệt; không đổi code. Ghi nhận spec ghi đè UX-DR51, cần chỉnh planning (UX-DR51/EXPERIENCE.md) sau.
- [x] [Review][Patch] Hold-confirm-button chạy 5% thời gian khi bật Reduce Motion/Remove animations — `AnimationController` mặc định `AnimationBehavior.normal` nên khi `disableAnimations` là true, 3 giây rút còn ~150 ms: một chạm xóa vĩnh viễn vault, mất chốt an toàn của FR-9/UX-DR14. Sửa: `animationBehavior: AnimationBehavior.preserve` + test đặt `disableAnimations` [pak_manager/lib/features/shared/hold_confirm_button.dart:66]
- [x] [Review][Patch] Chữ trong `EraseDialog` không qua `CupertinoDynamicColor.resolve` — tiêu đề, thân, nhãn và `DefaultTextStyle` dùng thẳng `PakColors.inkPrimary/inkSecondary`; nền thì đã resolve. Đã chạy thử: `Text` dưới `CupertinoApp` tối vẫn nhận `0xff000000`, nên ở chế độ tối là chữ đen trên nền `surface-raised` tối, đọc không được lời cảnh báo xóa vĩnh viễn. Sửa: resolve cả bốn màu chữ + test độ sáng tối [pak_manager/lib/features/auth/erase_dialog.dart:91]
- [x] [Review][Defer] Ứng dụng vào nền giữa lúc giữ mà không có `PointerCancel` có thể báo `completed` khi quay lại [pak_manager/lib/features/shared/hold_confirm_button.dart:85] — deferred: chưa chứng minh (maybe-false, nếu thật là medium); cần thử trên máy thật: giữ nút rồi để cuộc gọi/thông báo chen vào quá 3 giây, xem `onConfirmed` có chạy khi quay lại không → `DW-2.4-2`
- [x] [Review][Defer] Màu chữ `PakColors.ink*` dùng thẳng không resolve ở màn khác (`login_screen.dart:269`, `wiping_screen.dart:71`, `create_account_screen.dart:211`, `inline_message.dart:37`) [pak_manager/lib/features/auth/login_screen.dart:269] — deferred: có từ trước story 2.4, cùng nguyên nhân với patch trên → `DW-2.4-3`

Vòng 2 đã áp dụng cả 3 patch: `AnimationBehavior.preserve` cho nút giữ (test `ux_dr14_fr09_reduce_motion_keeps_full_3_second_hold`), resolve màu chữ `EraseDialog` (test `ux_dr13_ux_dr2_dialog_text_colors_resolve_in_dark_mode`), test padding đáy (`ux_dr31_fr09_erase_bottom_42_measured_from_safe_area`; `pumpGateApp` thêm tham số `appearance`). Hai test đầu đã kiểm fail khi bỏ phần sửa. `flutter analyze --fatal-infos --fatal-warnings` sạch, `check_imports` OK, `flutter test` 1087 pass, 20 skip, 0 fail.

#### Rejected

- sprint-status `last_updated` lùi từ 17:30 xuống 17:26 (blind, edge-case): low; bước 6 của workflow này ghi đè `last_updated`.
- Metadata spec lệch (`status: done` so với `review`, `review_loop_iteration: 0`, Spec Change Log trống) (blind, acceptance): sửa là sửa chính spec đang review; bước 6 đặt lại `status`.
- Kéo ngón ra khỏi nút vẫn xác nhận được (blind): low, trùng #5 vòng 1; người dùng đã chủ động giữ, sửa cần thêm nhánh `onPointerMove`.
- Dialog tràn/cắt "Hủy" ở chữ rất lớn, nút xóa 44 cố định cắt chữ Anh (blind): low; planning không đặt sàn trợ năng, epics ghi `textScaler` kẹp ≤ 1,3 ở gốc app (epics.md:154), dialog cao ~250 pt ở cỡ thường.
- Người đọc màn hình không xóa được; dialog thiếu `scopesRoute/namesRoute`, `barrierLabel`; nhãn đọc hai lần (blind, acceptance, verification-gap): trùng `DW-2.4-1` đã ghi.
- AC3 chưa kiểm đầu-cuối với `AccountService` thật, chưa chạy trên máy (blind, acceptance): low; `wipe()` thật đã có test ở story 2.3, thêm test tích hợp là việc ngoài story; nên chạy tay một lần với `--flavor dev` trước khi merge.
- `onWipe == null` hoặc `!mounted` thì bỏ im lặng (blind, edge-case): false; nút xóa chỉ vẽ khi `hasAccount`, và `SessionGate` luôn truyền `onWipe` cho `BootstrapHasAccount` (`session_gate.dart:209-213`); `unavailable`/no-account không có nút.
- Tổ hợp `hasAccount` + `unavailable` chưa test (edge-case): false; `BootstrapUnavailable` luôn dựng `hasAccount: false`.
- Nhấn nút xóa hai lần liền chồng hai dialog (edge-case, verification-gap): low; cần hai chạm trong cùng một khung hình, sửa thêm cờ chặn.
- `barrierColor` giữ màu cũ khi đổi sáng/tối lúc S4 đang mở (edge-case): low; hiếm và chỉ là màu scrim.
- S1 đổi từ `SingleChildScrollView` sang `CustomScrollView` chưa có test hồi quy riêng (edge-case): low; test bố cục S1 hiện có vẫn pass (1084 pass), không có tình huống lỗi cụ thể.
- Không test nào kiểm mờ dần 150 ms (verification-gap): low; chuyển theo quyết định về UX-DR51 ở trên.
- Test dễ vỡ (finder theo thứ tự, so sánh số thực chính xác, helper trùng), hằng `holdIconSize`/600 ms tự đặt, icon cứng trong widget `shared` (blind): low; không có nơi nào gây hỏng cụ thể, test đang xanh.
