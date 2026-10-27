# Visual extract — 4 ảnh tham chiếu (Kaspersky Password Manager, iOS)

> Chỉ ghi lại những gì quan sát được trên ảnh. Không đề xuất hướng thiết kế.
> Nguồn: `screens/password_generator.jpg`, `screens/edit_pass.jpg`, `screens/recent_password.jpg`, `screens/setting.jpg` (bản sao trong `imports/`).
> Công cụ: Python + PIL (`python -I`), lấy mẫu trung bình ô 5×5 px, phân cụm màu median-cut 10 màu trên ảnh thu nhỏ 1/4. Ảnh là JPEG nên màu nhiễu ±3–6; các mã hex dưới đây đã làm tròn về giá trị đại diện.

## 0. Kích thước & hệ số quy đổi

| Ảnh | Kích thước (px) |
|---|---|
| password_generator.jpg | 1125 × 2095 |
| edit_pass.jpg | 1125 × 1411 (đã cắt, chỉ phần bottom sheet) |
| recent_password.jpg | 1125 × 2274 |
| setting.jpg | 1125 × 1355 (đã cắt, chỉ phần trên) |

- Cả 4 ảnh đều rộng **1125 px** = iPhone @3x, chiều rộng logic **375 pt**. Hệ số dùng trong tài liệu: **1 pt = 3 px** (nếu quy về thiết bị 390 pt thì nhân thêm ≈ 1.04; nếu quy về 360 dp Android thì 1 dp ≈ 3.125 px — sai lệch nhỏ, bỏ qua).
- Các thanh trạng thái (status bar) đã bị cắt khỏi ảnh; ảnh `edit_pass` và `recent_password` có home indicator ở đáy → đây là iOS (có Face ID, switch kiểu iOS, nav kiểu UIKit).

## 1. Bảng màu quan sát được

### 1.1 Phân cụm màu chủ đạo (median-cut, % diện tích)

- **password_generator**: #FFFFFF 83% · #198470 5.9% (+0.7% #188470) · #FBFBFB 3.3% · #DDDFDA 1.7% (viền/separator khử răng cưa) · #385C56 / #79A09B (cạnh chữ/icon xanh pha trắng).
- **edit_pass**: #FFFFFF 74% · #198470 8.1% · #EDFAF6 6.8% + #D5ECE7 1.7% (nền chip) · #EFF3F1 2.1% · #90B0A3 (cạnh khử răng cưa).
- **recent_password**: #F6F6F6 67.5% · #FFFFFF 16.5% · #FAFAFA 10.1% (thanh đáy) · #B3BAB6 2.4% (chữ/separator).
- **setting**: #FFFFFF 44.2% · #F2F1F7 41.8% (nền grouped) · #92A4A1 3.5% (cạnh chữ/teal).

### 1.2 Mẫu điểm (toạ độ theo px ảnh gốc)

| Vai trò | Hex | Mẫu lấy tại |
|---|---|---|
| Accent chính (nút đầy, switch ON, vòng tick chip, tab đang chọn) | **#198470** | gen Copy (209,722); gen toggle (974,1146); setting toggle (900,585); edit chip check (160,928); edit nút (200,1175) |
| Chữ link / nút chữ teal (Close, Clear, Change Main Password, Lock Vault, chevron Back, icon copy, icon refresh) | ≈ #198470 (pixel tối nhất do khử răng cưa đo được #007362–#04795F) | recent "Close" (52–89, 64–101); setting "Change…" (100–139, 935–971); recent icon copy (1024–1081, 350–411) |
| Fill thanh slider (phần đã chọn) | **#2DD1AC** (mint sáng, khác accent chính) | edit (104–351, y 700) |
| Track slider phần còn lại | #CBCBCB | edit (480–1020, y 700) |
| Núm slider | #FFFFFF + bóng đổ xám (#D5D5D5 ngay dưới núm) | edit (420,697), (420,739) |
| Nền chip lựa chọn (123 / ABC / !@#) | **#E5F8F2** (nhiễu #E0F3ED–#E7F7F6) | edit (120,870), (334–384, y 930) |
| Nền màn hình trắng | #FFFFFF | gen (565,209); edit sheet (300,420) |
| Nền grouped (Settings) | **#F2F1F7** | setting (20,600) |
| Nền sheet "Recent Passwords" + vùng trống | **#F6F6F6** (≈#F5F5F5) | recent (600,0–272), (600,921–2038) |
| Thanh công cụ đáy (Clear) | #FAFAFA | recent (600,2040–2234) |
| Card / ô nhóm | #FFFFFF | setting (600,330); edit card (560,620) |
| Hàng xen kẽ trong Recent | hàng 1 #FFFFFF · hàng 2 #F5F5F5 · hàng 3 #FDFDFD (≈ trắng) | recent (600, 274–487 / 489–703 / 705–919) |
| Separator / divider (hairline) | **#C5C5C5–#C8C8C8** (1 px ảnh, ~0.33 pt) | gen y=948, 1079, 1584, 1847; setting y=385; recent y=273, 488 |
| Divider trên toolbar đáy Recent | #ACACAC (đậm hơn) | recent (600,2039) |
| Viền card & viền nút tròn trong sheet | **#CCCCCC** (1 px) | edit card top (560,504), left (48,780); nút refresh tròn (1022,48) |
| Viền switch OFF | #C9C9C9; track OFF #CBCBCB, núm #FFFFFF | setting (950,671), (1000,716), (920,716) |
| Grabber của bottom sheet | #CCCCCC | edit (516–610, y 24–35) |
| Lớp mờ phía sau sheet | #999999 | edit (2,2) |
| Chữ chính | #000000 (tiêu đề) / #1A1A1A–#1D1D1D (chữ hàng) | gen title; gen row (53–80, y 1146) |
| Chữ phụ (xám) — ngày giờ, "Password strength: High", "Password Length:", giá trị "16" ở hàng | **≈ #868686–#8A8A8A** | recent date (51–99,328–362); edit strength (288–329,196–231); gen "16" (995–1042,996–1033) |
| Giá trị trong Settings ("1 min", "30 sec") | ≈ #636363–#686868 (đậm hơn xám phụ) | setting (857–953, y 320) |
| Tiêu đề section "GENERAL" | ≈ #757479 (pixel tối nhất; tông xám hơi tím) | setting (99–269,195–223) |
| Icon tab bar không chọn | #989898 | gen tab1/2/4/5 (y 2070–2095) |
| Icon tab bar đang chọn | ≈ #198470 (pixel tối nhất #008165) | gen tab3 (520–600, y 2070–2095) |
| Ký tự số trong mật khẩu | **≈ #007CC6** (xanh dương) | gen "9" (300–380, 300–400) |
| Ký tự đặc biệt trong mật khẩu | **≈ #E58B00** (cam/hổ phách) | gen "/" (370–420, 320–410) |
| Chữ cái trong mật khẩu | đen ≈ #1B1B1B | — |
| Icon đen trên app bar (history, cloud) | #030303–#0D0D0D | gen (1005–1076, 30–101); setting (1011–1070, 36–92) |

**Màu trạng thái:** không có thanh đo độ mạnh dạng vạch màu (xanh/vàng/đỏ) trong 4 ảnh. Độ mạnh chỉ hiển thị bằng chữ xám "Password strength: High". Không quan sát được màu cảnh báo/lỗi (đỏ) hay vàng nào; màu cam chỉ dùng cho ký tự đặc biệt.

## 2. Số đo (pt, = px/3)

### 2.1 Lề & khoảng cách
- **Lề ngang card** (Settings, card trong sheet): x = 48 px → **16 pt**. Card Settings rộng 48–1076 px.
- **Inset nội dung trong card**: chữ bắt đầu x ≈ 96–100 px → **16 pt** bên trong card (32 pt từ mép màn hình).
- **List full-width** (Generator, Recent): chữ bắt đầu x ≈ 48–53 px → **16 pt**; separator giữa hàng **thụt vào 16 pt** (x=20 vẫn trắng), separator đầu/cuối nhóm chạy **full width**.
- **Nút Copy** (Generator): x 88–1035 → lề **≈ 29–30 pt** mỗi bên, rộng ≈ 316 pt.
- **Nút Use Password** (sheet): x 120–1005 → lề **40 pt**, rộng ≈ 295 pt (hẹp hơn card bên trên).
- **Khoảng giữa các nhóm/card**: Settings 784–887 px → **≈ 35 pt**; Generator giữa 2 nhóm 1476–1584 → **36 pt**.
- **Khoảng giữa các chip**: ≈ 31 px → **≈ 10 pt**.
- Switch Generator lệch sát mép phải: kết thúc x≈1095 → chỉ **≈ 10 pt** tới mép (trong Settings: cách mép card ≈ 15 pt).
- Generator: tiêu đề baseline ~ y 83 px; dòng mật khẩu tâm ~ y 372 px (**≈124 pt**); nút Copy y 624–767 (**208–256 pt**); nhóm tuỳ chọn bắt đầu y 948 (**316 pt**) → có nhiều khoảng trắng phía trên.

### 2.2 Bo góc
| Thành phần | Bo góc ước lượng |
|---|---|
| Card Settings (inset grouped) | ≈ 30–32 px → **≈ 10 pt** |
| Card trong sheet (Password Length + chip) | ≈ 18–20 px → **≈ 6–7 pt** |
| Chip 123/ABC/!@# | ≈ 16–18 px → **≈ 6 pt** |
| Nút đầy Copy / Use Password | ≈ 18–20 px → **≈ 6–7 pt** (bo nhẹ, không phải pill) |
| Bottom sheet (edit_pass) góc trên | ≈ 55–60 px → **≈ 18–20 pt** |
| Page sheet Recent góc trên | ≈ 30 px → **≈ 10 pt** |
| Nút icon tròn (refresh trong sheet) | tròn hoàn toàn, Ø ≈ 107 px → **36 pt** |
| Grabber | 94 × 12 px → **≈ 31 × 4 pt**, bo tròn |

### 2.3 Chiều cao thành phần
| Thành phần | px | pt |
|---|---|---|
| Hàng list (Generator, Settings) | 131–132 | **44** |
| Hàng Recent (2 dòng: ngày + mật khẩu) | 214–215 | **≈ 72** (đệm trên ≈18 pt, dưới ≈17 pt) |
| Nút Copy | 144 | **48** |
| Nút Use Password | ≈148 | **≈ 49–50** |
| Chip lựa chọn | 150 | **50** (rộng ≈ 97 pt) |
| Card slider+chip trong sheet | 504–1050 | **≈ 182** |
| Switch iOS | ≈157 × 97 | **≈ 51 × 31** (chuẩn UISwitch) |
| Track slider | 12 | **4** ; núm Ø ≈ 80 px → **≈ 27 pt** |
| Header sheet Recent (vùng trên danh sách) | 0–272 | **≈ 91** (tiêu đề + khoảng trống) |
| Toolbar đáy Recent (gồm home indicator) | 2040–2273 | **≈ 78** |
| Ô nhập (text field) | — | **Không có ô nhập văn bản nào trong 4 ảnh** |

### 2.4 Kích thước icon
| Icon | Bbox px | ≈ pt |
|---|---|---|
| History (đồng hồ có mũi tên, app bar Generator) | 72 × 72 | **24** |
| Cloud sync (mũi tên lên/xuống, app bar Settings) | 60 × 57 | **≈ 20** |
| Refresh (cạnh mật khẩu Generator) | 63 × 60 | **≈ 20–21** |
| Refresh trong nút tròn (sheet) | ≈ 70 | **≈ 22–24** trong vòng 36 pt |
| Copy (hai hình vuông chồng, Recent) | 58 × 62 | **≈ 20** |
| Back chevron | 32 × 56 | **≈ 11 × 19** |
| Vòng tick trong chip | 72 × 72 | **24** |
| Chevron lên/xuống (Settings, picker) | 22 × 32 | **≈ 7 × 11** |

## 3. Typography

Cap-height đo được → suy ra cỡ chữ (SF Pro: cap ≈ 0.7 × size).

| Vai trò | Cap-height px | Cỡ ước lượng | Weight / ghi chú |
|---|---|---|---|
| Tiêu đề nav ("Password Generator", "Recent Passwords", "Settings") | 36–38 | **17 pt** | Semibold, căn giữa (kiểu inline title iOS, không có large title) |
| Chữ hàng list (body) | 36–37 | **17 pt** | Regular, đen |
| Nút đầy ("Copy", "Use Password") | 36 | **17 pt** | Semibold, trắng trên #198470 |
| Nút chữ / link ("Close", "Clear", "Change Main Password", "Lock Vault") | 37–39 | **17 pt** | "Close"/"Change…"/"Lock Vault" Regular; "Clear" Semibold |
| Giá trị bên phải hàng ("16", "1 min", "30 sec") | 33–38 | **17 pt** | Regular, xám |
| "Password strength: High" | 36 | **17 pt** | Regular, xám #888 |
| "Password Length:" / "16" trong card sheet | 32–33 | **≈ 15–16 pt** | Regular; nhãn xám, số đen |
| Nhãn chip "123", "ABC", "!@#" | 37 | **≈ 17–18 pt** | Semibold, đen |
| Ngày giờ Recent ("01/08/2026 12:48") | 35 | **≈ 16 pt** | Regular, xám |
| Header section "GENERAL" | 29 | **≈ 13 pt** | Regular, VIẾT HOA, xám (footnote kiểu iOS) |
| Mật khẩu lớn — Generator | 52 (cao toàn dòng 68) | **≈ 24–26 pt** | **Monospace đậm** (chữ "k", "t" kiểu SF Mono/Menlo), tô màu theo loại ký tự |
| Mật khẩu lớn — sheet | 50 | **≈ 24 pt** | **Không phải monospace** — sans đậm tỷ lệ (SF Pro semibold/bold), cũng tô màu theo loại ký tự |
| Mật khẩu trong Recent | 36 | **17 pt** | **Monospace regular**, tô màu theo loại ký tự |
| Dòng ký tự đặc biệt `~!@#$%^&*+-/.,\{}[]();:?<>"'_` | ~ | **17 pt** | Regular, sans (không mono) |

- Họ chữ: hệ thống **SF Pro** (iOS); mật khẩu dùng **monospace** ở Generator và Recent, sans ở sheet.
- Quy tắc tô màu mật khẩu (nhất quán cả 3 màn): **chữ cái = đen, chữ số = xanh dương #007CC6, ký tự đặc biệt = cam #E58B00**.
- Viết hoa: Title Case cho tiêu đề và nhãn ("Password Length", "Use Password", "Change Main Password"); ALL CAPS chỉ cho header section ("GENERAL").
- Ngôn ngữ giao diện: **tiếng Anh**. Định dạng ngày **dd/MM/yyyy HH:mm** (24h).

## 4. Từng màn hình

### 4.1 `password_generator.jpg` — Password Generator (màn hình tab)
Từ trên xuống:
1. **App bar** nền trắng, không viền dưới: trái chevron Back teal; giữa tiêu đề **"Password Generator"**; phải icon **History** (đồng hồ có mũi tên vòng, đen, 24 pt).
2. Khoảng trắng lớn.
3. **Mật khẩu sinh ra** căn giữa, monospace đậm ~24–26 pt, tô màu theo ký tự: `Akkt9/B>T#7%DJ2u`; ngay bên phải là icon **refresh** teal (không có nền).
4. Khoảng trắng.
5. **Nút đầy "Copy"** (#198470, chữ trắng semibold, cao 48 pt, bo ~6–7 pt, lề ~30 pt).
6. Khoảng trắng lớn.
7. **Nhóm 1** (list full-width, separator đầu/cuối full width, giữa hàng thụt 16 pt), hàng 44 pt:
   - **"Password Length"** — bên phải giá trị xám **"16"** + chevron `>` xám (hàng điều hướng/picker).
   - **"Uppercase Letters (A–Z)"** — switch ON.
   - **"Lowercase Letters (a–z)"** — switch ON.
   - **"Digits (0–9)"** — switch ON.
8. Khoảng cách 36 pt (nền trắng, không đổi màu).
9. **Nhóm 2**:
   - **"Special Characters"** — switch ON.
   - Hàng hiển thị tập ký tự: `~!@#$%^&*+-/.,\{}[]();:?<>"'_` (chữ thường, không có control; có vẻ là tập ký tự đặc biệt sẽ dùng — có thể chỉnh sửa hay không thì ảnh không cho biết).
10. **Tab bar đáy** — bị cắt, chỉ thấy phần trên của **5 icon**; icon thứ 3 màu teal (đang chọn, khả năng là tab Generator), 4 icon còn lại xám #989898. Không đọc được nhãn tab. Hình dạng thấy được: tab1 dạng lưới/tài liệu, tab2 dạng người/chìa khoá (đầu tròn), tab3 nét cong teal, tab4 và tab5 dạng vòng tròn.
- Trạng thái thấy được: tất cả switch đều ON; không có trạng thái disabled.
- Branding: không có logo trong ảnh này.

### 4.2 `edit_pass.jpg` — bottom sheet tạo mật khẩu (trong luồng sửa mục)
Đây là **bottom sheet** (grabber trên cùng, lớp mờ #999 phía sau, góc trên bo ~18–20 pt). Không có tiêu đề.
1. **Grabber** xám #CCCCCC giữa mép trên.
2. Phải trên: **nút tròn viền** (Ø 36 pt, nền trắng, viền 1 px #CCCCCC) chứa icon **refresh** teal.
3. **"Password strength: High"** — xám, căn giữa, 17 pt.
4. **Mật khẩu** căn giữa, sans đậm ~24 pt, tô màu: `>[YZ]Te5F$+~<yuE`.
5. **Card viền** (1 px #CCCCCC, bo ~6–7 pt, lề 16 pt, padding 16 pt):
   - Hàng: **"Password Length:"** (xám, trái) — **"16"** (đen, phải).
   - **Slider** ngang: track 4 pt, phần đã chọn mint #2DD1AC, phần còn lại #CBCBCB, núm trắng tròn ~27 pt có bóng đổ. Núm nằm ở khoảng 1/3 track.
   - Divider mảnh #C9C9C9.
   - **3 chip toggle** ngang nhau (nền #E5F8F2, bo ~6 pt, cao 50 pt, cách 10 pt), mỗi chip: vòng tròn teal 24 pt có dấu ✓ trắng + nhãn semibold: **"123"**, **"ABC"**, **"!@#"**. Cả 3 đều ở trạng thái đã chọn (không thấy trạng thái bỏ chọn).
6. **Nút đầy "Use Password"** (#198470, chữ trắng semibold, cao ~49 pt, lề 40 pt, bo ~6–7 pt).
7. Home indicator.
- So với màn Generator: cùng chức năng nhưng dạng gọn — slider thay cho hàng "Password Length >", chip thay cho 4 switch (chữ hoa/thường gộp thành "ABC").
- Bóng đổ: chỉ thấy ở núm slider.

### 4.3 `recent_password.jpg` — Recent Passwords (page sheet modal)
1. Sheet modal kiểu iOS page sheet (góc trên bo ~10 pt, phía sau là nền đen).
2. **Header** nền #F6F6F6: trái nút chữ teal **"Close"**; giữa tiêu đề semibold **"Recent Passwords"**; khoảng trống bên dưới tiêu đề (tổng ~91 pt).
3. **Danh sách** (separator full width #C5C5C5), mỗi hàng ~72 pt, 2 dòng:
   - Dòng 1: ngày giờ xám, vd **"01/08/2026 12:48"**, **"20/10/2026 09:01"**, **"21/10/2026 15:47"**.
   - Dòng 2: mật khẩu monospace 17 pt, tô màu: `zAV+5*DTmW(Z4w4H`, `sc._##xzw8,5U(@T`, `9R.$'BPNkPsgj<6#`.
   - Phải: icon **copy** teal (~20 pt), không có nền nút.
   - Nền hàng: hàng 1 trắng, **hàng 2 #F5F5F5** (trùng màu nền), hàng 3 trắng → có thể là zebra stripe hoặc trạng thái được nhấn/highlight; ảnh đơn lẻ không đủ để khẳng định.
   - Thứ tự ngày không đơn điệu (01/08 rồi 20/10, 21/10) — ghi nhận nguyên trạng.
4. Vùng trống lớn #F6F6F6 (không có empty-state text vì đang có dữ liệu).
5. **Toolbar đáy** nền #FAFAFA, divider trên #ACACAC, nút chữ teal semibold **"Clear"** căn giữa; home indicator.

### 4.4 `setting.jpg` — Settings
Nền grouped **#F2F1F7**, kiểu iOS inset-grouped.
1. **App bar** (cùng màu nền): giữa tiêu đề **"Settings"**; phải icon **cloud có mũi tên lên/xuống** (đồng bộ/sao lưu, đen). Không có nút back.
2. Header section **"GENERAL"** (xám, 13 pt, viết hoa, thụt 32 pt).
3. **Card trắng** (bo ~10 pt, lề 16 pt, separator thụt 16 pt trong card), 4 hàng 44 pt:
   - **"Autolock Vault"** — giá trị **"1 min"** + chevron lên/xuống (⌃⌄, kiểu pop-up/menu picker).
   - **"Clear Clipboard"** — **"30 sec"** + chevron lên/xuống.
   - **"Use Face ID"** — switch **ON** (teal).
   - **"Notifications"** — switch **OFF** (track xám #CBCBCB, viền #C9C9C9).
4. Khoảng 35 pt.
5. **Card đơn** — chữ teal **"Change Main Password"** (hàng hành động, căn trái, không chevron).
6. Khoảng 35 pt.
7. **Card đơn** — chữ teal **"Lock Vault"**.
8. (Ảnh cắt ở đây; không thấy tab bar.)
- Trạng thái thấy được: switch ON và OFF cạnh nhau — mẫu tốt cho hai trạng thái.

## 5. Mẫu chung giữa các màn

- **Theme:** chỉ có **light theme**. Không có ảnh dark mode.
- **Accent duy nhất:** teal **#198470** dùng cho nút đầy, switch ON, link/nút chữ, icon hành động (copy, refresh, back), tab đang chọn, vòng tick chip. Ngoại lệ: slider dùng mint sáng #2DD1AC.
- **Phẳng (flat):** không có shadow trên card hay nút. Phân tách bằng (a) separator hairline #C5C5C5–#C8C8C8, (b) nền khác màu (card trắng trên #F2F1F7), hoặc (c) viền 1 px #CCCCCC (card và nút tròn trong sheet). Shadow duy nhất: núm slider (và núm switch mặc định iOS).
- **Bo góc:** nhỏ — nút và card nội dung ~6–7 pt, card grouped ~10 pt; nút icon tròn hoàn toàn.
- **Điều hướng:**
  - **Tab bar đáy 5 tab** (thấy ở Generator; tab thứ 3 đang chọn, teal; còn lại xám). Nhãn tab không nhìn thấy.
  - App bar dạng **inline title căn giữa 17 pt semibold**, không dùng large title; nút back là chevron teal không chữ.
  - **Modal:** bottom sheet có grabber (tạo mật khẩu khi sửa mục) và page sheet có nút chữ "Close" (lịch sử).
  - Hành động phụ đặt ở góc phải app bar dạng icon đen (History, Cloud sync).
- **Controls dùng:** UISwitch chuẩn iOS (tint teal), list row 44 pt có giá trị + chevron `>`, giá trị + chevron lên/xuống (menu picker), slider, chip toggle có vòng tick, nút đầy full-width, nút chữ, nút icon tròn có viền, icon copy trên hàng.
- **Hiển thị mật khẩu:** luôn tô màu theo loại ký tự (chữ đen / số xanh dương / ký tự đặc biệt cam); monospace ở Generator và Recent.
- **Copy-to-clipboard** có mặt ở mọi màn liên quan mật khẩu (nút Copy, icon copy từng hàng) và có cài đặt "Clear Clipboard".
- **Branding:** không thấy logo Kaspersky hay tên thương hiệu trong 4 ảnh; không có yếu tố thương hiệu nào cần loại trừ ngoài chính tông màu teal.
- **Không quan sát được:** ô nhập văn bản, thanh tìm kiếm, FAB, thanh đo độ mạnh có màu, màu lỗi/cảnh báo, empty state, dark mode, nhãn tab bar.
