---
name: PAK Manager
status: final
sources:
  - _bmad-output/planning-artifacts/prds/prd-passwordmanager-2026-10-23/prd.md
  - _bmad-output/planning-artifacts/prds/prd-passwordmanager-2026-10-23/addendum.md
created: 2026-10-26
updated: 2026-10-27
---

# PAK Manager — Experience Spine

> Spine này nói app **hoạt động** thế nào; thị giác nằm ở [`DESIGN.md`](DESIGN.md). Hành vi lấy từ PRD được dẫn bằng mã FR/NFR — đọc PRD để biết chi tiết, spine không chép lại. Mọi quyết định không truy được về memlog, PRD hay mock đã duyệt đều được gắn **[ASSUMPTION]**.
>
> Mỗi surface có mock đã duyệt (light + dark) trong [`mockups/`](mockups/) — cột **Mock** ở Bảng surface. Những chi tiết PRD và ảnh không có, mock tự bổ sung (ghi trong comment `<style>` đầu mỗi file); các chi tiết này đã được duyệt cùng mock và được nâng vào đây. **Hai spine thắng mọi mâu thuẫn với `mockups/` và ảnh tham chiếu trong `imports/`.**
>
> ADD = addendum của PRD; memlog = nhật ký quyết định của chủ sản phẩm ([`.memlog.md`](.memlog.md)). Số memlog (Q…) chỉ được ghi khi quyết định ghi đè PRD hoặc khác ảnh tham chiếu.

## Foundation

- **Form factor:** iOS + Android, **điện thoại và máy tính bảng** (NFR-12). Chỉ có một dạng sản phẩm: app native. Không web, không desktop.
- **UI system:** **iOS native look (UIKit/SwiftUI, SF Pro) trên cả hai nền tảng**. Trên Android, app vẽ lại cùng dáng iOS; với Android, spine này chỉ ghi phần hành vi **khác** mặc định iOS. Xem Responsive & Platform.
- **Visual identity:** `DESIGN.md` — token tham chiếu bằng cú pháp `{colors.accent}`, `{typography.body}`, `{spacing.margin}`…
- **Mẫu bám theo:** Kaspersky Password Manager — xem Inspiration & Anti-patterns.
- **Bối cảnh:** dự án cá nhân (hobby), một người dùng mỗi máy, offline hoàn toàn (NFR-7). Không có trạng thái mạng nào trong app.
- **Ngôn ngữ UI:** English + Tiếng Việt cho mọi chuỗi (NFR-14); mặc định theo ngôn ngữ máy (FR-47).
- **Giao diện:** Theo hệ thống / Sáng / Tối, mặc định Theo hệ thống (FR-47, NFR-13).

## Information Architecture

### Mô hình điều hướng

- **Trước đăng nhập:** chỉ có Login (hai trạng thái: chưa có / đã có tài khoản). Không có tab bar. Mọi surface khác chỉ dùng được sau đăng nhập (F1).
- **Sau đăng nhập:** **tab-bar 3 tab** — **Quản lý mật khẩu** · **Tạo mật khẩu** · **Cài đặt**; tab mặc định là Quản lý mật khẩu (FR-45). Mỗi tab giữ trạng thái riêng khi chuyển tab (mặc định iOS).
- **Ngăn xếp modal:** tối đa **2 tầng sheet** — form card (page-sheet) → sheet tạo mật khẩu (bottom-sheet). alert-dialog có thể nằm trên bất kỳ tầng nào và không tính là tầng sheet. Không có sheet thứ ba.
- **Khóa** (FR-14, FR-15, FR-49) gỡ toàn bộ ngăn xếp và về Login (đã có tài khoản).

### Bảng surface

| ID | Surface | Dạng | Vào từ | Chứa / hành vi chính | Flow | Mock |
|---|---|---|---|---|---|---|
| S1 | Login — chưa có tài khoản | Màn gốc | Lần đầu mở; sau xóa (FR-4 lần 10, FR-9); sau cài lại (FR-11) | "PAK Manager" + button-primary "Tạo tài khoản" (FR-1) | UJ-3, UJ-4 | [`onboarding.html`](mockups/onboarding.html) |
| S2 | Tạo tài khoản | Màn push từ S1 | S1 | Cảnh báo quên = mất hết; mật khẩu chính + nhập lại; strength-meter; inline-message (FR-1, FR-2) | UJ-3, UJ-4 | [`onboarding.html`](mockups/onboarding.html) |
| S3 | Login — đã có tài khoản | Màn gốc | Mở app; mọi lần khóa | Ô mật khẩu chính, "Đăng nhập", số lần thử còn lại, đếm ngược, "Dữ liệu bị hỏng", nút "Xóa & Tạo tài khoản mới" ở **đáy màn**, xa nút Đăng nhập (FR-3–FR-9, ADD) | UJ-1, UJ-2, UJ-4 | [`login.html`](mockups/login.html) · [`login-states.html`](mockups/login-states.html) |
| S4 | Dialog "Xóa & Tạo tài khoản mới" | alert-dialog + hold-confirm-button | S3 | Giữ 3 giây để xóa (FR-9); chỉ có nút "Hủy" | UJ-4 | [`login-states.html`](mockups/login-states.html) |
| S5 | Đang xóa dữ liệu | Màn trung gian | Lần sai thứ 10; S4 hoàn tất; mở app sau lần xóa bị gián đoạn (FR-12) | activity-indicator + một dòng chữ; không nút; tự chuyển S1 | UJ-4 | [`onboarding.html`](mockups/onboarding.html) |
| S6 | Dialog "Tiếp tục bản nháp?" | alert-dialog | Ngay sau đăng nhập khi có bản nháp (FR-26) | "Tiếp tục" → S9/S10 có dữ liệu nháp; "Bỏ bản nháp" → hủy bản nháp. Nền: khung S7 chưa hiện danh sách | (Key Flows: failure UJ-2) | [`login-states.html`](mockups/login-states.html) |
| S7 | Tab Quản lý mật khẩu | Tab 1 | tab-bar; mặc định sau đăng nhập | search-bar, danh sách credential-card, fab-new-card, empty-state (FR-17–FR-21) | UJ-1, UJ-2, UJ-3 | [`password-list.html`](mockups/password-list.html) · [`card-actions.html`](mockups/card-actions.html) (không có kết quả) |
| S8 | Menu card | popup-menu | ⋯ trên credential-card | "Sửa" / "Xóa" (FR-23) | — | [`card-actions.html`](mockups/card-actions.html) |
| S9 | Sheet Card mới | page-sheet | fab-new-card; S6 | 4 field + nút "Tạo mật khẩu" dưới field Mật khẩu, giống S10; "Hủy" / "Lưu" (FR-21, FR-22, FR-24, FR-26) | UJ-2 | [`card-actions.html`](mockups/card-actions.html) |
| S10 | Sheet Sửa card | page-sheet | S8 → Sửa; S6 | 4 field + nút "Tạo mật khẩu" dưới field Mật khẩu; "Hủy" / "Lưu" (FR-24, FR-26) | — | [`edit-card-sheet.html`](mockups/edit-card-sheet.html) |
| S11 | Sheet tạo mật khẩu | bottom-sheet **chồng trên S9 hoặc S10** | S9 / S10 → "Tạo mật khẩu" | Theo [`imports/edit_pass.jpg`](imports/edit_pass.jpg); FR-28–FR-36 | — | [`edit-card-sheet.html`](mockups/edit-card-sheet.html) |
| S12 | Dialog "Bỏ thay đổi?" | alert-dialog | S9/S10: bấm "Hủy" hoặc vuốt xuống khi đã có thay đổi | "Bỏ thay đổi" (= chủ động bỏ, hủy bản nháp — FR-26) / "Tiếp tục sửa" | — | [`card-actions.html`](mockups/card-actions.html) |
| S13 | Dialog xác nhận xóa card | alert-dialog | S8 → Xóa | FR-25 | — | [`card-actions.html`](mockups/card-actions.html) |
| S14 | Tab Tạo mật khẩu | Tab 2 | tab-bar | Theo [`imports/password_generator.jpg`](imports/password_generator.jpg), bỏ nút Back (FR-27) | UJ-2 | [`generator.html`](mockups/generator.html) |
| S15 | Picker Password Length | wheel-picker trong panel đáy (memlog Q6a) | Hàng "Độ dài mật khẩu" ở S14 | 4–99 (FR-29); nút "Xong" | UJ-2 | [`generator-extras.html`](mockups/generator-extras.html) |
| S16 | Sheet Mật khẩu gần đây (Recent) | page-sheet | Icon lịch sử ở S14 | Theo [`imports/recent_password.jpg`](imports/recent_password.jpg), **mới nhất ở trên** (FR-37–FR-43); "Đóng", "Xóa hết" | UJ-2 | [`generator-extras.html`](mockups/generator-extras.html) |
| S17 | Dialog xác nhận "Xóa hết" (Clear) | alert-dialog | S16 → "Xóa hết" | FR-42; chỉ tiêu đề, không thân | — | [`generator-extras.html`](mockups/generator-extras.html) |
| S18 | Tab Cài đặt | Tab 3 | tab-bar | Theo [`imports/setting.jpg`](imports/setting.jpg) đã chỉnh (bảng dưới; FR-46–FR-50) | UJ-3 | [`settings.html`](mockups/settings.html) |
| S19 | Picker cài đặt | popup-menu | Các hàng thời gian, Ngôn ngữ, Giao diện ở S18 | 1/3/5/10 phút (FR-46); English/Tiếng Việt; Theo hệ thống/Sáng/Tối (FR-47) | — | [`settings.html`](mockups/settings.html) |
| S20 | Đổi mật khẩu chính (Change Main Password) | Màn push trong tab Cài đặt | S18 | Mật khẩu cũ → mới (FR-2) → nhập lại (FR-13, FR-48); nút "Đổi mật khẩu" | — | [`settings.html`](mockups/settings.html) |
| S21 | Export — Bước 1: mật khẩu chính | page-sheet "Export" | S18 → Export | Nhập lại mật khẩu chính (FR-51); "Hủy" / "Tiếp tục" | UJ-3 | [`export-import.html`](mockups/export-import.html) |
| S22 | Export — Bước 2: mật khẩu export | Bước 2 push trong cùng sheet, back chỉ chevron | S21 | Mật khẩu export + nhập lại, strength-meter, dòng gợi ý, cảnh báo, "Tạo file" (FR-52) | UJ-3 | [`export-import.html`](mockups/export-import.html) |
| S23 | Menu chia sẻ OS | Hệ thống | S22 tạo file xong | FR-55 | UJ-3 | — (UI hệ thống) |
| S24 | Trình chọn file OS | Hệ thống | S18 → Import | FR-56 | UJ-3 | — (UI hệ thống) |
| S25 | Import — mật khẩu export | page-sheet "Import" | S24, khi file đã chọn qua được kiểm tra định dạng | Ô mật khẩu export, "Hủy" / "Tiếp tục"; sai không giới hạn (FR-56) | UJ-3 | [`export-import.html`](mockups/export-import.html) |
| S26 | Dialog xem trước Import | alert-dialog, tiêu đề "Import" | S25 giải mã xong | Số card + ngày export; "Hủy" / "Xác nhận" (FR-57) | UJ-3 | [`export-import.html`](mockups/export-import.html) |
| S27 | Alert "File không hợp lệ" | alert-dialog | S24 sau khi chọn file (FR-56, FR-63) | Nút "OK"; không có gì thay đổi | UJ-3 (failure) | [`export-import.html`](mockups/export-import.html) |
| S28 | Toast | toast | Mọi Copy (FR-64); Import xong (FR-57); đổi mật khẩu chính xong [ASSUMPTION] | "Đã copy", "Đã thêm N card"… | UJ-1, UJ-2, UJ-3 | [`card-actions.html`](mockups/card-actions.html) · [`export-import.html`](mockups/export-import.html) |

Flow "—" = FR yêu cầu nhưng không thuộc UJ nào (memlog Q19b).

**Lock Vault** ("Khóa Vault") không phải surface mà là hàng hành động ở S18 → khóa ngay → S3 (FR-49).

### Tab Cài đặt — nhóm và thứ tự

Nhóm và thứ tự theo memlog Q15a; mock: [`settings.html`](mockups/settings.html).

| Khối | Header (VI / EN) | Hàng (VI) | Control |
|---|---|---|---|
| 1 | CHUNG / GENERAL | Tự khóa (Autolock Vault) · Giới hạn phiên · Tự xóa clipboard (Clear Clipboard) | list-row giá trị + ⌃⌄ → S19 (FR-46) |
| 2 | NGÔN NGỮ & GIAO DIỆN / LANGUAGE & APPEARANCE | Ngôn ngữ · Giao diện | list-row giá trị + ⌃⌄ → S19 (FR-47) |
| 3 | DỮ LIỆU / DATA | Import · Export (dòng phụ "Lần export gần nhất: dd/MM/yyyy" / "Chưa export lần nào") | list-row chevron (FR-50) |
| 4 | — | Đổi mật khẩu chính | button-text trong ô riêng |
| 5 | — | Khóa Vault | button-text trong ô riêng |

Tên hàng EN lấy theo ảnh / PRD; xem microcopy `settings.rows`.

## Voice and Tone

Giọng: **ngắn gọn, trung tính, xưng "bạn"**. Cảnh báo nói thẳng hậu quả, không giảm nhẹ, không dọa. Không dấu chấm than, không emoji, không khen ngợi. Bản English có cùng giọng.

| Do | Don't |
|---|---|
| "Đã copy" | "Copy thành công! ✓" |
| "Còn 3 lần thử trước khi dữ liệu bị xóa." | "Cẩn thận!!! Bạn sắp mất dữ liệu" |
| "Không có cách khôi phục mật khẩu chính." | "Đừng lo, hãy nhớ kỹ mật khẩu nhé" |
| Nói lý do khi từ chối (FR-2) | "Mật khẩu không hợp lệ." không kèm lý do |

### Microcopy

Cột **Nguồn**: `PRD` = chuỗi nguyên văn hoặc tên tham chiếu trong PRD; `memlog` = chuỗi chủ sản phẩm đã chốt, kể cả nhãn do mock tự đặt rồi được duyệt; `mock` = chuỗi VI đã hiện trong mock được duyệt ([`mockups/`](mockups/)) — coi là đã duyệt; `ảnh` = chuỗi EN lấy nguyên văn từ ảnh tham chiếu `imports/`; `[A]` = câu chữ là [ASSUMPTION — đã ghi memlog]: bản nháp, chỉnh được trong lúc build. Mock chỉ vẽ tiếng Việt, nên mọi bản EN không phải `PRD` / `ảnh` vẫn là `[A]`. Tên tham chiếu tiếng Anh từ ảnh được giữ nguyên trong bản EN. `{N}`, `{date}`, `{query}`, `{title}`, `{mm:ss}` là biến. Cột **Vị trí** chỉ ghi khi chỗ đặt chuỗi không hiển nhiên. Cặp nút (`*.actions`) ghi theo thứ tự trái → phải.

**Điều hướng & nhãn chung**

| Khóa | VI | EN | Vị trí | Nguồn |
|---|---|---|---|---|
| app.name | PAK Manager | PAK Manager | Tiêu đề lớn S1, S3 | PRD |
| tab.cards | Quản lý mật khẩu | Passwords | Tab 1 + tiêu đề nav S7 | PRD (VI) · [A] (EN) |
| tab.generator | Tạo mật khẩu | Generator | Tab 2 | PRD (VI) · [A] (EN) |
| tab.settings | Cài đặt | Settings | Tab 3 + tiêu đề nav S18 | PRD |
| generator.title | Tạo mật khẩu | Password Generator | Tiêu đề nav S14 | PRD (EN) · mock (VI) |
| recent.title | Mật khẩu gần đây | Recent Passwords | Tiêu đề S16 | PRD (EN) · mock (VI) |
| common.cancel / save / close / ok | Hủy / Lưu / Đóng / OK | Cancel / Save / Close / OK | | PRD (Hủy, Lưu, Close) · mock (VI) · [A] (EN) |
| common.continue | Tiếp tục | Continue | button-primary S21, S25 | mock (VI) · [A] (EN) |
| common.done | Xong | Done | Thanh trên wheel-picker S15 | mock (VI) · [A] (EN) |
| card.field.* | Tiêu đề · Tên đăng nhập · Mật khẩu · Ghi chú | Title · Username · Password · Note | Nhãn trên card và trên ô form S9/S10 | PRD (Note) · mock (VI) · [A] (EN) |
| card.menu | Sửa / Xóa | Edit / Delete | | PRD (VI) · [A] (EN) |
| card.new.title / edit.title | Card mới / Sửa card | New Card / Edit Card | Tiêu đề page-sheet S9 / S10 | mock (VI) · [A] (EN) |
| card.generate | Tạo mật khẩu | Generate Password | button-text dưới ô Mật khẩu S9/S10 | PRD (VI) · [A] (EN) |
| card.required | Bắt buộc | Required | **Placeholder** của 3 ô bắt buộc (Tiêu đề, Tên đăng nhập, Mật khẩu); Ghi chú không có placeholder | memlog |
| search.placeholder | Tìm theo tiêu đề | Search by title | | mock (VI) · [A] (EN) |
| generator.length | Độ dài mật khẩu | Password Length | Hàng S14 | PRD (EN) · mock (VI) |
| sheet.length (S11, có dấu hai chấm như ảnh) | Độ dài mật khẩu: | Password Length: | | ảnh (EN) · mock (VI) |
| generator.toggles | Chữ hoa (A–Z) · Chữ thường (a–z) · Chữ số (0–9) · Ký tự đặc biệt | Uppercase Letters (A–Z) · Lowercase Letters (a–z) · Digits (0–9) · Special Characters | | PRD (EN) · mock (VI) |
| sheet.strength | Độ mạnh mật khẩu: Thấp / Trung bình / Cao | Password strength: Low / Medium / High | | PRD (EN) · mock (VI) |
| sheet.use | Dùng mật khẩu này | Use Password | | PRD (EN) · mock (VI) |
| copy | Copy | Copy | | PRD |
| recent.clear | Xóa hết | Clear | Thanh đáy S16 + nút hành động S17 | PRD (EN) · memlog (VI) |
| settings.sections | CHUNG · NGÔN NGỮ & GIAO DIỆN · DỮ LIỆU | GENERAL · LANGUAGE & APPEARANCE · DATA | section-header S18 | ảnh (GENERAL) · memlog (VI) · [A] (EN còn lại) |
| settings.rows | Tự khóa · Giới hạn phiên · Tự xóa clipboard · Ngôn ngữ · Giao diện · Import · Export · Đổi mật khẩu chính · Khóa Vault | Autolock Vault · Session Limit · Clear Clipboard · Language · Appearance · Import · Export · Change Main Password · Lock Vault | | PRD (Giới hạn phiên, Ngôn ngữ, Giao diện, EN reference) · memlog (Tự khóa, Đổi mật khẩu chính, Khóa Vault, Session Limit) · mock (VI còn lại) |
| settings.values | 1 phút … 10 phút · English / Tiếng Việt · Theo hệ thống / Sáng / Tối | 1 min … 10 min · English / Tiếng Việt · System / Light / Dark | Giá trị hàng S18 + mục S19 | PRD (VI) · [A] (EN) |

**Login & tài khoản**

| Khóa | VI | EN | Vị trí | Nguồn |
|---|---|---|---|---|
| login.submit | Đăng nhập | Log In | | PRD (VI) · [A] (EN) |
| login.create | Tạo tài khoản | Create Account | Nút S1, tiêu đề nav + nút S2 | PRD (VI) · [A] (EN) |
| login.erase | Xóa & Tạo tài khoản mới | Erase & Create New Account | | PRD (VI) · [A] (EN) |
| create.warning (bắt buộc, FR-1) | Không có cách khôi phục mật khẩu chính. Nếu quên, bạn sẽ mất toàn bộ dữ liệu. | There is no way to recover your main password. If you forget it, you lose all your data. | Đoạn chữ trên hai ô ở S2 | mock (VI) · [A] (EN) |
| create.field.main | Mật khẩu chính | Main password | **Placeholder** ô đầu S2 (ô Login không có nhãn trên) | memlog |
| create.field.confirm | Nhập lại mật khẩu chính | Re-enter main password | **Placeholder** ô thứ hai S2 | memlog |
| pw.nonAscii (FR-2) | Chỉ dùng chữ không dấu, số, ký hiệu và khoảng trắng. Chữ có dấu có thể bị bàn phím ghi khác đi và khiến bạn không đăng nhập được. | Use only unaccented letters, numbers, symbols and spaces. Accented letters may be typed differently by the keyboard and lock you out. | | mock (VI) · [A] (EN) |
| pw.strength (FR-2, chỉ chữ — memlog override) | Độ mạnh: Thấp / Trung bình / Cao | Strength: Low / Medium / High | | memlog · mock (VI) · [A] (EN) |
| pw.tooShort | Cần ít nhất 15 ký tự (hiện có {N}). | At least 15 characters ({N} so far). | | [A] |
| pw.tooLong | Tối đa 128 ký tự. | 128 characters maximum. | | [A] |
| pw.common | Mật khẩu này quá phổ biến hoặc đã bị lộ. Hãy chọn mật khẩu khác. | This password is too common or has been leaked. Choose another. | | [A] |
| pw.pattern | Không dùng một ký tự lặp lại hoặc một dãy liên tiếp. | Don't use one repeated character or a sequence. | | [A] |
| pw.mismatch | Hai mật khẩu không khớp. | Passwords don't match. | | [A] |
| login.wrong | Sai mật khẩu. | Incorrect password. | | [A] |
| login.attempts (FR-4) | Còn {N} lần thử trước khi dữ liệu bị xóa. | {N} attempts left before your data is erased. | | mock (VI) · [A] (EN) |
| login.lockout (FR-4) | Thử lại sau {mm:ss} | Try again in {mm:ss} | Trên dòng `login.attempts` | mock (VI) · [A] (EN) |
| login.corrupt (FR-7) | Dữ liệu bị hỏng — Mật khẩu đúng nhưng không đọc được dữ liệu. Bạn có thể dùng "Xóa & Tạo tài khoản mới" rồi import lại từ file export. | Data is damaged — The password is correct but the data can't be read. You can use "Erase & Create New Account", then import your export file. | Trên dòng `login.attempts` | PRD ("Dữ liệu bị hỏng") · mock (VI) · [A] (EN) |
| erase.title | Xóa toàn bộ dữ liệu? | Erase all data? | | mock (VI) · [A] (EN) |
| erase.body | Mọi card, Recent và bản nháp sẽ bị xóa vĩnh viễn. Không thể khôi phục. | All cards, recent passwords and drafts will be permanently erased. This can't be undone. | | mock (VI) · [A] (EN) |
| erase.hold | Giữ 3 giây để xóa | Hold for 3 seconds to erase | Dưới hold-confirm-button; nút dialog duy nhất là `common.cancel` | mock (VI) · [A] (EN) |
| wiping | Đang xóa dữ liệu… | Erasing data… | | mock (VI) · [A] (EN) |

S3 không có placeholder trong ô mật khẩu chính.

**Card, Copy, bản nháp, Recent**

| Khóa | VI | EN | Vị trí | Nguồn |
|---|---|---|---|---|
| toast.copied | Đã copy | Copied | | memlog (VI) · [A] (EN) |
| draft.title | Tiếp tục bản nháp? | Continue draft? | | memlog (VI) · [A] (EN) |
| draft.body | Bạn có một card chưa lưu. | You have an unsaved card. | | mock (VI) · [A] (EN) |
| draft.actions | Bỏ bản nháp / Tiếp tục | Discard Draft / Continue | | mock (VI) · [A] (EN) |
| discard.title | Bỏ thay đổi? | Discard changes? | Chỉ tiêu đề, không thân | mock (VI) · [A] (EN) |
| discard.actions | Tiếp tục sửa / Bỏ thay đổi | Keep Editing / Discard | | mock (VI) · [A] (EN) |
| card.delete.title | Xóa card "{title}"? | Delete "{title}"? | | mock (VI) · [A] (EN) |
| card.delete.body | Không thể hoàn tác. | This can't be undone. | | mock (VI) · [A] (EN) |
| card.delete.actions | Hủy / Xóa | Cancel / Delete | | mock (VI) · [A] (EN) |
| empty.cards (FR-20) | Chưa có card nào. Bấm + để lưu thông tin đăng nhập đầu tiên. | No cards yet. Tap + to save your first login. | | mock (VI) · [A] (EN) |
| empty.search | Không có card nào khớp "{query}". | No cards match "{query}". | | mock (VI) · [A] (EN) |
| empty.recent (FR-43) | Chưa có mật khẩu nào. Mật khẩu bạn Copy ở màn hình Tạo mật khẩu sẽ ở đây 72 giờ. | No passwords yet. Passwords you copy in the Generator stay here for 72 hours. | | mock (VI) · [A] (EN) |
| recent.clear.title | Xóa toàn bộ Recent? | Clear all recent passwords? | Chỉ tiêu đề, không thân | mock (VI) · [A] (EN) |
| recent.clear.actions | Hủy / Xóa hết | Cancel / Clear | | memlog · mock (VI) · [A] (EN) |

**Import / Export / Đổi mật khẩu chính**

| Khóa | VI | EN | Vị trí | Nguồn |
|---|---|---|---|---|
| export.title / import.title | Export / Import | Export / Import | Tiêu đề page-sheet S21–S22 / S25 (cùng tên hàng Cài đặt) | memlog |
| export.lastDate (FR-50) | Lần export gần nhất: {dd/MM/yyyy} | Last export: {dd/MM/yyyy} | | PRD (VI) · [A] (EN) |
| export.never (FR-50) | Chưa export lần nào | Never exported | | PRD (VI) · [A] (EN) |
| export.step1 | Nhập mật khẩu chính để tiếp tục. | Enter your main password to continue. | Ở chỗ nhãn, trên ô duy nhất của S21 | mock (VI) · [A] (EN) |
| export.wrongMain | Sai mật khẩu chính. | Incorrect main password. | | mock (VI) · [A] (EN) |
| export.field / export.confirm | Mật khẩu export / Nhập lại mật khẩu export | Export password / Re-enter export password | Nhãn trên ô S22; `export.field` cũng là nhãn ô S25 | memlog |
| export.hint (FR-52, không điền sẵn) | Bạn có thể dùng lại mật khẩu chính làm mật khẩu export. | You can reuse your main password as the export password. | Dưới ô nhập lại, trên `export.warning` | mock (VI) · [A] (EN) |
| export.warning (bắt buộc, FR-52) | Nếu quên mật khẩu export, file này sẽ vô dụng. Không có cách khôi phục. | If you forget the export password, this file is useless. It can't be recovered. | | mock (VI) · [A] (EN) |
| export.create | Tạo file | Create File | | mock (VI) · [A] (EN) |
| import.invalid (FR-56, FR-63) | File không hợp lệ | Invalid file | Tiêu đề S27, không thân | PRD (VI) · [A] (EN) |
| import.wrongPw | Sai mật khẩu export. | Incorrect export password. | | mock (VI) · [A] (EN) |
| import.preview.title | Import | Import | Tiêu đề S26 | memlog |
| import.preview (FR-57) | File có {N} card, export ngày {dd/MM/yyyy}. Thêm vào danh sách? | This file has {N} cards, exported on {dd/MM/yyyy}. Add them? | Thân S26 | mock (VI) · [A] (EN) |
| import.actions | Hủy / Xác nhận | Cancel / Confirm | | PRD (VI) · [A] (EN) |
| import.done (FR-57) | Đã thêm {N} card | Added {N} cards | | PRD (VI) · [A] (EN) |
| change.title | Đổi mật khẩu chính | Change Main Password | Tiêu đề nav S20 (= hàng Cài đặt) | memlog · PRD (EN) |
| change.field.old / new / confirm | Mật khẩu cũ / Mật khẩu mới / Nhập lại mật khẩu mới | Current password / New password / Re-enter new password | Nhãn trên ô S20 | memlog (VI) · [A] (EN) |
| change.submit | Đổi mật khẩu | Change Password | button-primary S20 | mock (VI) · [A] (EN) |
| change.wrongOld (FR-13) | Mật khẩu cũ không đúng. | Current password is incorrect. | Dưới ô Mật khẩu cũ | mock (VI) · [A] (EN) |
| change.done | Đã đổi mật khẩu chính | Main password changed | | [A] |

**Định dạng ngày:** `dd/MM/yyyy HH:mm` (Recent, FR-37) và `dd/MM/yyyy` (Export, FR-50), **giữ nguyên ở cả hai ngôn ngữ**, đồng hồ 24 giờ [ASSUMPTION — PRD không nói định dạng có đổi theo ngôn ngữ; mock chỉ vẽ tiếng Việt].

## Component Patterns

Bảng này mô tả hành vi; thị giác ở `DESIGN.md` › Components, tên component trùng khớp.

| Component | Dùng ở | Luật hành vi |
|---|---|---|
| **nav-bar** | Mọi màn | Tiêu đề inline. S14: icon lịch sử phải → S16; **không** nút Back (FR-27). S20, S2: chevron back → màn trước (S20 kèm chữ "Cài đặt", S2 chỉ chevron). Không có nút hành động nào khác trên nav-bar (không icon cloud — FR-50). |
| **tab-bar** | Sau đăng nhập | 3 tab (FR-45). Bấm tab đang chọn: cuộn về đầu [ASSUMPTION — mặc định iOS]. Ẩn khi sheet che toàn màn. |
| **button-primary** | Copy (S14), Use Password (S11), Đăng nhập (S3), Tạo tài khoản (S1, S2), Tạo file (S22), Tiếp tục (S21, S25), Đổi mật khẩu (S20) | Vô hiệu khi điều kiện chưa đạt (vd < 15 ký tự — FR-3; ô có ký tự không ASCII — xem State Patterns; field xác nhận chưa khớp). Khi đang chạy KDF/ghi: hiện activity-indicator, chặn bấm lặp (FR-5). |
| **button-text** | Đóng, Hủy, Lưu, Xóa hết, Đổi mật khẩu chính, Khóa Vault, "Xóa & Tạo tài khoản mới", "Tạo mật khẩu" (S9, S10), Xong (S15) | "Lưu" vô hiệu khi thiếu field bắt buộc (FR-22) — vô hiệu thay vì báo lỗi sau khi bấm. "Xóa hết" vô hiệu khi Recent trống (FR-43). Khóa Vault khóa ngay, không hỏi xác nhận [ASSUMPTION — đã ghi memlog]. |
| **icon-button** | Copy (card, Recent), refresh (S14), ẩn/hiện (card, text-field mật khẩu), ⋯ (card), lịch sử (S14) | Copy → interaction "Copy" (bên dưới). Refresh → sinh mật khẩu mới theo tiêu chí hiện tại (FR-31). Ẩn/hiện → đổi trạng thái của **riêng** card / ô đó; mặc định ẩn (FR-17); icon luôn thể hiện hành động kế tiếp (đang ẩn → mắt, đang hiện → mắt gạch chéo). |
| **icon-button-circle** | S11 | Như refresh (FR-31). |
| **fab-new-card** | S7 | FAB tròn teal góc dưới phải. Mở S9 (FR-21). Luôn hiển thị, kể cả khi đang tìm kiếm và khi danh sách trống. Nếu đã có bản nháp mà người dùng bấm FAB: bản nháp cũ bị thay (tối đa 1 bản nháp — FR-26) [ASSUMPTION]. |
| **search-bar** | S7 | Lọc **chỉ theo tiêu đề**, khớp chuỗi con, không phân biệt hoa thường và dấu tiếng Việt, "d" ↔ "đ", cập nhật mỗi lần gõ (FR-19). Kết quả giữ thứ tự FR-18. Từ khóa được giữ khi chuyển tab / chuyển app; bị xóa khi khóa [ASSUMPTION]. |
| **credential-card** | S7 | Hiển thị 4 field; ẩn hàng Ghi chú khi trống (FR-17). Mật khẩu mặc định ẩn; khi hiện dùng password-inline **có tô màu** FR-33. Hàng Tên đăng nhập có Copy; hàng Mật khẩu có ẩn/hiện + Copy; hàng Ghi chú không có nút — bấm vào chính đoạn Ghi chú. Bấm Ghi chú → mở rộng toàn bộ ngay trên card; bấm lần nữa → thu về 3 dòng [ASSUMPTION]. Chọn / kéo thả mật khẩu và Ghi chú: FR-64 — xem Bảo mật hiển thị & phiên. Sửa card không đổi vị trí (FR-18). Trạng thái hiện mật khẩu / mở Ghi chú **không** được lưu: trở về ẩn/thu gọn khi rời tab hoặc khóa [ASSUMPTION]. |
| **popup-menu** | S8, S19 | Dùng cho menu card (S8: "Sửa" / "Xóa") và picker Cài đặt (S19, mở từ hàng giá trị + ⌃⌄). Mở ngay dưới nút / hàng được bấm, căn mép phải với card hoặc nhóm, không scrim; chọn một mục → áp dụng ngay và đóng; bấm ra ngoài → đóng, không đổi gì. S19 đánh dấu ✓ mục hiện tại. Cài đặt thời gian áp dụng từ lần đếm kế tiếp; lần đếm đang chạy giữ giá trị cũ. Đổi Ngôn ngữ / Giao diện có hiệu lực ngay, không cần khởi động lại [ASSUMPTION]. |
| **text-field** | S2, S3, S9, S10, S20, S21, S22, S25 | Ô mật khẩu: ẩn ký tự, có nút ẩn/hiện; tắt autofill và gợi ý bàn phím (NFR-9 — xem Bảo mật hiển thị & phiên). Ô mật khẩu chính & export: ký tự không ASCII — xem State Patterns "Ký tự không ASCII". Ô Mật khẩu và Ghi chú trong form: **dán được**, nhưng tắt Copy / Cut / kéo thả ra ngoài (FR-64) [ASSUMPTION cách áp FR-64 cho ô đang sửa]. Phím Return: chuyển ô kế; ở ô cuối thì gửi nếu nút chính đang bật [ASSUMPTION]. Nhãn và placeholder: ô Login (S2) không có nhãn, dùng placeholder `create.field.*`; ô form (S9, S10, S20, S22, S25) có nhãn phía trên ô; ba ô bắt buộc của card, khi còn trống, hiện placeholder `card.required`. |
| **strength-meter** | S2, S20, S22 | **Chỉ chữ** `pw.strength` ("Độ mạnh: {mức}" / "Strength: {mức}"), không thanh (FR-2); ba mức Low / Medium / High. Ẩn khi ô trống. Cập nhật mỗi lần gõ; mức độ mạnh tính theo độ dễ đoán của mẫu (FR-2), khác cách tính ở FR-34. Chỉ thông tin; **không** chặn nút — việc chặn do luật FR-2 (độ dài, ASCII, blocklist, lặp/tuần tự). |
| **inline-message** | Dưới field; S3 | Hiện ngay khi vi phạm (khi gõ), ẩn khi hết vi phạm. Mỗi lúc chỉ một thông báo cho mỗi field, ưu tiên: không ASCII → độ dài → phổ biến → lặp/tuần tự → không khớp [ASSUMPTION thứ tự]. Lỗi xác nhận "không khớp" chỉ hiện khi ô nhập lại đã đủ độ dài ô đầu [ASSUMPTION]. Thứ tự các dòng trên màn: `DESIGN.md` › inline-message. |
| **list-row** | S14, S18 | S14 có hai nhóm: nhóm 1 = Password Length · Uppercase · Lowercase · Digits; nhóm 2 = Special Characters · hàng bộ ký tự đặc biệt. Hàng "Password Length" → S15. Hàng ⌃⌄ → S19. Import → S24; Export → S21. Hàng bộ ký tự đặc biệt chỉ đọc, không chỉnh được (FR-27). |
| **section-header** | S18 | Không bấm được, không thu gọn được. Chữ đổi theo ngôn ngữ UI theo microcopy `settings.sections`: "CHUNG" / "GENERAL", "NGÔN NGỮ & GIAO DIỆN" / "LANGUAGE & APPEARANCE", "DỮ LIỆU" / "DATA". |
| **toggle** | S14 | Bật/tắt độc lập; tắt cả 4 → mật khẩu chỉ chữ thường, không chặn (FR-30). Mỗi lần đổi → tự sinh lại (FR-31) và lưu tiêu chí (FR-35). |
| **slider** | S11 | Kéo liên tục 4–99, bước 1 (FR-29). Giá trị số cập nhật khi kéo; sinh lại mật khẩu khi **thả** [ASSUMPTION]. Không thêm +/− hay nhập số. |
| **chip-toggle** | S11 | ABC ↔ Uppercase, 123 ↔ Digits, !@# ↔ Special; chữ thường luôn có (FR-30, FR-35). Bỏ chọn cả 3 → chỉ chữ thường. Mỗi lần đổi → sinh lại (FR-31). |
| **password-display** | S14, S11 | Tô màu FR-33. Chọn / kéo thả: FR-64 — xem Bảo mật hiển thị & phiên. Xuống dòng khi dài. |
| **password-inline** | S16, credential-card | Tô màu FR-33. Chọn / kéo thả: FR-64 — xem Bảo mật hiển thị & phiên. Trong recent-row: luôn hiện rõ (không có ẩn/hiện, như ảnh). Trên credential-card: chỉ xuất hiện khi người dùng bấm hiện. Xuống dòng khi dài, không cắt. |
| **bottom-sheet** | S11 | Mở chồng trên S9 hoặc S10 (FR-24, FR-28). Đóng bằng vuốt xuống / bấm scrim → **giữ nguyên** field Mật khẩu (FR-24). "Use Password" → điền vào field Mật khẩu, đóng sheet, **không** ghi Recent (FR-36). Sheet không có Copy. |
| **page-sheet** | S9, S10, S16, S21–S22, S25 | Vuốt xuống = đóng, trừ form card đang có thay đổi (xem Interaction Primitives). S16 không có hành động nào ngoài Copy, "Xóa hết", "Đóng". Header: "Hủy" (form, Export, Import) hoặc "Đóng" (Recent) ở trái; bước 2 Export dùng chevron back để về bước 1. |
| **recent-row** | S16 | Mới nhất trên cùng (FR-40). Copy → toast, **không** tạo mục mới, không đổi thời điểm (FR-38, FR-39). Mục quá 72 giờ biến mất ngay nếu sheet đang mở, hoặc ở lần mở sheet kế tiếp nếu sheet đang đóng [ASSUMPTION thời điểm làm mới] (FR-41). Không vuốt-để-xóa từng mục [ASSUMPTION]. |
| **bottom-toolbar** | S16 | Luôn hiển thị, kể cả khi Recent trống (khi đó "Xóa hết" vô hiệu — FR-43). Chỉ chứa "Xóa hết" → S17; xác nhận xong → danh sách chuyển sang trạng thái trống. |
| **toast** | Toàn app (S28) | Một toast mỗi lúc; toast mới thay toast cũ. Hiện ~1,5 giây rồi mờ dần; không bấm được; không chặn thao tác. Hiện được trên cả sheet. |
| **alert-dialog** | S4, S6, S12, S13, S17, S26, S27 | Modal; không đóng khi bấm ra ngoài. Luôn có lối thoát không phá hủy: "Hủy" ở S4 (nút duy nhất trong hàng nút; hành động xóa nằm ở hold-confirm-button), S13, S17, S26; "Tiếp tục sửa" (S12); "Tiếp tục" (S6); S27 chỉ "OK". Chữ trên nút phá hủy nói rõ hành động. |
| **hold-confirm-button** | S4 | Xem interaction "Giữ 3 giây". |
| **wheel-picker** | S15 | Mở với giá trị hiện tại. Cuộn để chọn; "Xong" hoặc vuốt đóng → áp dụng giá trị và sinh lại mật khẩu (FR-31). Giá trị chỉ đổi khi đóng picker, không đổi liên tục khi cuộn — màn S14 phía sau giữ giá trị cũ tới lúc đó. |
| **empty-state** | S7 (chưa có card / không có kết quả), S16 | Chỉ chữ; không nút riêng — hành động chính (FAB, "Xóa hết") đã có sẵn trên màn. |
| **activity-indicator** | S2, S3, S5, S20, S21, S22, S25, S26 | Hiện khi chạy KDF (~1 giây, tối đa 2 giây — NFR-2) hoặc khi ghi; trong lúc hiện, chặn mọi nút chính. Không skeleton. |

## State Patterns

| State | Surface | Treatment |
|---|---|---|
| Chưa có tài khoản / first-run | S1 | Chỉ "PAK Manager" + "Tạo tài khoản" (FR-1). Cũng là trạng thái sau xóa và sau cài lại (FR-11). |
| Nhập mật khẩu (idle) | S3 | Dòng "Còn {N} lần thử trước khi dữ liệu bị xóa." **luôn hiển thị** dưới ô (FR-4). "Đăng nhập" vô hiệu khi < 15 ký tự (FR-3). |
| Ký tự không ASCII | S2, S3, S20, S21, S22, S25 | Ô mật khẩu chính / export chỉ **hợp lệ** với ASCII in được (FR-2, FR-52, ADD). **Không chặn phím khi gõ, không tự xóa ký tự**: ký tự vẫn vào ô và được giữ nguyên, vì chặn ngay sẽ phá bộ gõ Telex/VNI (như Laban Key) đang ghép dấu. Ngay khi ô chứa ký tự không ASCII: inline-message `pw.nonAscii` hiện, **nút chính** (Đăng nhập / Tạo tài khoản / Đổi mật khẩu / Tiếp tục / Tạo file) vô hiệu. Xóa hết ký tự đó → thông báo ẩn, nút theo các luật còn lại. Ở S3, chuỗi có ký tự không ASCII không bao giờ được gửi nên không tính lần thử. |
| Đang kiểm tra | S3 | button-primary hiện activity-indicator; ô và nút bị khóa; bấm lặp không tạo lần thử mới (FR-5). |
| Sai lần 1–4 | S3 | inline-message "Sai mật khẩu." + số lần còn lại cập nhật; ô giữ nguyên nội dung để sửa [ASSUMPTION]. Nhập lại đúng chuỗi sai trước đó không giảm số lần (FR-5). |
| Đang chờ (lần 5–9) | S3 | Ô + "Đăng nhập" vô hiệu; dòng "Thử lại sau {mm:ss}" đếm ngược từng giây + số lần còn lại (FR-4). Sau reboot, đếm lại từ 30:00 (FR-6). "Xóa & Tạo tài khoản mới" **vẫn bấm được**. Hết giờ → về idle. |
| Lần sai thứ 10 | S3 → S5 → S1 | Không dialog; app chuyển ngay S5 rồi S1 (FR-4, FR-12). |
| Dữ liệu bị hỏng | S3 | inline-message `login.corrupt`; không giảm số lần (FR-7); không xóa. Người dùng tự chọn "Xóa & Tạo tài khoản mới". |
| Xóa bị gián đoạn | Mở app → S5 | Xóa nốt rồi mới hiện S1 (FR-12). |
| Validation mật khẩu chính / export | S2, S20, S22 | inline-message theo luật FR-2; nút chính vô hiệu tới khi hợp lệ và hai ô khớp. |
| Độ mạnh mật khẩu chính / export | S2, S20, S22 | Một dòng chữ `pw.strength` (vd "Độ mạnh: Trung bình" / "Strength: Medium") dưới ô mật khẩu, không thanh (FR-2); thị giác: `DESIGN.md` › strength-meter. Ô trống: ẩn. |
| Đang tạo tài khoản | S2 | "Tạo tài khoản" hiện activity-indicator (KDF — NFR-2), chặn bấm lặp; xong → tab Quản lý mật khẩu, đã đăng nhập (FR-1, FR-45). |
| Sai mật khẩu cũ / sai mật khẩu chính trước Export | S20 / S21 | inline-message; **không** tính bộ đếm (FR-13, FR-51); không giới hạn số lần. |
| Bị khóa (Tự khóa / hết phiên / Khóa Vault) | Mọi surface → S3 | Gỡ toàn bộ sheet và dialog, về S3, không thông báo lý do. Clipboard: FR-65 — xem Bảo mật hiển thị & phiên. Form card đang mở → đã có bản nháp (FR-26). |
| Khóa khi đang ghi | S20, S22, S26 | Hoàn tất (hoặc hoàn tác) thao tác ghi với activity-indicator, rồi mới về S3 (FR-16). |
| Khóa khi chưa ghi | S21, S24, S25 | Thao tác bị hủy, dữ liệu giữ nguyên (FR-16). |
| Có bản nháp | Sau đăng nhập → S6 | Hỏi "Tiếp tục bản nháp?" trước khi hiện danh sách. "Tiếp tục" → mở S9 hoặc S10 đúng loại với dữ liệu nháp (sheet tạo mật khẩu không được khôi phục [ASSUMPTION]). "Bỏ bản nháp" → hủy. |
| Chưa có card | S7 | empty-state `empty.cards` (FR-20); search-bar vẫn hiện; FAB vẫn hiện. |
| Tìm kiếm không có kết quả | S7 | empty-state `empty.search` thay danh sách; không gợi ý, không nút tạo card. search-bar giữ từ khóa và có nút xóa (x). |
| Danh sách có card | S7 | Mới nhất trên cùng (FR-18); card import chèn theo thời gian tạo gốc (FR-58). |
| Mật khẩu card ẩn / hiện | credential-card | Ẩn: `••••••••`; hiện: password-inline tô màu. Copy hoạt động ở cả hai trạng thái (FR-17, FR-64). |
| Ghi chú thu gọn / mở rộng | credential-card | ≤ 3 dòng + "…" / toàn bộ (FR-17). Ghi chú ≤ 3 dòng: bấm không có tác dụng. |
| Form trống / có thay đổi | S9, S10 | Sau mỗi thay đổi, app tự lưu bản nháp mã hóa, im lặng, không chỉ báo [ASSUMPTION]. "Lưu" vô hiệu khi thiếu Tiêu đề / Tên đăng nhập / Mật khẩu (FR-22). |
| Lưu card | S9, S10 | Đóng sheet; card mới nằm trên cùng; bản nháp bị hủy (FR-26). Không toast [ASSUMPTION]. |
| Generator lần đầu | S14, S11 | Mọi loại bật, độ dài 16 (FR-35). |
| Độ mạnh | S11 | "Password strength: Low / Medium / High" theo FR-34; chỉ chữ. Màn S14 **không** có nhãn này (FR-28). |
| Recent có mục | S16 | Danh sách xen kẽ; "Xóa hết" bật. |
| Recent trống | S16 | empty-state `empty.recent` căn giữa vùng trống; "Xóa hết" vô hiệu (FR-43). |
| Export: chưa từng / đã export | S18 | Dòng phụ "Chưa export lần nào" / "Lần export gần nhất: {dd/MM/yyyy}"; ngày export được ghi nhận ngay khi tạo file xong, kể cả khi đóng menu chia sẻ mà không gửi (FR-50). |
| Export xong | S22 → S23 | Mở menu chia sẻ OS; khi menu đóng (gửi hay không) → đóng sheet Export, về S18 [ASSUMPTION]. |
| Import: file không hợp lệ | S24 → S27 | Alert "File không hợp lệ"; không có gì thay đổi (FR-56, FR-63). |
| Import: sai mật khẩu export | S25 | inline-message; ô giữ nguyên; thử lại không giới hạn (FR-56). |
| Import: hỏng / gián đoạn | S25, S26 | Dữ liệu nguyên vẹn, không card nào được thêm (FR-59); với file hỏng hiện "File không hợp lệ". |
| Import xong | S26 → S18 | Đóng sheet; toast "Đã thêm {N} card"; ở lại tab Cài đặt. |
| Đổi mật khẩu chính xong | S20 → S18 | Toast `change.done`, quay lại S18 [ASSUMPTION]. |
| Loading | Toàn app | Chỉ có activity-indicator lúc chạy KDF / ghi. Không skeleton, không màn chờ khởi động riêng. |
| Offline / mạng | — | Không tồn tại: app không có kết nối (NFR-7). Không banner, không trạng thái lỗi mạng. |

## Interaction Primitives

- **Bấm để làm.** Không cử chỉ ẩn nào là cách duy nhất để thực hiện một hành động.
- **Copy** (FR-64, FR-65): bấm Copy → ghi clipboard (cơ chế từng nền tảng: Responsive & Platform) → toast **"Đã copy"**; Copy ở S14 còn ghi Recent (FR-38).
- **Giữ 3 giây** (FR-9): trong S4, nhấn giữ hold-confirm-button → vòng tiến trình chạy đều quanh nút trong 3 giây. Nhả trước 3 giây → vòng chạy ngược về 0, không có gì xảy ra. Đủ 3 giây → dialog đóng, sang S5. Bấm nhanh (tap) không làm gì [ASSUMPTION: không kèm thông báo "hãy giữ"]. "Hủy" luôn bấm được.
- **Picker:** cài đặt dùng popup-menu (S19) giống ảnh ([`settings.html`](mockups/settings.html)); Password Length dùng wheel-picker (S15, memlog Q6a); sheet dùng slider.
- **Sheet chồng sheet:** form card là page-sheet; trong S9 hoặc S10, "Tạo mật khẩu" mở bottom-sheet S11 **chồng lên** form đang mở. Đóng S11 không ảnh hưởng form. Không mở sheet thứ ba.
- **Vuốt xuống để đóng:** S11, S16, S21–S22, S25 đóng tự do (đóng S21–S22/S25 = hủy thao tác). S9/S10: chưa có thay đổi → đóng ngay; có thay đổi → **không đóng**, hiện S12 "Bỏ thay đổi?" (mẫu iOS modal-in-presentation). "Hủy" ở S9/S10 cùng luật. "Bỏ thay đổi" = chủ động bỏ thay đổi → hủy bản nháp (FR-26).
- **Bản nháp:** tự lưu sau mỗi thay đổi (FR-26), im lặng. Khôi phục bằng S6 sau đăng nhập.
- **Ẩn/hiện mật khẩu:** bấm icon mắt; chỉ ảnh hưởng một card / một ô.
- **Không chọn văn bản** trên mật khẩu và Ghi chú (FR-64 — xem Bảo mật hiển thị & phiên); bấm giữ trên chúng không mở menu hệ thống.
- **Chuyển app:** không khóa ngay; chỉ khóa khi ở nền quá thời gian Tự khóa (FR-15, PRD nguyên tắc 1). Quay lại trong hạn → đúng màn, đúng trạng thái đã rời.
- **Chuyển cảnh:** dùng chuyển cảnh mặc định của iOS (push, sheet). Hoạt ảnh riêng duy nhất: vòng hold-confirm và toast mờ dần.
- **Không có:** vuốt-để-xóa card, kéo-để-làm-mới, sắp xếp lại card, haptic tùy biến, thông báo đẩy (Notifications đã bỏ — PRD §7), đăng nhập sinh trắc học (PRD §7).

## Bảo mật hiển thị & phiên

Mục riêng vì đây là app quản lý mật khẩu: các luật dưới đây ràng buộc mọi surface.

| Chủ đề | Luật | Nguồn |
|---|---|---|
| Mật khẩu trên card | Mặc định ẩn (`••••••••`, 8 chấm cố định); lấy giá trị **chỉ** qua Copy | FR-17, FR-64 |
| Chọn / kéo thả | Mật khẩu và Ghi chú không chọn được, không kéo thả ra ngoài | FR-64 |
| Bàn phím & autofill | Mọi ô mật khẩu (chính, export, card): tắt autofill, đề nghị lưu mật khẩu của OS, autocorrect, gợi ý, học từ. Kiểm thử với bàn phím mặc định, Gboard, Laban Key | NFR-9, ADD |
| Ký tự mật khẩu chính / export | Chỉ ASCII in được, 15–128 (ký tự khác: xem State Patterns "Ký tự không ASCII") | FR-2, FR-52 |
| Không khôi phục | Không có link "Quên mật khẩu", gợi ý hay câu hỏi bảo mật trên Login | FR-10 |
| Đặt nút xóa | "Xóa & Tạo tài khoản mới" ở đáy S3, xa "Đăng nhập"; luôn cần dialog + giữ 3 giây | FR-9, ADD |
| Giới hạn phiên | Tuyệt đối từ lúc đăng nhập, mặc định 10 phút; hết → khóa **kể cả đang thao tác**, không cảnh báo trước [ASSUMPTION] | FR-14, FR-46 |
| Tự khóa | Ở nền quá hạn (mặc định 3 phút) → khóa | FR-15, FR-46 |
| Khi khóa | Gỡ mọi surface, bỏ dữ liệu giải mã khỏi bộ nhớ, xóa clipboard nếu khóa lúc tiền cảnh | NFR-4, FR-65 |
| Chụp màn hình / ảnh đa nhiệm | **Không** chặn, **không** che (rủi ro chấp nhận) | NFR-10 |
| Cài đặt thời gian | Chỉ 1 / 3 / 5 / 10 phút, không có "Không bao giờ" | FR-46 |
| Luật nhập sai | Cố định, không có cài đặt | FR-8 |

## Accessibility Floor

**Quyết định của chủ sản phẩm: không đặt sàn accessibility riêng** (dự án cá nhân). Spine này **không** đặt yêu cầu accessibility nào (không WCAG, không cam kết Dynamic Type [ASSUMPTION — đã ghi memlog], không yêu cầu nhãn screen reader, không kích thước chạm tối thiểu bắt buộc).

Những gì có được chỉ là mặc định của nền tảng:

- Control iOS native (UISwitch, UIButton, UIAlertController, UIPickerView…) tự có nhãn và vai trò VoiceOver mặc định của hệ thống.
- Trên Android, các control vẽ lại theo dáng iOS **không** tự có ngữ nghĩa TalkBack tương đương; spine không yêu cầu bổ sung.
- Màu ký tự mật khẩu (FR-33) là kênh thông tin chỉ bằng màu — được chấp nhận theo quyết định trên.

Độ tương phản đo được ghi ở `DESIGN.md` › Colors để tham khảo.

## Responsive & Platform

| Chủ đề | Hành vi |
|---|---|
| Hướng màn hình | **Chỉ dọc** trên cả điện thoại và tablet. Không xoay ngang. |
| Điện thoại | Bố cục như ảnh tham chiếu, dọc. |
| Máy tính bảng | Dọc. **Một cột căn giữa**, rộng tối đa `{spacing.content-max-tablet}` (giá trị ở `DESIGN.md`, [ASSUMPTION — đã ghi memlog]); nền phủ toàn màn. Tab bar giữ nguyên ở đáy. page-sheet và bottom-sheet hiển thị dạng form sheet căn giữa theo mặc định iPad [ASSUMPTION]. |
| Android — dáng iOS | Cùng dáng iOS trên Android: tab bar đáy, nav-bar inline căn giữa, UISwitch, sheet có grabber, alert iOS, popup-menu, wheel-picker. Không Material. Font và bộ icon Android: xem `DESIGN.md` › Typography, Components. |
| Android — nút Back hệ thống | Đóng tầng trên cùng (dialog → sheet → màn push). Form card có thay đổi → hiện S12 như vuốt xuống. Ở gốc tab: hành vi mặc định của OS (đưa app ra nền) [ASSUMPTION]. S4 đang giữ: Back = hủy [ASSUMPTION]. |
| Clipboard (FR-65) | **iOS:** clipboard có hạn tự hết bằng thời gian Tự xóa clipboard, chỉ trên máy (không Universal Clipboard). **Android 13+:** đánh dấu nhạy cảm (OS che nội dung trong bản xem trước clipboard); quay lại app quá hạn → xóa ngay; không quay lại → có thể còn tới ~1 giờ (giới hạn nền tảng, rủi ro chấp nhận). **Cả hai:** hết thời gian Tự xóa clipboard → chỉ xóa khi clipboard còn đúng giá trị app đã copy; xóa khi khóa lúc tiền cảnh và khi xóa dữ liệu. UI giống nhau trên hai nền tảng: toast "Đã copy", không có thông báo nào khi xóa. |
| Import / Export | Dùng menu chia sẻ và trình chọn file **của từng OS** (FR-55, FR-56) — đây là hai chỗ app hiện UI hệ thống thật, không vẽ lại dáng iOS. |
| Tương thích file | File export đọc được chéo iOS ↔ Android (FR-61). |

## Inspiration & Anti-patterns

**Bám theo — Kaspersky Password Manager** (ảnh là mẫu bám theo, không chỉ tham khảo). Giữ bố cục màn hình Tạo mật khẩu, sheet tạo mật khẩu, sheet Recent (có "Xóa hết" / Clear ở footer) và Cài đặt inset-grouped ("Đổi mật khẩu chính" và "Khóa Vault" — Change Main Password, Lock Vault — trong khối riêng). Phần thị giác giữ lại từ mẫu: xem `DESIGN.md` › Brand & Style, Components. Chỉ lấy bố cục & phong cách — không dùng logo, tên hay dấu hiệu thương hiệu.

**Khác với mẫu (có chủ đích):**

| Mẫu Kaspersky | PAK Manager | Nguồn |
|---|---|---|
| Nút Back ở màn Password Generator | Bỏ (màn này là một tab) | FR-27, PRD F3 |
| Tab bar ~5 tab | 3 tab: Quản lý mật khẩu · Tạo mật khẩu · Cài đặt | FR-45 |
| Icon cloud ↓↑ ở Cài đặt | Bỏ; Import / Export thành hai hàng trong Cài đặt | FR-50 |
| "Use Face ID" | Bỏ (không sinh trắc học) | PRD §7 |
| "Notifications" | Bỏ | PRD §7 |
| Recent cũ → mới, giữ lâu | **Mới nhất ở trên**, mỗi mục hết hạn sau 72 giờ | FR-40, FR-41 |
| Autolock 1 min, Clear Clipboard 30 sec | 1/3/5/10 phút; mặc định Tự khóa 3 phút, Tự xóa clipboard 3 phút; thêm Giới hạn phiên (mặc định 10 phút) | FR-46 |
| Monospace ở Generator và Recent | Sans thường ở mọi chỗ | memlog Q3b |
| Hàng "Password Length 16 >" (đích không rõ) | Mở wheel-picker 4–99 | memlog Q6a |
| Chỉ có light theme | Light + Dark + Theo hệ thống | FR-47, NFR-13 |
| Chỉ tiếng Anh | English + Tiếng Việt | NFR-14 |
| Thêm vào mẫu | Ngôn ngữ, Giao diện, Giới hạn phiên, Import, Export (+ ngày export) | FR-46, FR-47, FR-50 |

**Bác bỏ:**
- Khóa ngay khi chuyển app, chặn chụp màn hình, che ảnh đa nhiệm — phá luồng copy-dán cốt lõi (PRD nguyên tắc 1, §7).
- "Quên mật khẩu" / gợi ý / câu hỏi bảo mật (FR-10).
- Thanh độ mạnh (FR-2 chỉ dùng chữ). Màu trạng thái và màu đỏ: xem `DESIGN.md` › Colors.
- Material Design trên Android.
- Đăng nhập sinh trắc học, AutoFill cho app khác, đồng bộ cloud (PRD §7).

## Key Flows

Chỉ bốn hành trình của PRD, nhân vật **Chị Lan**. Không có hành trình first-run riêng — tạo tài khoản nằm trong UJ-3 và UJ-4. Mỗi bước dẫn mã surface; mock của surface ở cột **Mock** trong Bảng surface.

### UJ-1: Đăng nhập Facebook bằng card đã lưu (Chị Lan, luồng cốt lõi)

1. Chị Lan mở app → S3. Chị gõ mật khẩu chính; "Đăng nhập" bật khi đủ 15 ký tự (FR-3).
2. Chị bấm "Đăng nhập" → activity-indicator ~1 giây (NFR-2) → tab Quản lý mật khẩu (FR-45).
3. Chị gõ "face" vào search-bar; danh sách lọc ngay theo tiêu đề (FR-19).
4. Chị bấm Copy cạnh Tên đăng nhập trên card "Facebook" → toast "Đã copy" (FR-64).
5. Chị chuyển sang Facebook và dán.
6. Chị **quay lại** PAK Manager (trong 3 phút — Tự khóa, FR-15) → vẫn đúng danh sách đã lọc, không phải đăng nhập lại.
7. Chị bấm Copy cạnh Mật khẩu (không cần bấm hiện) → toast "Đã copy".
8. **Climax:** chị dán vào Facebook và đăng nhập thành công. Từ lúc mở app tới lúc vào Facebook, chị chỉ gõ mật khẩu chính một lần và chưa bao giờ phải nhìn thấy mật khẩu Facebook.

Failure: chị ở Facebook quá thời gian Tự khóa → quay lại thấy S3; đăng nhập lại → về tab Quản lý mật khẩu, từ khóa tìm kiếm đã bị xóa, gõ lại "face". Gõ sai mật khẩu chính → "Sai mật khẩu." + "Còn {N} lần thử…". Không có card khớp → `empty.search`.

### UJ-2: Đăng ký tài khoản Shopee mới (Chị Lan, luồng cốt lõi)

1. Chị Lan bấm tab Tạo mật khẩu (S14); mật khẩu đã sinh sẵn theo tiêu chí lần trước (FR-35).
2. Chị bấm hàng "Độ dài mật khẩu" (Password Length) → wheel-picker (S15) → chọn 20 → "Xong" → mật khẩu sinh lại (FR-31).
3. Chị bật/tắt vài công tắc loại ký tự; mỗi lần đổi, mật khẩu sinh lại.
4. Chị bấm refresh vài lần tới khi ưng ý.
5. Chị bấm **Copy** → toast "Đã copy"; mật khẩu được ghi vào Recent (FR-38).
6. Chị sang Shopee, dán vào ô mật khẩu và ô xác nhận, chờ OTP, điền thông tin — mất vài phút.
7. Chị quay lại PAK Manager (nếu quá 3 phút: đăng nhập lại ở S3, rồi bấm lại tab Tạo mật khẩu).
8. Chị bấm icon lịch sử → S16; mật khẩu vừa tạo **nằm trên cùng** (FR-40). Chị bấm Copy → toast "Đã copy", rồi "Đóng" (Close).
9. Chị bấm tab Quản lý mật khẩu → fab-new-card → S9 "Card mới". (S9 có nút "Tạo mật khẩu" — FR-24 — nhưng chị đã có mật khẩu trong clipboard nên không dùng.)
10. Chị nhập Tiêu đề "Shopee", Tên đăng nhập, dán Mật khẩu; "Lưu" bật khi đủ 3 field bắt buộc (FR-22). Chị bấm "Lưu".
11. **Climax:** sheet đóng, card "Shopee" nằm **trên cùng** danh sách (FR-18) — một mật khẩu mạnh chị chưa từng phải đọc hay nhớ giờ đã được lưu, dù giữa chừng chị rời app vài phút.

Failure: app khóa khi chị đang điền S9 (hết phiên / Tự khóa) → bản nháp đã tự lưu (FR-26) → đăng nhập lại → S6 "Tiếp tục bản nháp?" → "Tiếp tục" → S9 mở lại với những gì chị đã gõ. Clipboard đã bị xóa sau 3 phút (FR-65) → chị lấy lại mật khẩu từ Recent (bước 8). Recent trống (quá 72 giờ hoặc đã "Xóa hết") → `empty.recent`, "Xóa hết" vô hiệu.

### UJ-3: Đổi điện thoại (Chị Lan, luồng bổ trợ — iPhone → Android)

1. Trên máy cũ, chị Lan vào Cài đặt → "Export" → S21, nhập lại mật khẩu chính → "Tiếp tục" (sai không tính bộ đếm — FR-51).
2. S22: chị đặt mật khẩu export + nhập lại; strength-meter cập nhật; chị đọc dòng gợi ý (có thể dùng lại mật khẩu chính) và cảnh báo (quên = file vô dụng) (FR-52). Chị bấm "Tạo file".
3. activity-indicator → menu chia sẻ OS (S23) → chị gửi file qua Zalo cho chính mình (FR-55). Dòng phụ của hàng Export đổi thành "Lần export gần nhất: {hôm nay}" (FR-50).
4. Trên máy mới, chị cài app → S1 → "Tạo tài khoản" → S2: đọc cảnh báo, đặt mật khẩu chính + nhập lại → vào tab Quản lý mật khẩu trống (`empty.cards`).
5. Chị vào Cài đặt → "Import" → trình chọn file OS (S24) → chọn file từ Zalo/Files.
6. S25: chị nhập mật khẩu export → "Tiếp tục" → activity-indicator.
7. S26: "File có {N} card, export ngày {dd/MM/yyyy}. Thêm vào danh sách?" → chị bấm "Xác nhận" (FR-57).
8. **Climax:** toast "Đã thêm {N} card"; chị mở tab Quản lý mật khẩu và thấy toàn bộ card cũ, đúng thứ tự thời gian tạo gốc (FR-58) — trên một hệ điều hành khác (FR-61).

Failure: chọn nhầm file → S27 "File không hợp lệ" (FR-56). Sai mật khẩu export → "Sai mật khẩu export."; thử lại không giới hạn. App khóa khi chị đang ở trình chọn file → import bị hủy, không có gì thay đổi (FR-16). Bấm "Hủy" ở S26 → không thêm card nào.

### UJ-4: Quên mật khẩu chính, hoặc nhập sai đến lần thứ 10 (Chị Lan, luồng bổ trợ)

Nhánh A — quên mật khẩu:
1. Chị Lan ở S3, không nhớ mật khẩu chính. Không có "Quên mật khẩu" (FR-10).
2. Chị bấm "Xóa & Tạo tài khoản mới" ở đáy màn → S4: "Xóa toàn bộ dữ liệu?" (FR-9).
3. Chị nhấn giữ hold-confirm-button; vòng tiến trình chạy quanh nút trong 3 giây.
4. Đủ 3 giây → S5 "Đang xóa dữ liệu…" → S1.

Nhánh B — nhập sai:
1. Lần sai 1–4: "Sai mật khẩu." và số lần còn lại giảm dần; có thể thử lại ngay (FR-4).
2. Lần sai 5–9: sau mỗi lần, chờ 30 phút với "Thử lại sau {mm:ss}" (FR-4).
3. Lần sai thứ 10 → S5 → S1; mọi dữ liệu đã bị xóa (FR-12).

Cả hai nhánh (tiếp sau bước cuối của A hoặc B):
1. Chị bấm "Tạo tài khoản" → S2 → tạo mật khẩu chính mới.
2. Nếu có file export và còn nhớ mật khẩu export, chị import theo bước 5–7 của UJ-3.
3. **Climax:** toast "Đã thêm {N} card" — chị lấy lại mọi card tính đến lần export gần nhất. Không có file hoặc quên mật khẩu export → tab Quản lý mật khẩu hiện `empty.cards`; dữ liệu cũ đã mất, đúng như cảnh báo lúc tạo tài khoản (FR-1).

Failure: nhả tay trước 3 giây ở S4 → không xóa gì, vòng trở về 0. Mất điện giữa lúc xóa → lần mở sau xóa nốt rồi mới hiện S1 (FR-12).
