---
type: brainstorm-intent
product: Password Manager (iOS + Android)
date: 2026-10-23
sources: idea.txt, screens/*.jpg, .memlog.md (bản ghi quyết định chính thức)
precedence: Khi có mâu thuẫn, quyết định trong memlog được ưu tiên hơn idea.txt
---

# Password Manager: tài liệu ý định (đầu vào cho PRD)

## 1. Tóm tắt sản phẩm & mục tiêu

- Ứng dụng di động **Password Manager** chạy trên **iOS và Android**.
- Ứng dụng làm 2 việc: (1) lưu trữ, quản lý thông tin tài khoản (tiêu đề, tên đăng nhập, mật khẩu, ghi chú); (2) tạo mật khẩu có độ bảo mật cao.
- Đây là tiện ích **cá nhân, phi thương mại**. Nếu chạy ổn thì chia sẻ cho gia đình và bạn bè dùng.
- Ứng dụng **offline 100%**: mọi dữ liệu nằm trên điện thoại và được mã hóa.
- Mỗi điện thoại chỉ có **1 tài khoản**.
- Luồng sử dụng điển hình (kể cả người dùng lớn tuổi): mở app → đăng nhập → tìm card theo tiêu đề → copy tên đăng nhập + mật khẩu → dán sang ứng dụng khác (vd Facebook). Người dùng sẽ tự hướng dẫn người thân, nên app không cần thiết kế riêng cho nhóm ít rành công nghệ.

## 2. Nguyên tắc thiết kế & luật cứng

1. **Đơn giản nhất có thể.** Không phân loại card, không thêm field chuyên biệt. Field Note tự do kết hợp tìm kiếm theo tiêu đề là đủ.
2. **Offline hoàn toàn.** Không có mạng, không đồng bộ, không dịch vụ cloud.
3. **Mã hóa trên máy.** Dữ liệu chỉ đọc được sau khi đăng nhập thành công. Nếu truy cập trực tiếp vào file dữ liệu từ bên ngoài app thì không đọc được.
4. **Không bao giờ có cơ chế khôi phục mật khẩu (luật cứng).** Quên mật khẩu chính là mất toàn bộ dữ liệu. Không có gợi ý mật khẩu, câu hỏi bảo mật hay khóa khôi phục.
5. **Các luật bảo mật cốt lõi là cố định**, không cho người dùng tùy chỉnh: giới hạn 10 lần sai, thời gian chờ 30 phút, tự động xóa dữ liệu.
6. **1 tài khoản / 1 điện thoại.**
7. Mọi màn hình và tính năng, trừ màn hình Login, chỉ dùng được sau khi đăng nhập thành công.

## 3. Threat model thực tế

- **Kẻ trộm phổ thông** thường reset điện thoại rồi bán, không nhắm vào vault. Khả năng bị tấn công có chủ đích vào Password Manager của người dùng thường là **rất thấp**.
- Các vector tấn công đã nhận diện:
  1. Dùng script dò mật khẩu đăng nhập (brute-force) trên màn hình Login. Giới hạn số lần sai xử lý vector này.
  2. Bỏ qua màn hình Login, tìm và mở thẳng nơi lưu dữ liệu của app trên máy.
  3. Chép file dữ liệu đã mã hóa ra ngoài rồi phân tích hoặc giải mã offline (kể cả dùng AI).
- **Đường rò rỉ thực tế nhất là FILE EXPORT**, chứ không phải trộm máy. Khi xuất ra, bản sao vault rời khỏi điện thoại và đi qua Zalo, email, Drive...
- Kịch bản người dùng chung máy cố tình nhập sai 10 lần để phá tài khoản: **loại bỏ, không xét**.

## 4. Yêu cầu chức năng theo màn hình

### 4.1 Màn hình Login

- Hiển thị tên ứng dụng, ô nhập mật khẩu chính và nút Đăng nhập.
- **Tạo tài khoản:** dùng khi máy chưa có tài khoản. Người dùng đặt mật khẩu chính.
- **Chỉ 1 tài khoản trên mỗi máy.** Muốn đổi tài khoản thì chỉ có 2 cách:
  - (a) Bấm nút **"Xóa tài khoản + tạo mới"** trên màn hình Login. Nút này **có hộp thoại xác nhận** và **không yêu cầu mật khẩu**, tương đương việc gỡ app. Cách này nhất quán với luật "quên là mất hết".
  - (b) Gỡ rồi cài lại app.
- **Không có tính năng quên mật khẩu.**
- **Giới hạn nhập sai:**
  - Lần sai thứ 1–4: được nhập lại ngay.
  - Từ lần sai thứ 5 trở đi: sau mỗi lần sai phải **chờ 30 phút** mới được nhập tiếp.
  - Lần sai thứ 10: **tự động xóa tài khoản và toàn bộ dữ liệu**, người dùng phải tạo tài khoản mới.

### 4.2 Màn hình Quản lý mật khẩu

- Hiển thị danh sách card tài khoản. Mỗi card gồm:
  - **Tiêu đề**
  - **Tên đăng nhập**
  - **Mật khẩu**
  - **Note** (tùy chọn): field văn bản tự do để ghi thông tin bên lề.
- **Thanh tìm kiếm** chỉ tìm theo tiêu đề.
- **Nút nổi bật để tạo card mới.**
- Field tên đăng nhập và mật khẩu đều có **nút Copy** để dán sang ứng dụng khác.
- Field mật khẩu có **nút ẩn/hiện**.
- **Sửa card:** người dùng sửa được tiêu đề, tên đăng nhập, mật khẩu, Note, rồi bấm **Lưu**. Có 2 cách đổi mật khẩu:
  1. Nhập thủ công bằng bàn phím.
  2. Bấm "Tạo mật khẩu" để mở bottom sheet theo **edit_pass.jpg**. Khi bấm **Use Password**, mật khẩu tự điền vào field mật khẩu.
- Thành phần của sheet edit_pass.jpg, **giữ nguyên toàn bộ**:
  - Thanh kéo (drag handle)
  - Nút tạo lại (refresh)
  - Nhãn "Password strength: High"
  - Mật khẩu được tô màu theo loại ký tự
  - Thanh trượt Password Length kèm giá trị (vd 16)
  - 3 chip bật/tắt: **123**, **ABC**, **!@#**
  - Nút **Use Password**

### 4.3 Màn hình Tạo mật khẩu + Recent Passwords

**Màn hình Tạo mật khẩu** (tham chiếu password_generator.jpg), **giữ nguyên toàn bộ thành phần**:
- Nút Back và tiêu đề "Password Generator".
- **Nút Recent Passwords** (icon lịch sử) ở góc trên bên phải.
- Mật khẩu vừa tạo, tô màu theo loại ký tự, kèm nút tạo lại (random theo các tiêu chí đang chọn).
- Nút **Copy**.
- Dòng **Password Length** (vd 16 >).
- Các công tắc: **Uppercase (A–Z)**, **Lowercase (a–z)**, **Digits (0–9)**, **Special Characters**. Bên dưới hiển thị bộ ký tự đặc biệt `~!@#$%^&*+-/.,\{}[]();:?<>"'_`.

**Recent Passwords** (tham chiếu recent_password.jpg):
- Mở dạng sheet, có nút **Close** và tiêu đề.
- Danh sách mục, mỗi mục gồm thời điểm (dd/MM/yyyy HH:mm), mật khẩu và nút copy.
- Nút **Clear** ở cuối.
- Một mật khẩu **chỉ được ghi vào Recent Passwords khi người dùng bấm Copy trên màn hình Tạo mật khẩu**.

### 4.4 Màn hình Cài đặt

Tham chiếu setting.jpg, **bỏ "Use Face ID"**.
- **Autolock Vault** (bộ chọn thời gian).
- **Clear Clipboard** (bộ chọn thời gian). **Mặc định 1 phút**; ảnh tham chiếu ghi 30 giây nhưng đã đổi.
- **Notifications** (công tắc, có trong ảnh tham chiếu).
- **Change Main Password**.
- **Lock Vault** / Sign out.
- **Import / Export dữ liệu** (ảnh có icon cloud ↑↓ ở góc trên bên phải), dùng khi đổi điện thoại hoặc cài lại app:
  - File export được mã hóa và chỉ đọc được khi import lại vào app.

## 5. Yêu cầu bảo mật / ghi chú kỹ thuật cho PRD

1. **Bộ đếm 10 lần sai chỉ bảo vệ màn hình Login.** Khi file dữ liệu bị chép ra ngoài (vector 2/3) thì không còn bộ đếm nào. Lúc đó lớp bảo vệ thật sự là **độ mạnh của mật khẩu chính** cộng với **hàm dẫn xuất khóa chậm** (vd **Argon2id**).
2. **File export phải được mã hóa mạnh ngang vault**, vì đây là đường rò rỉ thực tế nhất.
3. **File export là bản backup DUY NHẤT** của người dùng, do luật "quên là mất hết" và "sai 10 lần là xóa". Vì vậy export là tính năng sống còn, không phải tính năng phụ.
4. **Bộ đếm sai và thời gian chờ 30 phút:**
   - Chỉ có 1 bộ đếm, vì mỗi máy chỉ có 1 tài khoản.
   - Phải **lưu bền** qua việc tắt/mở lại app.
   - **Không được reset bằng cách chỉnh đồng hồ máy.**
5. **Recent Passwords và Note** chứa dữ liệu nhạy cảm, nên phải **được mã hóa trong vault** như mật khẩu. Tìm kiếm chỉ theo tiêu đề, nên Note không cần đánh index.

## 6. Thay đổi so với idea.txt (v1 → v2)

| Hạng mục | idea.txt (v1) | Đã chốt (v2) |
|---|---|---|
| Số tài khoản/máy | Nhiều tài khoản độc lập | **Chỉ 1 tài khoản** |
| Đổi tài khoản | Tạo thêm tài khoản | Nút "Xóa tài khoản + tạo mới" trên Login (có xác nhận), hoặc gỡ/cài lại app |
| Nhập sai mật khẩu | Không giới hạn | Tối đa 10 lần. Từ lần sai thứ 5, mỗi lần sai chờ 30 phút. Lần 10 tự động xóa tài khoản + dữ liệu |
| Khôi phục mật khẩu | Không có (chỉ gỡ/cài lại) | Không có, nâng thành **luật cứng** |
| Field của card | Tiêu đề, tên đăng nhập, mật khẩu | Thêm **Note** tự do, không bắt buộc |
| Phân loại / tìm kiếm | Tìm theo tiêu đề | Không phân loại card, vẫn chỉ tìm theo tiêu đề |
| Clear Clipboard | 30 giây (theo ảnh) | **Mặc định 1 phút** |
| Face ID | Bỏ | Bỏ (giữ nguyên) |
| UI tạo mật khẩu | Màn hình đầy đủ + sheet edit_pass | Giữ nguyên cả hai, không bỏ thành phần nào |
| Vai trò của export | Tiện ích khi đổi máy/cài lại | Là **backup duy nhất**, phải mã hóa mạnh ngang vault |

## 7. Ngoài phạm vi (non-goals)

PRD không đưa lại các mục sau:
- Nhiều tài khoản trên một máy.
- Bất kỳ cơ chế khôi phục mật khẩu chính nào: quên mật khẩu, gợi ý, câu hỏi bảo mật, khóa khôi phục.
- Nhập sai mật khẩu không giới hạn.
- Đăng nhập sinh trắc học (Face ID / vân tay).
- Phân loại, thư mục hoặc tag cho card. Field chuyên biệt theo loại tài khoản.
- Tìm kiếm theo Note hoặc tên đăng nhập.
- Đồng bộ, cloud, backend hay mọi tính năng cần mạng.
- Thiết kế UX riêng cho người dùng ít rành công nghệ (luồng chuyển app, autolock, clipboard).
- Xử lý kịch bản người chung máy cố tình nhập sai để xóa tài khoản người khác.
- Bỏ bớt thành phần của màn hình Tạo mật khẩu hoặc sheet edit_pass.
- Thương mại hóa.

## 8. Câu hỏi mở cho PRD

Phần này chỉ liệt kê, chưa quyết định.

**Import / Export**
1. File export dùng **mật khẩu chính** hay một **mật khẩu export riêng**?
2. Khi import mà máy đã có dữ liệu thì **gộp hay ghi đè**?
3. Sau khi Change Main Password, các file export cũ còn mở được không?
4. Icon cloud ↑↓ trong setting.jpg có phải lối vào Import/Export không?

**Đăng nhập & mật khẩu chính**
5. Bộ đếm sai có **reset về 0 sau khi đăng nhập thành công** không?
6. Mật khẩu chính có yêu cầu độ dài hoặc độ mạnh tối thiểu khi tạo tài khoản không?
7. Change Main Password có cần nhập lại mật khẩu cũ không?

**Cài đặt**
8. **Giá trị mặc định của Autolock Vault** là bao nhiêu (ảnh ghi 1 phút, chưa chốt)? Danh sách lựa chọn của Autolock và Clear Clipboard gồm những giá trị nào?
9. **Công tắc Notifications** dùng để làm gì trong một app offline? Có giữ lại không?
10. Lock Vault và Sign out là một hay hai hành động khác nhau?

**Tạo mật khẩu & Recent Passwords**
11. **Khoảng độ dài mật khẩu** (min/max) và độ dài mặc định (ảnh ghi 16)?
12. Chip **ABC** trong edit_pass tương ứng với cả chữ hoa lẫn chữ thường hay chỉ một loại? Cách ánh xạ với 4 công tắc của màn hình đầy đủ?
13. Cách tính và các mức hiển thị "Password strength"?
14. Recent Passwords có giới hạn số mục hay thời gian lưu không? Copy từ chính danh sách Recent có tạo mục mới không? Nút Clear có cần xác nhận không?
15. Clear Clipboard áp dụng cho mọi thao tác copy (tên đăng nhập, mật khẩu, Recent) hay chỉ cho mật khẩu?
16. Tạo mật khẩu ngoài màn hình đầy đủ (trong card) thì có lưu vào Recent không? Theo luật hiện tại là chỉ lưu khi bấm Copy ở màn hình Tạo mật khẩu.

**Card & điều hướng**
17. Card có **tính năng xóa** không (idea.txt không nhắc)? Nếu có thì có cần xác nhận không?
18. Field nào bắt buộc khi tạo card (tiêu đề, tên đăng nhập, mật khẩu)?
19. Điều hướng giữa các màn hình dùng gì? Ảnh password_generator.jpg có thanh tab dưới cùng, chưa xác định số tab và nội dung.
