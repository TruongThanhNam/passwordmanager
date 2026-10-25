# Trích xuất nguồn: idea.txt, screens/*.jpg, memlog brainstorm (2026-10-23)

Đối chiếu với brainstorm-intent.md. Mục đánh dấu MỚI là chi tiết intent chưa có.

## 1. Ảnh màn hình

### password_generator.jpg (nền trắng)
- **Header:** nút back "<" màu xanh lá, tiêu đề "Password Generator", icon lịch sử ở góc trên bên phải.
- **Mật khẩu:**
  - Font monospace, đậm.
  - MỚI: tô màu theo loại ký tự. Chữ màu đen, số màu xanh dương, ký tự đặc biệt màu cam.
  - Nút refresh màu xanh lá.
- **Nút "Copy":** rộng hết chiều ngang, nền teal (~#1E8A72), chữ trắng.
- **Dòng "Password Length 16 >":**
  - MỚI: có chevron, nghĩa là bấm vào sẽ mở picker hoặc màn hình con.
  - Sheet edit_pass thì dùng slider, khác với màn hình này.
- **Các công tắc:**
  - MỚI: nhãn đầy đủ là "Uppercase Letters (A–Z)", "Lowercase Letters (a–z)" và "Digits (0–9)". Cả ba đều đang bật.
  - MỚI: "Special Characters" nằm trong một nhóm riêng. Bên dưới có dòng hiển thị bộ ký tự.
- **Tab bar (bị cắt ở mép dưới ảnh):**
  - Nhìn thấy khoảng 5 icon. Icon thứ 3 màu xanh, có lẽ là tab đang mở.
  - Mâu thuẫn với idea.txt, vốn ghi app có "4 màn hình".
  - Màn hình này vừa có nút back vừa nằm trong tab bar, nên không nhất quán.

### setting.jpg (kiểu iOS inset-grouped, nền #F2F2F7)
- **Header:** tiêu đề "Settings", icon cloud ↓↑ ở góc trên bên phải.
- MỚI: các mục nằm dưới header nhóm "GENERAL".
- **Autolock Vault "1 min"** và **Clear Clipboard "30 sec"**: chọn giá trị bằng popup picker.
- **Use Face ID:** sẽ bỏ.
- MỚI: **Notifications** mặc định TẮT.
- MỚI: **"Change Main Password"** và **"Lock Vault"** là nút chữ màu teal, mỗi nút nằm trong một card riêng.
- Không có nhãn "Sign out".

### recent_password.jpg (sheet bo góc)
- **Header:** nút "Close" màu teal, tiêu đề "Recent Passwords".
- **Danh sách:**
  - MỚI: các dòng xen kẽ nền trắng và nền xám.
  - MỚI: các mục xếp từ CŨ NHẤT đến mới nhất (01/08/2026 → 20/10 → 21/10).
  - Mục cũ nhất đã khoảng 3 tháng tuổi, nghĩa là lịch sử được giữ nhiều tháng.
- **Footer:** nút "Clear" màu teal, căn giữa.

### edit_pass.jpg (bottom sheet)
- MỚI: nút refresh hình tròn có viền, đặt ở góc trên bên phải.
- MỚI: mật khẩu dùng font không monospace, khác với màn hình Tạo mật khẩu.
- MỚI: có slider độ dài. Khi giá trị là 16, nút kéo nằm ở khoảng 35% thanh trượt, nên giá trị tối đa có thể khoảng 40 (suy đoán).
- Có 3 chip, mỗi chip có dấu check màu teal.
- Nút "Use Password" nền teal.

### Tổng thể
- MỚI: chỉ có giao diện sáng (light mode), không thấy dark mode.
- Một màu nhấn duy nhất là teal-green.
- Giao diện theo phong cách iOS native.

## 2. Thiếu hoặc mâu thuẫn với intent
- **Luật bảo mật cố định:** memlog ghi các luật này "giữ cố định trong phiên". Intent nâng thành "không cho người dùng tùy chỉnh". Người dùng chưa tự nói ra điều này.
- **Nút xóa tài khoản không cần mật khẩu:** đây chỉ là cách người điều phối đặt câu hỏi. Người dùng mới xác nhận phần hộp thoại xác nhận.
- **"Xóa tài khoản + tạo mới":** chưa rõ đây là một nút làm cả hai việc hay là hai bước riêng.
- **Động lực trong idea.txt mà intent chưa có:** "thời đại công nghệ số khi phải đăng ký rất nhiều ứng dụng".
- **Field Note:** chưa rõ Note hiển thị trên card ngoài danh sách hay chỉ hiện trong màn hình chi tiết/sửa.
- **Số màn hình:** idea.txt ghi 4 màn hình, nhưng ảnh có khoảng 5 tab (liên quan câu hỏi mở 19).

## 3. Câu hỏi mở đã được nguồn trả lời
- **Câu 16 và một phần câu 14:** idea.txt ghi mật khẩu được lưu vào Recent "khi và chỉ khi" người dùng bấm Copy ở màn hình Tạo mật khẩu. Vì vậy:
  - Bấm "Use Password" trong sheet edit_pass KHÔNG ghi vào Recent.
  - Copy từ danh sách Recent KHÔNG tạo mục mới.
- **Câu 8 (một phần):** giá trị Autolock "1 min" trong ảnh chưa được chốt.
- **Câu 1:** vẫn còn mở.
