# Reconcile — imports/recent_password.jpg (S16 Sheet Recent Passwords)

## 1. Carried
- Page sheet góc trên 10, header nền #F6F6F6 (`surface-muted`); "Close" teal regular trái, "Recent Passwords" 17 semibold giữa; không hành động phải (page-sheet, EXPERIENCE page-sheet).
- Hàng 72pt, 2 dòng: thời điểm `dd/MM/yyyy HH:mm` xám 16 + mật khẩu 17 tô màu; icon copy teal (hai hình vuông chồng) phải, không nền (recent-row, icon-button).
- Nền xen kẽ trắng / #F5F5F5, separator full-width (recent-row, Q14a).
- Vùng trống bên dưới cùng màu header (`surface-muted`).
- Toolbar đáy #FAFAFA, đường trên #ACACAC, "Clear" teal semibold căn giữa (bottom-toolbar).
- Mật khẩu luôn hiện rõ, không có ẩn/hiện (password-inline).

## 2. Intentionally changed
- Monospace → sans — memlog Q3b.
- Mới nhất ở trên (ảnh không đơn điệu) — FR-40; hết hạn 72 giờ — FR-41.
- Clear có dialog xác nhận S17 — FR-42.
- Empty-state + Clear vô hiệu khi trống — FR-43.

## 3. Dropped / missed
- **Header cao ~91pt có dải trống dưới tiêu đề** (~45pt nền xám giữa hàng tiêu đề và hàng Recent đầu tiên). DESIGN page-sheet chỉ mô tả "nút chữ trái + tiêu đề giữa", không ghi chiều cao/dải trống này.
- **Đệm trong hàng**: trên ~18pt, dưới ~17pt, khe ngày → mật khẩu nhỏ (~6pt); cả hai dòng căn trái lề 16; icon copy căn giữa dọc theo hàng, lề phải ~16. Spine chỉ có tổng 72.
- **Chiều cao toolbar đáy** (~78pt gồm home indicator, ~49pt phần nội dung) — không có token.

## 4. Conflicts
- Không có.
