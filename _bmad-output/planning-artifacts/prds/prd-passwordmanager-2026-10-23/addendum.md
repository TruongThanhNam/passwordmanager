---
title: PAK Manager — Addendum (ghi chú cho architecture / UX)
created: 2026-10-23
updated: 2026-10-25
---

# Addendum

Tài liệu này giữ lại các chi tiết kỹ thuật và chi tiết triển khai mà PRD (`prd.md`, cùng thư mục) không đưa vào. Bước architecture và bước UX sẽ dùng các chi tiết này. Các mã FR-/NFR- trong tài liệu dẫn tới yêu cầu tương ứng trong `prd.md`.

## Cho architecture: bảo mật và lưu trữ

### KDF (NFR-2, NFR-3, FR-54, FR-63)
- **Thuật toán và tham số đề xuất:** Argon2id với m=64 MiB, t=3, p=4 (profile RFC 9106). Mức tối thiểu theo OWASP là m=19 MiB, t=2, p=1.
- **Vault:** hiệu chỉnh tham số để đạt NFR-2, tức thời gian chạy KDF khoảng 1 giây, tối đa 2 giây, trên máy yếu nhất được hỗ trợ.
- **File export:** dùng **bộ tham số cố định**, không phụ thuộc vào máy tạo file. Ghi tham số cùng số phiên bản định dạng vào header của file, để các bản app sau này vẫn đọc được file cũ (FR-62).
- **Khi import:** chỉ chấp nhận tham số nằm trong khoảng min/max cho phép. Ví dụ, file độc hại khai báo m=4 GiB sẽ bị từ chối trước khi chạy KDF.
- **Không cần chuẩn hóa Unicode:** mật khẩu chính và mật khẩu export chỉ dùng ký tự ASCII (FR-2, FR-52).

### Bộ đếm sai và xóa dữ liệu (FR-5, FR-7, FR-11, FR-12)
- **Ghi trước, kiểm tra sau.** Tăng bộ đếm và ghi xuống đĩa **trước khi** kiểm tra mật khẩu. Nếu mật khẩu đúng, đặt bộ đếm về 0.
- **Phân biệt sai mật khẩu với dữ liệu hỏng.** Kiểm tra mật khẩu bằng một bước riêng, tách khỏi bước kiểm tra tính toàn vẹn của dữ liệu. Ví dụ, dùng một giá trị xác minh khóa (key check value), hoặc một header được xác thực riêng. Nhờ vậy, lỗi giải mã do dữ liệu hỏng không bị tính là nhập sai mật khẩu.
- **Không lưu bộ đếm trong Keychain.** FR-11 yêu cầu gỡ app thì xóa sạch dữ liệu. Nhưng trên iOS, Keychain có thể vẫn giữ dữ liệu sau khi gỡ app. Nếu buộc phải dùng Keychain, lần chạy đầu tiên sau khi cài phải phát hiện và xóa các mục Keychain còn sót lại.
- **Xóa dữ liệu phải làm tiếp được khi bị gián đoạn.** Ghi một cờ "đang xóa" trước khi bắt đầu, và chỉ gỡ cờ khi đã xóa xong. Khi mở app mà cờ vẫn còn, app xóa tiếp.
- **Giới hạn của bộ đếm.** Bộ đếm sai chỉ bảo vệ màn hình Login. Khi file dữ liệu đã bị chép ra ngoài, dữ liệu chỉ còn được bảo vệ bởi độ mạnh của mật khẩu chính và KDF chậm.

### Thời gian chờ không phụ thuộc đồng hồ máy (FR-6)
- **Cách đo chung:** dùng đồng hồ đơn điệu có tính cả thời gian máy ngủ, và lưu thời điểm bắt đầu chờ theo chính đồng hồ đó.
- **Android:** dùng `SystemClock.elapsedRealtime()`. Đồng hồ này reset khi máy khởi động lại. Vì vậy, khi phát hiện máy vừa khởi động lại, tính lại thời gian chờ hiện tại từ đầu.
- **iOS:** dùng `mach_continuous_time()` hoặc `clock_gettime(CLOCK_MONOTONIC_RAW)`. **Không** dùng `systemUptime`, vì đồng hồ này dừng khi máy ngủ.

### Clipboard (FR-65)
- **iOS:** dùng `UIPasteboard` với `.expirationDate` và `.localOnly`. Lưu lại `changeCount` để biết clipboard có còn chứa giá trị app đã copy hay không.
- **Android:** gắn `ClipDescription.EXTRA_IS_SENSITIVE`. Từ Android 10, app ở background không đọc được clipboard, nên app chỉ kiểm tra và xóa clipboard khi quay lại foreground.

### Ô nhập mật khẩu (NFR-9, FR-2)
- **Kiểm tra ký tự:** mọi ô nhập mật khẩu phải chỉ nhận ký tự ASCII (FR-2). Áp dụng cho các ô ở Login, tạo tài khoản, đổi mật khẩu, export và import.
- **iOS:** không đặt `textContentType` là `.password` hoặc `.newPassword`, vì khi đó iOS sẽ hiện đề nghị lưu mật khẩu. Đặt `autocorrectionType = .no` và `spellCheckingType = .no`.
- **Android:** đặt `importantForAutofill="no"`, `IME_FLAG_NO_PERSONALIZED_LEARNING`, và `inputType` kiểu password.
- **Kiểm thử bàn phím:** kiểm thử các thiết lập trên với các bàn phím phổ biến: bàn phím mặc định, Gboard, Laban Key.

## Cho UX: các điểm chưa chốt

Đây là các điểm PRD cố ý chưa chốt, và bước UX sẽ quyết định. Mô tả chi tiết của ảnh tham chiếu nằm trong `source-extract.md`.

**Toàn app**
- **Phong cách trên Android.** Ảnh tham chiếu theo kiểu iOS native. Cần chọn giữa giữ nguyên kiểu này trên Android và chuyển sang Material.
- **Font mật khẩu.** Cần chọn một font dùng chung cho mọi chỗ hiển thị mật khẩu. Ảnh tham chiếu không nhất quán: màn hình Tạo mật khẩu và Recent dùng monospace, còn sheet tạo mật khẩu dùng font thường. Monospace giúp phân biệt l/1/I và O/0.
- **Màu mật khẩu trong dark mode.** Cần một bảng màu dark mode tương ứng với bảng màu light mode hiện có (chữ cái đen, chữ số xanh dương, ký tự đặc biệt cam).

**Màn hình Tạo mật khẩu và sheet tạo mật khẩu**
- **Chọn độ dài trên màn hình Tạo mật khẩu.** Dòng "Password Length 16 >" có chevron. Cần chọn cách nhập giá trị 4–99, ví dụ picker hoặc một màn hình con.
- **Thanh trượt trong sheet tạo mật khẩu.** Khoảng 4–99 có 96 nấc, nên khó chỉnh chính xác. Có thể thêm nút +/− hoặc cho nhập số.
- **Phân biệt hai chỗ dùng tên "Tạo mật khẩu".** Cả tab lẫn nút trong form tạo/sửa card đang dùng tên này. Cần đặt nhãn sao cho người dùng không nhầm hai chỗ với nhau.

**Màn hình Login**
- **Nút "Xóa & Tạo tài khoản mới" (FR-9).** Đặt nút cách xa nút Đăng nhập. Thao tác giữ 3 giây cần có phản hồi rõ, ví dụ vòng tiến trình.
- **Thông báo lỗi ký tự không hợp lệ (FR-2).** Khi người dùng gõ chữ có dấu vào ô mật khẩu, thông báo phải dễ hiểu.

**Cài đặt**
- **Nhóm và thứ tự các mục.** Ảnh có nhóm "GENERAL". Hai mục Change Main Password và Lock Vault là nút chữ màu teal, mỗi nút nằm trong một khối nền riêng. Cần xếp nhóm và thứ tự cho các mục mới: Giới hạn phiên, Ngôn ngữ, Giao diện, Import, và Export (kèm dòng "Lần export gần nhất").

**Recent**
- **Kiểu danh sách.** Ảnh tham chiếu có các dòng xen kẽ nền trắng và xám, nút Clear căn giữa ở footer. Cần quyết định giữ nguyên kiểu này, hay điều chỉnh cho dark mode và cho trạng thái rỗng (FR-43).

## Tham khảo
- `research-digest.md`: các app tương tự, chống dò mật khẩu, KDF, clipboard, chụp màn hình.
- `source-extract.md`: mô tả chi tiết ảnh tham chiếu và nội dung `idea.txt`.
- `review-adversarial-security.md`: phân tích lỗ hổng và lý do của các quyết định bảo mật ở trên.
