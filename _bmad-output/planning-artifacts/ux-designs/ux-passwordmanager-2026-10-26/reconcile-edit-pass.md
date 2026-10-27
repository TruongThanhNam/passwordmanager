# Reconcile — imports/edit_pass.jpg (S11 Sheet tạo mật khẩu)

## 1. Carried
- Bottom sheet nền trắng, góc trên 20, grabber ~31×4 #CCC, scrim phía sau, không tiêu đề (bottom-sheet).
- Nút tròn 36pt viền 1px #CCC, refresh teal, góc trên phải (icon-button-circle).
- "Password strength: High" xám 17 regular căn giữa, nằm trên mật khẩu; chỉ chữ (bottom-sheet, Q5a).
- Mật khẩu sans 24 đậm căn giữa, tô màu (password-display).
- Card viền 1px #CCC bo 6, lề 16, đệm 16: "Password Length:" xám 15 + "16" đen; slider mint #2DD1AC, track 4, núm ~27 có bóng; hairline; 3 chip.
- Chip cao 50, bo 6, cách 10, nền #E5F8F2, vòng teal 24 có ✓ trắng, nhãn semibold đen; thứ tự 123 · ABC · !@# (chip-toggle).
- "Use Password" hẹp hơn card, lề 40 (`button-inset-sheet`). Sheet không có Copy.

## 2. Intentionally changed
- Sheet mở chồng trên S10 form card — memlog Q9b.
- Giữ slider, không thêm +/− — memlog Q7a.
- Trạng thái chip chưa chọn tự suy ra (ảnh chỉ có trạng thái chọn) — [ASSUMPTION] có ghi.

## 3. Dropped / missed
- **Nhãn "Password Length:" có dấu hai chấm** trong sheet (khác hàng ở S14 không có). Microcopy chỉ có `generator.length` = "Password Length" / "Độ dài mật khẩu"; thiếu biến thể có ":" cho sheet.
- **Bố cục trong chip**: vòng tick + nhãn là một cụm căn giữa ngang trong chip, khe vòng→nhãn ~12pt. Spine chỉ ghi "vòng 24 + nhãn".
- **Hairline trong card thụt theo đệm card** (không chạm viền card, cùng mép với slider/chip). Spine chỉ ghi "hairline".
- **Nhịp dọc trong card**: hàng nhãn → slider ~25pt, slider → hairline ~33pt, hairline → chip ~16pt (card tổng ~182pt). Spine chỉ nói "cao theo nội dung", không có giá trị.
- **Khoảng lớn mật khẩu → card** (~55pt) và card → nút (~16pt), nút → home indicator (~40pt) — không có trong spine.

## 4. Conflicts
- Không có.
