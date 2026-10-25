---
title: Memlog audit — prd-passwordmanager-2026-10-23
date: 2026-10-25
inputs: .memlog.md (updated 2026-10-25T14:55), prd.md, addendum.md
---

# Memlog audit

Phân loại: **IN-PRD** (có trong PRD, kèm trích dẫn) · **IN-ADDENDUM** · **SET-ASIDE** (event/quy trình, không cần nội dung) · **MISSING/MISMATCH**.
Mục bị override/xác nhận lại bởi mục sau được đối chiếu theo mục sau cùng.

## Tổng hợp

| Phân loại | Số mục |
|---|---|
| IN-PRD | 68 (trong đó 4 mục đã bị mục sau thay thế/giải quyết: L27, L32, L40, L55; L28 có thêm phần trong addendum) |
| IN-ADDENDUM (thuần) | 0 |
| SET-ASIDE | 9 |
| MISSING/MISMATCH | 0 |
| **Tổng** | **77** |

## Bảng phân loại

| # | Dòng | Loại | Tóm tắt memlog | Phân loại | Vị trí trong PRD / ghi chú |
|---|---|---|---|---|---|
| 1 | L6 | event | Create intent; input brainstorm-intent.md | SET-ASIDE | Quy trình |
| 2 | L7 | event | Research digest xong | SET-ASIDE | Addendum §Tham khảo dẫn tới research-digest.md |
| 3 | L8 | decision | Cá nhân, phi thương mại, phát hành App Store + Google Play, miễn phí; phủ yêu cầu store (privacy label/data safety, khai báo mã hóa) | IN-PRD | §1 (Phát hành), §6 (App Privacy/Data Safety, export compliance), §7 Khác |
| 4 | L9 | decision | Ngôn ngữ EN/VI trong Settings | IN-PRD | FR-44, NFR-13 |
| 5 | L10 | event | Không có input bổ sung | SET-ASIDE | Quy trình |
| 6 | L11 | decision | Working mode: Coaching | SET-ASIDE | Quyết định quy trình, không phải nội dung |
| 7 | L12 | decision | Entry point: Vision + Features | SET-ASIDE | Quyết định quy trình; cấu trúc PRD phản ánh đúng (§1 → §4 → §3 journey) |
| 8 | L13 | event | Source extract; 4 câu hỏi cần xác nhận | SET-ASIDE | Cả 4 câu đã được giải quyết: L30 (FR-7), L39 (FR-8), L44/L47 (FR-14), L63 (FR-42) |
| 9 | L14 | decision | Vision: cá nhân, offline, an toàn, miễn phí | IN-PRD | §1 |
| 10 | L15 | decision | Thành công = đúng mong muốn + đạt bảo mật; không đo lượt cài/feedback; bảo mật ưu tiên số 1 | IN-PRD | §1, §2 đoạn đầu |
| 11 | L16 | decision | Thất bại = sai mong muốn hoặc trượt bảo mật | IN-PRD | §2 đoạn đầu |
| 12 | L17 | decision | TC-1..TC-6 | IN-PRD | §2 bảng TC-1..TC-6 (khớp đủ 6) |
| 13 | L18 | decision | Copy/paste là luồng cốt lõi; từ chối khóa khi chuyển app, từ chối chặn chụp màn hình | IN-PRD | §2 Nguyên tắc cân bằng, §3, NFR-9, §7 Bảo mật màn hình |
| 14 | L19 | decision | 2 journey quan trọng nhất | IN-PRD | §3 UJ-1, UJ-2 |
| 15 | L20 | decision | Autolock tính từ lúc chạy nền, mặc định 3 phút | IN-PRD | §3 Hệ quả, FR-13, FR-43 |
| 16 | L21 | override | Clear Clipboard mặc định 1 → 3 phút | IN-PRD | §3 Hệ quả, FR-34, FR-43 (đã theo giá trị override) |
| 17 | L22 | decision | Recent mới nhất ở trên | IN-PRD | §3 Hệ quả, FR-38 |
| 18 | L23 | decision | UJ-2: chỉnh tiêu chí, bấm random nhiều lần trước Copy | IN-PRD | UJ-2 bước 1 |
| 19 | L24 | decision | Mật khẩu chính theo NIST: ≥15, tối đa 128, mọi ký tự in được + khoảng trắng + Unicode, không composition, chặn danh sách phổ biến offline + chuỗi lặp/tuần tự | IN-PRD | FR-2 (xác nhận ở L35) |
| 20 | L25 | decision | Bộ đếm sai reset về 0 khi đăng nhập đúng | IN-PRD | FR-5 |
| 21 | L26 | decision | Login: chưa có TK → "Tạo tài khoản"; có rồi → "Xóa & Tạo tài khoản mới" + xác nhận | IN-PRD | FR-1, FR-8 |
| 22 | L27 | assumption | Nút Xóa & Tạo mới không cần mật khẩu | IN-PRD | FR-8 (đã xác nhận ở L39) |
| 23 | L28 | decision | Gỡ/cài lại = xóa sạch dữ liệu, TK, bộ đếm; không giữ trong Keychain | IN-PRD | FR-10; chi tiết Keychain ở addendum §Bộ đếm sai |
| 24 | L29 | decision | Change Main Password bắt buộc nhập mật khẩu cũ | IN-PRD | FR-11 |
| 25 | L30 | decision | Luật 10 lần / 30 phút / tự xóa không tùy chỉnh | IN-PRD | FR-7, §7 Đăng nhập |
| 26 | L31 | change | Bỏ công tắc Notifications | IN-PRD | §F5 tiêu đề màn hình Cài đặt, §7 Giao diện đã bỏ |
| 27 | L32 | decision | Mật khẩu export riêng mỗi lần export, "không ràng buộc điều kiện"; import cần đúng mật khẩu | IN-PRD (một phần bị thay thế) | FR-48, FR-52. Phần "không ràng buộc" bị override bởi L36 — PRD theo L36 |
| 28 | L33 | assumption | File export độc lập với mật khẩu chính; đổi MK chính không ảnh hưởng file cũ | IN-PRD | FR-11 câu cuối, FR-48 |
| 29 | L34 | event | Ghi F1 vào PRD | SET-ASIDE | Quy trình |
| 30 | L35 | decision | Xác nhận NIST: không bắt buộc hoa/số/đặc biệt | IN-PRD | FR-2 |
| 31 | L36 | override | Mật khẩu export theo cùng quy tắc FR-2 | IN-PRD | FR-48, NFR-3, §F6 đoạn mở đầu |
| 32 | L37 | decision | Login hiện số lần sai còn lại + đếm ngược 30 phút | IN-PRD | FR-4 gạch cuối |
| 33 | L38 | decision | Sai MK cũ ở Change Main Password không tính vào bộ đếm (rủi ro chấp nhận) | IN-PRD | FR-11 |
| 34 | L39 | decision | Xác nhận nút Xóa & Tạo mới không cần mật khẩu | IN-PRD | FR-8 (không còn tag ASSUMPTION — đúng) |
| 35 | L40 | assumption | "10 phút log out khi đang thao tác" — đang hỏi lại nghĩa | IN-PRD (đã giải quyết) | Giải quyết bởi L41 → FR-12 |
| 36 | L41 | decision | Giới hạn phiên tuyệt đối 10 phút mặc định, chỉnh được, tách biệt Autolock 3 phút | IN-PRD | FR-12, FR-13 (độc lập), FR-43 |
| 37 | L42 | decision | Nút góc trên phải card → popup Sửa/Xóa; xóa cần xác nhận | IN-PRD | FR-20, FR-22 |
| 38 | L43 | decision | Bắt buộc tiêu đề, tên đăng nhập, mật khẩu; Note tùy chọn; cho trùng tiêu đề; tìm kiếm hiện đủ card trùng | IN-PRD | FR-19, FR-16 gạch 4 |
| 39 | L44 | decision | Danh sách hiện đủ 4 field + nút Copy tại chỗ; thứ tự theo thời gian tạo, mới nhất trên; sửa không đổi thứ tự | IN-PRD | FR-14, FR-15. Ghi chú: FR-14 thêm `[ASSUMPTION]` mật khẩu ẩn mặc định + ẩn dòng Note khi trống — không mâu thuẫn, nhưng nên xác nhận ở Finalize vì memlog nói "hiện đủ 4 field" |
| 40 | L45 | decision | Tìm kiếm: chuỗi con, không phân biệt hoa thường, không phân biệt dấu | IN-PRD | FR-16 |
| 41 | L46 | decision | Hết phiên/autolock khi đang tạo/sửa card → giữ bản nháp mã hóa, tiếp tục sau khi đăng nhập | IN-PRD | FR-23, NFR-1 |
| 42 | L47 | decision | Note dài: hiện 2–3 dòng đầu, bấm xem đủ | IN-PRD | FR-14 gạch 3 |
| 43 | L48 | decision | Clear Clipboard áp dụng cho mọi thao tác copy | IN-PRD | FR-34 |
| 44 | L49 | decision | Độ dài mật khẩu tạo ra 4–99 | IN-PRD | FR-26 |
| 45 | L50 | decision | Chip ABC = hoa + thường; tắt ABC chỉ còn chữ thường; được tắt hết | IN-PRD | FR-27 |
| 46 | L51 | decision | Mọi thay đổi tiêu chí (sheet + màn hình đầy đủ) → tự random lại | IN-PRD | FR-28 (áp dụng cho cả F3) |
| 47 | L52 | decision | Password strength 3 mức Low/Medium/High | IN-PRD | FR-31, FR-25 |
| 48 | L53 | assumption | Tắt hết ở màn hình đầy đủ → chữ thường; mỗi loại bật xuất hiện ≥1 lần; mặc định 16; nhớ tiêu chí lần trước | IN-PRD | FR-27, FR-29, FR-26, FR-32 (đều giữ tag ASSUMPTION — nhất quán) |
| 49 | L54 | decision | Ngưỡng entropy: Low <50, Medium 50–79, High ≥80 | IN-PRD | FR-31 |
| 50 | L55 | decision | Recent tự xóa sau 3 ngày (đang hỏi lại cách tính) | IN-PRD (đã giải quyết) | Giải quyết bởi L59 → FR-39 |
| 51 | L56 | decision | Copy cùng mật khẩu nhiều lần → chỉ 1 mục | IN-PRD | FR-37 |
| 52 | L57 | decision | Nút Clear của Recent cần xác nhận | IN-PRD | FR-40 |
| 53 | L58 | decision | Copy từ Recent không tạo mục mới | IN-PRD | FR-36 |
| 54 | L59 | decision | Mỗi mục Recent hết hạn sau 3 ngày kể từ lúc ghi (cách a) | IN-PRD | FR-39. Ghi chú: FR-37 (assumption) cập nhật thời điểm khi copy lại — chưa nói rõ hạn 3 ngày có được tính lại không |
| 55 | L60 | decision | Autolock / Giới hạn phiên / Clear Clipboard: 1, 3, 5, 10 phút; không có "Không bao giờ" | IN-PRD | FR-43, §7 Giao diện đã bỏ |
| 56 | L61 | decision | Lock Vault = Sign out, khóa ngay, về Login | IN-PRD | FR-46 |
| 57 | L62 | decision | Ngôn ngữ mặc định theo điện thoại | IN-PRD | FR-44 |
| 58 | L63 | decision | Tab bar 3 tab (Quản lý mật khẩu, Tạo mật khẩu, Cài đặt) | IN-PRD | FR-42 |
| 59 | L64 | assumption | Cùng danh sách 1/3/5/10 cho 3 cài đặt; máy VI → VI, còn lại EN; tab mặc định Quản lý mật khẩu | IN-PRD | FR-43, FR-44, FR-42 (tag ASSUMPTION — nhất quán) |
| 60 | L65 | change | Bỏ nút Back trên màn hình Tạo mật khẩu — ngoại lệ duy nhất của luật "giữ nguyên thành phần" | IN-PRD | §F3 đoạn mở đầu, §7 Giao diện đã bỏ |
| 61 | L66 | decision | Import khi đã có dữ liệu: ghi đè | IN-PRD | FR-53 |
| 62 | L67 | decision | File export chỉ chứa card (cả Note); không Recent, cài đặt, bản nháp | IN-PRD | FR-49, §7 Import/Export |
| 63 | L68 | decision | Export qua share sheet OS; import chọn file từ Files; không quyền mạng | IN-PRD | FR-51, FR-52, NFR-6 |
| 64 | L69 | change | Bỏ icon cloud; Import/Export là item trong Settings | IN-PRD | FR-47, §7 Giao diện đã bỏ |
| 65 | L70 | decision | Không giới hạn số lần sai mật khẩu khi import | IN-PRD | FR-52, §7 Import/Export |
| 66 | L71 | assumption | Hộp thoại xác nhận số card; import nguyên tử; giữ thời gian tạo; Recent/cài đặt không bị đụng | IN-PRD | FR-53, FR-54, FR-49 (thời gian tạo — vẫn tag ASSUMPTION, đúng vì L72 không xác nhận phần này), FR-55 |
| 67 | L72 | decision | Xác nhận FR-53, FR-54, FR-55 | IN-PRD | FR-53/54/55 không còn tag ASSUMPTION — đúng |
| 68 | L73 | decision | Chặn sao lưu tự động OS; file export là backup duy nhất | IN-PRD | NFR-7, §F6 đoạn mở đầu, §7 Mạng và sao lưu |
| 69 | L74 | decision | Không che ảnh thu nhỏ đa nhiệm | IN-PRD | NFR-9, §7 Bảo mật màn hình |
| 70 | L75 | decision | Điện thoại + máy tính bảng (iOS + Android); có dark mode | IN-PRD | NFR-11, NFR-12 |
| 71 | L76 | decision | Privacy policy trên GitHub Pages | IN-PRD | §6 Chính sách quyền riêng tư |
| 72 | L77 | event | Kết thúc Discovery | SET-ASIDE | Quy trình |
| 73 | L78 | decision | UJ-3 đổi điện thoại | IN-PRD | §3 UJ-3 |
| 74 | L79 | decision | UJ-4 quên MK / sai lần 10 → tạo tài khoản mới | IN-PRD | §3 UJ-4 |
| 75 | L80 | assumption | FR-56 cross-platform, FR-57 tương thích ngược, FR-58 bỏ hộp thoại khi 0 card; UJ-4 nối với import | IN-PRD | FR-56, FR-57, FR-58, UJ-4 đoạn cuối |
| 76 | L81 | decision | Xác nhận FR-56, FR-57, FR-58, UJ-4 nối import | IN-PRD | Như trên, không tag ASSUMPTION — đúng |
| 77 | L82 | event | Bắt đầu Finalize | SET-ASIDE | Quy trình |

## Quan sát phụ (không phải MISSING/MISMATCH)

1. **FR-14 vs L44:** memlog nói danh sách "hiện đủ 4 field"; PRD thêm `[ASSUMPTION]` mật khẩu ẩn mặc định (có nút ẩn/hiện) và ẩn dòng Note khi trống. Tương thích, nhưng cần user xác nhận ở Finalize.
2. **FR-37 × FR-39 (L56/L59):** FR-37 (assumption) cập nhật thời điểm khi copy lại cùng mật khẩu; FR-39 tính hạn 3 ngày "kể từ thời điểm được ghi". Nên nói rõ copy lại có làm mới hạn 3 ngày hay không.
3. **Frontmatter prd.md** `updated: 2026-10-23` đã cũ so với memlog (2026-10-25).
4. Các `[ASSUMPTION]` chỉ có trong PRD, không có nguồn memlog (cần rà ở Finalize, ngoài phạm vi audit memlog): FR-1 (bước nhập lại), FR-6 (khởi động lại thì tính lại thời gian chờ), FR-16 (cập nhật kết quả khi gõ), FR-17 (empty state), FR-34 (chỉ xóa clipboard nếu còn đúng giá trị), NFR-2 (1–2 giây), NFR-8, NFR-12 (không có công tắc theme), §6 (privacy policy song ngữ).
