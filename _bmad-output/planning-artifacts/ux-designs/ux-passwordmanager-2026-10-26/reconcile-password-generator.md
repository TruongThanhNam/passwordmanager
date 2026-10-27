# Reconcile — imports/password_generator.jpg (S14 Tab Tạo mật khẩu)

## 1. Carried
- Nav inline căn giữa 17 semibold, không viền dưới; icon lịch sử đen 24pt bên phải (DESIGN nav-bar).
- Mật khẩu lớn căn giữa, tô màu chữ/số/ký hiệu; refresh teal không nền bên phải (password-display).
- Nút đầy "Copy" 48pt, bo 6, lề 30, chữ trắng semibold (button-primary, `button-inset-generator`).
- List full-width nền trắng, hàng 44, separator giữa hàng thụt 16, đầu/cuối nhóm full-width; khoảng giữa nhóm 35–36 trắng (list-row, `section-gap`).
- Hàng "Password Length" giá trị + `>`; 4 công tắc UISwitch teal; hàng bộ ký tự đặc biệt chỉ đọc (list-row, toggle).
- Khoảng trắng lớn phía trên, mật khẩu ~1/6 chiều cao (Layout & Spacing).
- Nhãn Title Case, "(A–Z)" dùng gạch nối en (microcopy generator.toggles).

## 2. Intentionally changed
- Bỏ chevron Back — FR-27.
- Monospace → sans — memlog Q3b.
- "Password Length >" mở wheel-picker 4–99 — memlog Q6a.
- Tab bar 5 → 3 tab — FR-45.
- Không có nhãn độ mạnh trên S14 (ảnh cũng không có) — FR-28.

## 3. Dropped / missed
- **Cách chia nhóm hàng**: ảnh có 2 nhóm — Nhóm 1 = Password Length · Uppercase · Lowercase · Digits; Nhóm 2 = Special Characters + hàng bộ ký tự. Spine chỉ nhắc "nhóm công tắc" và thứ tự 4 nhãn, không ghi hàng nào thuộc nhóm nào, Password Length là hàng đầu, hàng bộ ký tự nằm ngay dưới Special Characters.
- **Căn giữa theo cụm**: ảnh căn giữa cả cụm *mật khẩu + icon refresh* (mật khẩu lệch trái tâm màn), khoảng cách mật khẩu → icon ~10pt. Spine chỉ nói "password-display căn giữa, refresh ngay bên phải" — dễ hiểu thành mật khẩu căn giữa, icon treo ngoài.
- **Lề phải công tắc** ~10pt tới mép màn (khác giá trị "16 >" ~16pt và khác Cài đặt ~15pt). Spine không ghi; áp `cell-inset` 16 sẽ lệch ảnh.
- **Glyph icon**: lịch sử = đồng hồ có mũi tên vòng ngược chiều kim, nửa trái nét chấm; refresh = hai mũi tên vòng tròn. Spine chỉ gọi tên "lịch sử"/"refresh".
- **Nhịp dọc cụ thể**: mật khẩu (tâm ~124pt) → Copy (208–256pt) → nhóm tùy chọn (316pt), tức ~60pt Copy→list. Spine chỉ mô tả định tính, không có token.

## 4. Conflicts
- **Màu giá trị "16"**: DESIGN gán `{colors.ink-value}` #666666 cho "hàng Password Length"; ảnh lấy mẫu #868686–#8A8A8A (= `ink-secondary`, visual-extract §1.2). #666 chỉ đúng cho giá trị ở Cài đặt. Không có lý do được dẫn.
