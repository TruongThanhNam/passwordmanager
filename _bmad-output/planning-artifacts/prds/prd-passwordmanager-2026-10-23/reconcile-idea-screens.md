---
title: Đối chiếu nguồn — idea.txt + screens/*.jpg + memlog brainstorm vs PRD/addendum
created: 2026-10-25
inputs:
  - idea.txt
  - screens/password_generator.jpg, setting.jpg, recent_password.jpg, edit_pass.jpg
  - _bmad-output/brainstorming/brainstorm-password-manager-app-2026-10-23/.memlog.md
compared_against: prd.md, addendum.md, .memlog.md (PRD), source-extract.md
---

# Đối chiếu nguồn: idea.txt, ảnh màn hình, memlog brainstorm

Quy ước:
- **GAP**: nguồn có, PRD bỏ qua hoặc không có FR tương ứng.
- **MƠ HỒ**: PRD có nhắc nhưng nguồn làm lộ ra chỗ chưa định nghĩa.
- **CỐ Ý**: PRD thay đổi có ghi trong memlog (brainstorm hoặc PRD). Không phải gap, chỉ liệt kê để truy vết.

## 1. Gap chính (ưu tiên)

| # | Loại | Nguồn | Nội dung | Gợi ý |
|---|---|---|---|---|
| G1 | GAP (FR) | password_generator.jpg | Dòng **"Password Length 16 >"** có chevron, tức là bấm vào để mở picker/màn hình con. FR-24 chỉ ghi "Dòng Password Length", không nói cách chọn độ dài trên màn hình đầy đủ (sheet thì có slider ở FR-25). Với khoảng 4–99 (FR-26), cách nhập ảnh hưởng UX. | Thêm vào FR-24 cách chọn độ dài (picker dạng wheel / màn hình con / stepper), hoặc ghi rõ để bước UX quyết. |
| G2 | GAP (look & feel) | password_generator.jpg, recent_password.jpg, edit_pass.jpg | Mật khẩu ở màn hình Tạo mật khẩu và Recent dùng **font monospace đậm**, giúp phân biệt `l/1/I`, `O/0`. Sheet edit_pass lại dùng font thường. PRD chỉ quy định tô màu (FR-30), không nói gì về font, cũng không giải quyết sự không nhất quán giữa hai nơi. | Thêm yêu cầu: mật khẩu hiển thị bằng font monospace (cả card, generator, sheet, Recent), hoặc chuyển cho UX trong addendum. |
| G3 | GAP (nguyên tắc) | memlog brainstorm | Nguyên tắc thiết kế **"giữ mọi thứ đơn giản nhất"** (không phân loại, không field chuyên biệt, Note tự do + tìm theo tiêu đề là đủ). PRD chỉ còn các mục rời trong "Ngoài phạm vi"; mục Tầm nhìn chỉ nêu "Bảo mật là ưu tiên số một" và nguyên tắc cân bằng. Mất tiêu chí để các bước sau tự loại tính năng. | Thêm "Đơn giản nhất có thể" làm nguyên tắc thứ hai trong mục 1 hoặc mục 2. |
| G4 | GAP (động lực) | idea.txt | Hai động lực bị bỏ: (a) "thời đại công nghệ số khi phải đăng ký thông tin và sử dụng rất nhiều ứng dụng" (đã báo ở source-extract, PRD vẫn chưa đưa vào); (b) "nếu chạy ổn thì chia sẻ cho gia đình và bạn bè". PRD có phát hành lên store nhưng Tầm nhìn không nêu đối tượng người thân/bạn bè, nên lý do phát hành công khai không được giải thích. Việc PRD không đo bằng lượt cài (mục 2) là cố ý, không mâu thuẫn. | Thêm 1–2 câu vào Tầm nhìn: bối cảnh "quá nhiều tài khoản", đối tượng mở rộng là gia đình/bạn bè (lý do phát hành store). |
| G5 | MƠ HỒ (FR) | password_generator.jpg + edit_pass.jpg | Hai nơi tạo mật khẩu dùng **mô hình tiêu chí khác nhau** (4 công tắc với 3 chip, nút chevron với slider). FR-32 "nhớ tiêu chí lần trước" không nói nhớ chung hay riêng cho từng nơi, và ánh xạ ra sao (ví dụ màn hình đầy đủ tắt riêng Uppercase thì chip ABC hiện trạng thái gì). Giá trị mặc định lần đầu của các loại ký tự cũng không được ghi (ảnh: tất cả đều bật); FR-26 chỉ chốt độ dài 16. | Bổ sung FR-32: tiêu chí lưu riêng cho từng nơi (đề xuất), và mặc định lần đầu = bật tất cả. |

## 2. Gap phụ

| # | Loại | Nguồn | Nội dung |
|---|---|---|---|
| G6 | GAP (look & feel) | Toàn bộ ảnh | Ảnh mẫu đều là **giao diện iOS native** (inset-grouped, nền #F2F2F7, toggle iOS, sheet có thanh kéo). NFR-12 nói "theo phong cách ở ảnh tham chiếu" nhưng không nói Android giữ y hệt phong cách iOS hay theo Material. |
| G7 | GAP (hành vi) | edit_pass.jpg | Sheet có thanh kéo, gợi ý vuốt xuống để đóng. PRD không nói đóng sheet mà không bấm Use Password thì field mật khẩu giữ nguyên (hành vi hủy). |
| G8 | GAP (hành vi) | recent_password.jpg | Không có trạng thái rỗng cho Recent (khi chưa copy lần nào, sau Clear hoặc sau khi tất cả hết hạn 3 ngày). Card có FR-17, Recent thì không. Trạng thái của nút Clear khi danh sách rỗng cũng chưa định nghĩa. |
| G9 | MƠ HỒ | password_generator.jpg + edit_pass.jpg | Bộ ký tự đặc biệt chỉ hiện ở màn hình đầy đủ (`~!@#$%^&*+-/.,\{}[]();:?<>"'_`). PRD không nói chip **!@#** trong sheet dùng cùng bộ ký tự này. Điều này ảnh hưởng trực tiếp tới entropy ở FR-31. |
| G10 | MƠ HỒ | password_generator.jpg | Màn hình đầy đủ **không có** nhãn Password strength, chỉ sheet có. PRD giữ đúng như ảnh, nhưng không ghi rõ đây là chủ ý. Cần xác nhận để UX không tự thêm vào. |
| G11 | GAP (look & feel) | setting.jpg | Header nhóm **"GENERAL"**; Change Main Password và Lock Vault là nút chữ teal, mỗi nút nằm trong card riêng. PRD thêm các mục mới (Giới hạn phiên, Ngôn ngữ, Import, Export) nhưng không nói chúng thuộc nhóm nào hay thứ tự ra sao. Đây là quyết định UX, cần chuyển tiếp. |
| G12 | GAP (look & feel) | recent_password.jpg | Các dòng xen kẽ nền trắng/xám; nút Clear căn giữa ở footer. PRD chỉ nói "Nút Clear ở cuối sheet". Chi tiết nhỏ, chuyển cho UX. |
| G13 | MƠ HỒ | idea.txt | Phương án "Tạo mật khẩu" chỉ được mô tả khi **sửa** card (idea.txt và FR-21). PRD không nói form **tạo card mới** có nút "Tạo mật khẩu" hay không. UJ-2 dùng dán từ Recent nên không bị chặn, nhưng tính nhất quán của form chưa rõ. |
| G14 | MƠ HỒ | edit_pass.jpg | Slider ở giá trị 16 nằm ở khoảng 35% thanh, tức max khoảng 40. PRD chốt 4–99 (cố ý, memlog PRD). Với 96 nấc, slider khó chỉnh chính xác. Cần lưu ý cho UX (ví dụ thêm nút +/-). |
| G15 | GAP (bối cảnh) | memlog brainstorm | Threat model thực tế: "kẻ trộm phổ thông reset máy và bán, tấn công có chủ đích rất hiếm". Đây là căn cứ cho nguyên tắc cân bằng (không chặn chụp màn hình, không khóa ngay khi chuyển app). PRD giữ kết luận nhưng bỏ căn cứ. Nên ghi vào addendum. |
| G16 | MƠ HỒ | idea.txt | idea.txt đặt tên app là "Password Manager". PRD dùng tên này ở tiêu đề tài liệu, nhưng FR-3 chỉ ghi "tên app". Tên hiển thị trên store/màn hình chưa được chốt như một quyết định. |

## 3. Đã được PRD bao phủ (không phải gap)

- **idea.txt:**
  - Offline hoàn toàn, mã hóa, không đọc được ngoài app: TC-1, NFR-1, NFR-6.
  - Login gồm tên app, ô mật khẩu, nút đăng nhập: FR-3.
  - Không có quên mật khẩu, cài lại thì mất hết: FR-9, FR-10.
  - Card có copy tên đăng nhập/mật khẩu, nút ẩn/hiện: FR-14.
  - Tìm theo tiêu đề: FR-16.
  - Nút nổi bật để tạo card: FR-18.
  - Sửa card bằng 2 cách đổi mật khẩu, bấm Lưu: FR-21, FR-33.
  - Recent Passwords ở góc trên phải, chỉ ghi khi Copy: FR-24, FR-36.
  - Nút random theo tiêu chí: FR-24, FR-28.
  - Settings bỏ Face ID, có import/export mã hóa, có sign out: FR-46, FR-47, F6.
  - Mọi tính năng chỉ dùng được sau đăng nhập: F1.
- **password_generator.jpg:** tiêu đề, icon lịch sử, mật khẩu tô màu kèm nút tạo lại, nút Copy, 4 công tắc với nhãn đầy đủ, dòng bộ ký tự đặc biệt (FR-24, FR-30).
- **edit_pass.jpg:** thanh kéo, nút tạo lại, nhãn strength, slider kèm giá trị, 3 chip, Use Password (FR-25, FR-31).
- **recent_password.jpg:** Close, tiêu đề, định dạng thời điểm `dd/MM/yyyy HH:mm`, mật khẩu tô màu, nút copy từng dòng, Clear (FR-35).
- **setting.jpg:** Autolock Vault, Clear Clipboard (picker), Change Main Password, Lock Vault (FR-43, FR-45, FR-46).
- **Màu nhấn teal-green:** NFR-12.
- **memlog brainstorm:**
  - 10 lần sai, chờ 30 phút từ lần thứ 5, tự xóa: FR-4.
  - Luật cứng không khôi phục: FR-9.
  - Note: F2.
  - Giữ nguyên thành phần generator/edit_pass: F3.
  - Export là backup duy nhất, mã hóa ngang vault: F6, NFR-3.
  - Bộ đếm lưu bền, không bị reset bằng chỉnh đồng hồ: FR-6.
  - Recent/Note mã hóa: FR-41, NFR-1.
  - 1 tài khoản/máy: F1.
  - Nút xóa ở Login có hộp thoại xác nhận: FR-8.
  - KDF chậm: NFR-2, addendum.
  - Bỏ UX riêng cho người ít rành công nghệ: mục 7.

## 4. Thay đổi cố ý (có trong memlog, không phải gap)

| Nguồn nói | PRD | Căn cứ |
|---|---|---|
| Nhiều tài khoản/máy (idea.txt) | 1 tài khoản/máy | memlog brainstorm (decision) |
| Không giới hạn nhập sai (idea.txt) | 10 lần, chờ 30 phút, tự xóa | memlog brainstorm (decision) |
| Card 3 field (idea.txt) | 4 field, thêm Note | memlog brainstorm (idea + direction) |
| Sign out (idea.txt) | Lock Vault = Sign out | memlog PRD |
| Autolock "1 min" (ảnh) | mặc định 3 phút | memlog PRD |
| Clear Clipboard "30 sec" (ảnh) / 1 phút (brainstorm) | mặc định 3 phút, lựa chọn 1/3/5/10, bỏ 30 giây | memlog PRD (override + decision) |
| Notifications (ảnh) | bỏ | memlog PRD (change) |
| Icon cloud góc phải Settings (ảnh) | bỏ, Import/Export thành mục trong danh sách | memlog PRD (change) |
| Nút Back ở Password Generator (ảnh) | bỏ | memlog PRD (change) |
| Tab bar khoảng 5 icon (ảnh, bị cắt) / "4 màn hình" (idea.txt) | 3 tab + Login | memlog PRD (decision) |
| Recent xếp cũ nhất trên, giữ nhiều tháng (ảnh) | mới nhất trên, hết hạn 3 ngày | memlog PRD |
| Chỉ có giao diện sáng (ảnh) | sáng + tối theo hệ thống | memlog PRD (decision) |
| Luật bảo mật "cố định trong phiên" (brainstorm) | không bao giờ tùy chỉnh (FR-7) | memlog PRD (decision) |
| Slider gợi ý max khoảng 40 (ảnh) | 4–99 | memlog PRD (decision) |
