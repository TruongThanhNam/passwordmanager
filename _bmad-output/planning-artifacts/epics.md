---
status: final
stepsCompleted: [step-01-validate-prerequisites, step-02-design-epics, step-03-create-stories, step-04-final-validation]
inputDocuments:
  - _bmad-output/planning-artifacts/prds/prd-passwordmanager-2026-10-23/prd.md
  - _bmad-output/planning-artifacts/prds/prd-passwordmanager-2026-10-23/addendum.md
  - _bmad-output/planning-artifacts/architecture/architecture-passwordmanager-2026-10-27/ARCHITECTURE-SPINE.md
  - _bmad-output/planning-artifacts/ux-designs/ux-passwordmanager-2026-10-26/DESIGN.md
  - _bmad-output/planning-artifacts/ux-designs/ux-passwordmanager-2026-10-26/EXPERIENCE.md
---

# PAK Manager - Epic Breakdown

## Overview

Tài liệu này chia toàn bộ yêu cầu của PAK Manager thành epic và story để triển khai. Nguồn gồm PRD (kèm addendum), Architecture Spine và cặp UX DESIGN/EXPERIENCE. Mã FR-/NFR-/TC- dẫn tới `prd.md`; AD-n dẫn tới `ARCHITECTURE-SPINE.md`; S1–S28 dẫn tới bảng surface trong `EXPERIENCE.md`.

## Requirements Inventory

### Functional Requirements

**F1. Tài khoản và đăng nhập**

FR-1: Khi máy chưa có tài khoản, màn hình Login hiển thị nút "Tạo tài khoản". Người dùng đặt mật khẩu chính rồi nhập lại để xác nhận. Trước khi tạo, app cảnh báo rõ: quên mật khẩu chính là mất toàn bộ dữ liệu.
FR-2: Quy tắc mật khẩu chính (NIST SP 800-63B-4): dài 15–128 ký tự; chỉ chấp nhận ký tự ASCII in được, kể cả khoảng trắng, và báo rõ lý do khi gặp ký tự khác; không bắt buộc chữ hoa, chữ số hay ký tự đặc biệt; từ chối mật khẩu nằm trong blocklist mật khẩu phổ biến hoặc đã lộ (nhúng sẵn, dùng offline); từ chối chuỗi chỉ gồm một ký tự lặp lại hoặc một dãy tuần tự; trong lúc gõ hiển thị một dòng chữ độ mạnh Low / Medium / High (không vẽ thanh), đánh giá theo mẫu dễ đoán, khác cách tính ở FR-34.
FR-3: Khi máy đã có tài khoản, Login hiển thị tên app "PAK Manager", ô mật khẩu chính và nút "Đăng nhập". Nút bị vô hiệu khi ô có ít hơn 15 ký tự. Đăng nhập đúng thì chuyển sang tab Quản lý mật khẩu.
FR-4: Giới hạn nhập sai: lần sai 1–4 được nhập lại ngay; lần sai 5–9 phải chờ 30 phút sau mỗi lần; lần sai thứ 10 tự động xóa tài khoản và toàn bộ vault rồi về Login ở trạng thái chưa có tài khoản. Login hiển thị số lần thử còn lại trước khi dữ liệu bị xóa, và đồng hồ đếm ngược khi đang phải chờ.
FR-5: Cách tính lần sai: đăng nhập đúng thì bộ đếm về 0; nhập lại đúng chuỗi sai của lần ngay trước thì không tính thêm và không bắt đầu thời gian chờ mới; mỗi lúc chỉ xử lý một lần kiểm tra, bấm liên tiếp không tạo thêm lần thử; bộ đếm tăng trước khi kiểm tra, nếu app bị tắt giữa lúc kiểm tra thì lần đó tính là sai.
FR-6: Bộ đếm và thời gian chờ được lưu bền qua tắt app và khởi động lại máy. Chỉnh đồng hồ máy không rút ngắn được thời gian chờ. Khởi động lại máy trong lúc chờ thì thời gian chờ hiện tại tính lại từ đầu.
FR-7: Khi mật khẩu đúng nhưng vault bị hỏng, app báo "Dữ liệu bị hỏng". Lần nhập đó không tính vào bộ đếm và không bao giờ kích hoạt việc xóa. Người dùng có thể dùng "Xóa & Tạo tài khoản mới" rồi import lại.
FR-8: Ba luật của FR-4 (10 lần, 30 phút, tự xóa) là cố định, không có cài đặt nào thay đổi được.
FR-9: Khi đã có tài khoản, Login có nút "Xóa & Tạo tài khoản mới": bấm nút mở hộp thoại xác nhận, rồi giữ nút xác nhận 3 giây. Không yêu cầu mật khẩu. Xong thì xóa toàn bộ vault và về Login ở trạng thái chưa có tài khoản.
FR-10: Không có bất kỳ cơ chế khôi phục mật khẩu chính nào: không "quên mật khẩu", gợi ý, câu hỏi bảo mật hay khóa khôi phục.
FR-11: Gỡ app xóa sạch vault, tài khoản và bộ đếm sai. Cài lại thì máy như mới, không còn sót gì.
FR-12: Việc xóa dữ liệu (lần sai thứ 10 hoặc FR-9) xóa mọi thứ: card, Recent, bản nháp, bộ đếm, và clipboard nếu clipboard còn giữ giá trị app đã copy. Nếu quá trình xóa bị gián đoạn, lần mở app sau xóa nốt rồi mới hiện Login ở trạng thái chưa có tài khoản.
FR-13: Màn hình Change Main Password yêu cầu mật khẩu cũ, rồi mật khẩu mới theo FR-2 và nhập lại để xác nhận. Nhập sai mật khẩu cũ không tính vào bộ đếm. Bản nháp (nếu có) được giữ. File export cũ không bị ảnh hưởng.
FR-14: Mỗi phiên đăng nhập có giới hạn tuyệt đối tính từ lúc đăng nhập thành công (mặc định ở FR-46). Hết hạn thì app khóa và yêu cầu đăng nhập lại, kể cả khi người dùng đang thao tác.
FR-15: Autolock khóa app khi app đã chạy nền quá thời hạn (mặc định ở FR-46). FR-14 và FR-15 độc lập; điều kiện nào đến trước thì khóa theo điều kiện đó.
FR-16: Đến lúc khóa mà app đang ghi dữ liệu (đổi mật khẩu chính, tạo file export, ghi dữ liệu import) thì khóa ngay sau khi thao tác ghi hoàn tất hoặc được hoàn tác. Import/export chưa bắt đầu ghi (ví dụ đang ở trình chọn file) thì bị hủy, dữ liệu giữ nguyên.

**F2. Quản lý card**

FR-17: Tab Quản lý mật khẩu hiển thị danh sách card; mỗi card hiện đủ 4 field (Tiêu đề, Tên đăng nhập, Mật khẩu, Note), riêng dòng Note ẩn khi trống. Tên đăng nhập và mật khẩu có nút Copy ngay trên card. Mật khẩu có nút ẩn/hiện, mặc định ẩn. Note hiện tối đa 3 dòng đầu; bấm vào Note để xem toàn bộ.
FR-18: Danh sách xếp theo thời gian tạo, card mới nhất ở trên cùng. Sửa card không đổi vị trí.
FR-19: Thanh tìm kiếm chỉ tìm theo tiêu đề: khớp bất kỳ đoạn nào trong tiêu đề; không phân biệt hoa thường; không phân biệt dấu tiếng Việt ("ngan hang" khớp "Ngân hàng", "d" khớp "đ"); hiển thị mọi card khớp, kể cả trùng tiêu đề, theo thứ tự FR-18; kết quả cập nhật ngay trong lúc gõ.
FR-20: Khi chưa có card nào, tab hiển thị hướng dẫn tạo card đầu tiên.
FR-21: Tab Quản lý mật khẩu có một nút nổi bật để tạo card mới.
FR-22: Khi tạo hoặc sửa card, Tiêu đề, Tên đăng nhập và Mật khẩu là bắt buộc; Note không bắt buộc. Cho phép trùng tiêu đề.
FR-23: Góc trên bên phải mỗi card có nút menu, mở popup gồm Sửa và Xóa.
FR-24: Form tạo/sửa card cho nhập hoặc sửa cả 4 field rồi bấm Lưu. Mật khẩu nhập được bằng cách gõ/dán thủ công, hoặc bấm nút "Tạo mật khẩu" để mở sheet tạo mật khẩu (FR-28). Bấm Use Password thì mật khẩu được điền vào field Mật khẩu, thay giá trị hiện có. Đóng sheet mà không bấm Use Password thì field giữ nguyên.
FR-25: Muốn xóa card, người dùng phải đồng ý ở hộp thoại xác nhận.
FR-26: Bản nháp: trong lúc tạo/sửa card, app tự lưu bản nháp đã mã hóa sau mỗi thay đổi, giữ tối đa một bản nháp. Nếu app bị khóa (FR-14, FR-15, FR-49) hoặc bị OS tắt, lần đăng nhập sau mở lại bản nháp để làm tiếp. Bản nháp bị hủy khi bấm Lưu, khi người dùng chủ động bỏ thay đổi, hoặc khi dữ liệu bị xóa (FR-12).

**F3. Tạo mật khẩu**

FR-27: Màn hình Tạo mật khẩu gồm: tiêu đề "Password Generator"; nút Recent Passwords (icon lịch sử) ở góc trên phải; mật khẩu vừa tạo kèm nút tạo lại; nút Copy; dòng Password Length để chỉnh độ dài; 4 công tắc Uppercase Letters (A–Z), Lowercase Letters (a–z), Digits (0–9), Special Characters, bên dưới hiển thị bộ ký tự đặc biệt `~!@#$%^&*+-/.,\{}[]();:?<>"'_`. Không có nút Back.
FR-28: Sheet tạo mật khẩu (mở từ form tạo/sửa card) gồm: drag handle và nút tạo lại; nhãn Password strength (chỉ có ở sheet); mật khẩu vừa tạo; slider Password Length kèm giá trị; 3 chip 123, ABC, !@#; nút Use Password.
FR-29: Độ dài mật khẩu tạo ra: 4–99 ký tự.
FR-30: Loại ký tự: ở màn hình Tạo mật khẩu, 4 công tắc bật/tắt độc lập, tắt cả 4 thì mật khẩu chỉ gồm chữ thường. Ở sheet, luôn có chữ thường; chip ABC bật/tắt chữ hoa, chip 123 bật/tắt chữ số, chip !@# bật/tắt ký tự đặc biệt (cùng bộ ký tự với màn hình).
FR-31: Mỗi khi đổi một tiêu chí bất kỳ (độ dài hoặc loại ký tự), app tự tạo lại mật khẩu. Nút tạo lại sinh mật khẩu mới theo tiêu chí hiện tại.
FR-32: Mỗi loại ký tự đang bật xuất hiện ít nhất một lần trong mật khẩu.
FR-33: Mật khẩu được tô màu theo loại ký tự: chữ cái đen, chữ số xanh dương, ký tự đặc biệt cam (bảng màu dark mode theo UX).
FR-34: Password strength có 3 mức theo entropy = độ dài × log₂(tổng số ký tự thuộc các loại đang bật): Low < 50 bit; Medium 50 đến < 80 bit; High ≥ 80 bit.
FR-35: App lưu bộ tiêu chí dùng gần nhất, kể cả sau khi tắt app. Màn hình và sheet dùng chung một bộ tiêu chí: chip 123 ↔ Digits, chip !@# ↔ Special Characters, chip ABC ↔ Uppercase; công tắc Lowercase chỉ có tác dụng ở màn hình. Lần đầu mở app: mọi loại ký tự bật, độ dài 16.
FR-36: Bấm Use Password chỉ điền mật khẩu vào card, không ghi vào Recent.

**F4. Recent Passwords**

FR-37: Recent mở dạng sheet từ nút lịch sử trên màn hình Tạo mật khẩu, gồm: nút Close và tiêu đề; danh sách mục, mỗi mục có thời điểm (`dd/MM/yyyy HH:mm`), mật khẩu tô màu như FR-33 và nút Copy; nút Clear ở cuối sheet.
FR-38: Một mật khẩu được ghi vào Recent khi và chỉ khi người dùng bấm Copy trên màn hình Tạo mật khẩu. Use Password hay Copy ngay trong Recent không tạo mục mới.
FR-39: Copy cùng một mật khẩu nhiều lần thì Recent chỉ có 1 mục; các lần copy sau không đổi thời điểm, vị trí hay hạn của mục đó.
FR-40: Recent xếp mục mới nhất ở trên cùng.
FR-41: Mỗi mục tự động bị xóa sau 72 giờ kể từ lúc được ghi; hạn tính riêng cho từng mục.
FR-42: Bấm Clear xóa toàn bộ danh sách sau khi người dùng đồng ý ở hộp thoại xác nhận.
FR-43: Khi Recent trống (chưa copy lần nào, vừa Clear, hoặc mọi mục đã hết hạn), sheet hiển thị trạng thái rỗng và nút Clear bị vô hiệu.
FR-44: Recent được mã hóa trong vault, giống mật khẩu của card.

**F5. Cài đặt và điều hướng**

FR-45: Sau khi đăng nhập, app có tab bar 3 tab: Quản lý mật khẩu, Tạo mật khẩu, Cài đặt. Tab mặc định khi vừa đăng nhập là Quản lý mật khẩu.
FR-46: Có 3 cài đặt thời gian, chọn bằng picker trong các giá trị 1 / 3 / 5 / 10 phút, không có "Không bao giờ": Autolock Vault (FR-15, mặc định 3 phút), Giới hạn phiên (FR-14, mặc định 10 phút), Clear Clipboard (FR-65, mặc định 3 phút).
FR-47: Ngôn ngữ: English hoặc Tiếng Việt; lần đầu cài theo ngôn ngữ máy (máy tiếng Việt → Tiếng Việt, khác → English). Giao diện: Theo hệ thống, Sáng hoặc Tối; mặc định Theo hệ thống.
FR-48: Mục Change Main Password trong Cài đặt hoạt động theo FR-13.
FR-49: Lock Vault khóa app ngay và về màn hình Login. Lock Vault cũng là Sign out; không có nút Sign out riêng.
FR-50: Import và Export là hai mục trong Cài đặt (không dùng icon cloud). Mục Export hiển thị "Lần export gần nhất: dd/MM/yyyy" hoặc "Chưa export lần nào". Ngày được ghi nhận ngay khi tạo file xong (FR-55), kể cả khi người dùng đóng menu chia sẻ mà không gửi.

**F6. Import / Export**

FR-51: Muốn export, người dùng phải nhập lại mật khẩu chính trước. Nhập sai ở bước này không tính vào bộ đếm.
FR-52: Người dùng đặt mật khẩu export theo quy tắc FR-2 và nhập lại để xác nhận. App hiển thị dòng gợi ý (không điền sẵn) rằng có thể dùng lại mật khẩu chính, và cảnh báo rõ: quên mật khẩu export thì file vô dụng, không có cách khôi phục.
FR-53: File export chỉ chứa card: tiêu đề, tên đăng nhập, mật khẩu, Note và thời gian tạo. Không chứa Recent, cài đặt hay bản nháp.
FR-54: File export được mã hóa và chỉ đọc được khi import vào app với đúng mật khẩu export. Tham số mã hóa của file export cố định, không phụ thuộc máy tạo file.
FR-55: Tạo file xong, app mở menu chia sẻ của OS để người dùng gửi qua Zalo, email, Drive hoặc lưu vào Files. Không cần quyền mạng.
FR-56: Import chỉ nhận file do PAK Manager export; file khác (CSV, file của trình quản lý mật khẩu khác) bị từ chối với thông báo "File không hợp lệ". Người dùng chọn file bằng trình chọn file của OS rồi nhập mật khẩu export. Import không cần nhập lại mật khẩu chính và không giới hạn số lần nhập sai mật khẩu export.
FR-57: Import thêm card vào, không ghi đè: trước khi thêm, app cho biết file có bao nhiêu card và được export ngày nào, người dùng bấm Xác nhận hoặc Hủy; xác nhận thì mọi card trong file được thêm, card hiện có giữ nguyên; app không tự loại card trùng; thêm xong báo "Đã thêm N card".
FR-58: Card được import giữ nguyên thời gian tạo gốc và nằm trong danh sách theo thứ tự FR-18.
FR-59: Import là thao tác nguyên tử: sai mật khẩu, file hỏng hoặc bị gián đoạn thì dữ liệu hiện có vẫn nguyên vẹn, không card nào được thêm dở dang.
FR-60: Import không đụng tới Recent, cài đặt và bản nháp.
FR-61: File export tạo trên iOS import được trên Android, và ngược lại.
FR-62: Phiên bản app mới hơn import được file export do phiên bản cũ hơn tạo ra.
FR-63: App từ chối file có tham số mã hóa nằm ngoài giới hạn cho phép và báo "File không hợp lệ", để file độc hại không làm treo app hay cạn bộ nhớ.

**F7. Copy và clipboard**

FR-64: Nút Copy có ở: tên đăng nhập và mật khẩu trên card, màn hình Tạo mật khẩu, từng mục trong Recent. Mật khẩu và Note không cho bôi chọn hay kéo thả ra ngoài; muốn lấy mật khẩu chỉ có cách bấm Copy.
FR-65: Mọi thao tác copy đều áp dụng Clear Clipboard (mặc định ở FR-46); app chỉ xóa clipboard nếu clipboard còn đúng giá trị app đã copy. iOS: nội dung copy có hạn tự hết bằng thời gian Clear Clipboard và chỉ nằm trên máy (không Universal Clipboard). Android: nội dung copy được đánh dấu nhạy cảm (Android 13+); quay lại app mà đã quá hạn thì xóa ngay. Cả hai nền tảng: xóa clipboard khi app bị khóa lúc đang ở tiền cảnh và khi dữ liệu bị xóa (FR-12).

### NonFunctional Requirements

**Bảo mật dữ liệu**

NFR-1: Toàn bộ vault (tiêu đề, tên đăng nhập, mật khẩu, Note, Recent, bản nháp) được mã hóa trên máy và chỉ giải mã được sau khi đăng nhập đúng (TC-1).
NFR-2: Khóa mã hóa được dẫn xuất từ mật khẩu chính bằng hàm dẫn xuất khóa chậm; trên máy yếu nhất được hỗ trợ, mở khóa mất khoảng 1 giây, tối đa 2 giây.
NFR-3: File export được mã hóa mạnh ngang vault, dùng cùng loại KDF áp lên mật khẩu export, tham số cố định (FR-54, TC-2).
NFR-4: Khi app khóa (Lock Vault, hết phiên, Autolock), app bỏ mọi tham chiếu tới khóa giải mã và dữ liệu đã giải mã trong bộ nhớ; thời gian dữ liệu giải mã nằm trong bộ nhớ giữ ở mức ngắn nhất nền tảng cho phép.
NFR-5: Nếu có chỉ mục tìm kiếm theo tiêu đề, chỉ mục không được lưu ra ngoài vault ở dạng chưa mã hóa. Note không cần đánh chỉ mục.
NFR-6: Mật khẩu tạo ra dùng CSPRNG của hệ điều hành.

**Offline và quyền riêng tư**

NFR-7: App không có kết nối mạng nào; không SDK quảng cáo, analytics hay crash reporting. Android: manifest release đã merge không chứa quyền `INTERNET`, kiểm tra tự động khi build. iOS: rà soát thư viện và bắt gói tin khi chạy qua mọi luồng.
NFR-8: Dữ liệu app bị loại khỏi sao lưu tự động của OS (iCloud Backup, Google Backup, chuyển dữ liệu sang máy mới). File export là con đường backup duy nhất.
NFR-9: Ở mọi ô mật khẩu (chính, export, mật khẩu card): tắt đề nghị lưu mật khẩu của OS (iCloud Keychain, Google Autofill); tắt tự sửa, gợi ý từ và học từ của bàn phím.
NFR-10: Rủi ro chấp nhận: không chặn chụp màn hình, không che ảnh thu nhỏ trong màn hình đa nhiệm (ngoại lệ của TC-1).

**Độ bền dữ liệu**

NFR-11: Mọi thao tác ghi đều nguyên tử; app bị tắt đột ngột, hết pin hay khởi động lại giữa chừng không làm hỏng vault (TC-6).

**Nền tảng và giao diện**

NFR-12: Chạy trên iOS và Android, cho cả điện thoại và máy tính bảng, bố cục thích ứng kích thước màn hình (phiên bản OS tối thiểu chốt ở architecture: iOS 15.0, Android minSdk 24).
NFR-13: Có giao diện sáng và tối (lựa chọn và mặc định theo FR-47); phong cách theo ảnh tham chiếu với một màu nhấn teal-green.
NFR-14: Mọi chuỗi giao diện có đủ bản English và Tiếng Việt.

**Tiêu chí thành công (kiểm chứng được, trượt một tiêu chí là thất bại)**

TC-1: Lấy file dữ liệu của app ra khỏi máy (backup hoặc root/jailbreak) thì không đọc được nội dung nào: tiêu đề, tên đăng nhập, mật khẩu, Note, Recent, bản nháp. Ngoại lệ chấp nhận: ảnh thu nhỏ đa nhiệm (NFR-10).
TC-2: File export không mở được bằng cách nào khác ngoài import vào app với đúng mật khẩu export.
TC-3: Luồng đếm sai, chờ 30 phút và xóa ở lần thứ 10 chạy đúng theo FR-4–FR-6, kể cả khi tắt app, khởi động lại máy hoặc chỉnh đồng hồ.
TC-4: App không có bất kỳ kết nối mạng nào (cách kiểm tra theo NFR-7).
TC-5: Export rồi import sang máy khác khôi phục được 100% card.
TC-6: Không có lần mất dữ liệu nào do lỗi của app (hỏng file, import nhầm, xóa nhầm).

### Additional Requirements

**⚠️ Khởi tạo dự án (ảnh hưởng Epic 1 Story 1):** Architecture **không** dùng starter template bên thứ ba. Dự án là greenfield Flutter: tạo bằng `flutter create`, rồi dựng theo **Structural Seed** của Architecture Spine (`lib/core`, `lib/services`, `lib/platform`, `lib/features`, `lib/l10n`, `pigeons/`, `assets/`, `tool/`, `test/`, `docs/`, `.github/workflows/`), ghim đúng phiên bản trong bảng Stack, kèm lint, `tool/check_imports.dart` và khung CI. Đây là story đầu tiên của Epic 1.

**Nền tảng, stack và cấu trúc**

- Một codebase Flutter 3.47.8 stable (Dart 3.13) cho cả iOS và Android; Android minSdk 24, compileSdk/targetSdk 36; iOS tối thiểu 15.0 (AD-1, Stack).
- Dependency chỉ được lấy từ bảng Stack: `cupertino_ui` 1.1.4, `cupertino_icons` 2.0.0, `sodium` 4.1.2 (libsodium 1.0.22, `SodiumSumoInit`), `flutter_riverpod` 3.4.3 (viết tay, không codegen), `pigeon` 29.0.11 (dev), `zxcvbnm` 1.1.1, `path_provider` 2.1.6, `share_plus` 13.3.1, `file_selector` 1.1.0, `flutter_localizations`/gen-l10n, `flutter_test`. Thêm dependency = cập nhật spine kèm ghi chú đã rà soát network code (AD-12).
- Kiến trúc functional core / imperative shell, phụ thuộc một chiều features → services → core; platform chỉ được gọi qua interface port trong `core/ports`. `lib/core` là Dart thuần (không `package:flutter`, không plugin; chỉ `lib/core/io/` được import `dart:io`). `lib/features` chỉ import `core/model`, `core/policy`, `core/search` (AD-2).
- Widget lấy từ `package:cupertino_ui`; cấm `package:flutter/cupertino.dart`, `package:flutter/material.dart`, `material_ui` trong `lib/`. Icon chỉ dùng `CupertinoIcons` trên cả hai nền tảng; glyph thiếu thì vẽ bằng `CustomPainter` trong `features/shared/icons/`. Font hệ thống. Điện thoại khóa dọc; tablet mọi hướng trong `ContentColumn` (căn giữa, tối đa 672 pt). `textScaler` kẹp tối đa 1,3 ở gốc app; bố cục dùng safe-area inset (AD-1).
- CI chạy `tool/check_imports.dart` (script Dart, không dependency) và fail khi vi phạm luật import của AD-1/AD-2.
- Quy ước: file `snake_case.dart`, class `PascalCase`, provider `xxxProvider`; thư mục feature `auth` (S1–S6), `cards` (S7–S13), `generator` (S14–S17), `settings` (S18–S20), `transfer` (S21–S27), `shared`.
- Phạm vi trạng thái: **app** (settings, guard); **phiên** (dữ liệu giải mã, từ khóa tìm kiếm, mật khẩu generator đang hiện, form card — hủy khi khóa); **lượt vào tab** (mật khẩu card đang hiện, Note đang mở rộng — reset khi đổi tab); **route** (trạng thái riêng sheet/dialog).
- Lỗi: core và services trả kiểu kết quả sealed (vd `UnlockResult`: `success`, `wrongPassword`, `lockedOut`, `corrupt`), không ném exception qua ranh giới lớp; UI ánh xạ kết quả sang key microcopy.

**Crypto, khóa và vault**

- Khóa hai tầng: DEK 32 byte ngẫu nhiên sinh một lần khi tạo tài khoản; KEK = Argon2id(mật khẩu, salt). `checksum` = BLAKE2b-256 không khóa trên mọi byte trước nó; `kcv` = BLAKE2b 16 byte, khóa = KEK, thông điệp `PAK-KCV-v1` (AD-4).
- Thứ tự mở khóa: (1) đọc header — sai kích thước/magic/version, checksum lệch hoặc tham số ngoài khoảng → `corrupt`, không chạm guard, không chạy KDF; (2) `LockoutGuard` ghi trước rồi chạy KDF; (3) so `kcv` hằng thời gian, lệch → `wrongPassword`; (4) khớp → `recordSuccess()` trước mọi bước sau; mở bọc DEK/giải mã lỗi → `corrupt` (AD-4).
- Đổi mật khẩu chính tính lại salt, tham số, `wrapNonce`, `wrappedDek`, `kcv`, `checksum` trong một lần ghi `header`, không mã hóa lại vault. Kiểm tra lại mật khẩu ở FR-13/FR-51 dùng bước 1, 3, 4, bỏ guard (AD-4).
- Argon2id13 qua `pwhash.callRaw`, p=1 cố định. Vault: hiệu chỉnh trên máy lúc tạo tài khoản và đổi mật khẩu chính, khởi điểm m=64 MiB t=3, mục tiêu ~1 giây, trần 2 giây, sàn m=19 MiB t=2. Export: cố định m=64 MiB, t=3. Tham số ngoài [m 19–128 MiB, t 2–10] bị từ chối trước khi chạy KDF. KDF luôn chạy ngoài UI isolate (`Sodium.runIsolated`) (AD-5).
- `vault/` gồm `header`, `cards`, `recent`, `draft`; mỗi file dữ liệu là JSON mã hóa XChaCha20-Poly1305 bằng DEK, nonce ngẫu nhiên mỗi lần ghi, AD = `PAK-VAULT/<loại>/v<N>`. Mở khóa thì giải mã toàn bộ vào RAM; tìm kiếm trong RAM, không chỉ mục trên đĩa. Có `header` mà thiếu `cards`/`recent` → `corrupt`; thiếu `draft` = không có bản nháp (AD-6).
- `VaultSession`: một instance mới cho mỗi lần mở khóa, chủ duy nhất của DEK (`SecureKey`) và mọi dữ liệu giải mã; mọi thay đổi dữ liệu là method của nó; mọi I/O đi qua một hàng đợi tuần tự; sau `lock()` instance vô hiệu vĩnh viễn. Bản nháp: features gọi `updateDraft(d)`, debounce ≤ 500 ms nằm trong `VaultSession`; `lock()` flush bản nháp trước khi hủy khóa; widget không ghi bản nháp trong `dispose()` (AD-3).
- `AccountService` là lối vào duy nhất cho `bootstrap()` (WipeCoordinator.resumeIfNeeded → LockoutGuard.normalize → dọn `*.tmp` và `pak/tmp/`), `create(password)`, `unlock(password)` (trả `VaultSession` mới), `verify(password)` (không chạm guard). Đổi mật khẩu chính là `VaultSession.changeMainPassword(old, new)` (AD-26).
- Vòng đời bản rõ: bản rõ chỉ nằm trong `VaultSession` hoặc provider/State thuộc cây UI của phiên; service sống lâu hơn phiên chỉ giữ digest BLAKE2b 16 byte với khóa ngẫu nhiên 32 byte chỉ trong RAM; `Uint8List` chứa bản rõ được ghi đè 0 ngay sau dùng; model chứa bí mật override `toString()` (AD-22).
- Ngẫu nhiên chỉ từ `randombytes` của libsodium qua `RandomSource`; cấm `dart:math Random`. Generator dùng rejection sampling, bảo đảm mỗi loại có ít nhất một ký tự, rồi xáo Fisher–Yates; độ mạnh FR-34 tính trong core (AD-16).

**Lưu trữ, định dạng và độ bền**

- Mọi file app nằm dưới `ApplicationSupport/pak/` (`vault/`, `guard`, `settings`, `tmp/`). Ngoài vault chỉ ghi `guard`, `settings`, `pak/tmp/` (AD-11, AD-13).
- Ghi nguyên tử qua `core/io/AtomicFileWriter`: ghi `<tên>.tmp` cùng thư mục → fsync file → rename đè → `fsyncDirectory`; không bao giờ tạo thư mục cha; khởi động xóa mọi `*.tmp` sót. Mỗi thao tác nghiệp vụ commit đúng một file; bước dọn dẹp idempotent (AD-7).
- Tạo tài khoản: dọn `vault/` → tạo thư mục → ghi `cards`, `recent` rỗng → ghi `header` cuối cùng (điểm commit). Lưu card: upsert theo `draft.cardId` vào `cards`, rồi xóa `draft`. Lúc mở khóa bỏ bản nháp không hỏi nếu `mode=create` mà `cardId` đã có, hoặc `mode=edit` mà `cardId` không còn (AD-7).
- Schema v1 là hợp đồng, mỗi file một codec trong `lib/core/format/` (`header_codec`, `vault_file_codec`, `export_codec`, `settings_codec`, `guard_codec`); không nơi nào khác `jsonEncode`/`jsonDecode` hay ghép byte cho các file này. Số nguyên little-endian, thời gian UTC epoch ms, id UUIDv4 chữ thường, mọi key bắt buộc, JSON UTF-8. Thiếu key/sai kiểu/`v` lạ → `corrupt` (trừ settings, guard). Layout byte và JSON của `header`, `cards`, `recent`, `draft`, export, payload export, `settings`, `guard` theo bảng AD-20. Golden test cho `header`, `settings`, `guard` (AD-20).
- Định dạng file export (`PAKX`) là hợp đồng vĩnh viễn: một codec duy nhất `core/format/export/`. Thứ tự import: file > 8 MiB / sai magic/version / tham số ngoài khoảng → "File không hợp lệ" → KDF → AEAD lỗi = sai mật khẩu export → payload đúng schema, ≤ 10 000 card, title/username/password không rỗng, mỗi chuỗi ≤ 64 KiB, `createdAt` ≥ 0 (một card sai từ chối cả file) → `VaultSession.stageImport()` → xác nhận = một lần ghi `cards`, cấp id mới, giữ `createdAt`. Phiên bản đã phát hành không bao giờ bị sửa; mỗi phiên bản có fixture `test/fixtures/export/v<N>.pakx` sinh từ bảng AD-20 bằng script trong `tool/` (AD-10).
- Vault có phiên bản và migration: giữ reader cho mọi phiên bản đã phát hành; migration chạy ngay sau mở khóa, ghi từng file qua `AtomicFileWriter`, `header` cuối, idempotent; vault mới hơn app → `corrupt`; fixture `test/fixtures/vault/v<N>/` (AD-25).
- `SettingsStore` là chủ duy nhất của `settings`: một bản trong RAM làm nguồn sự thật, ghi snapshot qua hàng đợi tuần tự, gom thay đổi 300 ms; trường thiếu/sai dùng mặc định riêng; file không đọc được dùng toàn bộ mặc định, không chặn Login; nạp trước frame đầu tiên (AD-13).
- `pak/tmp/` chỉ chứa một file export đã mã hóa chờ chia sẻ; xóa khi share sheet đóng, khi khởi động và khi xóa dữ liệu. File do trình chọn file copy vào cache bị xóa ngay sau khi đọc (AD-13).

**Chống dò, phiên và xóa dữ liệu**

- `LockoutGuard` là chủ duy nhất của file `guard` (không mã hóa, rủi ro chấp nhận). Trước KDF, một lần ghi `failCount += 1`, nếu 5–9 thì đặt mốc chờ `(bootId, monotonicMs)`; ghi lỗi → hủy lần thử. Mật khẩu đúng → ghi `failCount = 0`, xóa mốc. Chuẩn hóa khi khởi động: `wiping` hoặc `failCount ≥ 10` → WipeCoordinator; 5–9 không mốc → mốc = bây giờ; `bootId` khác hoặc monotonic < mốc → mốc = bây giờ. Có header mà guard thiếu/hỏng → tạo lại `failCount = 0`. Chuỗi sai lần trước giữ trong RAM dạng digest có khóa; trùng → báo sai, không đếm, không KDF. Hằng số 10 / từ lần 5 / 30 phút nằm trong code (AD-8).
- `SessionController` là nguồn duy nhất quyết định khóa: mọi hạn thời gian (phiên, autolock, clipboard, chờ guard) đo bằng `ClockPort.monotonicMs` (tính cả lúc máy ngủ); `Timer` chỉ để đánh thức. "Vào nền" = lần đầu nhận `hidden` (hoặc `paused`) sau `resumed`. Khi `resumed`: `ClipboardService.onResume()` rồi `SessionController.evaluate()`. Trình tự khóa: flush bản nháp → chờ ghi xong/hoàn tác → hủy thao tác chưa ghi → `VaultSession.lock()` → xóa clipboard nếu khóa tiền cảnh → tăng epoch phiên và thay cây UI. Mọi `await` trên port platform so epoch sau khi trả về. Đổi cài đặt thời gian có hiệu lực từ lần đếm kế tiếp. OS kill = khóa; không state restoration (AD-9).
- `WipeCoordinator` là chủ duy nhất của quy trình xóa, các bước idempotent: `markWiping()` → vô hiệu `VaultSession` → xóa `vault/header` trước, rồi file khác, rồi thư mục → xóa `pak/tmp/` → `SettingsStore.clearLastExport()` → `ClipboardService.clearIfOurs()` → `LockoutGuard.reset()`. Bootstrap gọi `resumeIfNeeded()` trước khi quyết định S1/S3; không có header nhưng `vault/` còn file → dọn trước khi hiện S1 (AD-21).
- `PasswordPolicy` (`core/policy`) là nơi duy nhất kiểm tra mật khẩu chính/export: ASCII in được, 15–128, blocklist, lặp/tuần tự; thứ tự lỗi: không ASCII → độ dài → phổ biến → lặp/tuần tự. S3 và S25 chặn nút khi không ASCII hoặc < 15 ký tự (chuỗi đó không bao giờ tới guard). Độ mạnh FR-2 dùng `zxcvbnm`: 0–2 Low, 3 Medium, 4 High (AD-15).
- Blocklist: nguồn SecLists (ghim commit trong `tool/blocklist/SOURCE`), chỉ giữ chuỗi ASCII in được dài 15–128, chữ thường; đóng gói Bloom filter ≤ 2 MB, dương tính giả ≤ 0,1% ở `assets/blocklist.bloom`; đặc tả ở `assets/blocklist.FORMAT.md`; script tạo trong `tool/blocklist/` (AD-15).

**Native, clipboard và ô nhập bí mật**

- Một API Pigeon duy nhất (`pigeons/platform_api.dart`, `@HostApi` đồng bộ) với đúng bốn nhóm: đồng hồ (`bootId` — Android `Settings.Global.BOOT_COUNT`, iOS `kern.bootsessionuuid`; `monotonicMs` — Android `elapsedRealtime`, iOS `mach_continuous_time`), clipboard, đặt cờ loại khỏi backup, `fsyncDirectory`. iOS đăng ký trong `FlutterImplicitEngineDelegate` (UIScene). Không ghi gì vào Keychain/Keystore. Share sheet và chọn file dùng `share_plus`/`file_selector` sau port (AD-11).
- Loại khỏi backup: iOS đặt `isExcludedFromBackup` trên thư mục `pak/` ở mỗi lần khởi động trước mọi I/O; Android `allowBackup=false`, `dataExtractionRules` loại mọi domain cho `cloud-backup` và `device-transfer`, `fullBackupContent` tương ứng (AD-11).
- `ClipboardService` là lối duy nhất ghi clipboard (cấm `Clipboard.setData` nơi khác); không giữ bản rõ, chỉ digest + nhãn nonce + hạn theo `ClockPort`. iOS: hạn tự hết + `localOnly`, kiểm tra bằng `changeCount`. Android: nhãn `ClipDescription` = nonce, API 33+ gắn `EXTRA_IS_SENSITIVE`, kiểm tra bằng `getPrimaryClipDescription()` (không đọc nội dung), xóa bằng `clearPrimaryClip` (API ≥ 28) hoặc clip rỗng (24–27). Ở tiền cảnh, timer đánh thức việc xóa. Copy ở S14 còn gọi `VaultSession.recordRecent` (AD-17).
- `SecretField` dùng cho mọi ô nhập mật khẩu (chính, export, card): không autofill hints, `autocorrect=false`, `enableSuggestions=false`, `enableIMEPersonalizedLearning=false`, không menu Copy/Cut (vẫn Dán), `controller.clear()` trong `dispose()`; ô mật khẩu chính/export giữ nguyên ký tự không ASCII và báo lỗi qua `PasswordPolicy`. `SecretText` cho mọi chỗ hiển thị mật khẩu/Note: không chọn, không kéo thả. Không dùng `CupertinoTextField` trực tiếp cho bí mật (AD-14).

**Điều hướng khung UI**

- `CupertinoApp.builder` chứa `SessionGate`: hiển thị S1–S5 khi chưa mở khóa, hoặc cây UI sau đăng nhập bọc `KeyedSubtree` key = epoch phiên. Khóa = thay cả cây; cấm push S3 lên UI cũ (AD-23).
- Cây sau đăng nhập dùng `CupertinoTabScaffold` với navigator riêng mỗi tab; mọi sheet/dialog/panel/popup mở qua `ModalPresenter` trên navigator gốc của cây; toast host nằm trong `Overlay` trên mọi route, mỗi lúc một toast, bị xóa khi khóa. Locale và theme đọc từ `SettingsStore` phía trên `CupertinoApp` (AD-23).

**Không mạng, bảo mật repo, build và phát hành**

- Cấm `HttpClient`/`Socket` của `dart:io`, `package:http`, SDK analytics/crash reporting/quảng cáo. Lint khai báo trực tiếp trong `analysis_options.yaml`; test dùng `flutter_test` và fake tự viết, không thư viện mock (AD-12).
- Repo public: khóa ký Android, chứng chỉ iOS, API key chỉ trong GitHub Secrets, chỉ có trên workflow của `main`/tag. Fixture và test chỉ dùng dữ liệu giả. Không log mật khẩu, nội dung card, Recent, bản nháp hay khóa. Codec bắt mọi exception và trả `corrupt` không kèm thông điệp. Release: `debugPrint` không làm gì; `FlutterError.onError` và `PlatformDispatcher.instance.onError` nuốt lỗi. Lint cấm `print(` trong `lib/` (AD-18).
- GitHub Actions là môi trường build duy nhất cho release và Android (không hỗ trợ build Android local trên Windows). App ID `io.github.truongthanhnam.pakmanager`; flavor `dev` thêm hậu tố `.dev`. Semver; build number = số lần chạy CI. Mỗi PR: phân tích tĩnh + `check_imports`; kiểm code Pigeon sinh ra đã cập nhật; unit + widget test và import mọi file mẫu; build release Android, kiểm không có `INTERNET` và mọi `.so` căn 16 KB; build iOS `--no-codesign` trên macOS. Phát hành: iOS upload TestFlight bằng App Store Connect API key; Android CI build AAB đã ký, upload Play Console thủ công (AD-19).
- Chiến lược test ba tầng: (1) unit cho mọi thứ trong `lib/core/` với fake clock/port — bắt buộc máy trạng thái guard (kể cả crash ở từng bước), codec + golden fixture, generator, policy, chuẩn hóa tìm kiếm; (2) widget — cờ của `SecretField`, lock xóa cây UI, `ModalPresenter` (giới hạn tầng sheet, chính sách Back); (3) nghiệm thu trên máy thật theo `docs/acceptance-checklist.md` trước mỗi lần phát hành: TC-1, TC-3, TC-4 (bắt gói tin iOS), TC-5 (iOS ↔ Android), NFR-2 (máy mốc iPhone 6s/SE đời 1 iOS 15, Android 7 RAM 2 GB), NFR-9 (bàn phím mặc định, Gboard, Laban Key), clipboard và `bootId`. Tên test gắn FR (vd `fr05_same_wrong_string_not_counted`) (AD-24).

**Phát hành và store (PRD §6)**

- Tên app "PAK Manager"; phát hành App Store và Google Play; miễn phí hoàn toàn, không mua trong app, không quảng cáo.
- App Privacy (iOS) và Data Safety (Android) khai báo "Không thu thập dữ liệu".
- Chính sách quyền riêng tư EN/VI trên GitHub Pages của repo, nêu rõ: chạy offline, không thu thập dữ liệu, không có cơ chế khôi phục mật khẩu.
- Khai báo export compliance với Apple (mã hóa tiêu chuẩn); kiểm tra tên trống trên store; thử nghiệm kín Google Play cho tài khoản cá nhân mới (các mục hoãn, thuộc chủ sản phẩm, trước khi nộp store).
- Mô tả trên store cảnh báo rõ: quên mật khẩu chính là mất toàn bộ dữ liệu, nên export định kỳ.

### UX Design Requirements

**Design tokens và nền tảng thị giác**

UX-DR1: Định nghĩa toàn bộ color token của `DESIGN.md` một lần trong `features/shared/theme/`, có cặp light/dark cho **mọi** token (surface-base/grouped/raised/sheet/sheet-grouped/sheet-cell/muted/toolbar, fill-search, ink-primary/secondary/value/section/disabled/tab-inactive, accent/accent-disabled/accent-tint/on-accent/on-accent-disabled, slider-fill, thumb, track, separator/separator-strong, border, scrim, pw-letter/pw-digit/pw-symbol, toast-bg/toast-ink). Màu resolve theo `CupertinoTheme.brightnessOf`.
UX-DR2: Luật màu toàn app: không có token đỏ/destructive và không màu trạng thái; độ mạnh, lỗi, cảnh báo, số lần thử, đếm ngược chỉ bằng chữ `ink-secondary`/`ink-primary`; hành động phá hủy dùng `accent` như mọi nút; `pw-digit`/`pw-symbol` chỉ dùng cho ký tự mật khẩu; `slider-fill` chỉ dùng cho slider.
UX-DR3: Thang chữ 11 token (large-title 34/700, nav-title 17/600, body 17/400, body-emphasis 17/600, callout 16, subhead 15, subhead-emphasis 15/600, footnote 13, tab-label 10/500, password-display 24/600, password-inline 17/400) dùng font hệ thống; mật khẩu dùng sans thường, **không** monospace; Title Case cho nhãn EN, VIẾT HOA chỉ cho header nhóm.
UX-DR4: Token spacing (lưới 4pt + các khoảng đo từ ảnh: margin 16, cell-inset 16, section-gap 35, row-height 44, button-height 48, chip-height 50, fab 56, hold-button 72, recent-row 72, content-max-tablet 672, và các khoảng riêng của S14/S11/S16/S18) và token bo góc (sm 6, md 10, alert 14, lg 20, full).
UX-DR5: Elevation phẳng: phân tầng bằng tông nền, hairline `separator`, viền 1px `border`; không bóng card/nút/popup-menu. Ngoại lệ có bóng: núm slider/công tắc, sheet/wheel-picker/alert trên scrim, FAB (y 2, blur 8, đen 20%). Dark mode phân tầng bằng tông nền.
UX-DR6: Bộ icon: `CupertinoIcons` trên cả hai nền tảng; glyph thiếu (tab chìa khóa / đũa phép có tia sáng / núm xoay có vành răng; icon lịch sử đồng hồ mũi tên ngược chiều, nửa trái nét chấm) vẽ bằng `CustomPainter` trong `features/shared/icons/`. Kích thước 22pt trong card/hàng, 24pt trên nav-bar, 26pt trên tab bar và FAB.

**Component dùng chung (`features/shared/`, mỗi component một bản)**

UX-DR7: `ContentColumn`: căn giữa, rộng tối đa 672, nền phủ toàn màn; mọi màn hình nằm trong nó.
UX-DR8: `ModalPresenter`: giới hạn 2 tầng sheet (alert-dialog không tính tầng); tablet hiển thị sheet dạng form sheet căn giữa; mỗi kiểu trình bày khai báo chính sách Back/vuốt: đóng được / hỏi khi có thay đổi (S12) / chặn khi đang chạy KDF hoặc ghi / chặn hẳn (S5). Android Back dùng `PopScope`: S6 đóng và giữ bản nháp; S13, S17, S26 = Hủy; S27 = OK; S4 = hủy giữ.
UX-DR9: Toast: viên thuốc `rounded.full`, nền `toast-bg`, chữ subhead-emphasis, đệm 8×16, căn giữa ngang, đáy cách đỉnh tab bar 16 (hoặc home indicator khi không có tab bar); một toast mỗi lúc, toast mới thay toast cũ, hiện ~1,5 giây rồi mờ dần, không bấm được, không chặn thao tác, hiện được trên sheet, bị xóa khi khóa.
UX-DR10: `button-primary`: nút đầy cao 48, `rounded.sm`, nền accent, chữ body-emphasis; lề Copy 30, Use Password 40, còn lại 16. Trạng thái vô hiệu (`accent-disabled` + `on-accent-disabled`) và bận (activity-indicator màu on-accent thay chữ, chặn bấm lặp).
UX-DR11: `button-text`: chữ accent, body (riêng "Xóa hết" và "Lưu" dùng body-emphasis); trạng thái vô hiệu `ink-disabled`.
UX-DR12: `icon-button` (22pt, vùng chạm 44, màu accent; ⋯ màu ink-secondary; icon ẩn/hiện thể hiện hành động kế tiếp: đang ẩn → mắt, đang hiện → mắt gạch chéo) và `icon-button-circle` (vòng 36, nền surface-sheet, viền 1px border, icon refresh accent).
UX-DR13: `alert-dialog` dáng iOS: rộng 270, `rounded.alert`, modal, không đóng khi bấm ra ngoài; tiêu đề body-emphasis, thân footnote (có thể không thân); hai nút ngang, nút an toàn ở trái đậm, nút hành động ở phải thường (riêng S6: "Tiếp tục" phải đậm); luôn có lối thoát không phá hủy.
UX-DR14: `hold-confirm-button` (S4): nút tròn 72 không nền, icon thùng rác accent, vòng tiến trình dày 4 (nền track, phần đã giữ accent, chiều kim đồng hồ từ 12 giờ), nhãn `erase.hold` bên dưới. Giữ → vòng chạy đều 3 giây; nhả sớm → vòng chạy ngược về 0, không làm gì; tap nhanh không làm gì; đủ 3 giây → đóng dialog sang S5.
UX-DR15: `popup-menu` dáng iOS UIMenu phẳng (viền 1px border, `rounded.md`, rộng ~200–220, hàng 44, chỉ chữ, ✓ ở đầu hàng mục đang chọn); mở ngay dưới nút/hàng được bấm, căn mép phải, không scrim; chọn → áp dụng ngay và đóng; bấm ra ngoài → đóng không đổi gì.
UX-DR16: `bottom-sheet` (S11): nền surface-sheet, góc trên `rounded.lg`, grabber ~31×4, scrim; đóng bằng vuốt xuống/bấm scrim giữ nguyên field Mật khẩu; nhịp dọc theo token sheet-*.
UX-DR17: `page-sheet` (S9, S10, S16, S21–S22, S25): mép trên cách đỉnh 54, góc `rounded.md`; header dạng form cao 56 (nút trái "Hủy"/"Đóng" hoặc chevron back ở bước 2 Export, tiêu đề nav-title giữa, "Lưu" phải cho form card); Recent dùng header 91 và nền surface-muted.
UX-DR18: `wheel-picker` (S15): panel đáy ~302, góc `rounded.lg`, không grabber, thanh trên chỉ có "Xong" bên phải; bánh xe 4–99, 7 giá trị thấy được, dải chọn 32 surface-muted; giá trị chỉ áp dụng khi đóng ("Xong" hoặc vuốt đóng), rồi sinh lại mật khẩu.
UX-DR19: `text-field` dạng form (ô riêng `rounded.md`, cao ≥ 44, nhãn footnote phía trên ô, placeholder ink-disabled, ô mật khẩu có nút ẩn/hiện, Ghi chú nhiều dòng tự giãn) và biến thể `text-field-login` (S1/S2/S3: rộng bằng nút, cao 48, viền 1px border `rounded.sm`, đệm trái 15, không nhãn). Không đổi màu viền khi lỗi. Phím Return chuyển ô kế; ở ô cuối thì gửi nếu nút chính đang bật.
UX-DR20: `strength-meter`: chỉ một dòng chữ `pw.strength` ("Độ mạnh: {mức}") footnote ink-secondary dưới ô mật khẩu (S2 ô đầu, S20 ô mới, S22 ô export); ẩn khi ô trống; cập nhật mỗi lần gõ; chỉ thông tin, không chặn nút.
UX-DR21: `inline-message`: một dòng footnote ink-secondary dưới field, cách 6, thẳng mép chữ trong ô; hiện ngay khi vi phạm, ẩn khi hết; mỗi field một thông báo theo ưu tiên không ASCII → độ dài → phổ biến → lặp/tuần tự → không khớp; "không khớp" chỉ hiện khi ô nhập lại đã đủ độ dài ô đầu; khi có cả strength-meter thì dòng độ mạnh ở trên; ở S3 `login.lockout`/`login.corrupt` nằm trên `login.attempts` (luôn ở cuối).
UX-DR22: `list-row` các biến thể: giá trị + chevron `>` (Password Length, giá trị ink-secondary); giá trị + ⌃⌄ (Cài đặt, giá trị ink-value, khe 12); toggle; chevron `>` (Import, Export kèm dòng phụ footnote); hàng chỉ đọc. S14 dùng list full-width nền surface-base hai nhóm; S18 dùng inset-grouped `rounded.md`. Kèm `section-header` footnote VIẾT HOA ink-section, không bấm được.
UX-DR23: `toggle` UISwitch 51×31 (ON accent, OFF track), ở S14 mép phải cách mép màn 10; `slider` track cao 4, phần đã chọn slider-fill, núm ~27 có bóng, kéo liên tục 4–99 bước 1, giá trị số cập nhật khi kéo, sinh lại mật khẩu khi **thả**, không có +/− hay nhập số.
UX-DR24: `chip-toggle`: 3 chip bằng nhau cao 50, cách 10; cụm vòng 24 + nhãn body-emphasis căn giữa; chọn = nền accent-tint, vòng đặc accent có ✓ trắng; chưa chọn = nền surface-muted, vòng rỗng viền border.
UX-DR25: `password-display` (24/600, căn giữa; ở S14 cụm mật khẩu + refresh căn giữa như một khối, khe 10) và `password-inline` (17/400, căn trái) tô màu từng ký tự theo loại (pw-letter/pw-digit/pw-symbol), xuống dòng theo ký tự, không cắt ellipsis, dựng trên `SecretText` (không chọn, không kéo thả, bấm giữ không mở menu hệ thống).
UX-DR26: `credential-card`: ô surface-raised `rounded.md`, cách nhau 12; hàng tiêu đề cao 48 với ⋯ góc phải; hàng field cao ≥ 56 (nhãn footnote ink-secondary trên, giá trị body dưới, hairline thụt 16). Tên đăng nhập → Copy; Mật khẩu → ẩn/hiện rồi Copy ở mép phải; Ghi chú subhead không icon, ≤ 3 dòng + "…", bấm để mở rộng/thu gọn (Ghi chú ≤ 3 dòng bấm không tác dụng). Mật khẩu ẩn = `••••••••` 8 chấm cố định. Trạng thái hiện/mở rộng không lưu, reset khi rời tab hoặc khóa.
UX-DR27: `search-bar` (cao 36, `rounded.md`, nền fill-search, kính lúp 18pt, nút xóa x khi có chữ) chung dải nền với nav-bar; `fab-new-card` (tròn 56, accent, "+" 26pt, góc dưới phải cách mép 16 và cách tab bar 16, luôn hiển thị kể cả khi tìm kiếm/danh sách trống).
UX-DR28: `recent-row` (cao 72, 2 dòng: thời điểm callout ink-secondary + password-inline, Copy bên phải căn giữa dọc, nền xen kẽ surface-raised/surface-muted, separator full-width) và `bottom-toolbar` (cao 49, nền surface-toolbar, đường trên separator-strong, "Xóa hết" căn giữa, luôn hiển thị, vô hiệu khi trống).
UX-DR29: `nav-bar` (cao 44, tiêu đề inline căn giữa, không viền dưới, không large title; chevron back accent chỉ ở màn push: S20 kèm chữ "Cài đặt", S2 chỉ chevron) và `tab-bar` (3 mục, cao 49 + home indicator, icon 26 + nhãn tab-label, nền surface-toolbar, hairline trên; chọn accent, chưa chọn ink-tab-inactive; bấm tab đang chọn cuộn về đầu; ẩn khi sheet che toàn màn).
UX-DR30: `empty-state` (chỉ chữ body ink-secondary, căn giữa vùng trống, lề ngang 32, ≤ 2 câu, không minh họa, không nút riêng) và `activity-indicator` (spinner iOS ink-secondary, trên nút đầy màu on-accent; hiện khi chạy KDF/ghi và chặn mọi nút chính; không skeleton, không màn chờ khởi động).

**Bố cục từng màn hình**

UX-DR31: Login S1/S3: nền surface-base, không nav-bar; "PAK Manager" large-title căn giữa cách status bar ~120; S3: ô mật khẩu cách tên 48 → các dòng inline-message cách ô 6 → "Đăng nhập" cách khối chữ 24; hàng "Xóa & Tạo tài khoản mới" cao 44 ở đáy màn (đáy cách mép 42), xa nút Đăng nhập. S1: chỉ "Tạo tài khoản" ở đúng chỗ ô mật khẩu của S3. S3 không có placeholder.
UX-DR32: Tạo tài khoản S2 (màn push, tiêu đề "Tạo tài khoản"): `create.warning` cách nav 24 → ô mật khẩu chính (placeholder `create.field.main`) cách 24 → strength-meter/inline-message → ô nhập lại (placeholder `create.field.confirm`) cách 16 → nút cách 24. S5: toàn màn, spinner + một dòng `wiping` căn giữa, khe 14, không nút.
UX-DR33: S7: dải nav-bar + search-bar đệm dưới 8, card đầu cách dải 16; empty-state căn giữa giữa dải tìm kiếm và tab bar. Form trong page-sheet (S9, S10, S21, S22, S25) và màn push S20: ô lề 16, nhãn trên ô thụt 32 (đệm trên 8, từ field thứ hai 16, dưới 6); inline-message/strength-meter/gợi ý/cảnh báo thụt 32, cách ô 6, cách nhau 8; "Tạo mật khẩu" dưới ô Mật khẩu thụt 32 cách 8; button-primary cách khối trên 24; Ghi chú đệm dọc 11.
UX-DR34: S14 giữ nhịp dọc của ảnh (cụm mật khẩu tâm ~124pt, nút Copy ~208–256pt, nhóm tùy chọn bắt đầu cách nút 60); list hai nhóm cách nhau 35: nhóm 1 = Password Length · Uppercase · Lowercase · Digits; nhóm 2 = Special Characters + hàng bộ ký tự đặc biệt chỉ đọc. Nav-bar có icon lịch sử bên phải, không Back.
UX-DR35: S11 từ trên xuống: icon-button-circle góc phải (cách mép 16) → "Password strength: …" body ink-secondary căn giữa → mật khẩu → 55 → card viền 1px (`rounded.sm`, đệm 16) chứa "Password Length:" (có dấu hai chấm) + giá trị → 25 → slider → 33 → hairline thụt theo đệm card → 16 → 3 chip → 16 → "Use Password" → 40 → home indicator. Sheet không có Copy.
UX-DR36: S18 Cài đặt inset-grouped 5 khối theo thứ tự: (1) CHUNG/GENERAL — Tự khóa · Giới hạn phiên · Tự xóa clipboard (giá trị + ⌃⌄ → S19); (2) NGÔN NGỮ & GIAO DIỆN — Ngôn ngữ · Giao diện (→ S19); (3) DỮ LIỆU/DATA — Import · Export (chevron, Export có dòng phụ ngày export, đệm dọc 10); (4) Đổi mật khẩu chính (button-text trong ô riêng); (5) Khóa Vault (button-text trong ô riêng, khóa ngay không hỏi). Header đệm trên 17/24, dưới 6; hai khối không header cách khối trên 35.

**Microcopy, ngôn ngữ và định dạng**

UX-DR37: Toàn bộ chuỗi UI qua `flutter gen-l10n` với `app_vi.arb` và `app_en.arb`; key ARB = key microcopy trong `EXPERIENCE.md` (đổi `.` thành camelCase), gồm đủ các nhóm: điều hướng & nhãn chung, Login & tài khoản, Card/Copy/bản nháp/Recent, Import/Export/Đổi mật khẩu chính. Không hard-code chuỗi trong widget; delegate Cupertino lấy từ `cupertino_ui`.
UX-DR38: Giọng văn: ngắn gọn, trung tính, xưng "bạn"; không dấu chấm than, không emoji, không khen ngợi; cảnh báo nói thẳng hậu quả; từ chối luôn kèm lý do.
UX-DR39: Định dạng thời gian theo giờ máy, 24 giờ: `dd/MM/yyyy HH:mm` (Recent) và `dd/MM/yyyy` (Export), giống nhau ở cả hai ngôn ngữ.
UX-DR40: Đổi Ngôn ngữ / Giao diện có hiệu lực ngay, không cần khởi động lại; cài đặt thời gian áp dụng từ lần đếm kế tiếp.

**Hành vi trạng thái và tương tác**

UX-DR41: Ký tự không ASCII ở ô mật khẩu chính/export (S2, S3, S20, S21, S22, S25): không chặn phím, không tự xóa ký tự (giữ cho bộ gõ Telex/VNI); ngay khi ô chứa ký tự không ASCII thì hiện `pw.nonAscii` và vô hiệu nút chính; xóa ký tự đó thì thông báo ẩn.
UX-DR42: Trạng thái S3: idle (dòng `login.attempts` luôn hiện); đang kiểm tra (spinner trên nút, ô và nút khóa); sai lần 1–4 (`login.wrong`, ô giữ nguyên nội dung); đang chờ 5–9 (ô + nút vô hiệu, `login.lockout` đếm ngược từng giây, "Xóa & Tạo tài khoản mới" vẫn bấm được, hết giờ về idle); lần thứ 10 (không dialog, S5 → S1); dữ liệu hỏng (`login.corrupt`, không giảm số lần).
UX-DR43: Khóa (Tự khóa / hết phiên / Khóa Vault) gỡ toàn bộ sheet và dialog, về S3, không thông báo lý do; khóa khi đang ghi (S20, S22, S26) hoàn tất/hoàn tác với activity-indicator rồi mới về S3; khóa khi chưa ghi (S21, S24, S25) hủy thao tác.
UX-DR44: Bản nháp: tự lưu im lặng, không chỉ báo; sau đăng nhập nếu có bản nháp thì hiện S6 "Tiếp tục bản nháp?" trước danh sách (nền: khung S7 chưa hiện danh sách); "Tiếp tục" mở S9 hoặc S10 đúng loại với dữ liệu nháp (không khôi phục sheet tạo mật khẩu); "Bỏ bản nháp" hủy. Bấm FAB khi đã có bản nháp thì bản nháp cũ bị thay.
UX-DR45: Form card: "Lưu" vô hiệu khi thiếu Tiêu đề/Tên đăng nhập/Mật khẩu (placeholder `card.required` ở 3 ô bắt buộc); vuốt xuống/"Hủy" khi chưa thay đổi → đóng ngay; khi có thay đổi → không đóng, hiện S12 "Bỏ thay đổi?" ("Bỏ thay đổi" hủy bản nháp). Lưu → đóng sheet, không toast. Ô Mật khẩu và Ghi chú dán được nhưng tắt Copy/Cut/kéo thả ra ngoài.
UX-DR46: Tìm kiếm: từ khóa giữ khi chuyển tab / chuyển app, bị xóa khi khóa; không có kết quả → `empty.search` thay danh sách, giữ từ khóa và nút x; chưa có card → `empty.cards`, search-bar và FAB vẫn hiện.
UX-DR47: Copy ở mọi nơi → toast "Đã copy" (không thông báo khi clipboard bị xóa); Recent: mục quá 72 giờ biến mất ngay nếu sheet đang mở (timer cho mục sắp hết hạn), hoặc ở lần mở sau; không vuốt-để-xóa; xác nhận "Xóa hết" → danh sách chuyển sang trạng thái trống.
UX-DR48: Export xong → mở menu chia sẻ OS; khi menu đóng (gửi hay không) → đóng sheet Export, về S18, dòng phụ Export cập nhật. Import xong → đóng sheet, toast "Đã thêm {N} card", ở lại tab Cài đặt. Đổi mật khẩu chính xong → toast `change.done`, quay về S18. Import/Export dùng menu chia sẻ và trình chọn file thật của từng OS (không vẽ lại dáng iOS).

**Responsive và nền tảng**

UX-DR49: Điện thoại chỉ hướng dọc; tablet mọi hướng, một cột căn giữa ≤ 672 cả dọc lẫn ngang, nền phủ toàn màn, tab bar giữ ở đáy, page-sheet/bottom-sheet dạng form sheet căn giữa; không bố cục hai cột / master-detail.
UX-DR50: Android vẽ lại đúng dáng iOS (tab bar đáy, nav-bar inline căn giữa, UISwitch, sheet có grabber, alert iOS, popup-menu, wheel-picker); không Material, không ripple. Nút Back hệ thống đóng tầng trên cùng (dialog → sheet → màn push); form card có thay đổi → S12; ở gốc tab → hành vi mặc định của OS; S5 và lúc đang chạy KDF/ghi → Back bị chặn.
UX-DR51: Chuyển cảnh dùng mặc định iOS (push, sheet); hoạt ảnh riêng duy nhất là vòng hold-confirm và toast mờ dần. Không có: vuốt-để-xóa card, kéo-để-làm-mới, sắp xếp lại card, haptic tùy biến, thông báo đẩy, sinh trắc học. Không đặt sàn accessibility riêng (quyết định chủ sản phẩm) — chỉ dùng mặc định nền tảng.

### FR Coverage Map

FR-1: Epic 1 - Tạo tài khoản, cảnh báo quên mật khẩu chính
FR-2: Epic 1 - Quy tắc mật khẩu chính (PasswordPolicy, blocklist, độ mạnh)
FR-3: Epic 1 - Màn Login khi đã có tài khoản
FR-4: Epic 2 - Giới hạn nhập sai 10 lần / chờ 30 phút / tự xóa
FR-5: Epic 2 - Cách tính lần sai (ghi trước, trùng chuỗi sai)
FR-6: Epic 2 - Bộ đếm bền vững, không phụ thuộc đồng hồ máy
FR-7: Epic 2 - Dữ liệu hỏng không tính là sai mật khẩu
FR-8: Epic 2 - Luật chống dò cố định
FR-9: Epic 2 - "Xóa & Tạo tài khoản mới" giữ 3 giây
FR-10: Epic 1 - Không có cơ chế khôi phục mật khẩu chính
FR-11: Epic 1 - Gỡ app xóa sạch (không Keychain/Keystore, loại khỏi backup)
FR-12: Epic 2 - Xóa toàn bộ dữ liệu, xóa tiếp khi bị gián đoạn (phần clipboard: Epic 3)
FR-13: Epic 5 - Đổi mật khẩu chính
FR-14: Epic 1 - Giới hạn phiên tuyệt đối
FR-15: Epic 1 - Autolock khi chạy nền
FR-16: Epic 1 - Trình tự khóa khi đang ghi / chưa ghi (áp dụng thêm ở Epic 5, Epic 6)
FR-17: Epic 3 - Danh sách card, Copy, ẩn/hiện, Note 3 dòng
FR-18: Epic 3 - Thứ tự theo thời gian tạo
FR-19: Epic 3 - Tìm kiếm theo tiêu đề không phân biệt dấu
FR-20: Epic 3 - Trạng thái chưa có card
FR-21: Epic 3 - Nút tạo card
FR-22: Epic 3 - Field bắt buộc, cho phép trùng tiêu đề
FR-23: Epic 3 - Menu Sửa / Xóa
FR-24: Epic 3 - Form tạo/sửa card, nhập tay/dán (nút "Tạo mật khẩu" + sheet: Epic 4)
FR-25: Epic 3 - Xác nhận xóa card
FR-26: Epic 3 - Bản nháp mã hóa, khôi phục sau khi khóa
FR-27: Epic 4 - Màn hình Tạo mật khẩu
FR-28: Epic 4 - Sheet tạo mật khẩu
FR-29: Epic 4 - Độ dài 4–99
FR-30: Epic 4 - Loại ký tự (công tắc / chip)
FR-31: Epic 4 - Tự tạo lại khi đổi tiêu chí
FR-32: Epic 4 - Mỗi loại ký tự xuất hiện ít nhất một lần
FR-33: Epic 4 - Tô màu theo loại ký tự
FR-34: Epic 4 - Password strength theo entropy
FR-35: Epic 4 - Lưu và dùng chung bộ tiêu chí
FR-36: Epic 4 - Use Password không ghi Recent
FR-37: Epic 4 - Sheet Recent
FR-38: Epic 4 - Ghi Recent khi Copy ở màn Tạo mật khẩu
FR-39: Epic 4 - Không trùng mục Recent
FR-40: Epic 4 - Recent mới nhất ở trên
FR-41: Epic 4 - Mục Recent hết hạn sau 72 giờ
FR-42: Epic 4 - Clear có xác nhận
FR-43: Epic 4 - Recent trống
FR-44: Epic 4 - Recent mã hóa trong vault
FR-45: Epic 1 - Tab bar 3 tab, mặc định Quản lý mật khẩu
FR-46: Epic 5 - Picker 3 cài đặt thời gian (mặc định đã dùng từ Epic 1)
FR-47: Epic 5 - Chọn ngôn ngữ và giao diện (mặc định theo máy đã có từ Epic 1)
FR-48: Epic 5 - Mục Change Main Password trong Cài đặt
FR-49: Epic 1 - Lock Vault / Sign out
FR-50: Epic 6 - Mục Import / Export và ngày export gần nhất
FR-51: Epic 6 - Nhập lại mật khẩu chính trước Export
FR-52: Epic 6 - Mật khẩu export, gợi ý và cảnh báo
FR-53: Epic 6 - Nội dung file export chỉ có card
FR-54: Epic 6 - Mã hóa file export, tham số cố định
FR-55: Epic 6 - Menu chia sẻ của OS
FR-56: Epic 6 - Import chỉ nhận file PAK Manager, sai không giới hạn
FR-57: Epic 6 - Import thêm vào, xem trước và xác nhận
FR-58: Epic 6 - Giữ thời gian tạo gốc khi import
FR-59: Epic 6 - Import nguyên tử
FR-60: Epic 6 - Import không đụng Recent, cài đặt, bản nháp
FR-61: Epic 6 - Tương thích chéo iOS ↔ Android
FR-62: Epic 6 - Tương thích phiên bản cũ
FR-63: Epic 6 - Từ chối tham số mã hóa ngoài giới hạn
FR-64: Epic 3 - Nút Copy, không chọn/kéo thả mật khẩu và Note
FR-65: Epic 3 - Clear Clipboard theo từng nền tảng

**NFR / TC (nơi được hiện thực hóa chính; Epic 7 nghiệm thu trên máy thật):**
NFR-1, NFR-2, NFR-4, NFR-7, NFR-8, NFR-11, NFR-12, NFR-13, NFR-14: Epic 1 (nền), các epic sau tuân theo
NFR-3: Epic 6 · NFR-5: Epic 3 · NFR-6: Epic 4 · NFR-9: Epic 1 (`SecretField`) · NFR-10: rủi ro chấp nhận, không có code
TC-1: Epic 1 · TC-2, TC-5: Epic 6 · TC-3: Epic 2 · TC-4: Epic 1 (CI) · TC-6: Epic 1–6 · Nghiệm thu tầng 3 tất cả TC: Epic 7

## Epic List

### Epic 1: Tạo tài khoản, đăng nhập và khóa vault an toàn
Người dùng cài app, tạo tài khoản với mật khẩu chính đạt chuẩn, đăng nhập vào khung 3 tab và khóa vault. App tự khóa khi chạy nền quá lâu hoặc hết thời hạn phiên. Dữ liệu được mã hóa trên máy, không nằm trong backup của OS và app không có kết nối mạng. Story đầu tiên dựng dự án Flutter theo Structural Seed kèm CI; epic này cũng dựng nền dùng chung (theme token, ARB vi/en, `ContentColumn`, `ModalPresenter`, toast, `SecretField`, `AtomicFileWriter`, codec `header`/`settings`, `VaultSession`, `SessionController`, Pigeon đồng hồ/backup/fsync). Ở epic này, nhập sai chỉ báo "Sai mật khẩu", chưa đếm lần.
**FRs covered:** FR-1, FR-2, FR-3, FR-10, FR-11, FR-14, FR-15, FR-16, FR-45, FR-49

### Epic 2: Chống dò mật khẩu và xóa dữ liệu
Màn Login có đủ cơ chế chống dò: đếm số lần sai, chờ 30 phút không phụ thuộc đồng hồ máy, tự xóa ở lần sai thứ 10; thêm "Xóa & Tạo tài khoản mới" (giữ 3 giây), trạng thái "Dữ liệu bị hỏng", và xóa tiếp khi lần xóa trước bị gián đoạn. Hoàn thành UJ-4 và TC-3. Gồm `LockoutGuard`, `WipeCoordinator`, codec `guard`, `bootId`/`monotonicMs` native, các trạng thái S3, S4, S5 và hold-confirm-button.
**FRs covered:** FR-4, FR-5, FR-6, FR-7, FR-8, FR-9, FR-12

### Epic 3: Lưu và dùng thông tin đăng nhập (card)
Người dùng tạo, sửa, xóa card; tìm theo tiêu đề không phân biệt dấu; copy tên đăng nhập và mật khẩu để dán sang app khác với clipboard tự xóa; bản nháp tự lưu nên không mất dữ liệu khi app bị khóa. Hoàn thành UJ-1. Gồm `ClipboardService` + Pigeon clipboard, và nối bước xóa clipboard vào quy trình xóa dữ liệu (FR-12).
**FRs covered:** FR-17, FR-18, FR-19, FR-20, FR-21, FR-22, FR-23, FR-24 (nhập tay/dán), FR-25, FR-26, FR-64, FR-65

### Epic 4: Tạo mật khẩu mạnh và Recent
Người dùng tạo mật khẩu ở tab Tạo mật khẩu và trong sheet của form card (Use Password); mật khẩu đã copy được giữ trong Recent 72 giờ để lấy lại sau khi đăng ký ở app khác. Hoàn thành UJ-2.
**FRs covered:** FR-24 (nút "Tạo mật khẩu" + sheet), FR-27, FR-28, FR-29, FR-30, FR-31, FR-32, FR-33, FR-34, FR-35, FR-36, FR-37, FR-38, FR-39, FR-40, FR-41, FR-42, FR-43, FR-44

### Epic 5: Tùy chỉnh cài đặt và đổi mật khẩu chính
Người dùng chỉnh 3 cài đặt thời gian, chọn ngôn ngữ và giao diện (có hiệu lực ngay), và đổi mật khẩu chính mà không phải mã hóa lại vault. Epic 1 đã dùng giá trị mặc định và ngôn ngữ máy; epic này thêm picker S19 và màn S20.
**FRs covered:** FR-13, FR-46, FR-47, FR-48

### Epic 6: Sao lưu và chuyển máy (Export / Import)
Người dùng export file đã mã hóa, chia sẻ qua menu của OS, rồi import sang máy khác (kể cả iOS ↔ Android) và lấy lại 100% card. Hoàn thành UJ-3, TC-2 và TC-5. Gồm codec `PAKX` là hợp đồng vĩnh viễn, fixture `v1.pakx` sinh bằng script, và import nguyên tử.
**FRs covered:** FR-50, FR-51, FR-52, FR-53, FR-54, FR-55, FR-56, FR-57, FR-58, FR-59, FR-60, FR-61, FR-62, FR-63

### Epic 7: Sẵn sàng phát hành lên store
App vượt qua bộ nghiệm thu trên máy thật và có mặt trên TestFlight và thử nghiệm kín Google Play, với chính sách quyền riêng tư và mô tả store đúng yêu cầu. Gồm `docs/acceptance-checklist.md` (TC-1–TC-6, NFR-2, NFR-7, NFR-9 ở tầng 3), ký và upload qua CI, privacy policy EN/VI trên GitHub Pages, khai báo App Privacy / Data Safety.
**FRs covered:** không có FR mới — nghiệm thu TC-1–TC-6, NFR-2, NFR-7, NFR-9 và yêu cầu PRD §6

## Epic 1: Tạo tài khoản, đăng nhập và khóa vault an toàn

Người dùng cài app, tạo tài khoản với mật khẩu chính đạt chuẩn, đăng nhập vào khung 3 tab và khóa vault. App tự khóa khi chạy nền quá lâu hoặc hết thời hạn phiên. Dữ liệu được mã hóa trên máy, không nằm trong backup của OS và app không có kết nối mạng.

### Story 1.1: Khởi tạo dự án Flutter theo Structural Seed và cổng CI

As a chủ sản phẩm (người phát triển duy nhất),
I want một dự án Flutter khung với cấu trúc thư mục, dependency ghim phiên bản và cổng CI kiểm tra mọi PR,
So that mọi story sau được xây trên cùng một nền đúng kiến trúc, offline và không lộ bí mật ngay từ đầu.

**Acceptance Criteria:**

**Given** repo hiện chỉ có tài liệu
**When** dự án được tạo bằng `flutter create` và dựng theo Structural Seed
**Then** tồn tại `pak_manager/` với `lib/core/{model,crypto,format,guard,policy,generator,search,ports,io}`, `lib/services/`, `lib/platform/`, `lib/features/{auth,cards,generator,settings,transfer,shared}`, `lib/l10n/`, `pigeons/`, `assets/`, `tool/`, `test/`, `docs/`, `.github/workflows/`
**And** dự án dùng Flutter 3.47.8 stable; Android minSdk 24, compileSdk 36, targetSdk 36; iOS tối thiểu 15.0
**And** app ID là `io.github.truongthanhnam.pakmanager`, flavor `dev` thêm hậu tố `.dev` để build dev không ghi đè vault thật
**And** `pubspec.yaml` (kể cả `dev_dependencies`) chỉ chứa package có trong bảng Stack với đúng phiên bản đã ghim

**Given** dự án khung
**When** chạy `dart run tool/check_imports.dart`
**Then** script fail khi `lib/` import `package:flutter/material.dart`, `package:flutter/cupertino.dart` hoặc `material_ui`
**And** fail khi `lib/features/` import `core/crypto`, `core/format`, `core/io`, `core/ports`, `lib/platform/` hoặc `dart:io`
**And** fail khi `lib/core/` import `package:flutter` hay plugin, hoặc khi file trong `lib/core/` ngoài `lib/core/io/` import `dart:io`
**And** fail khi `lib/` dùng `HttpClient`/`Socket` của `dart:io`, `package:http` hoặc `Random` của `dart:math`
**And** script có test với các file vi phạm mẫu

**Given** `analysis_options.yaml`
**When** chạy phân tích tĩnh
**Then** lint được khai báo trực tiếp trong file (không dùng package lint ngoài) và cấm `print(` trong `lib/`

**Given** một PR được mở
**When** GitHub Actions chạy
**Then** CI chạy phân tích tĩnh, `check_imports`, unit + widget test
**And** CI build release Android và fail nếu manifest đã merge chứa `android.permission.INTERNET` hoặc có file `.so` không căn 16 KB
**And** CI build iOS `--no-codesign` trên runner macOS
**And** workflow của PR không truy cập được secret nào (AD-18)

**Given** một bản build release
**When** app gặp lỗi chưa bắt hoặc gọi `debugPrint`
**Then** `debugPrint` không làm gì, `FlutterError.onError` và `PlatformDispatcher.instance.onError` nuốt lỗi, không in ra

### Story 1.2: Thư mục dữ liệu riêng, ghi nguyên tử và loại khỏi backup

As a người dùng,
I want dữ liệu của app nằm trong một thư mục riêng, được ghi an toàn và không bị đưa vào backup của hệ điều hành,
So that tắt máy đột ngột không làm hỏng dữ liệu và dữ liệu không rời máy qua iCloud hay Google Backup (NFR-8, NFR-11, FR-11).

**Acceptance Criteria:**

**Given** `core/ports` định nghĩa `ClockPort` (`monotonicMs`, `bootId`), `FileSyncPort` (`fsyncDirectory`) và `BackupPort`
**When** platform cài đặt các port này
**Then** native code nằm trong **một** API Pigeon `pigeons/platform_api.dart` (`@HostApi` đồng bộ, kênh mặc định, không bật FFI/JNI thử nghiệm) gồm các nhóm đồng hồ, backup và `fsyncDirectory`
**And** Android trả `bootId` từ `Settings.Global.BOOT_COUNT` và `monotonicMs` từ `elapsedRealtime`; iOS trả `bootId` từ `kern.bootsessionuuid` và `monotonicMs` từ `mach_continuous_time`
**And** iOS đăng ký API trong `FlutterImplicitEngineDelegate` (UIScene)
**And** CI fail nếu code Pigeon sinh ra chưa được cập nhật

**Given** app khởi động
**When** chưa có I/O nào chạy
**Then** mọi file của app nằm dưới `ApplicationSupport/pak/`
**And** trên iOS, cờ `isExcludedFromBackup` được đặt lại trên thư mục `pak/` ở mỗi lần khởi động, trước mọi I/O
**And** trên Android, manifest có `allowBackup=false`, `dataExtractionRules` loại mọi domain cho cả `cloud-backup` và `device-transfer`, và `fullBackupContent` tương ứng
**And** app không ghi gì vào Keychain/Keystore

**Given** `core/io/AtomicFileWriter`
**When** ghi một file
**Then** writer ghi `<tên>.tmp` cùng thư mục với file đích → fsync file → rename đè → `FileSyncPort.fsyncDirectory`
**And** writer không bao giờ tạo thư mục cha; thư mục không tồn tại thì trả lỗi
**And** unit test với fake port chứng minh nếu tiến trình dừng ở bất kỳ bước nào trước rename thì file đích cũ còn nguyên

**Given** thư mục `pak/` còn sót file `*.tmp` từ lần chạy trước
**When** app khởi động
**Then** mọi `*.tmp` bị xóa trước khi đọc dữ liệu

### Story 1.3: Giao diện sáng/tối, hai ngôn ngữ và cài đặt mặc định

As a người dùng,
I want app mở bằng ngôn ngữ của máy và theo giao diện sáng/tối của hệ thống,
So that tôi thấy app quen thuộc ngay từ lần đầu mở (FR-47 mặc định, NFR-13, NFR-14).

**Acceptance Criteria:**

**Given** `core/format/settings_codec`
**When** đọc và ghi file `settings`
**Then** schema đúng bảng AD-20: `{"v":1,"language","appearance","autolockMin","sessionMin","clipboardMin","gen":{"length","upper","lower","digits","special"},"lastExportAt"}`
**And** trường thiếu hoặc sai kiểu dùng mặc định của riêng trường đó; file không đọc được thì dùng toàn bộ mặc định và không bao giờ chặn Login
**And** có golden test cho `settings`

**Given** cài app lần đầu
**When** `SettingsStore` nạp file
**Then** mặc định là `language=null`, `appearance=system`, `autolockMin=3`, `sessionMin=10`, `clipboardMin=3`, `gen` độ dài 16 với mọi loại bật, `lastExportAt=null`
**And** store được nạp trước frame đầu tiên, giữ một bản trong RAM làm nguồn sự thật, ghi snapshot qua hàng đợi tuần tự gom thay đổi 300 ms bằng `AtomicFileWriter`, và là nơi duy nhất đọc/ghi `settings`

**Given** ngôn ngữ máy là tiếng Việt và `language=null`
**When** app khởi động
**Then** giao diện dùng Tiếng Việt; với mọi ngôn ngữ máy khác thì dùng English

**Given** `appearance=system`
**When** hệ thống ở chế độ tối
**Then** app dùng bộ token `*-dark`; khi hệ thống ở chế độ sáng thì dùng token light; kiểu thanh hệ thống theo theme của app

**Given** `features/shared/theme/`
**When** định nghĩa token
**Then** mọi color token trong `DESIGN.md` có đủ cặp light/dark và được resolve theo `CupertinoTheme.brightnessOf` (UX-DR1)
**And** không có token đỏ/destructive hay màu trạng thái (UX-DR2)
**And** đủ 11 token chữ dùng font hệ thống, token spacing và token bo góc (UX-DR3, UX-DR4)
**And** quy ước elevation phẳng (UX-DR5) được ghi trong theme: không bóng cho card, nút và popup-menu; chỉ núm slider/công tắc, sheet, wheel-picker, alert-dialog và FAB có bóng

**Given** mọi chuỗi trong ARB
**When** viết bản VI và EN
**Then** chuỗi theo giọng văn UX-DR38: ngắn gọn, trung tính, xưng "bạn", không dấu chấm than, không emoji, từ chối luôn kèm lý do

**Given** `lib/l10n/app_vi.arb` và `app_en.arb`
**When** chạy `flutter gen-l10n`
**Then** key ARB theo quy ước key microcopy của `EXPERIENCE.md` (đổi `.` thành camelCase), delegate Cupertino lấy từ `cupertino_ui`; widget không hard-code chuỗi (UX-DR37); mỗi story sau thêm key microcopy của màn hình mình vào cả hai file
**And** một test xác nhận hai file ARB có cùng tập key

**Given** app chạy trên điện thoại
**When** người dùng xoay máy
**Then** app giữ hướng dọc; trên tablet app xoay mọi hướng và nội dung nằm trong `ContentColumn` căn giữa rộng tối đa 672 pt, nền phủ toàn màn (UX-DR7, UX-DR49)
**And** `textScaler` bị kẹp tối đa 1,3 ở gốc app; bố cục dùng safe-area inset

### Story 1.4: Mã hóa vault bằng khóa hai tầng và Argon2id

As a người dùng,
I want vault được mã hóa bằng khóa dẫn xuất chậm từ mật khẩu chính,
So that ai chép được file dữ liệu ra ngoài cũng không đọc được nội dung (NFR-1, NFR-2, TC-1).

**Acceptance Criteria:**

**Given** core crypto
**When** khởi tạo libsodium
**Then** dùng `SodiumSumoInit.init()`; mọi DEK, salt, nonce và id lấy từ `randombytes` qua `RandomSource` trong core (AD-16)

**Given** một mật khẩu và salt
**When** dẫn xuất KEK
**Then** dùng Argon2id13 qua `pwhash.callRaw` với p=1, chạy ngoài UI isolate (`Sodium.runIsolated`) và trả về `SecureKey`
**And** hàm hiệu chỉnh vault bắt đầu từ m=64 MiB, t=3, hướng tới ~1 giây, trần 2 giây, sàn m=19 MiB, t=2
**And** tham số ngoài khoảng [m 19–128 MiB, t 2–10] bị từ chối trước khi chạy KDF

**Given** `core/format/header_codec`
**When** ghi và đọc `header`
**Then** layout đúng AD-20: `PAKV`[4] · version u16 · kdfAlg u8 · opslimit u32 · memlimit u64 · salt[16] · wrapNonce[24] · wrappedDek[48] · kcv[16] · checksum[32], little-endian
**And** associated data khi bọc DEK là mọi byte từ magic đến hết salt; `kcv` = BLAKE2b 16 byte, khóa KEK, thông điệp `PAK-KCV-v1`; `checksum` = BLAKE2b-256 không khóa trên mọi byte đứng trước nó
**And** có golden test cho `header`

**Given** `core/format/vault_file_codec`
**When** ghi `cards` hoặc `recent`
**Then** nội dung là JSON v1 theo AD-20, mã hóa XChaCha20-Poly1305 bằng DEK, nonce ngẫu nhiên mỗi lần ghi, associated data `PAK-VAULT/<loại>/v1`
**And** Note rỗng là `""`, id là UUIDv4 chữ thường, thời gian là UTC epoch ms

**Given** dữ liệu đọc vào thiếu key, sai kiểu, `v` lạ, sai magic/version hoặc AEAD lỗi
**When** codec giải mã
**Then** codec trả `corrupt` không kèm thông điệp và không ném exception qua ranh giới lớp

**Given** header hợp lệ và một mật khẩu sai
**When** kiểm tra
**Then** `kcv` lệch (so hằng thời gian) được phân biệt rõ với `checksum` lệch trong unit test

**Given** model chứa bí mật
**When** gọi `toString()`
**Then** giá trị bí mật bị che; mọi `Uint8List` chứa bản rõ được ghi đè 0 ngay sau khi dùng (AD-22)

**Given** fixture `test/fixtures/vault/v1/` được sinh bằng script trong `tool/fixtures/` từ bảng AD-20 với dữ liệu giả
**When** CI chạy test
**Then** codec mở được fixture

### Story 1.5: Luật mật khẩu chính và đánh giá độ mạnh

As a người dùng,
I want app kiểm tra mật khẩu chính theo chuẩn NIST và báo độ mạnh khi tôi gõ,
So that tôi đặt được mật khẩu đủ mạnh để chống dò offline (FR-2).

**Acceptance Criteria:**

**Given** `core/policy/PasswordPolicy` là nơi duy nhất kiểm tra mật khẩu chính/export
**When** kiểm tra một chuỗi
**Then** chỉ ký tự ASCII in được (0x20–0x7E, kể cả khoảng trắng) là hợp lệ; độ dài hợp lệ 15–128
**And** lỗi trả về theo thứ tự ưu tiên: không ASCII → độ dài → phổ biến → lặp/tuần tự (kiểu kết quả sealed)

**Given** chuỗi `aaaaaaaaaaaaaaa` hoặc `123456789012345`
**When** kiểm tra
**Then** policy trả lỗi lặp/tuần tự

**Given** một chuỗi ≥ 15 ký tự chỉ gồm chữ thường và khoảng trắng, không nằm trong blocklist
**When** kiểm tra
**Then** policy chấp nhận (không bắt buộc chữ hoa, chữ số hay ký tự đặc biệt)

**Given** script `tool/blocklist/` với nguồn SecLists ghim commit trong `tool/blocklist/SOURCE`
**When** chạy script
**Then** chỉ giữ chuỗi ASCII in được dài 15–128, chuyển chữ thường, đóng gói thành Bloom filter ≤ 2 MB với dương tính giả ≤ 0,1% ở `assets/blocklist.bloom`
**And** `assets/blocklist.FORMAT.md` mô tả hàm băm và seed
**And** policy so khớp trên bản chữ thường; một mật khẩu có trong danh sách nguồn bị trả lỗi phổ biến

**Given** một chuỗi đang gõ
**When** tính độ mạnh
**Then** dùng `zxcvbnm`: điểm 0–2 = Low, 3 = Medium, 4 = High; cách tính này tách biệt với FR-34
**And** tên test gắn FR (vd `fr02_repeated_char_rejected`)

### Story 1.6: Tạo tài khoản và vào khung 3 tab

As a người dùng mới,
I want tạo tài khoản PAK Manager bằng mật khẩu chính và vào app ngay,
So that tôi bắt đầu dùng app với vault được bảo vệ (FR-1, FR-2, FR-10, FR-45).

**Acceptance Criteria:**

**Given** máy chưa có `vault/header`
**When** mở app
**Then** `AccountService.bootstrap()` trả trạng thái chưa có tài khoản và `SessionGate` hiện S1: "PAK Manager" và nút "Tạo tài khoản", đúng bố cục UX-DR31
**And** không có link "Quên mật khẩu", gợi ý hay câu hỏi bảo mật (FR-10)

**Given** S1
**When** bấm "Tạo tài khoản"
**Then** S2 được push (chỉ chevron back), hiện `create.warning`, ô mật khẩu chính (placeholder `create.field.main`) và ô nhập lại (placeholder `create.field.confirm`) theo bố cục UX-DR32

**Given** người dùng gõ vào ô mật khẩu chính
**When** nội dung thay đổi
**Then** strength-meter hiện "Độ mạnh: {mức}" ngay dưới ô (ẩn khi ô trống) và inline-message hiện lỗi `PasswordPolicy` ưu tiên cao nhất; dòng độ mạnh ở trên, thông báo ở dưới (UX-DR20, UX-DR21)
**And** `pw.mismatch` chỉ hiện khi ô nhập lại đã dài bằng ô đầu
**And** nút "Tạo tài khoản" chỉ bật khi mật khẩu hợp lệ và hai ô khớp

**Given** người dùng gõ chữ có dấu (bộ gõ Telex/VNI)
**When** ký tự không ASCII vào ô
**Then** ký tự được giữ nguyên (không chặn phím, không tự xóa), `pw.nonAscii` hiện và nút chính bị vô hiệu; xóa ký tự đó thì thông báo ẩn (UX-DR41)

**Given** mọi ô mật khẩu dùng `SecretField` trong `features/shared/`
**When** chạy widget test
**Then** ô không có autofill hints, `autocorrect=false`, `enableSuggestions=false`, `enableIMEPersonalizedLearning=false`, không có menu Copy/Cut nhưng vẫn Dán được, và `controller.clear()` được gọi trong `dispose()` (AD-14, NFR-9)

**Given** mật khẩu hợp lệ và khớp
**When** bấm "Tạo tài khoản"
**Then** nút hiện activity-indicator và chặn bấm lặp; `AccountService.create` hiệu chỉnh KDF, sinh DEK, dọn `vault/` → tạo thư mục → ghi `cards` và `recent` rỗng → ghi `header` **cuối cùng**
**And** button-primary và button-text dùng chung trong `features/shared/` có đủ trạng thái thường / vô hiệu / bận theo UX-DR10, UX-DR11; activity-indicator theo UX-DR30

**Given** app bị tắt trước khi `header` được ghi
**When** mở lại app
**Then** app hiện S1 (chưa có tài khoản)

**Given** tạo tài khoản thành công
**When** `AccountService` trả về một `VaultSession` mới
**Then** `SessionGate` thay S1/S2 bằng cây UI sau đăng nhập bọc `KeyedSubtree` theo epoch phiên, gồm `CupertinoTabScaffold` 3 tab "Quản lý mật khẩu", "Tạo mật khẩu", "Cài đặt" với navigator riêng mỗi tab, tab mặc định là Quản lý mật khẩu (FR-45)
**And** tab-bar đúng thị giác UX-DR29, icon chìa khóa / đũa phép / núm xoay vẽ bằng `CustomPainter` trong `features/shared/icons/` (UX-DR6)
**And** chuyển cảnh dùng mặc định iOS trên cả Android, không Material, không ripple (UX-DR50, UX-DR51)

**Given** đang ở một ô của S2
**When** bấm phím Return
**Then** con trỏ chuyển sang ô kế; ở ô cuối thì gửi nếu nút chính đang bật

### Story 1.7: Đăng nhập bằng mật khẩu chính

As a người dùng đã có tài khoản,
I want đăng nhập bằng mật khẩu chính,
So that tôi mở được vault đã mã hóa của mình (FR-3).

**Acceptance Criteria:**

**Given** máy đã có `vault/header`
**When** mở app
**Then** `SessionGate` hiện S3: "PAK Manager", ô mật khẩu chính không placeholder, nút "Đăng nhập", đúng bố cục UX-DR31

**Given** S3
**When** ô có ít hơn 15 ký tự hoặc chứa ký tự không ASCII
**Then** nút "Đăng nhập" bị vô hiệu (với ký tự không ASCII thì hiện `pw.nonAscii`), và chuỗi đó không bao giờ được gửi đi kiểm tra

**Given** mật khẩu đúng
**When** bấm "Đăng nhập"
**Then** nút hiện activity-indicator, ô và nút bị khóa, bấm lặp không tạo lần kiểm tra thứ hai
**And** `AccountService.unlock` đọc header → chạy KDF ngoài UI isolate → so `kcv` → mở bọc DEK → giải mã `cards` và `recent` vào RAM trong một `VaultSession` mới
**And** app chuyển sang tab Quản lý mật khẩu

**Given** mật khẩu sai
**When** bấm "Đăng nhập"
**Then** S3 hiện inline-message `login.wrong` ("Sai mật khẩu."), ô giữ nguyên nội dung để sửa

**Given** header hỏng hoặc mật khẩu đúng nhưng giải mã dữ liệu lỗi
**When** bấm "Đăng nhập"
**Then** `unlock` trả `corrupt` và S3 hiện `login.corrupt`; app không xóa gì

**Given** mọi kết quả của `unlock`
**When** service trả về UI
**Then** kết quả là kiểu sealed `UnlockResult` (`success`, `wrongPassword`, `corrupt`), UI ánh xạ sang key microcopy, không có exception vượt ranh giới lớp

### Story 1.8: Khóa Vault và xóa dữ liệu giải mã khỏi bộ nhớ

As a người dùng,
I want khóa vault ngay bằng một thao tác,
So that không ai xem được dữ liệu của tôi khi tôi đưa máy cho người khác (FR-49, NFR-4).

**Acceptance Criteria:**

**Given** người dùng đã đăng nhập
**When** mở tab Cài đặt
**Then** có khối "Khóa Vault" là button-text trong ô riêng, đúng thị giác UX-DR36 (các khối khác thêm ở epic sau)

**Given** tab Cài đặt
**When** bấm "Khóa Vault"
**Then** app khóa ngay, không hỏi xác nhận, và về S3; app không có nút Sign out riêng

**Given** `SessionController` là nơi duy nhất gọi `lock()`
**When** khóa
**Then** trình tự là: flush bản nháp → chờ thao tác ghi đang chạy xong hoặc hoàn tác → hủy thao tác chưa ghi → `VaultSession.lock()` → xóa clipboard nếu khóa ở tiền cảnh → tăng epoch phiên; các bước chưa có tính năng tương ứng là hook rỗng

**Given** `VaultSession.lock()` đã chạy
**When** gọi bất kỳ method nào của instance đó
**Then** method trả `locked` và không làm I/O; `SecureKey` đã bị hủy và model giải mã đã bị bỏ

**Given** epoch phiên tăng
**When** `SessionGate` dựng lại
**Then** toàn bộ cây UI sau đăng nhập bị thay bằng S3 (không push S3 lên trên UI cũ), mọi sheet và dialog bị gỡ, không có thông báo lý do khóa (UX-DR43)
**And** widget test xác nhận sau khi khóa cây UI không còn `SecretField`/`SecretText` và không còn provider nào thuộc phiên (AD-22)

**Given** một `await` trên port platform trả về sau khi epoch đã đổi
**When** xử lý kết quả
**Then** kết quả bị bỏ

### Story 1.9: Tự khóa khi chạy nền và giới hạn phiên

As a người dùng,
I want app tự khóa khi tôi để app chạy nền quá lâu hoặc khi phiên đã kéo dài quá giới hạn,
So that vault không mở mãi khi tôi quên khóa, mà vẫn không làm phiền lúc tôi chuyển qua lại để copy-dán (FR-14, FR-15, FR-16).

**Acceptance Criteria:**

**Given** người dùng vừa đăng nhập với mặc định Tự khóa 3 phút, Giới hạn phiên 10 phút
**When** `SessionController` đo thời gian
**Then** mọi hạn đo bằng `ClockPort.monotonicMs` (tính cả lúc máy ngủ); `Stopwatch` và `DateTime.now()` không bao giờ là nguồn sự thật; `Timer` chỉ dùng để đánh thức lần kiểm tra

**Given** app đang mở
**When** app nhận `AppLifecycleState.hidden` lần đầu sau `resumed` (hoặc `paused` nếu nền tảng không có `hidden`)
**Then** đó là mốc vào nền; `inactive` không được tính

**Given** app đã ở nền
**When** người dùng quay lại trong thời hạn Tự khóa
**Then** app ở đúng màn hình và trạng thái đã rời, không bắt đăng nhập lại

**Given** app đã ở nền lâu hơn thời hạn Tự khóa
**When** app `resumed`
**Then** `SessionController.evaluate()` khóa app (tính là khóa ở tiền cảnh) và hiện S3

**Given** người dùng đang thao tác
**When** đủ thời hạn Giới hạn phiên tính từ lúc đăng nhập thành công
**Then** app khóa ngay, không cảnh báo trước; điều kiện nào (FR-14 hay FR-15) đến trước thì khóa theo điều kiện đó

**Given** đến lúc khóa mà một thao tác ghi đang chạy
**When** `SessionController` khóa
**Then** app khóa ngay sau khi thao tác ghi hoàn tất hoặc được hoàn tác (unit test với thao tác ghi giả chậm)

**Given** giá trị thời gian trong `SettingsStore` thay đổi
**When** đang đếm
**Then** lần đếm hiện tại giữ giá trị cũ, giá trị mới có hiệu lực từ lần đếm kế tiếp

**Given** OS kill process khi app ở nền
**When** mở lại app
**Then** app ở S3 (không dùng state restoration)
**And** unit test dùng fake clock cho mọi trường hợp trên

## Epic 2: Chống dò mật khẩu và xóa dữ liệu

Màn Login có đủ cơ chế chống dò: đếm số lần sai, chờ 30 phút không phụ thuộc đồng hồ máy, tự xóa ở lần sai thứ 10; thêm "Xóa & Tạo tài khoản mới" (giữ 3 giây), trạng thái "Dữ liệu bị hỏng" không bao giờ dẫn tới xóa, và xóa tiếp khi lần xóa trước bị gián đoạn. Hoàn thành UJ-4 và TC-3.

### Story 2.1: Đếm lần nhập sai bền vững

As a người dùng,
I want app đếm số lần nhập sai mật khẩu chính một cách bền vững và cho tôi biết còn bao nhiêu lần thử,
So that kẻ dùng script dò mật khẩu trên màn Login bị chặn, còn tôi biết rõ mình đang ở đâu (FR-4 lần 1–4, FR-5, FR-8).

**Acceptance Criteria:**

**Given** `core/format/guard_codec`
**When** đọc và ghi file `guard`
**Then** schema đúng AD-20: `{"v":1,"failCount":0–10,"waitBootId":str|null,"waitStartMono":int|null,"wiping":bool}`, ghi qua `AtomicFileWriter`, có golden test
**And** chỉ `LockoutGuard` đọc/ghi `guard`; máy trạng thái thuần nằm trong `core/guard`

**Given** người dùng bấm "Đăng nhập" với một chuỗi hợp lệ về hình thức
**When** `AccountService.unlock` chạy
**Then** `LockoutGuard` ghi `failCount += 1` xuống đĩa **trước** khi chạy KDF; nếu lần ghi lỗi thì hủy lần thử và không chạy KDF
**And** nếu mật khẩu đúng, một lần ghi đặt `failCount = 0` và xóa mốc chờ trước mọi bước sau

**Given** app bị tắt sau khi bộ đếm đã tăng nhưng trước khi kiểm tra xong
**When** mở lại app
**Then** lần đó được tính là sai (unit test mô phỏng crash ở từng bước của máy trạng thái)

**Given** người dùng vừa nhập sai chuỗi X
**When** nhập lại đúng chuỗi X
**Then** app báo sai ngay, không tăng bộ đếm, không chạy KDF, không bắt đầu thời gian chờ mới
**And** chuỗi sai trước đó chỉ giữ trong RAM dưới dạng digest BLAKE2b 16 byte với khóa ngẫu nhiên 32 byte sinh khi mở process (AD-22)

**Given** một lần kiểm tra đang chạy
**When** người dùng bấm "Đăng nhập" liên tiếp
**Then** không có lần kiểm tra thứ hai được tạo

**Given** S3 ở trạng thái idle
**When** hiển thị
**Then** dòng `login.attempts` ("Còn {N} lần thử trước khi dữ liệu bị xóa.") luôn hiện dưới ô và nằm cuối khối thông báo; sau mỗi lần sai 1–4, `login.wrong` hiện và {N} giảm, người dùng nhập lại được ngay (UX-DR42)

**Given** máy có `header` nhưng `guard` thiếu hoặc không đọc được
**When** app khởi động
**Then** `guard` được tạo lại với `failCount = 0`

**Given** code của `LockoutGuard`
**When** rà soát
**Then** ba hằng số 10 lần, từ lần thứ 5 và 30 phút nằm trong code, không có cài đặt nào đổi được (FR-8)
**And** tên test gắn FR (vd `fr05_same_wrong_string_not_counted`)

### Story 2.2: Thời gian chờ 30 phút không phụ thuộc đồng hồ máy

As a người dùng,
I want sau lần sai thứ 5 trở đi app bắt chờ 30 phút và hiện đồng hồ đếm ngược,
So that việc dò mật khẩu bị làm chậm hẳn và không ai né được bằng cách tắt app, khởi động lại máy hay chỉnh giờ (FR-4 lần 5–9, FR-6, TC-3).

**Acceptance Criteria:**

**Given** `failCount` mới nằm trong 5–9
**When** `LockoutGuard` ghi lần tăng bộ đếm trước KDF
**Then** cùng lần ghi đó đặt mốc chờ bằng `(bootId, monotonicMs)` hiện tại

**Given** đang trong thời gian chờ
**When** S3 hiển thị
**Then** ô mật khẩu và nút "Đăng nhập" bị vô hiệu, icon trong ô màu `ink-disabled`, dòng `login.lockout` ("Thử lại sau {mm:ss}") đếm ngược từng giây nằm trên dòng `login.attempts`
**And** khi hết 30 phút, S3 về trạng thái idle

**Given** đang trong thời gian chờ
**When** người dùng tắt app rồi mở lại
**Then** thời gian chờ còn lại được giữ nguyên

**Given** đang trong thời gian chờ
**When** người dùng chỉnh đồng hồ máy tới trước
**Then** thời gian chờ không bị rút ngắn, vì mọi phép đo dùng `ClockPort.monotonicMs`

**Given** app khởi động
**When** `LockoutGuard.normalize()` chạy
**Then** nếu `failCount` 5–9 mà không có mốc chờ thì mốc = bây giờ
**And** nếu `waitBootId` khác `bootId` hiện tại (máy đã khởi động lại) hoặc `monotonicMs` nhỏ hơn mốc thì mốc = bây giờ, tức thời gian chờ tính lại từ 30:00 và không bao giờ bị rút ngắn
**And** mỗi lần đặt lại được ghi xuống đĩa trước khi hiển thị S3

**Given** máy trạng thái guard
**When** chạy unit test với fake clock và fake `bootId`
**Then** các trường hợp tắt app, khởi động lại và chỉnh đồng hồ đều cho đúng kết quả

### Story 2.3: Tự xóa dữ liệu ở lần sai thứ 10

As a người dùng,
I want app tự xóa toàn bộ dữ liệu khi có người nhập sai đến lần thứ 10,
So that kẻ dò mật khẩu trên màn Login không bao giờ mở được vault, và việc xóa luôn hoàn tất kể cả khi bị gián đoạn (FR-4 lần 10, FR-12, UJ-4).

**Acceptance Criteria:**

**Given** `services/wipe_coordinator.dart` là chủ duy nhất của quy trình xóa
**When** xóa chạy
**Then** các bước theo thứ tự, mỗi bước idempotent: `LockoutGuard.markWiping()` → vô hiệu `VaultSession` hiện hành nếu có → xóa `vault/header` **trước**, rồi các file còn lại, rồi thư mục → xóa `pak/tmp/` → `SettingsStore.clearLastExport()` → bước xóa clipboard (hook, nối ở Epic 3) → `LockoutGuard.reset()`

**Given** người dùng nhập sai lần thứ 10
**When** kiểm tra xong
**Then** app không hiện dialog, chuyển ngay sang S5 (activity-indicator + dòng `wiping` căn giữa, không nút, Back bị chặn — UX-DR32) rồi sang S1 khi xóa xong

**Given** quá trình xóa bị gián đoạn (tắt app, hết pin)
**When** mở lại app
**Then** `AccountService.bootstrap()` gọi `WipeCoordinator.resumeIfNeeded()` trước khi quyết định hiện S1 hay S3; nếu `wiping = true` hoặc `failCount ≥ 10` thì hiện S5, xóa nốt rồi mới hiện S1

**Given** khởi động mà không có `header` nhưng `vault/` còn file khác
**When** bootstrap chạy
**Then** các file đó bị dọn trước khi hiện S1

**Given** xóa đã hoàn tất
**When** người dùng tạo tài khoản mới
**Then** không còn card, Recent, bản nháp, bộ đếm hay ngày export cũ nào

**Given** `WipeCoordinator`
**When** chạy unit test mô phỏng crash sau từng bước
**Then** lần chạy lại luôn đưa máy về trạng thái chưa có tài khoản, không sót file cũ cạnh tài khoản mới

### Story 2.4: Xóa & Tạo tài khoản mới khi quên mật khẩu chính

As a người dùng quên mật khẩu chính,
I want xóa vault cũ bằng một thao tác cố ý ngay trên màn Login,
So that tôi tạo lại được tài khoản và import file export để lấy lại card (FR-9, UJ-4 nhánh A).

**Acceptance Criteria:**

**Given** S3 ở bất kỳ trạng thái nào (idle, sai, đang chờ đếm ngược, dữ liệu bị hỏng)
**When** hiển thị
**Then** button-text "Xóa & Tạo tài khoản mới" nằm ở đáy màn, cao 44, xa nút "Đăng nhập", luôn bấm được (UX-DR31, UX-DR42)

**Given** S3
**When** bấm "Xóa & Tạo tài khoản mới"
**Then** S4 mở: alert-dialog dáng iOS (UX-DR13) với tiêu đề `erase.title`, thân `erase.body`, hold-confirm-button và nhãn `erase.hold`, hàng nút chỉ có "Hủy"
**And** không yêu cầu nhập mật khẩu

**Given** S4
**When** nhấn giữ hold-confirm-button
**Then** vòng tiến trình chạy đều theo chiều kim đồng hồ từ 12 giờ trong 3 giây (UX-DR14)
**And** nhả tay trước 3 giây thì vòng chạy ngược về 0 và không có gì xảy ra; tap nhanh không làm gì

**Given** giữ đủ 3 giây
**When** vòng đầy
**Then** dialog đóng, app sang S5 và chạy `WipeCoordinator`, xong thì về S1

**Given** S4 đang mở
**When** bấm "Hủy", hoặc bấm nút Back trên Android (kể cả lúc đang giữ)
**Then** dialog đóng hoặc lần giữ bị hủy, không xóa gì; bấm ra ngoài dialog không đóng dialog

### Story 2.5: "Dữ liệu bị hỏng" không bao giờ dẫn tới xóa

As a người dùng,
I want app phân biệt rõ mật khẩu sai với dữ liệu bị hỏng,
So that một file vault hỏng không bao giờ bị tính là nhập sai rồi kích hoạt tự xóa (FR-7, TC-6).

**Acceptance Criteria:**

**Given** `header` sai kích thước, sai magic/version, `checksum` lệch hoặc tham số KDF ngoài khoảng
**When** người dùng bấm "Đăng nhập"
**Then** `unlock` trả `corrupt` mà không chạm `LockoutGuard` và không chạy KDF; bộ đếm giữ nguyên

**Given** mật khẩu đúng (`kcv` khớp) nhưng mở bọc DEK hoặc giải mã `cards`/`recent` lỗi, hoặc có `header` mà thiếu `cards`/`recent`
**When** người dùng đăng nhập
**Then** `LockoutGuard.recordSuccess()` (failCount = 0) đã chạy trước bước giải mã, và kết quả là `corrupt`

**Given** vault có phiên bản mới hơn phiên bản app hỗ trợ
**When** đăng nhập
**Then** kết quả là `corrupt`, không đếm, không xóa (AD-25)

**Given** kết quả `corrupt`
**When** S3 hiển thị
**Then** inline-message `login.corrupt` nằm trên dòng `login.attempts`, số lần thử không giảm, app không tự xóa gì; người dùng tự chọn "Xóa & Tạo tài khoản mới" nếu muốn

**Given** các tình huống trên
**When** chạy unit test
**Then** có test riêng cho từng nguồn hỏng (header, DEK, `cards`, `recent`, phiên bản mới) xác nhận bộ đếm không tăng và `WipeCoordinator` không bao giờ được gọi

## Epic 3: Lưu và dùng thông tin đăng nhập (card)

Người dùng tạo, sửa, xóa card; tìm theo tiêu đề không phân biệt dấu; copy tên đăng nhập và mật khẩu để dán sang app khác với clipboard tự xóa; bản nháp tự lưu nên không mất dữ liệu khi app bị khóa. Hoàn thành UJ-1.

### Story 3.1: Tạo card mới và xem danh sách card

As a người dùng,
I want tạo một card với Tiêu đề, Tên đăng nhập, Mật khẩu và Ghi chú rồi thấy nó trong danh sách,
So that thông tin đăng nhập của tôi được lưu an toàn trong vault (FR-17 hiển thị cơ bản, FR-18, FR-20, FR-21, FR-22, FR-24 nhập tay).

**Acceptance Criteria:**

**Given** vault chưa có card nào
**When** mở tab Quản lý mật khẩu
**Then** nav-bar có tiêu đề `tab.cards`, vùng nội dung hiện empty-state `empty.cards` căn giữa (UX-DR30, UX-DR33), và fab-new-card tròn teal ở góc dưới phải (UX-DR27)

**Given** `ModalPresenter` trong `features/shared/` là lối duy nhất mở sheet/dialog trên navigator gốc của cây sau đăng nhập
**When** chạy widget test
**Then** presenter giới hạn tối đa 2 tầng sheet (alert-dialog không tính), hiển thị sheet dạng form sheet căn giữa trên tablet, và áp chính sách Back/vuốt khai báo theo từng kiểu trình bày (UX-DR8)

**Given** tab Quản lý mật khẩu
**When** bấm fab-new-card
**Then** S9 "Card mới" mở dạng page-sheet (UX-DR17) với 4 ô: Tiêu đề, Tên đăng nhập, Mật khẩu (`SecretField` có nút ẩn/hiện), Ghi chú (nhiều dòng, tự giãn); 3 ô bắt buộc có placeholder `card.required`, nhãn nằm trên ô (UX-DR19, UX-DR33)
**And** ô Mật khẩu và Ghi chú dán được nhưng không có Copy/Cut và không kéo thả ra ngoài

**Given** S9 thiếu Tiêu đề, Tên đăng nhập hoặc Mật khẩu
**When** hiển thị
**Then** nút "Lưu" bị vô hiệu (màu `ink-disabled`); Ghi chú không bắt buộc; tiêu đề trùng với card khác vẫn được phép

**Given** S9 đủ 3 field bắt buộc
**When** bấm "Lưu"
**Then** `VaultSession` upsert card (id UUIDv4 cấp khi mở form, `createdAt` = lúc lưu) vào `cards` bằng một lần ghi nguyên tử, sheet đóng, không có toast
**And** card mới nằm trên cùng danh sách

**Given** S9 chưa có thay đổi nào
**When** bấm "Hủy" hoặc vuốt xuống
**Then** sheet đóng ngay

**Given** S9 đã có thay đổi
**When** bấm "Hủy", vuốt xuống hoặc bấm Back trên Android
**Then** sheet không đóng; S12 hiện alert-dialog `discard.title` với "Tiếp tục sửa" (trái, đậm) và "Bỏ thay đổi" (phải) (UX-DR13, UX-DR45); "Bỏ thay đổi" đóng sheet không lưu

**Given** danh sách có nhiều card
**When** hiển thị
**Then** card xếp theo `createdAt` giảm dần, hòa thì theo id; mỗi credential-card hiện tiêu đề (với nút ⋯ ở góc phải), Tên đăng nhập, Mật khẩu ở dạng `••••••••` (8 chấm cố định) và Ghi chú tối đa 3 dòng + "…"; hàng Ghi chú ẩn khi Note rỗng (UX-DR26)
**And** fab-new-card luôn hiển thị, nổi trên danh sách cuộn

### Story 3.2: Ẩn/hiện mật khẩu và đọc Ghi chú trên card

As a người dùng,
I want xem mật khẩu của một card khi cần và đọc toàn bộ Ghi chú dài,
So that tôi kiểm tra được thông tin mà mật khẩu vẫn ẩn theo mặc định và không bị bôi chọn ra ngoài (FR-17, FR-64 phần hiển thị).

**Acceptance Criteria:**

**Given** `SecretText` trong `features/shared/`
**When** dùng để hiển thị mật khẩu hoặc Ghi chú
**Then** văn bản không chọn được, không kéo thả được, bấm giữ không mở menu hệ thống (AD-14)

**Given** component password-inline / password-display dùng chung (UX-DR25)
**When** hiển thị một mật khẩu rõ
**Then** mỗi ký tự được tô theo loại: chữ cái `pw-letter`, chữ số `pw-digit`, ký tự đặc biệt `pw-symbol`, có bản dark tương ứng; mật khẩu dài xuống dòng theo ký tự, không cắt ellipsis; font sans thường, không monospace

**Given** mật khẩu trên một card đang ẩn
**When** bấm icon mắt
**Then** chỉ mật khẩu của card đó hiện ra ở dạng password-inline có tô màu, và icon đổi thành mắt gạch chéo (icon luôn thể hiện hành động kế tiếp — UX-DR12)

**Given** Ghi chú dài hơn 3 dòng
**When** bấm vào đoạn Ghi chú
**Then** toàn bộ Ghi chú mở rộng ngay trên card; bấm lần nữa thu về 3 dòng; Ghi chú ≤ 3 dòng thì bấm không có tác dụng

**Given** có card đang hiện mật khẩu hoặc mở rộng Ghi chú
**When** người dùng chuyển sang tab khác rồi quay lại, hoặc app bị khóa
**Then** mọi mật khẩu trở về ẩn và Ghi chú trở về thu gọn (trạng thái "lượt vào tab", không được lưu)

### Story 3.3: Copy tên đăng nhập và mật khẩu với clipboard tự xóa

As a người dùng,
I want copy tên đăng nhập và mật khẩu từ card để dán sang app khác, và clipboard tự xóa sau một thời gian,
So that tôi đăng nhập Facebook mà không phải nhìn thấy mật khẩu, và mật khẩu không nằm mãi trong clipboard (FR-64, FR-65, FR-12 phần clipboard, UJ-1).

**Acceptance Criteria:**

**Given** `services/clipboard_service.dart` là lối duy nhất ghi clipboard
**When** rà soát code
**Then** không có lời gọi `Clipboard.setData` ở nơi khác; service không giữ bản rõ, chỉ giữ digest có khóa, nhãn nonce của lần copy và hạn tính bằng `ClockPort` (AD-17, AD-22)

**Given** API Pigeon có thêm nhóm clipboard
**When** copy trên iOS
**Then** nội dung được ghi với `expirationDate` bằng thời gian Tự xóa clipboard (mặc định 3 phút) và `localOnly` (không Universal Clipboard); app kiểm tra bằng `changeCount`

**When** copy trên Android
**Then** nhãn `ClipDescription` là nonce; từ API 33 gắn `EXTRA_IS_SENSITIVE`; app kiểm tra bằng `getPrimaryClipDescription()` mà không đọc nội dung clip; xóa bằng `clearPrimaryClip` (API ≥ 28) hoặc clip rỗng (API 24–27)

**Given** một credential-card
**When** bấm Copy ở hàng Tên đăng nhập hoặc hàng Mật khẩu (kể cả khi mật khẩu đang ẩn)
**Then** giá trị được ghi vào clipboard qua `ClipboardService.copy` và toast "Đã copy" hiện (UX-DR47)

**Given** toast host nằm trong `Overlay` phía trên mọi route
**When** có toast mới trong lúc toast cũ còn hiện
**Then** toast mới thay toast cũ; toast hiện ~1,5 giây rồi mờ dần, không bấm được, không chặn thao tác, hiện được trên sheet, và bị xóa khi khóa (UX-DR9)

**Given** app ở tiền cảnh
**When** tới hạn Tự xóa clipboard
**Then** một timer đánh thức việc xóa, và clipboard chỉ bị xóa nếu vẫn còn đúng giá trị app đã copy; không có thông báo nào khi xóa

**Given** người dùng đã copy rồi chuyển app
**When** quay lại app sau khi đã quá hạn
**Then** `ClipboardService.onResume()` chạy trước `SessionController.evaluate()` và xóa clipboard nếu còn đúng giá trị app đã copy; nếu người dùng đã copy thứ khác thì giữ nguyên

**Given** app bị khóa khi đang ở tiền cảnh (Khóa Vault, hết phiên)
**When** `SessionController` chạy trình tự khóa
**Then** bước xóa clipboard gọi `ClipboardService.clearIfOurs()`

**Given** `WipeCoordinator` chạy
**When** tới bước xóa clipboard
**Then** hook gọi `ClipboardService.clearIfOurs()` (hoàn tất phần clipboard của FR-12)

### Story 3.4: Tìm card theo tiêu đề

As a người dùng,
I want gõ một phần tiêu đề, không cần dấu, để lọc ngay danh sách card,
So that tôi tìm thấy card "Facebook" hay "Ngân hàng" trong vài giây (FR-19, UJ-1).

**Acceptance Criteria:**

**Given** `core/search/normalize`
**When** chuẩn hóa một chuỗi
**Then** chuỗi được chuyển chữ thường, bỏ dấu tiếng Việt, `đ` → `d`; unit test có các ca "ngan hang" khớp "Ngân hàng", "d" khớp "đ", "GMAIL" khớp "Tài khoản Gmail"

**Given** tab Quản lý mật khẩu
**When** hiển thị
**Then** search-bar `search.placeholder` nằm dưới nav-bar, chung dải nền, đúng thị giác UX-DR27

**Given** người dùng gõ vào search-bar
**When** mỗi ký tự thay đổi
**Then** danh sách chỉ còn các card có tiêu đề đã chuẩn hóa chứa từ khóa đã chuẩn hóa, kể cả các card trùng tiêu đề, giữ thứ tự FR-18
**And** tìm kiếm chạy trong RAM trên dữ liệu của `VaultSession`, không có chỉ mục trên đĩa (NFR-5); không tìm theo Note hay tên đăng nhập

**Given** không card nào khớp
**When** hiển thị
**Then** empty-state `empty.search` thay danh sách, search-bar giữ từ khóa và có nút xóa (x), fab-new-card vẫn hiện (UX-DR46)

**Given** đang có từ khóa
**When** người dùng chuyển tab hoặc chuyển sang app khác rồi quay lại trong hạn
**Then** từ khóa và kết quả lọc được giữ nguyên

**Given** đang có từ khóa
**When** app bị khóa
**Then** từ khóa bị xóa cùng trạng thái phiên

### Story 3.5: Sửa và xóa card

As a người dùng,
I want sửa hoặc xóa một card qua menu trên card,
So that thông tin đăng nhập của tôi luôn đúng và gọn (FR-18 sửa không đổi vị trí, FR-23, FR-24 sửa, FR-25).

**Acceptance Criteria:**

**Given** một credential-card
**When** bấm nút ⋯
**Then** S8 popup-menu dáng iOS phẳng mở ngay dưới nút, căn mép phải với card, không scrim, gồm "Sửa" và "Xóa" cùng màu chữ (UX-DR15)
**And** bấm ra ngoài thì menu đóng, không đổi gì

**Given** S8
**When** chọn "Sửa"
**Then** S10 "Sửa card" mở dạng page-sheet với 4 field điền sẵn giá trị hiện tại, cùng luật bắt buộc, cùng luật "Bỏ thay đổi?" như S9

**Given** S10 đã sửa và đủ field bắt buộc
**When** bấm "Lưu"
**Then** card được cập nhật bằng một lần ghi `cards`, giữ nguyên id và `createdAt`, nên vị trí trong danh sách không đổi

**Given** S8
**When** chọn "Xóa"
**Then** S13 hiện alert-dialog `card.delete.title` với tên card, thân `card.delete.body`, nút "Hủy" (trái, đậm) và "Xóa" (phải, cùng màu accent — không có màu đỏ)

**Given** S13
**When** bấm "Xóa"
**Then** card bị gỡ khỏi `cards` bằng một lần ghi nguyên tử và biến mất khỏi danh sách

**Given** S13
**When** bấm "Hủy", hoặc bấm Back trên Android
**Then** dialog đóng, card giữ nguyên

### Story 3.6: Bản nháp tự lưu và khôi phục sau khi khóa

As a người dùng,
I want những gì tôi đang gõ trong form card được tự lưu và mở lại sau khi app bị khóa,
So that tôi không mất card đang tạo dở khi phải rời app vài phút để đăng ký tài khoản (FR-26, UJ-2 failure).

**Acceptance Criteria:**

**Given** `vault_file_codec` cho `draft`
**When** ghi bản nháp
**Then** schema đúng AD-20: `{"v":1,"mode":"create"|"edit","cardId","title","username","password","note","updatedAt"}`, mã hóa bằng DEK với associated data `PAK-VAULT/draft/v1`; thiếu file `draft` nghĩa là không có bản nháp

**Given** S9 hoặc S10 đang mở
**When** người dùng thay đổi bất kỳ field nào
**Then** feature gọi `VaultSession.updateDraft(d)`; debounce ≤ 500 ms nằm trong `VaultSession`; bản nháp được lưu im lặng, không chỉ báo; app chỉ giữ tối đa một bản nháp
**And** widget không bao giờ ghi bản nháp trong `dispose()`

**Given** form đang có thay đổi chưa flush
**When** app bị khóa (Tự khóa, hết phiên, Khóa Vault)
**Then** `lock()` flush bản nháp trước khi hủy `SecureKey`, và lần flush này được tính là thao tác ghi đang chạy theo FR-16

**Given** có bản nháp hợp lệ
**When** đăng nhập thành công
**Then** S6 alert-dialog `draft.title` / `draft.body` hiện trước khi danh sách hiển thị (nền là khung S7 chưa có danh sách), nút "Bỏ bản nháp" (trái) và "Tiếp tục" (phải, đậm) (UX-DR44)
**And** "Tiếp tục" mở S9 hoặc S10 đúng loại với dữ liệu nháp (không khôi phục sheet tạo mật khẩu); "Bỏ bản nháp" xóa bản nháp
**And** Back trên Android đóng S6 và giữ bản nháp để hỏi lại ở lần đăng nhập sau

**Given** bản nháp `mode=create` mà `cardId` đã có trong `cards`, hoặc `mode=edit` mà `cardId` không còn trong `cards`
**When** mở khóa
**Then** bản nháp bị bỏ không hỏi (không hiện S6)

**Given** form có bản nháp
**When** bấm "Lưu"
**Then** card được upsert theo `draft.cardId` vào `cards`, sau đó `draft` bị xóa; nếu app chết giữa hai bước, lần mở sau không tạo card trùng

**Given** S12
**When** chọn "Bỏ thay đổi"
**Then** bản nháp bị hủy

**Given** đã có bản nháp
**When** người dùng bấm fab-new-card mở form mới
**Then** bản nháp cũ bị thay bằng bản nháp của form mới

## Epic 4: Tạo mật khẩu mạnh và Recent

Người dùng tạo mật khẩu ở tab Tạo mật khẩu và trong sheet của form card (Use Password); mật khẩu đã copy được giữ trong Recent 72 giờ để lấy lại sau khi đăng ký ở app khác. Hoàn thành UJ-2.

### Story 4.1: Bộ sinh mật khẩu an toàn và bộ tiêu chí dùng chung

As a người dùng,
I want mật khẩu được sinh ngẫu nhiên thật sự theo tiêu chí tôi chọn, và app nhớ tiêu chí đó,
So that mật khẩu tôi dùng cho app khác vừa mạnh vừa đúng ý mà không phải chỉnh lại mỗi lần (FR-29, FR-30, FR-32, FR-34, FR-35, NFR-6).

**Acceptance Criteria:**

**Given** `core/generator`
**When** sinh một mật khẩu với độ dài L (4–99) và tập loại ký tự đang bật
**Then** mọi ký tự lấy từ `RandomSource` (libsodium `randombytes`) bằng rejection sampling, không dùng phép modulo thiên lệch và không dùng `dart:math Random`
**And** mỗi loại đang bật xuất hiện ít nhất một lần, rồi chuỗi được xáo Fisher–Yates bằng cùng nguồn ngẫu nhiên (FR-32)
**And** bộ ký tự đặc biệt đúng `~!@#$%^&*+-/.,\{}[]();:?<>"'_`

**Given** mọi loại ký tự đều tắt
**When** sinh mật khẩu
**Then** mật khẩu chỉ gồm chữ thường (FR-30)

**Given** độ dài và tập loại ký tự
**When** tính độ mạnh FR-34
**Then** entropy = độ dài × log₂(tổng số ký tự thuộc các loại đang bật); < 50 bit = Low, 50 đến < 80 = Medium, ≥ 80 = High; tính trong core
**And** unit test có ca biên 50 bit và 80 bit

**Given** `GeneratorService`
**When** người dùng đổi tiêu chí
**Then** tiêu chí được lưu vào trường `gen` của `settings` qua `SettingsStore` và còn nguyên sau khi tắt app
**And** lần đầu dùng app, mọi loại bật và độ dài 16

**Given** bộ tiêu chí dùng chung cho màn hình và sheet
**When** ánh xạ
**Then** chip 123 ↔ `digits`, chip ABC ↔ `upper`, chip !@# ↔ `special`; `lower` chỉ được màn hình đọc/ghi, sheet không bao giờ đọc/ghi `lower` (FR-35, AD-20)

### Story 4.2: Màn hình Tạo mật khẩu

As a người dùng đang đăng ký tài khoản mới,
I want một tab để tạo mật khẩu mạnh, chỉnh độ dài và loại ký tự rồi copy,
So that tôi dán được mật khẩu không ai đoán nổi vào app khác (FR-27, FR-29, FR-30, FR-31, FR-33, UJ-2).

**Acceptance Criteria:**

**Given** người dùng mở tab Tạo mật khẩu
**When** S14 hiển thị
**Then** nav-bar có tiêu đề `generator.title`, icon lịch sử ở bên phải (vẽ bằng `CustomPainter` — UX-DR6), **không** có nút Back
**And** mật khẩu đã được sinh sẵn theo tiêu chí đã lưu, hiển thị bằng password-display tô màu, cùng icon refresh như một cụm căn giữa; không có nhãn Password strength
**And** bố cục giữ nhịp dọc của ảnh và list hai nhóm: nhóm 1 = Password Length · Uppercase · Lowercase · Digits; nhóm 2 = Special Characters + hàng bộ ký tự đặc biệt chỉ đọc (UX-DR34, UX-DR22, UX-DR23)

**Given** S14
**When** bấm icon refresh
**Then** một mật khẩu mới được sinh theo tiêu chí hiện tại

**Given** S14
**When** bật/tắt bất kỳ công tắc nào
**Then** mật khẩu được sinh lại ngay và tiêu chí được lưu; tắt cả 4 công tắc vẫn được phép (mật khẩu chỉ chữ thường)

**Given** S14
**When** bấm hàng "Độ dài mật khẩu" (giá trị màu `ink-secondary` + chevron)
**Then** S15 wheel-picker mở trong panel đáy với giá trị hiện tại, bánh xe 4–99, thanh trên chỉ có "Xong" (UX-DR18)
**And** cuộn bánh xe không đổi giá trị ở S14; bấm "Xong" hoặc vuốt đóng thì áp dụng giá trị, sinh lại mật khẩu và lưu tiêu chí

**Given** S14
**When** bấm nút Copy (button-primary, lề 30)
**Then** mật khẩu được copy qua `ClipboardService` và toast "Đã copy" hiện

**Given** mật khẩu đang hiện ở S14
**When** app bị khóa
**Then** mật khẩu đó bị bỏ cùng trạng thái phiên (AD-22); lần đăng nhập sau sinh mật khẩu mới

**Given** bấm tab Tạo mật khẩu khi đang ở tab đó
**When** nội dung đang cuộn
**Then** màn cuộn về đầu

### Story 4.3: Sheet tạo mật khẩu trong form card

As a người dùng đang tạo hoặc sửa card,
I want mở một sheet tạo mật khẩu ngay trong form và bấm "Use Password" để điền vào card,
So that tôi đặt được mật khẩu mạnh cho card mà không phải rời form (FR-24 nút "Tạo mật khẩu", FR-28, FR-30, FR-31, FR-34, FR-36).

**Acceptance Criteria:**

**Given** S9 hoặc S10
**When** hiển thị
**Then** button-text `card.generate` nằm dưới ô Mật khẩu, thụt 32, cách ô 8 (UX-DR33)

**Given** S9 hoặc S10
**When** bấm "Tạo mật khẩu"
**Then** S11 mở dạng bottom-sheet (UX-DR16) chồng lên form (tầng sheet thứ hai qua `ModalPresenter`), gồm grabber, icon-button-circle refresh, nhãn `sheet.strength` theo FR-34, password-display tô màu, card viền chứa "Password Length:" + giá trị, slider, hairline, 3 chip 123 / ABC / !@#, và nút `sheet.use` — đúng nhịp dọc UX-DR35
**And** sheet không có nút Copy và không mở thêm được sheet thứ ba

**Given** S11
**When** kéo slider
**Then** giá trị số cập nhật liên tục (4–99, bước 1); mật khẩu chỉ được sinh lại khi **thả** tay (UX-DR23)

**Given** S11
**When** bật/tắt chip
**Then** chip đổi giữa trạng thái chọn (nền `accent-tint`, vòng đặc có ✓) và chưa chọn (nền `surface-muted`, vòng rỗng) (UX-DR24), mật khẩu sinh lại ngay, chữ thường luôn có; bỏ chọn cả 3 chip thì mật khẩu chỉ gồm chữ thường

**Given** S11
**When** bấm icon-button-circle refresh
**Then** mật khẩu mới được sinh theo tiêu chí hiện tại

**Given** S11
**When** bấm "Use Password"
**Then** mật khẩu được điền vào field Mật khẩu của form, thay giá trị đang có, sheet đóng, và Recent **không** có mục mới (FR-36)

**Given** S11
**When** vuốt xuống, bấm scrim hoặc bấm Back trên Android
**Then** sheet đóng và field Mật khẩu giữ nguyên

**Given** đổi tiêu chí ở S11
**When** mở tab Tạo mật khẩu
**Then** S14 phản ánh cùng độ dài và các loại Digits / Uppercase / Special (bộ tiêu chí dùng chung)

### Story 4.4: Ghi mật khẩu vào Recent và lấy lại từ Recent

As a người dùng vừa đăng ký ở app khác,
I want mật khẩu tôi đã copy ở tab Tạo mật khẩu được ghi vào Recent và nằm trên cùng,
So that tôi lấy lại được đúng mật khẩu đó để lưu vào card dù clipboard đã bị xóa (FR-37, FR-38, FR-39, FR-40, FR-44, UJ-2).

**Acceptance Criteria:**

**Given** S14
**When** bấm Copy
**Then** ngoài việc copy, `VaultSession.recordRecent` ghi mục `{password, recordedAt}` vào file `recent` mã hóa trong vault (FR-44)

**Given** mật khẩu X đã có trong Recent
**When** copy X một lần nữa ở S14
**Then** Recent vẫn chỉ có một mục X; thời điểm, vị trí và hạn của mục đó không đổi (FR-39)

**Given** S14
**When** bấm icon lịch sử
**Then** S16 mở dạng page-sheet với nút "Đóng" và tiêu đề `recent.title`, header cao 91 nền `surface-muted` (UX-DR17)
**And** danh sách xếp mục mới nhất ở trên cùng; mỗi recent-row cao 72 gồm thời điểm `dd/MM/yyyy HH:mm` (giờ máy, 24 giờ) và password-inline tô màu, luôn hiện rõ, với nút Copy bên phải; nền hàng xen kẽ (UX-DR28, UX-DR39)
**And** bottom-toolbar có "Xóa hết" ở đáy sheet

**Given** S16
**When** bấm Copy trên một mục
**Then** mật khẩu được copy qua `ClipboardService`, toast "Đã copy" hiện, và Recent **không** có mục mới (FR-38)

**Given** Use Password ở S11 hoặc Copy trên card
**When** thực hiện
**Then** Recent không thay đổi

**Given** S16
**When** vuốt xuống hoặc bấm "Đóng"
**Then** sheet đóng; không có vuốt-để-xóa từng mục

### Story 4.5: Recent tự hết hạn sau 72 giờ và Xóa hết

As a người dùng,
I want các mục Recent tự biến mất sau 72 giờ và tôi có thể xóa hết khi muốn,
So that mật khẩu tạm không nằm lâu trong app hơn mức cần thiết (FR-41, FR-42, FR-43).

**Acceptance Criteria:**

**Given** một mục Recent được ghi lúc T
**When** đọc Recent hoặc mở S16 sau T + 72 giờ
**Then** mục đó không còn hiển thị; hạn được tính riêng cho từng mục
**And** mỗi lần ghi Recent, các mục đã hết hạn được dọn khỏi file

**Given** S16 đang mở
**When** một mục tới hạn 72 giờ
**Then** mục đó biến mất ngay nhờ một timer đặt cho mục sắp hết hạn tiếp theo

**Given** một mục có `recordedAt` lớn hơn thời điểm hiện tại quá 5 phút
**When** đọc Recent
**Then** mục đó được coi là đã hết hạn (AD-20)

**Given** S16 có ít nhất một mục
**When** bấm "Xóa hết"
**Then** S17 hiện alert-dialog `recent.clear.title` (không có thân) với "Hủy" (trái, đậm) và "Xóa hết" (phải)
**And** chọn "Xóa hết" thì toàn bộ Recent bị xóa bằng một lần ghi nguyên tử và danh sách chuyển sang trạng thái trống; chọn "Hủy" hoặc bấm Back trên Android thì không đổi gì

**Given** Recent trống (chưa copy lần nào, vừa Xóa hết, hoặc mọi mục đã hết hạn)
**When** mở S16
**Then** empty-state `empty.recent` hiện căn giữa vùng trống, bottom-toolbar vẫn hiển thị và "Xóa hết" bị vô hiệu (FR-43)

## Epic 5: Tùy chỉnh cài đặt và đổi mật khẩu chính

Người dùng chỉnh 3 cài đặt thời gian, chọn ngôn ngữ và giao diện (có hiệu lực ngay), và đổi mật khẩu chính mà không phải mã hóa lại vault.

### Story 5.1: Chỉnh thời gian Tự khóa, Giới hạn phiên và Tự xóa clipboard

As a người dùng,
I want chọn thời gian Tự khóa, Giới hạn phiên và Tự xóa clipboard trong vài giá trị cố định,
So that app cân bằng giữa an toàn và tiện lợi theo cách tôi dùng (FR-46).

**Acceptance Criteria:**

**Given** tab Cài đặt
**When** hiển thị
**Then** S18 dùng bố cục inset-grouped với nav-bar `tab.settings`; khối 1 có section-header "CHUNG" / "GENERAL" và ba hàng Tự khóa · Giới hạn phiên · Tự xóa clipboard, mỗi hàng hiện giá trị hiện tại màu `ink-value` + ⌃⌄ (UX-DR22, UX-DR36)
**And** khối "Khóa Vault" vẫn là khối cuối cùng, cách khối trên 35

**Given** S18
**When** bấm một hàng thời gian
**Then** S19 popup-menu mở ngay dưới hàng, căn mép phải với nhóm, gồm đúng 4 mục "1 phút", "3 phút", "5 phút", "10 phút" với ✓ ở mục hiện tại; không có lựa chọn "Không bao giờ" (UX-DR15)

**Given** S19
**When** chọn một giá trị
**Then** giá trị được áp dụng ngay vào `SettingsStore` (trường `autolockMin`, `sessionMin` hoặc `clipboardMin`), menu đóng và hàng hiện giá trị mới
**And** bấm ra ngoài menu thì menu đóng và không đổi gì

**Given** một lần đếm đang chạy (phiên, autolock hoặc clipboard)
**When** người dùng đổi giá trị tương ứng
**Then** lần đếm đang chạy giữ giá trị cũ; giá trị mới có hiệu lực từ lần đếm kế tiếp (UX-DR40)

**Given** đã đổi giá trị
**When** tắt app rồi mở lại
**Then** giá trị mới được giữ nguyên

### Story 5.2: Chọn ngôn ngữ và giao diện

As a người dùng,
I want chọn English hay Tiếng Việt, và giao diện Sáng, Tối hay Theo hệ thống,
So that app hiển thị đúng cách tôi muốn mà không phụ thuộc cài đặt của điện thoại (FR-47).

**Acceptance Criteria:**

**Given** S18
**When** hiển thị
**Then** khối 2 có section-header "NGÔN NGỮ & GIAO DIỆN" / "LANGUAGE & APPEARANCE" với hai hàng Ngôn ngữ · Giao diện, mỗi hàng có giá trị + ⌃⌄, nằm ngay dưới khối CHUNG (UX-DR36)

**Given** hàng Ngôn ngữ
**When** bấm và chọn "English" hoặc "Tiếng Việt" trong S19
**Then** toàn bộ chuỗi giao diện đổi ngay sang ngôn ngữ đã chọn, không cần khởi động lại (UX-DR40)
**And** `language` được lưu là `"en"` hoặc `"vi"`, nên từ đó app không còn đi theo ngôn ngữ máy

**Given** hàng Giao diện
**When** chọn "Theo hệ thống", "Sáng" hoặc "Tối"
**Then** theme đổi ngay (`appearance` = `system` / `light` / `dark`); với "Theo hệ thống", app đổi theo khi người dùng đổi chế độ sáng/tối của máy
**And** mọi màn hình và sheet đang mở dùng đúng bộ token của chế độ mới, kể cả kiểu thanh hệ thống

**Given** đã chọn ngôn ngữ và giao diện
**When** tắt app rồi mở lại
**Then** S3 hiển thị ngay bằng ngôn ngữ và giao diện đã chọn (settings nạp trước frame đầu tiên)

### Story 5.3: Đổi mật khẩu chính

As a người dùng,
I want đổi mật khẩu chính khi đã đăng nhập,
So that tôi thay được mật khẩu cũ có thể đã bị lộ mà không mất card, bản nháp hay file export cũ (FR-13, FR-48).

**Acceptance Criteria:**

**Given** S18
**When** hiển thị
**Then** khối 4 là button-text "Đổi mật khẩu chính" trong ô riêng, nằm trên khối "Khóa Vault" (UX-DR36)

**Given** S18
**When** bấm "Đổi mật khẩu chính"
**Then** S20 được push trong tab Cài đặt với chevron back kèm chữ "Cài đặt", tiêu đề `change.title`, ba `SecretField` có nhãn trên ô: Mật khẩu cũ · Mật khẩu mới · Nhập lại mật khẩu mới, và nút `change.submit` (UX-DR33)

**Given** người dùng gõ mật khẩu mới
**When** nội dung thay đổi
**Then** strength-meter hiện dưới ô Mật khẩu mới, inline-message theo `PasswordPolicy`, ký tự không ASCII được giữ nguyên và báo `pw.nonAscii`; nút chỉ bật khi mật khẩu mới hợp lệ, hai ô khớp và ô mật khẩu cũ không trống

**Given** mật khẩu cũ sai
**When** bấm "Đổi mật khẩu"
**Then** `change.wrongOld` hiện dưới ô Mật khẩu cũ; `AccountService.verify` không chạm `LockoutGuard`, nên bộ đếm sai không tăng và không giới hạn số lần thử

**Given** mật khẩu cũ đúng và mật khẩu mới hợp lệ
**When** bấm "Đổi mật khẩu"
**Then** nút hiện activity-indicator, Back/vuốt bị chặn trong lúc chạy KDF và ghi
**And** `VaultSession.changeMainPassword` hiệu chỉnh lại KDF, sinh salt mới, tính lại `wrapNonce`, `wrappedDek`, `kcv`, `checksum` và ghi `header` bằng **một** lần ghi nguyên tử; DEK, `cards`, `recent` và `draft` không bị mã hóa lại hay thay đổi
**And** xong thì quay về S18 và toast `change.done` hiện

**Given** app bị tắt giữa lúc ghi `header`
**When** mở lại app
**Then** vault mở được bằng đúng một trong hai mật khẩu (cũ hoặc mới), không bao giờ ở trạng thái hỏng

**Given** đến hạn khóa (Tự khóa hoặc hết phiên) trong lúc đang ghi `header`
**When** `SessionController` khóa
**Then** app khóa ngay sau khi lần ghi hoàn tất (FR-16)

**Given** đổi mật khẩu chính thành công
**When** khóa rồi đăng nhập lại
**Then** chỉ mật khẩu mới mở được vault, mọi card và Recent còn nguyên, và bản nháp (nếu có) vẫn được hỏi lại ở S6

## Epic 6: Sao lưu và chuyển máy (Export / Import)

Người dùng export file đã mã hóa, chia sẻ qua menu của OS, rồi import sang máy khác (kể cả iOS ↔ Android) và lấy lại 100% card. Hoàn thành UJ-3, TC-2 và TC-5.

### Story 6.1: Định dạng file export là hợp đồng vĩnh viễn

As a người dùng,
I want file export có định dạng cố định, mã hóa mạnh và đọc được trên mọi máy, mọi phiên bản app,
So that file backup của tôi luôn khôi phục được khi đổi điện thoại, kể cả từ iPhone sang Android (FR-53, FR-54, FR-61, FR-62, FR-63, NFR-3, TC-2).

**Acceptance Criteria:**

**Given** `core/format/export/` là codec duy nhất của file export
**When** mã hóa một danh sách card với mật khẩu export
**Then** file có layout `PAKX`[4] · version u16 · kdfAlg u8 · opslimit u32 · memlimit u64 · salt[16] · nonce[24] · ciphertext‖tag (little-endian), associated data là mọi byte đứng trước ciphertext (AD-20)
**And** KDF là Argon2id13 với tham số **cố định** m=64 MiB, t=3, p=1, không phụ thuộc máy tạo file
**And** payload là `{"v":1,"exportedAt":int,"cards":[{"title","username","password","note","createdAt"}]}`, không có `id`, không có Recent, cài đặt hay bản nháp

**Given** một file đầu vào
**When** codec kiểm tra trước khi giải mã
**Then** file > 8 MiB, sai magic, version lạ hoặc tham số ngoài khoảng [m 19–128 MiB, t 2–10] bị trả "không hợp lệ" **trước** khi chạy KDF (FR-63)

**Given** header hợp lệ
**When** giải mã
**Then** AEAD lỗi được trả là sai mật khẩu export
**And** payload phải đúng schema, ≤ 10 000 card, mỗi card có `title`/`username`/`password` không rỗng, mỗi chuỗi ≤ 64 KiB, `createdAt` ≥ 0; chỉ một card sai cũng làm cả file bị trả "không hợp lệ"
**And** codec bắt mọi exception, không kèm thông điệp

**Given** script trong `tool/fixtures/` sinh file mẫu từ bảng AD-20 bằng dữ liệu giả, không dùng code của app
**When** CI chạy
**Then** `test/fixtures/export/v1.pakx` được import thành công bằng codec, và CI bắt buộc import được mọi file mẫu của mọi phiên bản đã có (FR-62)

**Given** quy tắc phiên bản
**When** định dạng cần thay đổi trong tương lai
**Then** tài liệu codec ghi rõ: phiên bản đã phát hành không bao giờ bị sửa; thay đổi là một phiên bản mới kèm reader cho mọi phiên bản cũ

**Given** cùng một file
**When** codec chạy trên iOS hay Android
**Then** kết quả giải mã giống hệt nhau, vì định dạng không phụ thuộc nền tảng (FR-61; kiểm chứng trên máy thật ở Epic 7)

### Story 6.2: Export file sao lưu và chia sẻ

As a người dùng sắp đổi điện thoại,
I want tạo một file sao lưu đã mã hóa bằng mật khẩu export riêng rồi gửi nó đi qua Zalo, email hay Drive,
So that tôi có bản backup duy nhất để khôi phục card trên máy mới (FR-50 Export, FR-51, FR-52, FR-55, UJ-3).

**Acceptance Criteria:**

**Given** S18
**When** hiển thị
**Then** khối 3 có section-header "DỮ LIỆU" / "DATA" và hàng Export (chevron) kèm dòng phụ `export.never` ("Chưa export lần nào") hoặc `export.lastDate` ("Lần export gần nhất: dd/MM/yyyy"), nằm giữa khối NGÔN NGỮ & GIAO DIỆN và khối Đổi mật khẩu chính; không có icon cloud (UX-DR36)

**Given** S18
**When** bấm Export
**Then** S21 mở dạng page-sheet "Export" với nút "Hủy", dòng `export.step1`, một `SecretField` và nút "Tiếp tục"

**Given** S21
**When** nhập sai mật khẩu chính và bấm "Tiếp tục"
**Then** `export.wrongMain` hiện; `AccountService.verify` không chạm `LockoutGuard`, bộ đếm sai không tăng, không giới hạn số lần (FR-51)

**Given** S21 với mật khẩu chính đúng
**When** bấm "Tiếp tục"
**Then** S22 được push trong cùng sheet (chỉ chevron back về S21), gồm ô Mật khẩu export và ô Nhập lại (nhãn trên ô), strength-meter, rồi `export.hint` (không điền sẵn mật khẩu chính) và `export.warning`, rồi nút "Tạo file" (UX-DR33)
**And** mật khẩu export phải qua `PasswordPolicy` (15–128 ASCII, blocklist, lặp/tuần tự) và hai ô phải khớp thì "Tạo file" mới bật

**Given** S22 hợp lệ
**When** bấm "Tạo file"
**Then** nút hiện activity-indicator, Back/vuốt bị chặn; file export chỉ chứa card được ghi qua `AtomicFileWriter` vào `pak/tmp/` (tối đa một file)
**And** ngay khi file tạo xong, `lastExportAt` được ghi vào settings, rồi menu chia sẻ của OS (S23) mở qua port `share_plus`, không cần quyền mạng

**Given** menu chia sẻ đóng (người dùng gửi file hay không)
**When** kết quả trả về
**Then** file trong `pak/tmp/` bị xóa, sheet Export đóng, app về S18 và dòng phụ Export hiện ngày vừa export (UX-DR48)
**And** nếu epoch phiên đã đổi trong lúc chờ share sheet thì kết quả bị bỏ

**Given** đến hạn khóa khi đang ở S21 hoặc S22 (chưa bắt đầu ghi)
**When** `SessionController` khóa
**Then** thao tác export bị hủy, không có file nào được tạo

**Given** đến hạn khóa khi đang ghi file export
**When** `SessionController` khóa
**Then** app khóa ngay sau khi lần ghi hoàn tất (FR-16); file tạm bị dọn ở lần khởi động hoặc lần mở phiên sau

### Story 6.3: Chọn file import và từ chối file không hợp lệ

As a người dùng trên máy mới,
I want chọn file sao lưu bằng trình chọn file của điện thoại và được báo ngay nếu chọn nhầm file,
So that tôi không bao giờ làm hỏng dữ liệu vì import nhầm (FR-50 Import, FR-56, FR-63, TC-6).

**Acceptance Criteria:**

**Given** S18
**When** hiển thị
**Then** khối DỮ LIỆU có hàng Import (chevron) đứng trước hàng Export

**Given** S18
**When** bấm Import
**Then** trình chọn file thật của OS (S24) mở qua port `file_selector` (không vẽ lại dáng iOS)

**Given** người dùng chọn một file
**When** file được đọc
**Then** bản sao file do trình chọn file tạo trong cache bị xóa ngay sau khi đọc

**Given** file là CSV, file của trình quản lý mật khẩu khác, file > 8 MiB, sai magic/version hoặc có tham số KDF ngoài giới hạn
**When** kiểm tra định dạng
**Then** S27 hiện alert-dialog `import.invalid` ("File không hợp lệ") không có thân, chỉ một nút "OK"; Back trên Android tương đương OK
**And** không có gì thay đổi trong vault, và KDF không được chạy

**Given** người dùng hủy trình chọn file
**When** quay lại
**Then** app ở S18, không có gì thay đổi

**Given** đến hạn khóa khi trình chọn file đang mở
**When** trình chọn file trả kết quả sau khi epoch phiên đã đổi
**Then** kết quả bị bỏ, import bị hủy, dữ liệu giữ nguyên (FR-16)

### Story 6.4: Nhập mật khẩu export, xem trước và thêm card

As a người dùng trên máy mới,
I want nhập mật khẩu export, xem file có bao nhiêu card và xác nhận để thêm chúng vào app,
So that tôi lấy lại toàn bộ card cũ mà không mất card đang có (FR-56, FR-57, FR-58, FR-59, FR-60, TC-5, UJ-3).

**Acceptance Criteria:**

**Given** file đã qua kiểm tra định dạng ở story 6.3
**When** tiếp tục
**Then** S25 mở dạng page-sheet "Import" với nút "Hủy", một `SecretField` nhãn `export.field` và nút "Tiếp tục"; nút bị vô hiệu khi ô có ít hơn 15 ký tự hoặc chứa ký tự không ASCII
**And** không yêu cầu nhập lại mật khẩu chính

**Given** S25
**When** nhập sai mật khẩu export và bấm "Tiếp tục"
**Then** sau activity-indicator, `import.wrongPw` hiện, ô giữ nguyên nội dung; người dùng thử lại không giới hạn và bộ đếm sai của Login không bị chạm

**Given** mật khẩu export đúng nhưng payload sai schema hoặc vượt giới hạn
**When** giải mã xong
**Then** S27 "File không hợp lệ" hiện và không card nào được thêm

**Given** mật khẩu export đúng và payload hợp lệ
**When** giải mã xong
**Then** payload được chuyển cho `VaultSession.stageImport()` và S26 alert-dialog tiêu đề "Import" hiện `import.preview` với số card N và ngày export `dd/MM/yyyy`, nút "Hủy" (trái, đậm) và "Xác nhận" (phải)

**Given** S26
**When** bấm "Hủy" hoặc Back trên Android
**Then** payload đang chờ bị bỏ, không card nào được thêm

**Given** S26
**When** bấm "Xác nhận"
**Then** mọi card trong file được thêm vào `cards` bằng **một** lần ghi nguyên tử, mỗi card nhận id mới và giữ `createdAt` gốc; card hiện có giữ nguyên, card trùng không bị loại
**And** sheet đóng, app ở lại tab Cài đặt và toast `import.done` ("Đã thêm {N} card") hiện
**And** trong danh sách, card được import nằm đúng vị trí theo `createdAt` gốc (FR-58)
**And** Recent, cài đặt và bản nháp không thay đổi (FR-60)

**Given** app bị tắt giữa lúc ghi `cards`
**When** mở lại app
**Then** danh sách hoặc giữ nguyên như trước import, hoặc có đủ mọi card trong file; không bao giờ có card được thêm dở dang (FR-59)

**Given** đến hạn khóa
**When** khóa xảy ra ở S25 hoặc S26 trước khi xác nhận
**Then** import bị hủy và payload bị bỏ khỏi bộ nhớ; nếu khóa đến trong lúc đang ghi `cards` thì app khóa ngay sau khi ghi xong (FR-16)

**Given** một vault có card, được export rồi import vào một tài khoản mới (kể cả sau khi đã đổi mật khẩu chính ở máy cũ)
**When** so sánh
**Then** 100% card khớp tiêu đề, tên đăng nhập, mật khẩu, Note và `createdAt` (test round-trip cho TC-5)

## Epic 7: Sẵn sàng phát hành lên store

App vượt qua bộ nghiệm thu trên máy thật và có mặt trên TestFlight và thử nghiệm kín Google Play, với chính sách quyền riêng tư và mô tả store đúng yêu cầu.

### Story 7.1: Bộ nghiệm thu trên máy thật

As a chủ sản phẩm,
I want một checklist nghiệm thu chạy trên máy thật trước mỗi lần phát hành,
So that những tiêu chí chỉ kiểm được trên thiết bị thật (TC-1 đến TC-6, NFR-2, NFR-7, NFR-9) không bao giờ bị bỏ sót (AD-24).

**Acceptance Criteria:**

**Given** `docs/acceptance-checklist.md`
**When** mở checklist
**Then** mỗi mục có: mã tiêu chí, thiết bị và phiên bản OS, các bước thực hiện, kết quả mong đợi, và chỗ ghi đạt/không đạt kèm phiên bản app

**Given** checklist
**When** rà nội dung
**Then** có đủ các mục:
- **TC-1:** trích dữ liệu app (backup iTunes/Finder, `adb` trên máy debug hoặc root/jailbreak) và xác nhận không đọc được tiêu đề, tên đăng nhập, mật khẩu, Note, Recent hay bản nháp; xác nhận iCloud/Google Backup không chứa thư mục `pak/`; ghi nhận ảnh thu nhỏ đa nhiệm là ngoại lệ chấp nhận
- **TC-2:** file export không mở được bằng công cụ ngoài app
- **TC-3:** nhập sai tới lần 5–9 rồi tắt app, khởi động lại máy, chỉnh đồng hồ máy; xác nhận thời gian chờ không bị rút ngắn và lần thứ 10 xóa dữ liệu
- **TC-4:** bắt gói tin trên iOS khi chạy qua mọi luồng, không có kết nối ra ngoài; xác nhận build Android không có quyền `INTERNET`
- **TC-5:** export trên iOS rồi import trên Android, và ngược lại, khôi phục 100% card
- **TC-6:** tắt app đột ngột khi đang lưu card, đổi mật khẩu chính, import; vault không hỏng
- **NFR-2:** đo thời gian mở khóa trên máy mốc iPhone 6s/SE đời 1 (iOS 15) và Android 7 RAM 2 GB, đạt ~1 giây, tối đa 2 giây
- **NFR-9:** với bàn phím mặc định, Gboard và Laban Key, các ô mật khẩu không hiện đề nghị lưu mật khẩu, không gợi ý từ, không tự sửa; gõ Telex/VNI vào ô mật khẩu chính hiện `pw.nonAscii`
- **Clipboard:** iOS hết hạn theo cài đặt và không đồng bộ Universal Clipboard; Android 13+ che nội dung trong bản xem trước, xóa khi quay lại app quá hạn; không hiện thông báo "đã dán từ clipboard" khi app kiểm tra
- **`bootId`:** `kern.bootsessionuuid` trên iPhone thật đổi sau khi khởi động lại
- **FR-11:** trên cả iOS và Android, với một tài khoản có card và đang ở trạng thái sai 5–9 lần (đang chờ), gỡ app rồi cài lại; xác nhận app hiện S1 (chưa có tài khoản), bộ đếm sai về 0, không còn card, Recent, bản nháp hay ngày export cũ, và trên iOS không còn mục Keychain nào sót lại

**Given** một bản phát hành sắp được đẩy lên store
**When** còn mục nào trong checklist chưa đạt
**Then** bản đó không được phát hành; nếu đề nghị lưu mật khẩu của iOS vẫn hiện với `SecretField` thì ghi nhận cần sửa AD-11/AD-14 trước khi phát hành

### Story 7.2: Ký app và phát hành qua CI

As a chủ sản phẩm,
I want CI build, ký và đưa app lên TestFlight và tạo AAB đã ký cho Google Play,
So that tôi phát hành được cả iOS lẫn Android mà không cần máy Mac và không để lộ khóa ký trong repo public (AD-18, AD-19).

**Acceptance Criteria:**

**Given** khóa ký Android, chứng chỉ iOS và App Store Connect API key
**When** cấu hình CI
**Then** các bí mật này chỉ nằm trong GitHub Secrets và chỉ có trên workflow chạy ở `main` hoặc tag; workflow của PR không đọc được chúng

**Given** một tag phát hành theo semver `MAJOR.MINOR.PATCH`
**When** workflow phát hành chạy
**Then** build number bằng số lần chạy CI
**And** iOS được build, ký và upload lên TestFlight bằng App Store Connect API key
**And** Android tạo AAB release đã ký thành artifact để upload thủ công lên Play Console
**And** cả hai bản đều đã qua các cổng của PR (không có `INTERNET`, `.so` căn 16 KB, test, import file mẫu)

**Given** công cụ ký và upload còn hoãn ở Architecture (fastlane hay script)
**When** làm story này
**Then** lựa chọn được chốt, và nếu thêm dependency hay công cụ thì bảng Stack của spine được cập nhật kèm ghi chú đã rà soát

**Given** bản iOS
**When** nộp lên App Store Connect
**Then** app có privacy manifest khai báo mọi API "required reason" đang dùng, hoặc không dùng API nào như vậy

### Story 7.3: Chính sách quyền riêng tư và hồ sơ store

As a người dùng tìm app trên store,
I want đọc được chính sách quyền riêng tư và mô tả nói rõ app offline, không thu thập dữ liệu và không khôi phục được mật khẩu chính,
So that tôi hiểu đúng rủi ro trước khi giao mật khẩu của mình cho app (PRD §6).

**Acceptance Criteria:**

**Given** GitHub Pages của repo
**When** mở trang chính sách quyền riêng tư
**Then** có bản English và Tiếng Việt, nêu rõ ba điều: app chạy offline, không thu thập dữ liệu, không có cơ chế khôi phục mật khẩu chính

**Given** hồ sơ App Store và Google Play
**When** điền khai báo
**Then** App Privacy (iOS) và Data Safety (Android) đều khai báo "Không thu thập dữ liệu"
**And** app được đặt miễn phí hoàn toàn, không mua trong app, không quảng cáo

**Given** mô tả trên store (EN và VI)
**When** đọc
**Then** mô tả cảnh báo rõ: quên mật khẩu chính là mất toàn bộ dữ liệu, và người dùng nên export định kỳ

**Given** các mục hoãn của PRD §8
**When** chuẩn bị nộp store
**Then** chủ sản phẩm đã kiểm tra tên "PAK Manager" còn trống trên hai store, chốt loại khai báo export compliance với Apple (mã hóa tiêu chuẩn), và đáp ứng yêu cầu thử nghiệm kín hiện hành của Google Play cho tài khoản cá nhân (số tester, thời gian); kết quả được ghi lại trong `docs/`
