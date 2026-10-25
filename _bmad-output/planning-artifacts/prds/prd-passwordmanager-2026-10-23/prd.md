---
title: PAK Manager (iOS + Android) — PRD
status: final
created: 2026-10-23
updated: 2026-10-25
---

# PAK Manager (iOS + Android) — PRD

> **Trạng thái:** không còn câu hỏi nào chặn bước UX hay architecture. Các mục đã hoãn nằm ở mục 8.
> **Tài liệu kèm theo:** ảnh tham chiếu trong `screens/` (`password_generator.jpg`, `edit_pass.jpg`, `recent_password.jpg`, `setting.jpg`), và `addendum.md` (tham số bảo mật cho architecture, các điểm UX chưa chốt).

## Thuật ngữ

- **Tài khoản PAK Manager:** tài khoản duy nhất của app trên máy, được bảo vệ bằng **mật khẩu chính**.
- **Card:** một bộ thông tin đăng nhập mà người dùng lưu lại, gồm Tiêu đề, Tên đăng nhập, Mật khẩu và Note.
- **Vault:** toàn bộ dữ liệu đã mã hóa của app, gồm card, Recent và bản nháp.
- **Recent:** cách gọi tắt của Recent Passwords, tức danh sách mật khẩu vừa tạo (F4).
- **Màn hình Tạo mật khẩu:** nội dung của tab Tạo mật khẩu (`password_generator.jpg`).
- **Sheet tạo mật khẩu:** sheet được mở từ form sửa card (`edit_pass.jpg`).
- **Tên nút và tên cài đặt** trong tài liệu này là tên tham chiếu, lấy theo ảnh tham chiếu. Chuỗi hiển thị thực tế có đủ bản English và Tiếng Việt (NFR-14).

## 1. Tầm nhìn

**PAK Manager** là trình quản lý mật khẩu **cá nhân, miễn phí, offline hoàn toàn** trên iOS và Android. **Bảo mật là ưu tiên số một.** Dữ liệu không bao giờ rời khỏi điện thoại, trừ khi chính người dùng chủ động xuất ra file đã mã hóa.

**Động lực:** Thời đại số buộc mỗi người phải đăng ký rất nhiều ứng dụng, và ứng dụng nào cũng cần một mật khẩu mạnh, không trùng với các ứng dụng khác. Không ai nhớ nổi chừng ấy mật khẩu. Chủ sản phẩm muốn có một công cụ của riêng mình: offline, an toàn và miễn phí.

**App làm hai việc:**
1. Lưu trữ và quản lý thông tin đăng nhập. Mỗi bộ thông tin là một **card**.
2. Tạo mật khẩu mạnh để người dùng copy rồi dán vào app khác. Đây là loại mật khẩu không ai tự nhớ nổi.

**Người dùng:** Trước hết là chủ sản phẩm. Nếu app chạy ổn, chủ sản phẩm sẽ chia sẻ cho gia đình và bạn bè, kể cả người thân lớn tuổi. Chính chủ sản phẩm sẽ hướng dẫn họ dùng app, nên app không cần thiết kế riêng cho người ít rành công nghệ.

**Nguyên tắc thiết kế:**
1. **Bảo mật trên hết, trừ khi phá vỡ luồng cốt lõi.** Bảo mật luôn được ưu tiên, **trừ khi** một biện pháp bảo mật phá vỡ hai luồng cốt lõi ở mục 3 (copy rồi dán sang app khác). Vì vậy, app **không** khóa ngay khi người dùng chuyển sang app khác, và **không** chặn chụp màn hình.
2. **Đơn giản nhất có thể.** App không phân loại card và không có field chuyên biệt. Một field Note tự do cộng với tìm kiếm theo tiêu đề là đủ. Một tính năng chỉ được thêm vào khi nó phục vụ trực tiếp các luồng ở mục 3.

**Threat model thực tế (căn cứ cho nguyên tắc 1):**
- Kẻ trộm thông thường sẽ reset máy rồi bán, chứ không nhắm vào dữ liệu trong app. Khả năng một người dùng bình thường bị tấn công có chủ đích vào trình quản lý mật khẩu là **rất thấp**.
- Có ba đường tấn công đã được nhận diện:
  1. Dùng script dò mật khẩu trên màn hình Login. FR-4 chặn đường này.
  2. Bỏ qua màn hình Login để vào thẳng nơi lưu dữ liệu.
  3. Chép file dữ liệu ra ngoài rồi giải mã offline, kể cả với sự trợ giúp của AI.

  Với đường 2 và đường 3, bộ đếm sai không còn tác dụng. Lớp bảo vệ thật sự là **độ mạnh của mật khẩu chính cộng với hàm dẫn xuất khóa chậm** (NFR-1, NFR-2).
- Đường rò rỉ thực tế nhất là **file export**, vì file này đi qua Zalo, email hay Drive. Rủi ro này lớn hơn rủi ro mất máy.
- Tình huống người dùng chung máy cố tình nhập sai 10 lần để xóa dữ liệu được **loại khỏi phạm vi**.

**Rủi ro đã chấp nhận:** đây là các lỗ hổng được chấp nhận có chủ đích. Chi tiết nằm ở từng yêu cầu được dẫn.
- Không chặn chụp màn hình, không che ảnh thu nhỏ trong màn hình đa nhiệm (NFR-10, ngoại lệ của TC-1).
- Nếu app bị tắt giữa chừng khi đang kiểm tra lần nhập thứ 10, lần đó bị tính là sai và có thể dẫn đến xóa dữ liệu (FR-5).
- Nhập sai mật khẩu cũ ở màn hình Change Main Password, hoặc nhập sai mật khẩu chính trước khi Export, không bị tính vào bộ đếm (FR-13, FR-51).
- Không giới hạn số lần nhập sai mật khẩu export khi Import (FR-56).
- Trên Android, nội dung đã copy có thể còn trong clipboard tối đa khoảng 1 giờ nếu người dùng không quay lại app (FR-65).

**Phát hành:** App Store và Google Play, miễn phí hoàn toàn, phi thương mại.

## 2. Tiêu chí thành công

App được coi là **thành công** khi chạy đúng như chủ sản phẩm mong muốn và đạt mọi tiêu chí bảo mật dưới đây. Số lượt cài và phản hồi của người khác **không** phải thước đo. App **thất bại** khi chạy sai so với mong muốn hoặc trượt bất kỳ tiêu chí nào.

| ID | Tiêu chí (kiểm chứng được) |
|---|---|
| TC-1 | Lấy file dữ liệu của app ra khỏi máy (qua backup hoặc root/jailbreak) thì không đọc được nội dung nào: tiêu đề, tên đăng nhập, mật khẩu, Note, Recent hay bản nháp. Có một ngoại lệ đã chấp nhận: ảnh thu nhỏ trong màn hình đa nhiệm (NFR-10). |
| TC-2 | File export không mở được bằng cách nào khác ngoài import vào app với đúng mật khẩu export. |
| TC-3 | Luồng đếm sai, chờ 30 phút và xóa ở lần thứ 10 chạy đúng theo FR-4 đến FR-6, kể cả khi tắt app, khởi động lại máy hoặc chỉnh đồng hồ. |
| TC-4 | App không có bất kỳ kết nối mạng nào. Cách kiểm tra trên từng nền tảng: NFR-7. |
| TC-5 | Export rồi import sang máy khác thì khôi phục được 100% card. |
| TC-6 (tiêu chí đối trọng với bảo mật) | Không có lần mất dữ liệu nào do lỗi của app, ví dụ hỏng file, import nhầm hay xóa nhầm. |

## 3. Các luồng sử dụng

### Hai luồng cốt lõi

Hai luồng này là lý do app tồn tại. Mọi quyết định bảo mật phải giữ chúng thông suốt.

**UJ-1: Đăng nhập Facebook bằng card đã lưu.**
1. Chị Lan mở app, nhập mật khẩu chính, rồi gõ "face" vào ô tìm kiếm.
2. Chị copy tên đăng nhập, chuyển sang Facebook và dán vào.
3. Chị **quay lại** PAK Manager, copy mật khẩu, chuyển sang Facebook và dán vào.
4. Chị đăng nhập thành công.

Trong lúc chị chuyển qua lại giữa hai app, PAK Manager không bắt chị đăng nhập lại.

**UJ-2: Đăng ký tài khoản Shopee mới.**
1. Chị Lan mở tab Tạo mật khẩu, chỉnh độ dài và loại ký tự, rồi bấm tạo lại vài lần cho tới khi ưng ý.
2. Chị bấm **Copy**. Mật khẩu được ghi vào Recent.
3. Chị chuyển sang Shopee để đăng ký: dán mật khẩu vào ô mật khẩu và ô xác nhận, chờ OTP, rồi điền thêm thông tin. Bước này có thể mất vài phút.
4. Đăng ký xong, chị quay lại PAK Manager và mở Recent. Mật khẩu vừa tạo **nằm trên cùng**. Chị copy lại mật khẩu đó.
5. Chị tạo card "Shopee", nhập tên đăng nhập, dán mật khẩu rồi bấm Lưu.

**Hệ quả cho yêu cầu:**
- **Autolock** tính từ lúc app chuyển sang chạy nền, **mặc định 3 phút**. Quá thời hạn đó thì người dùng phải đăng nhập lại, và điều này được chấp nhận.
- **Clear Clipboard** **mặc định 3 phút**.
- **Recent** xếp mục **mới nhất ở trên**.

### Các luồng bổ trợ

**UJ-3: Đổi điện thoại.**
1. Trên máy cũ, chị Lan vào Cài đặt, chọn Export, nhập lại mật khẩu chính, rồi đặt mật khẩu export. Chị lưu file ở nơi chị muốn, ví dụ gửi qua Zalo cho chính mình hoặc lưu lên Drive.
2. Trên máy mới, chị cài app, tạo tài khoản PAK Manager và đăng nhập.
3. Chị vào Cài đặt, chọn Import, chọn file, nhập mật khẩu export rồi xác nhận.
4. Toàn bộ card trong file được **thêm** vào app trên máy mới.

Máy cũ và máy mới có thể chạy hai hệ điều hành khác nhau, ví dụ khi đổi từ iPhone sang Android.

**UJ-4: Quên mật khẩu chính, hoặc nhập sai đến lần thứ 10.** Chị Lan không vào được app nữa.
- Nếu quên mật khẩu, chị dùng nút "Xóa & Tạo tài khoản mới".
- Nếu nhập sai đến lần thứ 10, app tự xóa dữ liệu.

Trong cả hai trường hợp, chị phải tạo tài khoản mới. Nếu có file export **và còn nhớ mật khẩu export**, chị import để lấy lại các card tính đến thời điểm export, theo bước 3–4 của UJ-3. Nếu không, toàn bộ dữ liệu cũ đã mất.

## 4. Tính năng

### F1. Tài khoản và đăng nhập

Mỗi máy chỉ có **một tài khoản PAK Manager**, được bảo vệ bằng một mật khẩu chính. Mọi màn hình và tính năng khác chỉ dùng được sau khi đăng nhập thành công.

**Tạo tài khoản**
- **FR-1:** Khi máy chưa có tài khoản, màn hình Login hiển thị nút **"Tạo tài khoản"**. Người dùng đặt mật khẩu chính rồi nhập lại để xác nhận. Trước khi tạo, app cảnh báo rõ: quên mật khẩu chính là mất toàn bộ dữ liệu.
- **FR-2:** Quy tắc cho mật khẩu chính, dựa trên NIST SP 800-63B-4:
  - Độ dài **15–128 ký tự**.
  - **Chỉ chấp nhận ký tự ASCII in được, kể cả khoảng trắng.** App không chấp nhận chữ có dấu tiếng Việt hay ký tự Unicode khác, và báo rõ lý do khi người dùng nhập phải. Lý do của quy tắc này: cùng một mật khẩu có dấu có thể bị bàn phím hoặc hệ điều hành biểu diễn thành những chuỗi ký tự khác nhau. Khi đó app sẽ tính là nhập sai, và có thể xóa dữ liệu.
  - **Không** bắt buộc phải có chữ hoa, chữ số hay ký tự đặc biệt.
  - **Từ chối** mật khẩu nằm trong danh sách mật khẩu phổ biến hoặc đã bị lộ. Danh sách này được nhúng sẵn trong app để dùng offline. Nguồn và kích thước danh sách sẽ chốt ở bước architecture.
  - **Từ chối** mật khẩu chỉ gồm một ký tự lặp lại hoặc một dãy tuần tự, ví dụ `aaaaaaaaaaaaaaa` hay `123456789012345`.
  - Trong lúc nhập có thanh độ mạnh với 3 nhãn **Low / Medium / High**. Thanh này dùng cách tính **khác** FR-34: nó đánh giá theo các mẫu dễ đoán như từ điển, dãy phím hay ngày tháng, vì công thức entropy đánh giá quá cao mật khẩu do người tự đặt.

**Đăng nhập và chống dò mật khẩu**
- **FR-3:** Khi máy đã có tài khoản, màn hình Login hiển thị tên app (**PAK Manager**), ô nhập mật khẩu chính và nút **Đăng nhập**. Nút Đăng nhập bị vô hiệu khi ô mật khẩu có ít hơn 15 ký tự. Đăng nhập đúng thì app chuyển sang tab Quản lý mật khẩu.
- **FR-4:** Giới hạn nhập sai:
  - Lần sai thứ 1–4: người dùng được nhập lại ngay.
  - Lần sai thứ 5–9: sau mỗi lần sai, người dùng phải **chờ 30 phút** mới được nhập tiếp.
  - Lần sai thứ 10: app **tự động xóa tài khoản và toàn bộ vault**, rồi quay về màn hình Login ở trạng thái chưa có tài khoản (FR-1).
  - Màn hình Login hiển thị **số lần thử còn lại trước khi dữ liệu bị xóa**. Trong thời gian phải chờ, màn hình hiển thị thêm **đồng hồ đếm ngược**.
- **FR-5:** Cách tính một lần sai:
  - Đăng nhập đúng thì bộ đếm **về 0**.
  - Nhập lại **đúng chuỗi sai của lần ngay trước đó** thì không tính thêm lần sai và không bắt đầu thời gian chờ mới.
  - Mỗi lúc chỉ xử lý **một** lần kiểm tra. Bấm nút liên tiếp không tạo thêm lần thử.
  - Bộ đếm tăng **trước** khi kiểm tra mật khẩu. Nếu app bị tắt giữa lúc đang kiểm tra, lần đó tính là sai.
- **FR-6:** Bộ đếm và thời gian chờ được **lưu bền**, không mất khi tắt app hay khởi động lại máy. Chỉnh đồng hồ máy **không** rút ngắn được thời gian chờ. Nếu máy khởi động lại trong lúc đang chờ, thời gian chờ hiện tại tính lại từ đầu.
- **FR-7:** **Vault bị hỏng không phải là sai mật khẩu.** Khi mật khẩu đúng nhưng vault bị hỏng, app báo trạng thái "Dữ liệu bị hỏng". Lần nhập đó **không** tính vào bộ đếm và **không bao giờ** kích hoạt việc xóa. Người dùng có thể dùng "Xóa & Tạo tài khoản mới" rồi import lại từ file export.
- **FR-8:** Ba luật ở FR-4 (10 lần, 30 phút, tự động xóa) là cố định. **Không** có cài đặt nào thay đổi được chúng.

**Xóa tài khoản và khôi phục**
- **FR-9:** Khi máy đã có tài khoản, màn hình Login có nút **"Xóa & Tạo tài khoản mới"**. Nút này cần hai bước:
  1. Người dùng bấm nút, và app mở hộp thoại xác nhận.
  2. Người dùng **giữ nút xác nhận trong hộp thoại 3 giây**.

  Nút **không** yêu cầu mật khẩu, để người quên mật khẩu chính vẫn dùng được. Xong hai bước, app xóa toàn bộ vault và quay về màn hình Login ở trạng thái chưa có tài khoản.
- **FR-10:** App **không có** bất kỳ cơ chế khôi phục mật khẩu chính nào: không có "quên mật khẩu", gợi ý, câu hỏi bảo mật hay khóa khôi phục. Đây là luật cứng.
- **FR-11:** Gỡ app là xóa sạch vault, tài khoản và bộ đếm sai. Cài lại app thì máy trở về như mới, không còn sót lại gì.
- **FR-12:** Việc xóa dữ liệu, dù xảy ra ở lần sai thứ 10 hay qua FR-9, xóa **mọi thứ**: card, Recent, bản nháp, bộ đếm, và cả clipboard nếu clipboard còn giữ giá trị app đã copy. Nếu quá trình xóa bị gián đoạn, lần mở app tiếp theo sẽ xóa nốt rồi mới hiện màn hình Login ở trạng thái chưa có tài khoản.

**Đổi mật khẩu chính**
- **FR-13:** Màn hình Change Main Password yêu cầu nhập **mật khẩu cũ**, rồi nhập mật khẩu mới theo FR-2 và xác nhận lại. Nhập sai mật khẩu cũ ở đây **không** tính vào bộ đếm, vì muốn vào màn hình này thì vault đã phải đang mở. Bản nháp (nếu có) vẫn được giữ. Các file export cũ không bị ảnh hưởng, vì chúng dùng mật khẩu export riêng (F6).

**Phiên đăng nhập**
- **FR-14:** Mỗi phiên đăng nhập có **giới hạn tuyệt đối**, tính từ lúc đăng nhập thành công (giá trị mặc định: FR-46). Hết thời hạn, app khóa và yêu cầu đăng nhập lại, kể cả khi người dùng đang thao tác.
- **FR-15:** **Autolock** khóa app khi app đã chạy nền quá thời hạn (giá trị mặc định: FR-46). FR-14 và FR-15 độc lập với nhau: điều kiện nào đến trước thì app khóa theo điều kiện đó.
- **FR-16:** Nếu đến lúc phải khóa (FR-14, FR-15) mà app đang **ghi dữ liệu**, ví dụ đang đổi mật khẩu chính, tạo file export hay ghi dữ liệu import, thì app khóa ngay sau khi thao tác ghi đó hoàn tất hoặc được hoàn tác. Nếu import hay export **chưa bắt đầu ghi**, ví dụ người dùng vẫn đang ở trình chọn file, thì thao tác đó bị hủy và dữ liệu giữ nguyên.

### F2. Quản lý card

Mỗi card gồm **Tiêu đề**, **Tên đăng nhập**, **Mật khẩu** và **Note** (văn bản tự do, không bắt buộc).

**Danh sách và tìm kiếm**
- **FR-17:** Tab Quản lý mật khẩu hiển thị danh sách card. Mỗi card hiển thị cả 4 field. Riêng dòng Note được ẩn khi Note trống.
  - Tên đăng nhập và mật khẩu đều có **nút Copy** ngay trên card.
  - Mật khẩu có **nút ẩn/hiện** và **mặc định ở trạng thái ẩn**.
  - Note hiện **tối đa 3 dòng đầu**. Bấm vào Note thì xem được toàn bộ nội dung.
- **FR-18:** Danh sách xếp theo **thời gian tạo, card mới nhất ở trên cùng**. Sửa card **không** làm đổi vị trí của card.
- **FR-19:** Thanh tìm kiếm **chỉ tìm theo tiêu đề**:
  - Khớp với bất kỳ đoạn nào trong tiêu đề. Ví dụ gõ "gmail" thì ra card "Tài khoản Gmail".
  - **Không phân biệt hoa thường.**
  - **Không phân biệt dấu tiếng Việt.** Ví dụ gõ "ngan hang" thì ra "Ngân hàng", và "d" khớp với "đ".
  - Hiển thị mọi card khớp, kể cả các card trùng tiêu đề, theo thứ tự của FR-18.
  - Kết quả cập nhật ngay trong lúc gõ.
- **FR-20:** Khi chưa có card nào, tab hiển thị hướng dẫn tạo card đầu tiên.

**Tạo, sửa và xóa card**
- **FR-21:** Tab Quản lý mật khẩu có một **nút nổi bật** để tạo card mới.
- **FR-22:** Khi tạo hoặc sửa card, **Tiêu đề, Tên đăng nhập và Mật khẩu là bắt buộc**, còn Note thì không. Các card được phép **trùng tiêu đề**.
- **FR-23:** Góc trên bên phải mỗi card có một nút menu. Bấm vào sẽ mở popup gồm **Sửa** và **Xóa**.
- **FR-24:** Ở form sửa card, người dùng sửa được cả 4 field rồi bấm **Lưu**. Có hai cách đổi mật khẩu:
  - Gõ thủ công.
  - Bấm nút **"Tạo mật khẩu"** trong form để mở sheet tạo mật khẩu (FR-28). Bấm **Use Password** thì mật khẩu vừa tạo thay cho giá trị hiện có trong field Mật khẩu. Đóng sheet mà không bấm Use Password thì field giữ nguyên.

  Form **tạo card mới không có** nút "Tạo mật khẩu". Người dùng gõ hoặc dán mật khẩu vào, ví dụ dán từ Recent như ở UJ-2.
- **FR-25:** Muốn xóa card, người dùng phải đồng ý ở **hộp thoại xác nhận**.
- **FR-26:** **Bản nháp:**
  - Trong lúc người dùng tạo hoặc sửa card, app **tự động lưu bản nháp đã mã hóa sau mỗi thay đổi**. App chỉ giữ tối đa **một** bản nháp.
  - Nếu app bị khóa (FR-14, FR-15, FR-49) hoặc bị hệ điều hành tắt, lần đăng nhập tiếp theo sẽ mở lại bản nháp để người dùng làm tiếp.
  - Bản nháp bị hủy khi người dùng bấm Lưu, khi người dùng chủ động bỏ thay đổi, hoặc khi dữ liệu bị xóa (FR-12).

### F3. Tạo mật khẩu

App có hai nơi tạo mật khẩu: màn hình Tạo mật khẩu và sheet tạo mật khẩu. Cả hai **giữ nguyên toàn bộ thành phần** trong ảnh tham chiếu. Ngoại lệ duy nhất là nút Back của màn hình Tạo mật khẩu, được bỏ vì màn hình này đã là một tab.

- **FR-27:** **Màn hình Tạo mật khẩu** (`password_generator.jpg`) gồm:
  - Tiêu đề "Password Generator".
  - Nút **Recent Passwords** (icon lịch sử) ở góc trên bên phải.
  - Mật khẩu vừa tạo, kèm nút tạo lại.
  - Nút **Copy**.
  - Dòng **Password Length** để điều chỉnh độ dài. Kiểu điều khiển do bước UX quyết định.
  - 4 công tắc: **Uppercase Letters (A–Z)**, **Lowercase Letters (a–z)**, **Digits (0–9)** và **Special Characters**. Bên dưới hiển thị bộ ký tự đặc biệt `~!@#$%^&*+-/.,\{}[]();:?<>"'_`.
- **FR-28:** **Sheet tạo mật khẩu** (mở từ form sửa card, `edit_pass.jpg`) gồm:
  - Tay nắm kéo (drag handle) của sheet và nút tạo lại.
  - Nhãn **Password strength**. Nhãn này chỉ có ở sheet; màn hình Tạo mật khẩu không có.
  - Mật khẩu vừa tạo.
  - Thanh trượt **Password Length** kèm giá trị.
  - 3 chip: **123**, **ABC** và **!@#**.
  - Nút **Use Password**.
- **FR-29:** Độ dài mật khẩu tạo ra: **4–99 ký tự**.
- **FR-30:** Loại ký tự:
  - **Màn hình Tạo mật khẩu:** 4 công tắc bật/tắt độc lập với nhau. Nếu tắt cả 4, mật khẩu chỉ gồm chữ thường.
  - **Sheet tạo mật khẩu:** **luôn dùng chữ thường**.
    - Chip **ABC** bật/tắt chữ hoa. Bật thì mật khẩu có cả chữ hoa lẫn chữ thường; tắt thì chỉ còn chữ thường.
    - Chip **123** bật/tắt chữ số.
    - Chip **!@#** bật/tắt ký tự đặc biệt, dùng đúng bộ ký tự của màn hình Tạo mật khẩu.
- **FR-31:** **Mỗi khi người dùng đổi một tiêu chí bất kỳ** (độ dài hoặc loại ký tự), app tự động tạo lại mật khẩu theo tiêu chí mới. Nút tạo lại sinh mật khẩu mới theo tiêu chí hiện tại.
- **FR-32:** Mỗi loại ký tự đang bật xuất hiện **ít nhất một lần** trong mật khẩu.
- **FR-33:** Mật khẩu được **tô màu theo loại ký tự**: chữ cái màu đen, chữ số màu xanh dương, ký tự đặc biệt màu cam. Bảng màu cho dark mode do bước UX quyết định.
- **FR-34:** **Password strength** có 3 mức. Độ mạnh được tính theo entropy: độ dài × log₂ của tổng số ký tự thuộc các loại đang bật.
  - **Low:** dưới 50 bit.
  - **Medium:** từ 50 đến dưới 80 bit.
  - **High:** từ 80 bit trở lên.
- **FR-35:** App lưu bộ tiêu chí dùng gần nhất, kể cả sau khi tắt app. Màn hình Tạo mật khẩu và sheet tạo mật khẩu **dùng chung một bộ tiêu chí**, ánh xạ như sau:

  | Sheet tạo mật khẩu | Màn hình Tạo mật khẩu |
  |---|---|
  | Chip 123 | Công tắc Digits |
  | Chip !@# | Công tắc Special Characters |
  | Chip ABC | Công tắc Uppercase |
  | (không có) | Công tắc Lowercase, chỉ có tác dụng ở màn hình này |

  Lần đầu mở app: **mọi loại ký tự đều bật, độ dài 16**.
- **FR-36:** Bấm **Use Password** chỉ điền mật khẩu vào card. Thao tác này **không** ghi vào Recent.

### F4. Recent Passwords

- **FR-37:** **Recent Passwords** (gọi tắt là **Recent**) mở dạng sheet từ nút lịch sử trên màn hình Tạo mật khẩu (`recent_password.jpg`). Sheet gồm:
  - Nút **Close** và tiêu đề.
  - Danh sách các mục. Mỗi mục gồm thời điểm (`dd/MM/yyyy HH:mm`), mật khẩu được tô màu như FR-33, và nút Copy.
  - Nút **Clear** ở cuối sheet.
- **FR-38:** Một mật khẩu được ghi vào Recent **khi và chỉ khi** người dùng bấm **Copy trên màn hình Tạo mật khẩu**. Bấm Use Password hay bấm Copy ngay trong Recent đều **không** tạo mục mới.
- **FR-39:** Copy cùng một mật khẩu nhiều lần thì Recent vẫn **chỉ có 1 mục**. Các lần copy sau **không** đổi thời điểm, vị trí hay hạn của mục đó.
- **FR-40:** Danh sách xếp mục **mới nhất ở trên cùng**.
- **FR-41:** Mỗi mục **tự động bị xóa sau 72 giờ** kể từ lúc được ghi. Hạn này tính riêng cho từng mục.
- **FR-42:** Bấm **Clear** thì xóa toàn bộ danh sách, sau khi người dùng đồng ý ở **hộp thoại xác nhận**.
- **FR-43:** Khi Recent trống, sheet hiển thị trạng thái rỗng và nút Clear bị vô hiệu. Recent trống khi người dùng chưa copy lần nào, vừa bấm Clear, hoặc mọi mục đã hết hạn.
- **FR-44:** Recent được **mã hóa trong vault**, giống như mật khẩu của card.

### F5. Cài đặt và điều hướng

- **FR-45:** Sau khi đăng nhập, app có **tab bar gồm 3 tab**: **Quản lý mật khẩu**, **Tạo mật khẩu** và **Cài đặt**. Tab mặc định khi vừa đăng nhập là Quản lý mật khẩu.
- **FR-46:** Có 3 cài đặt thời gian. Người dùng chọn bằng picker trong các giá trị **1 / 3 / 5 / 10 phút**. **Không** có lựa chọn "Không bao giờ".

  | Cài đặt | Yêu cầu | Mặc định |
  |---|---|---|
  | Autolock Vault | FR-15 | 3 phút |
  | Giới hạn phiên | FR-14 | 10 phút |
  | Clear Clipboard | FR-65 | 3 phút |
- **FR-47:** **Ngôn ngữ và giao diện:**
  - **Ngôn ngữ:** **English** hoặc **Tiếng Việt**. Lần đầu cài, app theo ngôn ngữ của điện thoại: máy để tiếng Việt thì dùng Tiếng Việt, các ngôn ngữ khác thì dùng English.
  - **Giao diện:** **Theo hệ thống**, **Sáng** hoặc **Tối**. Mặc định là Theo hệ thống.
- **FR-48:** **Change Main Password** hoạt động theo FR-13.
- **FR-49:** **Lock Vault** khóa app ngay và quay về màn hình Login. Lock Vault cũng là thao tác Sign out; app không có nút Sign out riêng.
- **FR-50:** **Import** và **Export** là hai mục trong danh sách Cài đặt. App không dùng icon cloud trong ảnh tham chiếu. Mục Export hiển thị **"Lần export gần nhất: dd/MM/yyyy"**, hoặc "Chưa export lần nào" nếu chưa từng export. Ngày này được ghi nhận ngay khi tạo file xong (FR-55), kể cả khi người dùng đóng menu chia sẻ mà không gửi file đi.

### F6. Import / Export

File export là **bản backup duy nhất** của người dùng, vì quên mật khẩu chính hay nhập sai 10 lần đều làm mất hết dữ liệu. Đây là tính năng sống còn, không phải tính năng phụ. File export cũng là đường rò rỉ thực tế nhất (xem threat model ở mục 1 và NFR-3).

**Export**
- **FR-51:** Muốn export, người dùng phải **nhập lại mật khẩu chính** trước. Nhập sai ở bước này **không** tính vào bộ đếm.
- **FR-52:** Người dùng đặt một **mật khẩu export** theo quy tắc FR-2 (15–128 ký tự ASCII) và nhập lại để xác nhận.
  - App hiển thị một dòng gợi ý, không điền sẵn: người dùng có thể dùng lại mật khẩu chính làm mật khẩu export.
  - App **cảnh báo rõ**: quên mật khẩu export thì file export vô dụng, vì không có cách nào khôi phục.
- **FR-53:** File export **chỉ chứa card**: tiêu đề, tên đăng nhập, mật khẩu, Note và thời gian tạo. File **không** chứa Recent, cài đặt hay bản nháp.
- **FR-54:** File export được mã hóa và **chỉ đọc được khi import vào app** với đúng mật khẩu export. Tham số mã hóa của file export là **cố định**, không phụ thuộc vào máy tạo file, nên file tạo trên máy nào cũng import được trên máy khác.
- **FR-55:** Tạo file xong, app mở **menu chia sẻ của hệ điều hành** để người dùng gửi qua Zalo, email, Drive hoặc lưu vào Files. Việc này không cần quyền mạng.

**Import**
- **FR-56:** Import **chỉ nhận file do PAK Manager export**. File khác, ví dụ CSV hay file của trình quản lý mật khẩu khác, bị từ chối với thông báo "File không hợp lệ". Người dùng chọn file bằng trình chọn file của hệ điều hành, rồi nhập mật khẩu export. Import **không** cần nhập lại mật khẩu chính, và **không giới hạn** số lần nhập sai mật khẩu export. Lý do: ai có được file thì vẫn dò mật khẩu bên ngoài app được, nên giới hạn trong app không bảo vệ thêm gì. Lớp bảo vệ thật là độ mạnh của mật khẩu export.
- **FR-57:** Import **thêm card vào**, không ghi đè:
  - Trước khi thêm, app cho biết file có bao nhiêu card và được export ngày nào. Người dùng bấm **Xác nhận** hoặc **Hủy**.
  - Khi người dùng xác nhận, mọi card trong file được thêm vào danh sách. Các card hiện có giữ nguyên.
  - App **không** tự loại card trùng. Người dùng tự kiểm tra và xóa card trùng (FR-25).
  - Thêm xong, app báo "Đã thêm N card".
- **FR-58:** Card được import giữ nguyên thời gian tạo gốc và nằm trong danh sách theo thứ tự của FR-18.
- **FR-59:** Import là thao tác **nguyên tử**. Nếu sai mật khẩu, file hỏng hoặc import bị gián đoạn, dữ liệu hiện có **vẫn nguyên vẹn** và không có card nào được thêm dở dang (TC-6).
- **FR-60:** Import **không** đụng tới Recent, cài đặt và bản nháp.
- **FR-61:** File export tạo trên iOS phải import được trên Android, và ngược lại.
- **FR-62:** Phiên bản app mới hơn phải import được file export do phiên bản cũ hơn tạo ra.
- **FR-63:** App từ chối file có tham số mã hóa nằm ngoài giới hạn cho phép và báo "File không hợp lệ". Việc này ngăn một file độc hại làm treo app hoặc làm cạn bộ nhớ.

### F7. Copy và clipboard (áp dụng chung)

- **FR-64:** App có các nút Copy sau: tên đăng nhập và mật khẩu trên card, màn hình Tạo mật khẩu, và từng mục trong Recent. Mật khẩu và Note **không** cho bôi chọn hay kéo thả ra ngoài. Muốn lấy mật khẩu, người dùng chỉ có cách bấm nút Copy.
- **FR-65:** **Mọi** thao tác copy đều áp dụng Clear Clipboard (giá trị mặc định: FR-46). App chỉ xóa clipboard nếu clipboard vẫn còn chứa đúng giá trị app đã copy, để không xóa nhầm thứ người dùng copy sau đó. Hệ điều hành không cho app chạy hẹn giờ khi đang ở nền, nên cách xóa khác nhau theo nền tảng:
  - **iOS:** nội dung copy được gắn **hạn tự hết** bằng đúng thời gian Clear Clipboard, và **chỉ nằm trên máy**, không đồng bộ qua Universal Clipboard.
  - **Android:** nội dung copy được đánh dấu **nhạy cảm** (Android 13 trở lên). Khi người dùng quay lại app mà đã quá thời hạn, app xóa clipboard ngay. Nếu người dùng không quay lại, nội dung có thể nằm trong clipboard cho tới khi hệ thống tự xóa, khoảng 1 giờ trên Android 13 trở lên. Đây là giới hạn của nền tảng.
  - **Cả hai nền tảng:** app xóa clipboard khi app bị khóa lúc đang ở tiền cảnh (ví dụ Lock Vault hoặc hết phiên) và khi dữ liệu bị xóa (FR-12).

## 5. Yêu cầu phi chức năng

**Bảo mật dữ liệu**
- **NFR-1:** Toàn bộ vault được **mã hóa trên máy**, gồm tiêu đề, tên đăng nhập, mật khẩu, Note, Recent và bản nháp. Vault chỉ giải mã được sau khi đăng nhập đúng (TC-1).
- **NFR-2:** Khóa mã hóa được dẫn xuất từ mật khẩu chính bằng một **hàm dẫn xuất khóa chậm**, để chống dò mật khẩu offline khi file bị chép ra ngoài. Trên máy yếu nhất được hỗ trợ, mở khóa mất **khoảng 1 giây, tối đa 2 giây**. Danh sách máy cụ thể sẽ chốt ở bước architecture, và tham số đề xuất nằm trong addendum.
- **NFR-3:** File export được mã hóa **mạnh ngang vault**. File dùng cùng loại hàm dẫn xuất khóa, áp lên mật khẩu export, với tham số cố định (FR-54, TC-2).
- **NFR-4:** Khi app khóa (Lock Vault, hết phiên, Autolock), app bỏ mọi tham chiếu tới khóa giải mã và dữ liệu đã giải mã trong bộ nhớ. Thời gian dữ liệu đã giải mã nằm trong bộ nhớ được giữ ở mức ngắn nhất mà nền tảng cho phép.
- **NFR-5:** Nếu app có chỉ mục tìm kiếm theo tiêu đề, chỉ mục này không được lưu ra ngoài vault ở dạng chưa mã hóa. Note không cần đánh chỉ mục.
- **NFR-6:** Mật khẩu tạo ra dùng **bộ sinh số ngẫu nhiên an toàn mật mã** (CSPRNG) của hệ điều hành.

**Offline và quyền riêng tư**
- **NFR-7:** App **không có kết nối mạng nào**, và không tích hợp SDK quảng cáo, analytics hay crash reporting. Cách kiểm tra TC-4:
  - **Android:** manifest của bản release, sau khi gộp các thư viện, **không** chứa quyền `INTERNET`. Bước này được kiểm tra tự động khi build.
  - **iOS:** iOS không có quyền mạng để kiểm tra, nên cần rà soát các thư viện dùng trong app và bắt gói tin khi chạy qua mọi luồng, để chứng minh không có kết nối nào ra ngoài.
- **NFR-8:** Dữ liệu app bị **loại khỏi sao lưu tự động của hệ điều hành**, gồm iCloud Backup, Google Backup và chuyển dữ liệu sang máy mới. File export là con đường backup duy nhất.
- **NFR-9:** **Bàn phím và tự động điền.** Ở các ô mật khẩu (mật khẩu chính, mật khẩu export, mật khẩu của card):
  - **Tắt** đề nghị lưu mật khẩu của hệ điều hành (iCloud Keychain, Google Autofill).
  - **Tắt** tự sửa, gợi ý từ, và tính năng bàn phím học từ nội dung người dùng gõ.
- **NFR-10:** **Rủi ro đã chấp nhận** theo nguyên tắc thiết kế 1: app **không** chặn chụp màn hình và **không** che ảnh thu nhỏ trong màn hình đa nhiệm. Hệ quả:
  - Ảnh chụp màn hình có mật khẩu đang hiện có thể tự đồng bộ lên iCloud Photos hoặc Google Photos.
  - Hệ điều hành lưu ảnh thu nhỏ của màn hình thành file chưa mã hóa ngay trong vùng dữ liệu của app. Đây là ngoại lệ của TC-1.

**Độ bền dữ liệu**
- **NFR-11:** Mọi thao tác ghi đều **nguyên tử**. Nếu app bị tắt đột ngột, máy hết pin hoặc khởi động lại giữa chừng, vault không bị hỏng (TC-6).

**Nền tảng và giao diện**
- **NFR-12:** App chạy trên **iOS và Android**, cho cả **điện thoại và máy tính bảng**, với bố cục thích ứng theo kích thước màn hình. Phiên bản hệ điều hành tối thiểu sẽ chốt ở bước architecture.
- **NFR-13:** App có **giao diện sáng và tối**. Lựa chọn và giá trị mặc định: FR-47. Phong cách theo ảnh tham chiếu, với một màu nhấn teal-green.
- **NFR-14:** Mọi chuỗi giao diện đều có đủ hai bản **English** và **Tiếng Việt**.

## 6. Phát hành và yêu cầu store

- **Tên app:** **PAK Manager** (xem mục 8).
- **Kênh phát hành:** App Store và Google Play. App **miễn phí hoàn toàn**: không có mua trong app, không quảng cáo, không gói trả phí.
- **Khai báo quyền riêng tư:** App Privacy (iOS) và Data Safety (Android) đều khai báo **"Không thu thập dữ liệu"**.
- **Chính sách quyền riêng tư:** đặt trên **GitHub Pages**, có bản English và Tiếng Việt. Nội dung nêu rõ ba điều: app chạy offline, không thu thập dữ liệu, và không có cơ chế khôi phục mật khẩu.
- **Khai báo mã hóa với Apple (export compliance):** app dùng mã hóa tiêu chuẩn để bảo vệ dữ liệu người dùng (xem mục 8).
- **Tài khoản nhà phát triển:** cần tài khoản Apple Developer (phí hằng năm) và Google Play Console (phí một lần). Tài khoản Google Play cá nhân mới phải qua giai đoạn thử nghiệm kín trước khi phát hành công khai (xem mục 8).
- **Mô tả trên store** phải cảnh báo rõ: quên mật khẩu chính là mất toàn bộ dữ liệu, và người dùng nên export định kỳ.

## 7. Ngoài phạm vi

Các mục sau **không** được đưa vào sản phẩm:
- **Tài khoản và khôi phục:**
  - Nhiều tài khoản trên một máy.
  - Bất kỳ cơ chế khôi phục mật khẩu chính nào.
- **Đăng nhập:**
  - Nhập sai mật khẩu không giới hạn.
  - Cho người dùng tùy chỉnh các luật ở FR-4.
  - Đăng nhập sinh trắc học (Face ID, vân tay).
  - Mật khẩu chính hoặc mật khẩu export có ký tự ngoài ASCII, ví dụ chữ có dấu tiếng Việt.
- **Card và tìm kiếm:**
  - Phân loại, thư mục hoặc tag cho card.
  - Field chuyên biệt theo loại tài khoản.
  - Tìm kiếm theo Note hoặc tên đăng nhập.
- **Tự động điền:** cung cấp mật khẩu cho app khác qua tính năng AutoFill của hệ điều hành. Luồng copy và dán đã đủ dùng.
- **Mạng và sao lưu:**
  - Đồng bộ, cloud, backend, hay bất kỳ tính năng nào cần mạng.
  - Sao lưu qua iCloud hoặc Google Backup.
- **Import / Export:**
  - Import kiểu ghi đè.
  - Import từ trình quản lý mật khẩu khác hoặc từ file CSV.
  - Tự động loại card trùng khi import.
  - Nhập lại mật khẩu chính khi import.
  - Giới hạn số lần nhập sai mật khẩu export.
  - Đưa Recent, cài đặt hoặc bản nháp vào file export.
- **Bảo mật màn hình:**
  - Khóa ngay khi chuyển sang app khác.
  - Chặn chụp màn hình.
  - Che ảnh thu nhỏ trong màn hình đa nhiệm.
- **Tạo mật khẩu:** bỏ bớt thành phần của màn hình Tạo mật khẩu hoặc sheet tạo mật khẩu. Ngoại lệ duy nhất là nút Back.
- **Giao diện đã bỏ:**
  - Công tắc Notifications và Use Face ID.
  - Icon cloud ở Cài đặt.
  - Lựa chọn "Không bao giờ" cho các cài đặt thời gian.
- **Khác:**
  - Thiết kế UX riêng cho người ít rành công nghệ.
  - Xử lý tình huống người dùng chung máy cố tình nhập sai để xóa dữ liệu.
  - Thương mại hóa dưới mọi hình thức.

## 8. Câu hỏi mở và các mục đã hoãn

Chủ sản phẩm đã xác nhận mọi giả định. Không còn câu hỏi nào chặn bước UX hay architecture.

Các mục dưới đây được hoãn lại và không chặn bước tiếp theo. Người phụ trách là chủ sản phẩm, và sẽ xem lại trước khi nộp app lên store:
- Kiểm tra tên "PAK Manager" còn trống trên App Store và Google Play.
- Xác định loại khai báo mã hóa (export compliance) với Apple.
- Kiểm tra yêu cầu hiện hành về thử nghiệm kín đối với tài khoản Google Play cá nhân, gồm số lượng tester và thời gian thử nghiệm.
