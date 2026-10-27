---
title: PAK Manager — Source extract cho bước UX (DESIGN.md + EXPERIENCE.md)
created: 2026-10-26
sources:
  - prds/prd-passwordmanager-2026-10-23/prd.md (status: final, updated 2026-10-25) — NGUỒN CHÍNH, ưu tiên cao nhất
  - prds/prd-passwordmanager-2026-10-23/addendum.md
  - prds/prd-passwordmanager-2026-10-23/research-digest.md
  - prds/prd-passwordmanager-2026-10-23/reconcile-idea-screens.md
  - brainstorming/brainstorm-password-manager-app-2026-10-23/brainstorm-intent.md
  - idea.txt
  - (bổ sung, để đối chiếu ảnh) prds/.../source-extract.md (mô tả ảnh) + screens/*.jpg (đã xem trực tiếp)
---

# Source extract — PAK Manager (UX)

Viết tắt nguồn: **PRD** = prd.md · **ADD** = addendum.md · **RD** = research-digest.md · **REC** = reconcile-idea-screens.md · **BI** = brainstorm-intent.md · **IDEA** = idea.txt · **PSE** = prds/.../source-extract.md (mô tả ảnh) · **IMG:<tên>** = ảnh trong `screens/`.

> **Cảnh báo về mã FR trong REC:** REC dùng **đánh số FR cũ** (vd "FR-24" = màn hình Tạo mật khẩu, "FR-25" = sheet, "FR-26" = độ dài, "FR-14" = card, "FR-32" = nhớ tiêu chí). Trong PRD final các mục này là FR-27, FR-28, FR-29, FR-17, FR-35. Tài liệu này luôn dùng **mã PRD final**.
>
> **Thứ tự ưu tiên khi mâu thuẫn:** PRD final > ADD > BI (memlog) > IDEA / ảnh (BI frontmatter: "quyết định trong memlog được ưu tiên hơn idea.txt"; PRD là bản chốt sau cùng).

---

## 1. Glossary (nguyên văn PRD § "Thuật ngữ")

- **Tài khoản PAK Manager:** tài khoản duy nhất của app trên máy, được bảo vệ bằng **mật khẩu chính**.
- **Card:** một bộ thông tin đăng nhập mà người dùng lưu lại, gồm Tiêu đề, Tên đăng nhập, Mật khẩu và Note.
- **Vault:** toàn bộ dữ liệu đã mã hóa của app, gồm card, Recent và bản nháp.
- **Recent:** cách gọi tắt của Recent Passwords, tức danh sách mật khẩu vừa tạo (F4).
- **Màn hình Tạo mật khẩu:** nội dung của tab Tạo mật khẩu (`password_generator.jpg`).
- **Sheet tạo mật khẩu:** sheet được mở từ form sửa card (`edit_pass.jpg`).
- **Tên nút và tên cài đặt** trong tài liệu này là tên tham chiếu, lấy theo ảnh tham chiếu. Chuỗi hiển thị thực tế có đủ bản English và Tiếng Việt (NFR-14).

Thuật ngữ phụ dùng xuyên PRD (không nằm trong mục Thuật ngữ nhưng dùng nhất quán):
- **mật khẩu export** (F6, FR-52) — mật khẩu riêng để mã hóa file export, khác mật khẩu chính.
- **bản nháp** (FR-26) — tối đa 1 bản, mã hóa, tự lưu khi tạo/sửa card.
- **bộ đếm** (sai) (FR-4–FR-6), **thời gian chờ** (30 phút).
- **Autolock / Autolock Vault** (FR-15), **Giới hạn phiên** (FR-14), **Clear Clipboard** (FR-65), **Lock Vault** (FR-49, = Sign out).
- **Use Password**, **Password strength**, **Password Length**, chip **123 / ABC / !@#** (FR-28).
- **"Xóa & Tạo tài khoản mới"** (FR-9). BI dùng tên cũ "Xóa tài khoản + tạo mới".
- **Tab bar 3 tab:** **Quản lý mật khẩu**, **Tạo mật khẩu**, **Cài đặt** (FR-45).

---

## 2. Personas / nhân vật

| Tên (nguyên văn) | Bối cảnh | Nguồn |
|---|---|---|
| **Chị Lan** | Nhân vật duy nhất được đặt tên; xuất hiện trong UJ-1, UJ-2, UJ-3, UJ-4. Đăng nhập Facebook, đăng ký Shopee, đổi điện thoại (iPhone → Android), quên mật khẩu / sai 10 lần. | PRD §3 |
| **Chủ sản phẩm** | Người dùng chính và đầu tiên. Muốn công cụ của riêng mình: offline, an toàn, miễn phí. Sẽ tự hướng dẫn người thân dùng. | PRD §1 "Người dùng", "Động lực"; IDEA dòng 11–12; BI §1 |
| **Gia đình và bạn bè, kể cả người thân lớn tuổi** | Đối tượng mở rộng nếu app chạy ổn. "app không cần thiết kế riêng cho người ít rành công nghệ" (chủ sản phẩm hướng dẫn). | PRD §1; BI §1 ("kể cả người dùng lớn tuổi"); PRD §7 Ngoài phạm vi |
| **Kẻ trộm thông thường / người chung máy** (anti-persona) | Kẻ trộm reset máy rồi bán; kịch bản người chung máy cố tình nhập sai 10 lần bị **loại khỏi phạm vi**. | PRD §1 Threat model; BI §3 |

Động lực (PRD §1): "Thời đại số buộc mỗi người phải đăng ký rất nhiều ứng dụng… Không ai nhớ nổi chừng ấy mật khẩu."

---

## 3. User journeys / flows

### UJ-1: Đăng nhập Facebook bằng card đã lưu (luồng cốt lõi) — PRD §3
1. Mở app → nhập mật khẩu chính (FR-3) → gõ "face" vào ô tìm kiếm (FR-19).
2. Copy tên đăng nhập (FR-17, FR-64) → chuyển sang Facebook, dán.
3. **Quay lại** PAK Manager → copy mật khẩu → chuyển sang Facebook, dán.
4. Đăng nhập thành công.
- Trong lúc chuyển qua lại, app **không** bắt đăng nhập lại (Autolock FR-15, mặc định 3 phút; nguyên tắc thiết kế 1).

### UJ-2: Đăng ký tài khoản Shopee mới (luồng cốt lõi) — PRD §3
1. Mở tab Tạo mật khẩu, chỉnh độ dài + loại ký tự, bấm tạo lại vài lần (FR-27, FR-30, FR-31).
2. Bấm **Copy** → mật khẩu ghi vào Recent (FR-38).
3. Sang Shopee: dán vào ô mật khẩu + xác nhận, chờ OTP, điền thông tin — **có thể mất vài phút**.
4. Quay lại PAK Manager, mở Recent → mật khẩu vừa tạo **nằm trên cùng** (FR-40) → copy lại.
5. Tạo card "Shopee", nhập tên đăng nhập, dán mật khẩu, bấm Lưu (FR-21, FR-22; form tạo mới **không** có nút "Tạo mật khẩu" — FR-24).
- Hệ quả: Autolock mặc định 3 phút tính từ lúc app chạy nền; Clear Clipboard mặc định 3 phút; Recent mới nhất ở trên.

### UJ-3: Đổi điện thoại (bổ trợ) — PRD §3
1. Máy cũ: Cài đặt → Export → nhập lại mật khẩu chính (FR-51) → đặt mật khẩu export + xác nhận (FR-52) → menu chia sẻ OS (FR-55), vd gửi Zalo cho chính mình / lưu Drive.
2. Máy mới: cài app → tạo tài khoản PAK Manager (FR-1, FR-2) → đăng nhập (FR-3).
3. Cài đặt → Import → chọn file (trình chọn file OS) → nhập mật khẩu export → xác nhận (FR-56, FR-57).
4. Toàn bộ card trong file được **thêm** vào (FR-57, FR-58).
- Hai máy có thể khác OS (iPhone → Android) (FR-61).

### UJ-4: Quên mật khẩu chính hoặc nhập sai lần thứ 10 (bổ trợ) — PRD §3
- Quên mật khẩu → nút "Xóa & Tạo tài khoản mới" (FR-9: hộp thoại + giữ 3 giây).
- Sai lần thứ 10 → app tự xóa (FR-4, FR-12).
- Cả hai: tạo tài khoản mới (FR-1). Có file export **và còn nhớ mật khẩu export** → import theo bước 3–4 UJ-3. Nếu không → mất hết.

### Flow con suy ra từ FR (không có UJ riêng, chỉ liệt kê bước PRD mô tả)
- **Tạo tài khoản lần đầu (first-run):** Login trạng thái chưa có tài khoản → nút "Tạo tài khoản" → cảnh báo quên = mất hết → nhập mật khẩu chính (thanh Low/Medium/High, kiểm tra ASCII, blocklist, lặp/tuần tự) → nhập lại xác nhận → vào tab Quản lý mật khẩu (FR-1, FR-2, FR-3, FR-45).
- **Đăng nhập sai:** lần 1–4 nhập lại ngay; lần 5–9 chờ 30 phút + đếm ngược; lần 10 xóa → Login chưa có tài khoản. Luôn hiển thị số lần còn lại (FR-4–FR-6).
- **Vault hỏng:** mật khẩu đúng → trạng thái "Dữ liệu bị hỏng" → dùng "Xóa & Tạo tài khoản mới" → import lại (FR-7).
- **Sửa card + sheet tạo mật khẩu:** menu ⋯ trên card → Sửa → form → nút "Tạo mật khẩu" → sheet → Use Password (thay giá trị) hoặc đóng sheet (giữ nguyên) → Lưu (FR-23, FR-24, FR-28, FR-36).
- **Xóa card:** menu ⋯ → Xóa → hộp thoại xác nhận (FR-23, FR-25).
- **Bản nháp phục hồi:** đang tạo/sửa card → app khóa / OS kill → đăng nhập lại → mở lại bản nháp (FR-26).
- **Change Main Password:** Cài đặt → nhập mật khẩu cũ → mật khẩu mới (FR-2) → xác nhận (FR-13, FR-48).
- **Lock Vault / Sign out:** Cài đặt → Lock Vault → Login, xóa clipboard nếu còn giá trị app (FR-49, FR-65).
- **Recent:** tab Tạo mật khẩu → icon lịch sử → sheet Recent → copy mục / Clear (xác nhận) / Close (FR-37–FR-43).

---

## 4. Functional requirements có hàm ý UI (đầy đủ, PRD §4)

| ID | Tóm tắt 1 dòng | Surface / hàm ý UX |
|---|---|---|
| FR-1 | Chưa có tài khoản → Login hiện nút **"Tạo tài khoản"**; đặt mật khẩu chính + nhập lại; **cảnh báo rõ** quên = mất toàn bộ dữ liệu trước khi tạo | Login (no-account) → màn/flow Tạo tài khoản; cảnh báo |
| FR-2 | Quy tắc mật khẩu chính: 15–128 ký tự; chỉ ASCII in được (kể cả khoảng trắng), **báo rõ lý do** khi gõ chữ có dấu/Unicode; không bắt buộc hoa/số/đặc biệt; từ chối mật khẩu phổ biến/bị lộ (danh sách nhúng offline); từ chối lặp 1 ký tự / dãy tuần tự; **thanh độ mạnh 3 nhãn Low / Medium / High** (tính theo mẫu dễ đoán, khác FR-34) | Tạo tài khoản, Change Main Password, đặt mật khẩu export; validation inline + strength meter |
| FR-3 | Đã có tài khoản → Login: tên app **PAK Manager**, ô mật khẩu chính, nút **Đăng nhập**; nút bị vô hiệu khi < 15 ký tự; đúng → tab Quản lý mật khẩu | Login (has-account); disabled state nút |
| FR-4 | Sai 1–4: nhập lại ngay; 5–9: **chờ 30 phút** sau mỗi lần; lần 10: **tự xóa tài khoản + vault** → Login chưa có tài khoản; hiển thị **số lần thử còn lại trước khi dữ liệu bị xóa**; khi chờ hiển thị **đồng hồ đếm ngược** | Login: attempts-remaining, lockout/countdown, wiped state |
| FR-5 | Đăng nhập đúng → bộ đếm về 0; nhập lại đúng chuỗi sai ngay trước không tính thêm; mỗi lúc 1 lần kiểm tra (bấm liên tiếp không tạo thêm lần thử); tăng bộ đếm trước khi kiểm tra (tắt app giữa chừng = sai) | Login: trạng thái đang kiểm tra (chặn bấm lặp) |
| FR-6 | Bộ đếm + thời gian chờ lưu bền; chỉnh đồng hồ không rút ngắn; reboot khi đang chờ → tính lại từ đầu | Login countdown có thể "reset" sau reboot |
| FR-7 | Mật khẩu đúng nhưng vault hỏng → trạng thái **"Dữ liệu bị hỏng"**; không tính bộ đếm, không bao giờ xóa; gợi ý "Xóa & Tạo tài khoản mới" + import | Login: error state "Dữ liệu bị hỏng" |
| FR-8 | 3 luật FR-4 cố định, **không** có cài đặt thay đổi | Cài đặt: không có mục này |
| FR-9 | Login (đã có tài khoản) có nút **"Xóa & Tạo tài khoản mới"**: (1) bấm → hộp thoại xác nhận; (2) **giữ nút xác nhận trong hộp thoại 3 giây**; không yêu cầu mật khẩu; xong → Login chưa có tài khoản | Login + dialog hold-to-confirm |
| FR-10 | **Không** có khôi phục: không "quên mật khẩu", gợi ý, câu hỏi bảo mật, khóa khôi phục | Login: không có link "Quên mật khẩu" |
| FR-11 | Gỡ app = xóa sạch; cài lại như mới | First-run sau cài lại |
| FR-12 | Xóa (lần 10 hoặc FR-9) xóa mọi thứ: card, Recent, bản nháp, bộ đếm, clipboard (nếu còn giá trị app); bị gián đoạn → lần mở sau xóa nốt rồi mới hiện Login chưa có tài khoản | Trạng thái "đang xóa/xóa tiếp" khi mở app |
| FR-13 | Change Main Password: nhập **mật khẩu cũ** → mật khẩu mới (FR-2) → xác nhận; sai mật khẩu cũ không tính bộ đếm; bản nháp giữ; file export cũ không ảnh hưởng | Màn Change Main Password; lỗi sai mật khẩu cũ |
| FR-14 | **Giới hạn phiên tuyệt đối** từ lúc đăng nhập (mặc định FR-46: 10 phút); hết → khóa, yêu cầu đăng nhập lại **kể cả khi đang thao tác** | Locked state, chuyển về Login giữa chừng |
| FR-15 | **Autolock** khi app chạy nền quá thời hạn (mặc định 3 phút); FR-14 & FR-15 độc lập, cái nào đến trước thì khóa | Locked state khi quay lại app |
| FR-16 | Đến lúc khóa mà đang **ghi** (đổi mật khẩu chính, tạo file export, ghi import) → khóa ngay sau khi ghi xong/hoàn tác; import/export **chưa bắt đầu ghi** (vd đang ở trình chọn file) → hủy, dữ liệu giữ nguyên | Trạng thái chờ ghi xong rồi khóa; hủy flow |
| FR-17 | Tab Quản lý mật khẩu: danh sách card hiển thị **cả 4 field** (ẩn dòng Note nếu trống); nút **Copy** cho tên đăng nhập + mật khẩu ngay trên card; mật khẩu có nút **ẩn/hiện**, **mặc định ẩn**; Note hiện **tối đa 3 dòng đầu**, bấm vào để xem toàn bộ | Card list item; Note expanded view (surface chưa định) |
| FR-18 | Sắp theo thời gian tạo, **mới nhất trên cùng**; sửa không đổi vị trí | Card list ordering |
| FR-19 | Tìm kiếm **chỉ theo tiêu đề**: khớp substring, không phân biệt hoa thường, **không phân biệt dấu tiếng Việt** ("ngan hang" → "Ngân hàng", "d" ↔ "đ"); hiện mọi card khớp (cả trùng tiêu đề) theo thứ tự FR-18; cập nhật ngay khi gõ | Search bar; no-results state (ngầm định) |
| FR-20 | Chưa có card → hướng dẫn tạo card đầu tiên | Empty state tab Quản lý mật khẩu |
| FR-21 | **Nút nổi bật** tạo card mới | FAB / primary action |
| FR-22 | Tiêu đề, Tên đăng nhập, Mật khẩu **bắt buộc**; Note không; cho phép trùng tiêu đề | Form tạo/sửa: validation bắt buộc |
| FR-23 | Góc trên phải mỗi card: nút menu → popup **Sửa** / **Xóa** | Card overflow menu |
| FR-24 | Form sửa: sửa 4 field, bấm **Lưu**; đổi mật khẩu: gõ tay hoặc nút **"Tạo mật khẩu"** → sheet (FR-28); **Use Password** thay giá trị; đóng sheet không bấm → giữ nguyên. Form **tạo card mới không có** nút "Tạo mật khẩu" | Form sửa card ≠ form tạo card |
| FR-25 | Xóa card cần **hộp thoại xác nhận** | Confirm dialog |
| FR-26 | **Bản nháp**: tự lưu mã hóa sau mỗi thay đổi khi tạo/sửa; tối đa 1; app khóa (FR-14/15/49) hoặc OS kill → lần đăng nhập sau **mở lại bản nháp**; hủy khi Lưu / chủ động bỏ thay đổi / dữ liệu bị xóa | Restore-draft state sau login; hành động "bỏ thay đổi" |
| FR-27 | **Màn hình Tạo mật khẩu** (`password_generator.jpg`): tiêu đề "Password Generator"; nút **Recent Passwords** (icon lịch sử) góc trên phải; mật khẩu + nút tạo lại; nút **Copy**; dòng **Password Length** (kiểu điều khiển do UX quyết); 4 công tắc **Uppercase Letters (A–Z)**, **Lowercase Letters (a–z)**, **Digits (0–9)**, **Special Characters** + bộ ký tự `~!@#$%^&*+-/.,\{}[]();:?<>"'_` hiển thị bên dưới. **Bỏ nút Back** (F3 intro) | Tab Tạo mật khẩu |
| FR-28 | **Sheet tạo mật khẩu** (`edit_pass.jpg`): drag handle + nút tạo lại; nhãn **Password strength** (chỉ ở sheet); mật khẩu; slider **Password Length** + giá trị; 3 chip **123**, **ABC**, **!@#**; nút **Use Password** | Bottom sheet từ form sửa |
| FR-29 | Độ dài **4–99** | Range cho slider / picker |
| FR-30 | Màn hình: 4 công tắc độc lập, tắt cả 4 → chỉ chữ thường. Sheet: **luôn chữ thường**; ABC = chữ hoa; 123 = số; !@# = ký tự đặc biệt (cùng bộ) | Logic công tắc / chip |
| FR-31 | Đổi bất kỳ tiêu chí → **tự tạo lại**; nút tạo lại sinh mới | Live regenerate |
| FR-32 | Mỗi loại đang bật xuất hiện ≥1 lần | (logic) |
| FR-33 | **Tô màu theo loại ký tự**: chữ cái **đen**, chữ số **xanh dương**, ký tự đặc biệt **cam**; bảng màu dark mode do UX quyết | Password display (generator, sheet, Recent; card?—xem §11) |
| FR-34 | **Password strength** 3 mức theo entropy = độ dài × log₂(số ký tự các loại bật): **Low < 50 bit**, **Medium 50–<80**, **High ≥ 80** | Nhãn ở sheet |
| FR-35 | Lưu bộ tiêu chí gần nhất (bền); **dùng chung** giữa màn hình & sheet: 123↔Digits, !@#↔Special, ABC↔Uppercase, Lowercase chỉ có ở màn hình; lần đầu: **mọi loại bật, độ dài 16** | Default/first-run state generator |
| FR-36 | Use Password chỉ điền vào card, **không** ghi Recent | — |
| FR-37 | **Recent** mở dạng **sheet** từ nút lịch sử: nút **Close** + tiêu đề; danh sách mục (thời điểm `dd/MM/yyyy HH:mm`, mật khẩu tô màu FR-33, nút Copy); nút **Clear** ở cuối sheet | Recent sheet |
| FR-38 | Ghi Recent **khi và chỉ khi** bấm Copy trên màn hình Tạo mật khẩu | — |
| FR-39 | Copy cùng mật khẩu nhiều lần → 1 mục; không đổi thời điểm/vị trí/hạn | — |
| FR-40 | Mới nhất trên cùng | Recent ordering |
| FR-41 | Mỗi mục tự xóa sau **72 giờ** (riêng từng mục) | Mục biến mất |
| FR-42 | **Clear** xóa toàn bộ sau **hộp thoại xác nhận** | Confirm dialog |
| FR-43 | Recent trống → **trạng thái rỗng**, nút Clear **vô hiệu**; trống khi chưa copy / vừa Clear / tất cả hết hạn | Empty state Recent |
| FR-44 | Recent mã hóa trong vault | — |
| FR-45 | **Tab bar 3 tab**: Quản lý mật khẩu, Tạo mật khẩu, Cài đặt; mặc định sau đăng nhập: Quản lý mật khẩu | Navigation |
| FR-46 | 3 cài đặt thời gian, chọn bằng **picker** trong **1 / 3 / 5 / 10 phút**, **không** có "Không bao giờ": Autolock Vault (mặc định 3), Giới hạn phiên (10), Clear Clipboard (3) | Cài đặt: 3 picker rows |
| FR-47 | **Ngôn ngữ**: English / Tiếng Việt (lần đầu theo ngôn ngữ máy: vi → Tiếng Việt, khác → English). **Giao diện**: Theo hệ thống / Sáng / Tối (mặc định Theo hệ thống) | Cài đặt: 2 lựa chọn |
| FR-48 | Change Main Password theo FR-13 | Cài đặt → màn đổi mật khẩu |
| FR-49 | **Lock Vault** khóa ngay → Login; = Sign out; không có nút Sign out riêng | Cài đặt action |
| FR-50 | **Import** và **Export** là 2 mục trong danh sách Cài đặt; **không** dùng icon cloud; Export hiển thị **"Lần export gần nhất: dd/MM/yyyy"** hoặc **"Chưa export lần nào"**; ngày ghi ngay khi tạo file xong (kể cả đóng share sheet không gửi) | Cài đặt rows + subtitle |
| FR-51 | Export: **nhập lại mật khẩu chính** trước; sai không tính bộ đếm | Export step 1 + lỗi |
| FR-52 | Đặt **mật khẩu export** theo FR-2 + nhập lại; **dòng gợi ý (không điền sẵn)**: có thể dùng lại mật khẩu chính; **cảnh báo rõ** quên mật khẩu export = file vô dụng | Export step 2 |
| FR-53 | File chỉ chứa card (tiêu đề, tên ĐN, mật khẩu, Note, thời gian tạo) | — |
| FR-54 | File mã hóa, tham số cố định, đọc được trên mọi máy | — |
| FR-55 | Tạo file xong → **menu chia sẻ của OS** (Zalo, email, Drive, Files) | OS share sheet |
| FR-56 | Import chỉ nhận file PAK Manager; file khác → **"File không hợp lệ"**; chọn file bằng **trình chọn file OS** → nhập mật khẩu export; **không** cần mật khẩu chính; **không giới hạn** số lần sai mật khẩu export | Import: OS file picker → nhập mật khẩu export; lỗi |
| FR-57 | Import **thêm**, không ghi đè: trước khi thêm cho biết **số card** + **ngày export** → **Xác nhận** / **Hủy**; không tự loại trùng; xong báo **"Đã thêm N card"** | Import preview dialog + success message |
| FR-58 | Card import giữ thời gian tạo gốc, xếp theo FR-18 | Card có thể chèn giữa danh sách |
| FR-59 | Import nguyên tử: sai mật khẩu / file hỏng / gián đoạn → dữ liệu nguyên vẹn | Error states import |
| FR-60 | Import không đụng Recent, cài đặt, bản nháp | — |
| FR-61 | iOS ↔ Android tương thích file | — |
| FR-62 | Bản mới đọc file bản cũ | — |
| FR-63 | Tham số mã hóa ngoài giới hạn → **"File không hợp lệ"** | Error |
| FR-64 | Các nút Copy: tên ĐN + mật khẩu trên card, màn hình Tạo mật khẩu, từng mục Recent. Mật khẩu và Note **không cho bôi chọn hay kéo thả**; chỉ lấy qua nút Copy | Text không selectable; phản hồi copy (chưa nêu) |
| FR-65 | **Mọi** copy áp dụng Clear Clipboard; chỉ xóa nếu clipboard còn đúng giá trị app copy. iOS: hạn tự hết + local only (không Universal Clipboard). Android 13+: đánh dấu **nhạy cảm**; quay lại app quá hạn → xóa ngay; không quay lại → tối đa ~1 giờ (giới hạn nền tảng). Cả hai: xóa khi khóa lúc tiền cảnh (Lock Vault, hết phiên) và khi xóa dữ liệu | Hành vi clipboard; Android hiển thị nội dung nhạy cảm ẩn (OS) |

---

## 5. Screens / surfaces

Nguồn cấu trúc: PRD FR-45 ("3 tab + Login" — REC §4). IDEA ghi "4 màn hình"; ảnh có ~5 icon tab (cắt) — đều đã bị PRD thay.

| # | Surface | Phải chứa | Nguồn |
|---|---|---|---|
| S1 | **Login — trạng thái chưa có tài khoản** | Nút **"Tạo tài khoản"** | FR-1, FR-4, FR-9, FR-12 |
| S2 | **Tạo tài khoản** (màn/flow từ S1) | Cảnh báo quên = mất hết; ô mật khẩu chính; ô nhập lại; thanh độ mạnh **Low / Medium / High**; thông báo lỗi ASCII / blocklist / lặp-tuần tự / độ dài 15–128 | FR-1, FR-2, NFR-9, ADD "Màn hình Login" |
| S3 | **Login — đã có tài khoản** | Tên app **PAK Manager**; ô mật khẩu chính; nút **Đăng nhập** (disabled < 15 ký tự); **số lần thử còn lại trước khi dữ liệu bị xóa**; **đồng hồ đếm ngược** khi đang chờ; nút **"Xóa & Tạo tài khoản mới"** (cách xa nút Đăng nhập — ADD); trạng thái "Dữ liệu bị hỏng" | FR-3–FR-9, ADD |
| S4 | **Dialog xác nhận "Xóa & Tạo tài khoản mới"** | Nút xác nhận phải **giữ 3 giây**, phản hồi rõ (vd vòng tiến trình — ADD gợi ý) | FR-9, ADD |
| S5 | **Tab Quản lý mật khẩu** (mặc định sau login) | Thanh tìm kiếm (theo tiêu đề); danh sách card; nút nổi bật tạo card; empty state hướng dẫn tạo card đầu tiên | FR-17–FR-21, FR-45 |
| S5a | **Card (list item)** | Tiêu đề; Tên đăng nhập + Copy; Mật khẩu (ẩn mặc định) + ẩn/hiện + Copy; Note ≤3 dòng (ẩn khi trống); nút menu góc trên phải | FR-17, FR-23, FR-64 |
| S5b | **Popup menu card** | **Sửa**, **Xóa** | FR-23 |
| S5c | **Dialog xác nhận xóa card** | Đồng ý / hủy | FR-25 |
| S5d | **Xem toàn bộ Note** | "Bấm vào Note thì xem được toàn bộ nội dung" — dạng surface không nêu | FR-17 |
| S6 | **Form tạo card** | Tiêu đề*, Tên đăng nhập*, Mật khẩu*, Note; nút Lưu; **không** có nút "Tạo mật khẩu"; bản nháp tự lưu; cách "bỏ thay đổi" | FR-21, FR-22, FR-24, FR-26 |
| S7 | **Form sửa card** | 4 field; nút **"Tạo mật khẩu"**; nút **Lưu**; bản nháp tự lưu | FR-24, FR-26 |
| S8 | **Sheet tạo mật khẩu** (`edit_pass.jpg`) | Drag handle; nút tạo lại (tròn, viền, góc trên phải — IMG); "Password strength: <mức>"; mật khẩu tô màu; slider Password Length + giá trị (4–99); chip 123 / ABC / !@# (có dấu check teal — IMG); nút **Use Password** | FR-28–FR-36 |
| S9 | **Tab Tạo mật khẩu** (`password_generator.jpg`) | Tiêu đề "Password Generator" (không Back); icon lịch sử góc trên phải; mật khẩu tô màu + nút tạo lại; nút **Copy** (full-width); Password Length (control do UX quyết); 4 công tắc; dòng bộ ký tự đặc biệt; **không** có nhãn strength | FR-27, FR-29–FR-35, REC G10 |
| S9a | **Bộ chọn độ dài** (picker/màn con — chưa chốt) | Giá trị 4–99 | FR-27, ADD |
| S10 | **Sheet Recent Passwords** (`recent_password.jpg`) | **Close** + tiêu đề "Recent Passwords"; danh sách (thời điểm `dd/MM/yyyy HH:mm`, mật khẩu tô màu, Copy); nút **Clear** ở cuối; empty state; Clear disabled khi trống | FR-37–FR-43 |
| S10a | **Dialog xác nhận Clear** | | FR-42 |
| S11 | **Tab Cài đặt** (`setting.jpg`) | Autolock Vault (picker); Giới hạn phiên (picker); Clear Clipboard (picker); Ngôn ngữ; Giao diện; Change Main Password; Lock Vault; Import; Export (+ "Lần export gần nhất: dd/MM/yyyy" / "Chưa export lần nào"). **Bỏ**: Use Face ID, Notifications, icon cloud | FR-46–FR-50, PRD §7 |
| S11a | **Picker thời gian** (1/3/5/10 phút) | Ảnh: popup picker (icon ⌃⌄) | FR-46, PSE |
| S11b | **Chọn Ngôn ngữ / Giao diện** | English · Tiếng Việt / Theo hệ thống · Sáng · Tối | FR-47 |
| S12 | **Change Main Password** | Mật khẩu cũ; mật khẩu mới (FR-2 + thanh độ mạnh); xác nhận | FR-13, FR-48 |
| S13 | **Export flow** | B1 nhập lại mật khẩu chính → B2 mật khẩu export + nhập lại + gợi ý dùng lại mật khẩu chính (không điền sẵn) + cảnh báo → tạo file → **OS share sheet** | FR-51–FR-55 |
| S14 | **Import flow** | **OS file picker** → nhập mật khẩu export (không giới hạn sai) → xác nhận "file có N card, export ngày …" **Xác nhận / Hủy** → "Đã thêm N card"; lỗi "File không hợp lệ" | FR-56–FR-63 |
| S15 | **Tab bar** | 3 tab: Quản lý mật khẩu · Tạo mật khẩu · Cài đặt | FR-45 |

Bố cục thích ứng **điện thoại và máy tính bảng** (NFR-12) áp cho mọi surface.

---

## 6. States

| State | Ở đâu | Chi tiết | Nguồn |
|---|---|---|---|
| **First-run / chưa có tài khoản** | Login | Chỉ có "Tạo tài khoản"; cũng là trạng thái sau xóa (FR-4 lần 10, FR-9), sau cài lại (FR-11) | FR-1, FR-11 |
| First-run generator | Tạo mật khẩu | Mọi loại ký tự bật, độ dài 16 | FR-35 |
| First-run ngôn ngữ | Toàn app | Theo ngôn ngữ máy: vi → Tiếng Việt, khác → English | FR-47 |
| First-run giao diện | Toàn app | Theo hệ thống | FR-47 |
| First-run Export row | Cài đặt | "Chưa export lần nào" | FR-50 |
| **Disabled** | Nút Đăng nhập | < 15 ký tự | FR-3 |
| Disabled | Nút Clear (Recent) | Khi Recent trống | FR-43 |
| **Error – sai mật khẩu** | Login | Lần 1–4: nhập lại ngay; hiển thị số lần còn lại | FR-4 |
| **Lockout / cooldown** | Login | Lần 5–9: chờ 30 phút + **đồng hồ đếm ngược**; lưu bền; reboot → đếm lại từ đầu | FR-4, FR-6 |
| **Wiped (tự xóa)** | Login | Lần 10 → Login chưa có tài khoản | FR-4, FR-12 |
| Đang kiểm tra mật khẩu (busy) | Login | Chỉ 1 lần kiểm tra mỗi lúc; KDF ~1 s, tối đa 2 s trên máy yếu nhất (→ loading ngầm định) | FR-5, NFR-2 |
| **Error – "Dữ liệu bị hỏng"** | Login | Mật khẩu đúng, vault hỏng; không tính bộ đếm | FR-7 |
| Đang xóa / xóa tiếp | Mở app | Xóa bị gián đoạn → mở lần sau xóa nốt rồi mới hiện Login | FR-12, ADD "Bộ đếm sai…" |
| Validation lỗi mật khẩu chính / export | Tạo tài khoản, đổi mật khẩu, Export | < 15 / > 128 ký tự; ký tự không ASCII (thông báo dễ hiểu — ADD); nằm trong blocklist; lặp/tuần tự; xác nhận không khớp (ngầm định) | FR-2, FR-52, ADD |
| Strength meter | Tạo tài khoản / đổi / export | Low / Medium / High | FR-2 |
| **Locked (session/autolock)** | Toàn app → Login | Hết giới hạn phiên (kể cả đang thao tác); chạy nền quá Autolock; Lock Vault | FR-14, FR-15, FR-49 |
| Khóa hoãn khi đang ghi | Đổi mật khẩu, export, import | Khóa sau khi ghi xong/hoàn tác; nếu chưa ghi (đang ở file picker) → hủy | FR-16 |
| **Restore draft** | Sau login | Mở lại bản nháp card đang tạo/sửa | FR-26 |
| **Empty – card list** | Quản lý mật khẩu | Hướng dẫn tạo card đầu tiên | FR-20 |
| Empty – search no results | Quản lý mật khẩu | **Không được nêu** trong nguồn (ngầm định từ FR-19) | — |
| **Empty – Recent** | Sheet Recent | Trạng thái rỗng + Clear disabled | FR-43, REC G8 |
| Password ẩn/hiện | Card | Mặc định ẩn | FR-17 |
| Note thu gọn / mở rộng | Card | ≤3 dòng / toàn bộ | FR-17 |
| Error – sai mật khẩu chính khi Export / sai mật khẩu cũ khi đổi | Export, Change Main Password | Không tính bộ đếm | FR-13, FR-51 |
| Error – Import | Import | "File không hợp lệ" (file khác / tham số ngoài giới hạn); sai mật khẩu export (không giới hạn); file hỏng / gián đoạn → dữ liệu nguyên vẹn | FR-56, FR-59, FR-63 |
| Success – Import | Import | "Đã thêm N card" | FR-57 |
| Success – Export | Export | OS share sheet; cập nhật "Lần export gần nhất" | FR-50, FR-55 |
| Loading | — | Không nguồn nào nhắc "loading" trực tiếp; chỉ ngầm qua KDF ~1–2 s (login, export, import) | NFR-2, NFR-3 |
| **Offline** | — | App **luôn** offline, không có trạng thái mạng | NFR-7, TC-4 |

---

## 7. Security-UX constraints (giá trị chính xác)

| Hạng mục | Giá trị / luật | Nguồn |
|---|---|---|
| Mật khẩu chính – độ dài | **15–128** ký tự | FR-2 |
| Mật khẩu chính – ký tự | Chỉ **ASCII in được, kể cả khoảng trắng**; từ chối chữ có dấu/Unicode, báo rõ lý do | FR-2, ADD |
| Composition | **Không** bắt buộc hoa/số/đặc biệt | FR-2 (NIST SP 800-63B-4) |
| Blocklist | Từ chối mật khẩu phổ biến/bị lộ (nhúng offline); từ chối lặp 1 ký tự / dãy tuần tự (`aaaaaaaaaaaaaaa`, `123456789012345`) | FR-2 |
| Strength meter mật khẩu chính | **Low / Medium / High**, theo mẫu dễ đoán (từ điển, dãy phím, ngày tháng) — RD gợi ý zxcvbn | FR-2, RD §5 |
| Mật khẩu export | Cùng quy tắc FR-2 (15–128 ASCII), nhập lại xác nhận; gợi ý có thể dùng lại mật khẩu chính (không điền sẵn); cảnh báo quên = file vô dụng | FR-52 |
| Nhập sai | Lần 1–4 ngay; 5–9 chờ **30 phút** mỗi lần; lần **10** xóa toàn bộ. **Cố định**, không tùy chỉnh | FR-4, FR-8 |
| Không tính sai | Lặp lại đúng chuỗi sai trước; vault hỏng; sai mật khẩu cũ (Change Main Password); sai mật khẩu chính trước Export | FR-5, FR-7, FR-13, FR-51 |
| Import | Không giới hạn sai mật khẩu export; không cần mật khẩu chính | FR-56 |
| Xóa & Tạo tài khoản mới | Dialog + **giữ 3 giây**; không cần mật khẩu | FR-9 |
| Khôi phục | **Không có** (luật cứng) | FR-10 |
| Giới hạn phiên | Tuyệt đối từ lúc login; mặc định **10 phút**; lựa chọn 1/3/5/10 | FR-14, FR-46 |
| Autolock Vault | Khi chạy nền; mặc định **3 phút**; 1/3/5/10; **không** khóa ngay khi chuyển app | FR-15, FR-46, PRD §1 nguyên tắc 1 |
| Clear Clipboard | Mặc định **3 phút**; 1/3/5/10; áp cho **mọi** copy; iOS expirationDate + localOnly; Android 13+ EXTRA_IS_SENSITIVE, xóa khi quay lại foreground, tối đa ~**1 giờ** nếu không quay lại | FR-46, FR-65, ADD Clipboard |
| "Không bao giờ" | Không có cho bất kỳ cài đặt thời gian nào | FR-46, §7 |
| Sinh trắc học | **Ngoài phạm vi** (Face ID/vân tay bị bỏ; "Use Face ID" xóa khỏi Cài đặt) | §7, IDEA, BI |
| Chụp màn hình | **Không** chặn; **không** che ảnh thu nhỏ đa nhiệm (rủi ro chấp nhận) | NFR-10, §1, §7 |
| Chọn/kéo text | Mật khẩu và Note **không** bôi chọn / kéo thả | FR-64 |
| Mật khẩu trên card | Mặc định **ẩn** | FR-17 |
| Bàn phím / autofill | Tắt đề nghị lưu mật khẩu OS (iCloud Keychain, Google Autofill), tắt autocorrect, gợi ý, học từ (ô mật khẩu chính, export, card). iOS: không dùng textContentType .password/.newPassword; Android: importantForAutofill="no", IME_FLAG_NO_PERSONALIZED_LEARNING. Test với bàn phím mặc định, Gboard, **Laban Key** | NFR-9, ADD |
| KDF unlock time | ~**1 s**, tối đa **2 s** trên máy yếu nhất (Argon2id m=64 MiB, t=3, p=4 đề xuất) | NFR-2, ADD |
| Backup OS | Loại khỏi iCloud/Google Backup/chuyển máy; **file export là backup duy nhất** | NFR-8, F6 |
| Khi khóa | Bỏ khóa và dữ liệu giải mã khỏi bộ nhớ; xóa clipboard nếu khóa lúc tiền cảnh | NFR-4, FR-65 |
| Recent | Hết hạn **72 giờ**/mục; mã hóa | FR-41, FR-44 |
| Mạng | Không có (Android không có quyền INTERNET) | NFR-7 |

---

## 8. Microcopy / tone / ngôn ngữ

- **Ngôn ngữ UI:** **English** và **Tiếng Việt**, mọi chuỗi có đủ hai bản (NFR-14, FR-47). Mặc định theo ngôn ngữ máy (vi → Tiếng Việt, còn lại → English). Chính sách quyền riêng tư cũng có cả hai bản (PRD §6).
- Tên nút/cài đặt trong PRD là **tên tham chiếu** lấy từ ảnh (tiếng Anh) — chuỗi thực tế cần bản EN + VI (PRD Thuật ngữ).
- Tên app hiển thị: **PAK Manager** (FR-3, PRD §6). (IDEA/BI: "Password Manager".)
- Chuỗi nguyên văn trong nguồn:
  - Login: "Tạo tài khoản", "Đăng nhập", "Xóa & Tạo tài khoản mới", "Dữ liệu bị hỏng"
  - Card: "Sửa", "Xóa", "Lưu", "Copy", "Tạo mật khẩu", "Use Password"
  - Generator (ảnh/PRD): "Password Generator", "Recent Passwords", "Copy", "Password Length", "Uppercase Letters (A–Z)", "Lowercase Letters (a–z)", "Digits (0–9)", "Special Characters", "Password strength" (ảnh: "Password strength: High"; "Password Length:" có dấu hai chấm trong sheet), "123", "ABC", "!@#", Low / Medium / High
  - Recent: "Close", "Recent Passwords", "Clear"
  - Cài đặt (ảnh): "Settings", "GENERAL", "Autolock Vault", "Clear Clipboard", "Change Main Password", "Lock Vault"; PRD thêm: "Giới hạn phiên", "Ngôn ngữ", "Giao diện" (Theo hệ thống / Sáng / Tối), "Import", "Export", "Lần export gần nhất: dd/MM/yyyy", "Chưa export lần nào"
  - Import: "File không hợp lệ", "Xác nhận", "Hủy", "Đã thêm N card"
  - Ví dụ giá trị picker trong ảnh: "1 min", "30 sec" (giá trị cũ).
- **Định dạng ngày:** `dd/MM/yyyy HH:mm` (Recent, FR-37); `dd/MM/yyyy` (Export, FR-50). Nguồn không nói định dạng có đổi theo ngôn ngữ hay không.
- **Cảnh báo bắt buộc (nội dung, không nguyên văn):** quên mật khẩu chính = mất toàn bộ dữ liệu (FR-1); quên mật khẩu export = file vô dụng (FR-52); thông báo lỗi ký tự có dấu phải **dễ hiểu** và nêu lý do (FR-2, ADD). Store description phải cảnh báo quên mật khẩu chính = mất hết + nên export định kỳ (PRD §6).
- **Tone:** nguồn không định nghĩa tone/voice. Ngầm: rõ ràng, cảnh báo thẳng thắn; không thiết kế riêng cho người ít rành công nghệ (PRD §1, §7).

---

## 9. Accessibility, platform, dark mode, i18n, offline, notifications

- **Nền tảng:** iOS + Android, **điện thoại và máy tính bảng**, bố cục thích ứng; OS tối thiểu chốt ở architecture (NFR-12). Phát hành App Store + Google Play, miễn phí (PRD §6).
- **Phong cách Android:** ảnh tham chiếu kiểu iOS native; chọn giữ nguyên hay Material — **mở cho UX** (ADD; REC G6).
- **Dark mode:** có giao diện sáng + tối; lựa chọn Theo hệ thống / Sáng / Tối, mặc định Theo hệ thống (NFR-13, FR-47). Ảnh chỉ có light (PSE). Bảng màu mật khẩu dark mode do UX quyết (FR-33, ADD).
- **i18n:** EN + VI đầy đủ (NFR-14). Tìm kiếm không phân biệt dấu tiếng Việt, "d" ↔ "đ" (FR-19). Mật khẩu chính/export chỉ ASCII (FR-2) — **không** chuẩn hóa Unicode (ADD).
- **Offline:** hoàn toàn, không SDK quảng cáo/analytics/crash reporting (NFR-7). Export/import qua share sheet & file picker của OS, không cần mạng (FR-55, FR-56).
- **Notifications:** công tắc Notifications **bị bỏ** (PRD §7 "Giao diện đã bỏ"; REC §4). Không có thông báo đẩy nào được nêu.
- **Accessibility:** **Không nguồn nào nêu yêu cầu accessibility cụ thể** (không WCAG, Dynamic Type, screen reader, contrast). Liên quan gián tiếp: người dùng có thể là người thân lớn tuổi nhưng **không** thiết kế riêng (PRD §1, §7); monospace giúp phân biệt l/1/I, O/0 (ADD); màu tô ký tự là kênh thông tin (FR-33).
- **Screenshot / multitasking:** không chặn, không che (NFR-10).
- **Clipboard OS behaviors:** iOS local only (không Universal Clipboard); Android 13+ sensitive flag (FR-65).

---

## 10. Visual / brand

- **Màu nhấn:** **một** màu nhấn **teal-green** (NFR-13; PSE "Tổng thể"). PSE ước lượng nút Copy nền teal **~#1E8A72**, chữ trắng. Ảnh: slider fill màu teal sáng hơn (xanh ngọc), chip nền teal rất nhạt với check tròn teal đậm.
- **Phong cách:** "theo ảnh tham chiếu" (NFR-13). Ảnh = **iOS native**: inset-grouped, nền **#F2F2F7** (Settings), toggle iOS màu teal, sheet có drag handle, header nhóm "GENERAL" chữ hoa xám, nút chữ teal trong khối nền trắng riêng (Change Main Password, Lock Vault) (PSE, IMG:setting).
- **Màu ký tự mật khẩu (light):** chữ cái **đen**, chữ số **xanh dương**, ký tự đặc biệt **cam** (FR-33; IMG).
- **Font mật khẩu:** ảnh không nhất quán — generator + Recent dùng **monospace đậm** (Recent: monospace thường), sheet dùng font thường (PSE, ADD). Chọn chung — **mở cho UX**.
- **Chi tiết ảnh:**
  - password_generator.jpg: nền trắng; Back "<" teal (sẽ bỏ); icon lịch sử đen góc phải; mật khẩu lớn căn giữa + icon refresh teal; nút Copy full-width bo góc teal; danh sách rows có divider; nhóm Special Characters tách riêng + dòng bộ ký tự; tab bar ~5 icon bị cắt.
  - setting.jpg: icon cloud ↓↑ góc phải (bỏ); pickers hiển thị giá trị xám + icon ⌃⌄; Use Face ID ON (bỏ), Notifications OFF (bỏ).
  - recent_password.jpg: sheet bo góc trên; "Close" teal bên trái, tiêu đề đậm giữa; dòng xen kẽ trắng/xám, thời điểm xám nhỏ trên, mật khẩu monospace dưới, icon copy teal bên phải; "Clear" teal căn giữa ở footer; thứ tự trong ảnh **cũ → mới** (PRD đảo).
  - edit_pass.jpg: drag handle xám; nút refresh tròn viền xám góc phải; "Password strength: High" xám; mật khẩu lớn font thường; khối viền bo góc chứa "Password Length:" + giá trị, slider, divider, 3 chip; nút "Use Password" teal.
- **Kaspersky:** **Không** có trong 6 nguồn được giao. Chỉ xuất hiện ở `ux-designs/ux-passwordmanager-2026-10-26/.memlog.md` (decision): ảnh `screens/` chụp từ **Kaspersky Password Manager** và là **MẪU BÁM THEO** (không chỉ tham khảo).
- **Icon/logo/app icon, typography chung, spacing:** không nguồn nào nêu.

---

## 11. Open UX points (PRD/ADD giao cho UX)

Từ **ADD § "Cho UX: các điểm chưa chốt"** (gần nguyên văn):

**Toàn app**
1. **Phong cách trên Android** — ảnh kiểu iOS native; chọn giữ nguyên trên Android hay chuyển Material. (ADD; REC G6)
2. **Font mật khẩu** — một font dùng chung cho mọi chỗ hiển thị mật khẩu; ảnh không nhất quán (generator + Recent monospace, sheet font thường); monospace giúp phân biệt l/1/I và O/0. (ADD; REC G2)
3. **Màu mật khẩu trong dark mode** — bảng màu dark tương ứng light (đen / xanh dương / cam). (ADD; FR-33)

**Màn hình Tạo mật khẩu và sheet**
4. **Chọn độ dài trên màn hình Tạo mật khẩu** — dòng "Password Length 16 >" có chevron; chọn cách nhập 4–99 (picker / màn con). (ADD; FR-27 "Kiểu điều khiển do bước UX quyết định"; REC G1)
5. **Thanh trượt trong sheet** — 4–99 = 96 nấc, khó chỉnh; có thể thêm +/− hoặc nhập số. (ADD; REC G14)
6. **Phân biệt hai chỗ dùng tên "Tạo mật khẩu"** — tab và nút trong form sửa card; đặt nhãn không gây nhầm. (ADD)

**Login**
7. **Nút "Xóa & Tạo tài khoản mới" (FR-9)** — đặt cách xa nút Đăng nhập; giữ 3 giây cần phản hồi rõ (vd vòng tiến trình). (ADD)
8. **Thông báo lỗi ký tự không hợp lệ (FR-2)** — khi gõ chữ có dấu, thông báo phải dễ hiểu. (ADD)

**Cài đặt**
9. **Nhóm và thứ tự các mục** — ảnh có nhóm "GENERAL"; Change Main Password và Lock Vault là nút chữ teal trong khối riêng; cần xếp nhóm/thứ tự cho mục mới: Giới hạn phiên, Ngôn ngữ, Giao diện, Import, Export (kèm "Lần export gần nhất"). (ADD; REC G11)

**Recent**
10. **Kiểu danh sách** — dòng xen kẽ trắng/xám, Clear căn giữa footer; giữ nguyên hay điều chỉnh cho dark mode và trạng thái rỗng (FR-43). (ADD; REC G12)

Từ **PRD** (trong thân FR):
11. FR-27: "Dòng **Password Length** … Kiểu điều khiển do bước UX quyết định." (= #4)
12. FR-33: "Bảng màu cho dark mode do bước UX quyết định." (= #3)

Chưa định nghĩa trong nguồn (không phải "giao cho UX" tường minh, nhưng UX sẽ phải lấp — chỉ liệt kê):
- Surface xem toàn bộ Note (FR-17), form tạo/sửa card là màn đầy đủ hay sheet (FR-21/24), cách "chủ động bỏ thay đổi" bản nháp (FR-26), empty state khi tìm kiếm không ra kết quả (FR-19), phản hồi sau khi Copy (FR-64), màu tô mật khẩu có áp trên card không (FR-33 chỉ dẫn ở Recent FR-37), cách hiển thị bản nháp được khôi phục (FR-26), dạng hiển thị đếm ngược / số lần còn lại (FR-4), trình bày preview import (FR-57), kiểu picker cho Ngôn ngữ/Giao diện (FR-47), layout tablet (NFR-12), accessibility (không nêu).

---

## 12. Out of scope (PRD §7 — UX không thiết kế)

- **Tài khoản & khôi phục:** nhiều tài khoản/máy; mọi cơ chế khôi phục mật khẩu chính (quên mật khẩu, gợi ý, câu hỏi bảo mật, khóa khôi phục).
- **Đăng nhập:** nhập sai không giới hạn; tùy chỉnh luật FR-4; **đăng nhập sinh trắc học (Face ID, vân tay)**; mật khẩu chính/export có ký tự ngoài ASCII.
- **Card & tìm kiếm:** phân loại, thư mục, tag; field chuyên biệt theo loại tài khoản; tìm theo Note hoặc tên đăng nhập.
- **Tự động điền:** AutoFill của OS cho app khác.
- **Mạng & sao lưu:** đồng bộ, cloud, backend, mọi tính năng cần mạng; sao lưu iCloud/Google Backup.
- **Import/Export:** import ghi đè; import từ trình quản lý khác/CSV; tự loại trùng; nhập lại mật khẩu chính khi import; giới hạn sai mật khẩu export; đưa Recent/cài đặt/bản nháp vào file export.
- **Bảo mật màn hình:** khóa ngay khi chuyển app; chặn chụp màn hình; che ảnh thu nhỏ đa nhiệm.
- **Tạo mật khẩu:** bỏ bớt thành phần của màn hình Tạo mật khẩu hoặc sheet (ngoại lệ duy nhất: nút Back).
- **Giao diện đã bỏ:** công tắc **Notifications** và **Use Face ID**; **icon cloud** ở Cài đặt; lựa chọn **"Không bao giờ"** cho cài đặt thời gian.
- **Khác:** UX riêng cho người ít rành công nghệ; xử lý người chung máy cố tình nhập sai; thương mại hóa (không IAP, quảng cáo, gói trả phí — §6).
- Ngầm: không có nút Sign out riêng (FR-49); không có "Password strength" trên màn hình Tạo mật khẩu (FR-28, REC G10); form tạo card không có nút "Tạo mật khẩu" (FR-24).

---

## Phụ lục: Mâu thuẫn / khác biệt giữa các nguồn (PRD final thắng)

| Chủ đề | Nguồn cũ | PRD final |
|---|---|---|
| Tên app | "Password Manager" (IDEA, BI) | **PAK Manager** |
| Số tài khoản | Nhiều tài khoản/máy (IDEA) | 1 |
| Nhập sai | Không giới hạn (IDEA) | 10 lần / 30 phút / tự xóa |
| Số màn hình / tab | 4 màn hình (IDEA); ~5 icon tab (ảnh) | 3 tab + Login |
| Nút Back generator | Có (ảnh, BI) | Bỏ |
| Autolock mặc định | 1 min (ảnh) | 3 phút |
| Clear Clipboard mặc định | 30 sec (ảnh) / **1 phút** (BI) | **3 phút** |
| Notifications | Có (ảnh, BI §4.4) | Bỏ |
| Import/Export entry | Icon cloud (ảnh, BI) | 2 mục danh sách Cài đặt |
| Recent thứ tự / lưu giữ | Cũ nhất trên, giữ nhiều tháng (ảnh) | Mới nhất trên, 72 giờ |
| Theme | Chỉ light (ảnh) | Light + Dark + Theo hệ thống |
| Slider max | ~40 (suy từ ảnh) | 4–99 |
| Card fields | 3 (IDEA) | 4 (+ Note) |
| Tên nút xóa | "Xóa tài khoản + tạo mới" (BI) | "Xóa & Tạo tài khoản mới" (+ giữ 3 giây — BI chỉ có hộp thoại) |
| Tiêu chí generator | REC G5 đề xuất **lưu riêng** cho từng nơi | FR-35: **dùng chung** một bộ |
| Mã FR | REC dùng số FR cũ | Dùng số PRD final |
| Chụp màn hình / app switcher | RD §4 gợi ý FLAG_SECURE / che màn hình | Không chặn, không che (NFR-10) |
| Delay sai mật khẩu | RD §2: iOS leo thang 1/5/15/15/60 phút | Cố định 30 phút |
| Lưu bộ đếm | RD §2 gợi ý Keychain/Keystore | ADD: **không** lưu trong Keychain |
| Unlock time | RD §3 gợi ý 0.5–1 s | ~1 s, tối đa 2 s |
| Độ dài generator | RD §5 gợi ý 8–128, mặc định 16–20 | 4–99, mặc định 16 |
| Kaspersky | Không có trong 6 nguồn | Chỉ ở UX memlog (mẫu bám theo) |
| Tên file | ADD trỏ "`source-extract.md`" = file trong thư mục PRD (mô tả ảnh), **khác** file này | — |
