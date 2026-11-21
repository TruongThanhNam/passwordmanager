# Epic 2 Context: Chống dò mật khẩu và xóa dữ liệu

<!-- Compiled from planning artifacts. Edit freely. Regenerate with compile-epic-context if planning docs change. -->

## Goal

Hoàn thiện màn Login (S3) với đủ cơ chế chống dò mật khẩu chính: đếm lần nhập sai một cách bền vững, bắt chờ 30 phút từ lần sai thứ 5 mà tắt app, khởi động lại máy hay chỉnh đồng hồ đều không né được, và tự xóa toàn bộ dữ liệu ở lần sai thứ 10. Epic cũng thêm lối thoát cố ý cho người quên mật khẩu chính ("Xóa & Tạo tài khoản mới", giữ 3 giây), tách hẳn "Dữ liệu bị hỏng" khỏi nhập sai để file hỏng không bao giờ kích hoạt xóa, và bảo đảm lần xóa bị gián đoạn được xóa nốt ở lần mở app sau. Kẻ dò mật khẩu trên màn Login không bao giờ mở được vault, còn dữ liệu của người dùng không bao giờ mất vì lỗi của app. Epic hoàn thành hành trình quên mật khẩu (UJ-4) và tiêu chí TC-3. Nó dựng `LockoutGuard`, `WipeCoordinator`, codec `guard`, các trạng thái S3/S4/S5 và hold-confirm-button trên nền `AccountService`, `VaultSession`, `SessionController` và `ClockPort` (`bootId`/`monotonicMs`) đã có từ Epic 1.

## Stories

- Story 2.1: Đếm lần nhập sai bền vững
- Story 2.2: Thời gian chờ 30 phút không phụ thuộc đồng hồ máy
- Story 2.3: Tự xóa dữ liệu ở lần sai thứ 10
- Story 2.4: Xóa & Tạo tài khoản mới khi quên mật khẩu chính
- Story 2.5: "Dữ liệu bị hỏng" không bao giờ dẫn tới xóa

## Requirements & Constraints

- **Giới hạn nhập sai (FR-4, FR-8):** lần sai 1–4 nhập lại được ngay; lần sai 5–9 phải chờ 30 phút sau mỗi lần; lần sai thứ 10 tự xóa tài khoản và toàn bộ vault rồi về S1 (chưa có tài khoản). Login luôn hiện số lần thử còn lại và hiện đồng hồ đếm ngược khi đang chờ. Ba hằng số (10 lần, từ lần thứ 5, 30 phút) nằm cứng trong code, không có cài đặt nào đổi được.
- **Cách tính lần sai (FR-5):** đăng nhập đúng thì bộ đếm về 0. Nhập lại đúng chuỗi sai của lần ngay trước thì báo sai ngay, không đếm, không chạy KDF, không bắt đầu thời gian chờ mới. Mỗi lúc chỉ có một lần kiểm tra, bấm liên tiếp không tạo thêm lần thử. Bộ đếm tăng trước khi kiểm tra, nên app bị tắt giữa lúc kiểm tra thì lần đó tính là sai.
- **Bền vững (FR-6, TC-3):** bộ đếm và thời gian chờ giữ nguyên qua tắt app. Chỉnh đồng hồ máy không rút ngắn được thời gian chờ. Khởi động lại máy trong lúc chờ thì thời gian chờ tính lại từ 30:00. Thời gian chờ không bao giờ bị rút ngắn và không bao giờ kéo dài vô hạn.
- **Dữ liệu bị hỏng (FR-7, TC-6):** mật khẩu đúng mà vault hỏng thì báo "Dữ liệu bị hỏng", không tính vào bộ đếm, không bao giờ kích hoạt xóa. Người dùng tự chọn "Xóa & Tạo tài khoản mới" rồi import lại nếu muốn. Vault có phiên bản mới hơn app hỗ trợ cũng là `corrupt` (AD-25).
- **Xóa thủ công (FR-9):** khi đã có tài khoản, Login có nút "Xóa & Tạo tài khoản mới": mở hộp thoại xác nhận, giữ nút xác nhận 3 giây, không yêu cầu mật khẩu. Xong thì về S1.
- **Phạm vi xóa (FR-12):** xóa card, Recent, bản nháp, bộ đếm, ngày export gần nhất, và clipboard nếu nó còn giữ giá trị app đã copy. Xóa bị gián đoạn (tắt app, hết pin) thì lần mở sau xóa nốt rồi mới hiện S1. Sau khi xóa, tạo tài khoản mới không còn sót gì cũ.
- **Không khôi phục (FR-10, FR-11):** không có "quên mật khẩu" hay khóa khôi phục; gỡ app xóa sạch cả bộ đếm (không ghi gì vào Keychain/Keystore).
- Chuỗi không ASCII hoặc ngắn hơn 15 ký tự bị chặn ở nút "Đăng nhập" và không bao giờ tới `LockoutGuard`.

## Technical Decisions

- **`LockoutGuard` (AD-8):** chủ duy nhất của file `guard`; máy trạng thái thuần nằm trong `core/guard`, service nằm ở `services/lockout_guard.dart`. `guard` không mã hóa (rủi ro chấp nhận: root/jailbreak sửa được file; lớp bảo vệ thật là KDF). Trạng thái guard thuộc phạm vi **app**, sống lâu hơn phiên.
  - **Trước KDF, đúng một lần ghi:** `failCount += 1`; nếu giá trị mới là 5–9 thì cùng lần ghi đó đặt mốc chờ `(bootId, monotonicMs)` hiện tại. Ghi lỗi thì hủy lần thử, không chạy KDF.
  - **Mật khẩu đúng (`kcv` khớp, kể cả khi sau đó ra `corrupt`):** `recordSuccess()` ghi `failCount = 0` và xóa mốc chờ trước mọi bước sau.
  - **`normalize()` khi khởi động,** theo thứ tự, mỗi lần đặt lại ghi xuống đĩa trước khi hiển thị: (1) `wiping = true` hoặc `failCount ≥ 10` → `WipeCoordinator`; (2) `failCount` 5–9 mà không có mốc → mốc = bây giờ; (3) `waitBootId` khác `bootId` hiện tại, hoặc `monotonicMs` nhỏ hơn mốc → mốc = bây giờ.
  - Có `header` mà `guard` thiếu hoặc không đọc được → tạo lại với `failCount = 0`.
  - Chuỗi sai lần trước chỉ giữ trong RAM dưới dạng digest BLAKE2b 16 byte, khóa ngẫu nhiên 32 byte sinh khi mở process và chỉ nằm trong RAM (AD-22). Không bao giờ ghi chuỗi gần đúng xuống đĩa.
- **Codec `guard` (AD-20):** `core/format/guard_codec`, schema `{"v":1,"failCount":0–10,"waitBootId":str|null,"waitStartMono":int|null,"wiping":bool}`. Ghi qua `AtomicFileWriter`, có golden test. Đây là codec duy nhất được encode/decode file này. Khác các file vault, đọc lỗi không trả `corrupt` mà rơi vào luật tạo lại của AD-8.
- **Thứ tự mở khóa (AD-4):** (1) đọc header; sai kích thước/magic/version, `checksum` lệch hoặc tham số KDF ngoài khoảng → `corrupt`, **không chạm guard, không chạy KDF**. (2) Guard ghi trước rồi chạy KDF. (3) So `kcv` hằng thời gian; lệch → `wrongPassword`. (4) Khớp → `recordSuccess()`, rồi mở bọc DEK và giải mã `cards`/`recent`; lỗi, hoặc có header mà thiếu `cards`/`recent` → `corrupt`. `verify()` (dùng sau này cho đổi mật khẩu chính và export) bỏ qua guard.
- **`UnlockResult`** thêm `lockedOut` bên cạnh `success`, `wrongPassword`, `corrupt` (tài liệu kế hoạch không nói rõ khi nào trả `lockedOut` so với `wrongPassword` kèm trạng thái chờ; story 2.1/2.2 chốt); vẫn là kiểu sealed, không ném exception qua ranh giới lớp, UI ánh xạ sang key microcopy.
- **Đo thời gian (AD-9):** thời gian chờ đo bằng `ClockPort.monotonicMs` (tính cả lúc máy ngủ) kết hợp `bootId`; `Timer` chỉ để đánh thức lần cập nhật đếm ngược. Không bao giờ dùng `DateTime.now()` hay `Stopwatch` làm nguồn sự thật. `bootId` lấy từ Android `Settings.Global.BOOT_COUNT`, iOS `kern.bootsessionuuid` (đã có trong Pigeon). Nếu `bootId` trên iPhone thật không dùng được thì AD-8 vẫn an toàn, vì `bootId` lệch chỉ làm thời gian chờ bắt đầu lại; việc kiểm trên máy thật để cho Epic 7.
- **`WipeCoordinator` (AD-21):** `services/wipe_coordinator.dart` là chủ duy nhất của quy trình xóa cho cả ba lối vào (lần sai thứ 10, S4, xóa nốt khi khởi động). Các bước theo thứ tự, mỗi bước idempotent: `LockoutGuard.markWiping()` → vô hiệu `VaultSession` hiện hành nếu có → xóa `vault/header` **trước**, rồi các file còn lại, rồi thư mục → xóa `pak/tmp/` → `SettingsStore.clearLastExport()` → xóa clipboard (hook rỗng, Epic 3 nối `ClipboardService.clearIfOurs()`) → `LockoutGuard.reset()`.
- **`AccountService.bootstrap()` (AD-26):** theo thứ tự `WipeCoordinator.resumeIfNeeded()` → `LockoutGuard.normalize()` → dọn `*.tmp` và `pak/tmp/` → trả trạng thái khởi động. `resumeIfNeeded()` chạy trước khi quyết định S1 hay S3. Không có `header` nhưng `vault/` còn file khác thì dọn các file đó trước khi hiện S1.
- **`SessionGate` (AD-23):** hiển thị S1–S5 khi chưa mở khóa. S4 và S5 nằm ngoài cây sau đăng nhập, nên tự áp chính sách Back bằng `PopScope`, không qua `ModalPresenter` (dựng ở Epic 3).
- **Test (AD-24):** unit test bắt buộc cho máy trạng thái guard với fake clock và fake `bootId`, mô phỏng crash ở từng bước (tắt app, khởi động lại, chỉnh đồng hồ); `WipeCoordinator` mô phỏng crash sau từng bước, chạy lại luôn về trạng thái chưa có tài khoản; mỗi nguồn hỏng (header, DEK, `cards`, `recent`, phiên bản mới) có test riêng xác nhận bộ đếm không tăng và `WipeCoordinator` không được gọi. Golden test cho `guard`. Tên test mang id yêu cầu đệm 2 chữ số (`fr05_same_wrong_string_not_counted`, `ad08_…`, `ad21_…`). Fake port/timer/`SecureKey` dùng chung trong `test/support/`, không chép fake inline.

## UX & Interaction Patterns

- **Trạng thái S3 (UX-DR42):** idle (dòng `login.attempts` "Còn {N} lần thử trước khi dữ liệu bị xóa." luôn hiện dưới ô); đang kiểm tra (spinner trên nút, ô và nút khóa); sai lần 1–4 (`login.wrong`, ô giữ nội dung, nhập lại được ngay, {N} giảm); đang chờ 5–9 (ô và nút vô hiệu, icon trong ô `ink-disabled`, `login.lockout` "Thử lại sau {mm:ss}" đếm ngược từng giây, hết giờ về idle); lần thứ 10 (không dialog, S5 rồi S1); dữ liệu hỏng (`login.corrupt`, số lần thử không giảm, không xóa gì).
- **Thứ tự thông báo (UX-DR21):** inline-message cách ô 6; `login.wrong`/`login.lockout`/`login.corrupt` nằm trên, `login.attempts` luôn nằm cuối khối. Mọi thông báo, số lần thử và đếm ngược chỉ là chữ `ink-secondary`; không có màu đỏ hay màu trạng thái, hành động phá hủy cũng dùng `accent`.
- **Nút "Xóa & Tạo tài khoản mới" (`login.erase`, UX-DR31):** button-text cao 44 ở đáy màn (đáy cách mép 42), xa nút "Đăng nhập", bấm được ở mọi trạng thái của S3 kể cả khi đang chờ hay dữ liệu hỏng.
- **S4 (UX-DR13, UX-DR14):** alert-dialog dáng iOS rộng 270, `rounded.alert`, tiêu đề `erase.title` (body-emphasis), thân `erase.body` (footnote), hold-confirm-button với nhãn `erase.hold` bên dưới, hàng nút chỉ có "Hủy" (`common.cancel`). Bấm ra ngoài không đóng. hold-confirm-button: nút tròn 72 không nền, icon thùng rác `accent`, vòng tiến trình dày 4 (nền `track`, phần đã giữ `accent`) chạy đều theo chiều kim đồng hồ từ 12 giờ trong 3 giây. Nhả sớm thì vòng chạy ngược về 0 và không có gì xảy ra; tap nhanh không làm gì, không kèm thông báo. Đủ 3 giây thì dialog đóng, sang S5. "Hủy" hoặc Back trên Android (kể cả lúc đang giữ) đóng dialog hoặc hủy lần giữ. Đây là hoạt ảnh riêng duy nhất cùng với toast.
- **S5 (UX-DR32):** toàn màn, activity-indicator cùng một dòng `wiping` ("Đang xóa dữ liệu…") căn giữa, khe 14, không nút, Back bị chặn; xóa xong tự sang S1. S5 cũng hiện khi mở app sau một lần xóa bị gián đoạn.
- Chuỗi mới (`login.attempts`, `login.lockout`, `login.corrupt`, `login.erase`, `erase.title`, `erase.body`, `erase.hold`, `wiping`) có đủ bản vi/en trong ARB, key camelCase theo key microcopy; `{N}` và `{mm:ss}` là tham số.

## Cross-Story Dependencies

- 2.1 dựng codec `guard`, máy trạng thái `core/guard`, `LockoutGuard` và chèn guard vào `unlock`; 2.2, 2.3 và 2.5 dựa trên nó. 2.2 thêm mốc chờ và `normalize()`. 2.3 dựng `WipeCoordinator` và nối vào `bootstrap()` cùng lần sai thứ 10; 2.4 dùng lại `WipeCoordinator` và S5 của 2.3 cho lối vào S4. 2.5 khóa chặt ranh giới `corrupt`/guard trong `unlock`.
- **Ràng buộc từ retro Epic 1:** 2.1 khi chèn guard vào `unlock` phải sửa lỗi lần gọi `unlock` thứ hai trong lúc lần đầu đang chạy nhận kết quả của lần đầu bất kể mật khẩu. 2.5 phải tách "KDF lỗi/thiếu bộ nhớ" khỏi `corrupt` bằng một kết quả riêng kiểu "thử lại" (hiện KDF trả `null` bị ánh xạ thành `corrupt`), và giới hạn kích thước khi đọc `header`/`cards`/`recent`.
- **Epic 1:** dùng lại `AccountService` (chỗ chèn guard trong `unlock`/`bootstrap` đã được chừa), `AtomicFileWriter`, `ClockPort`, `SessionGate`, `SettingsStore` (cần `clearLastExport()` cho trường `lastExportAt`) và component shared của Login. API native mới (nếu có) phải đi qua các cổng CI đã dựng ở 1.11–1.16.
- **Epic 3** nối bước xóa clipboard vào `WipeCoordinator` (FR-12) và dựng `ModalPresenter`; Epic 2 không phụ thuộc vào chúng. **Epic 5** (đổi mật khẩu chính) và **Epic 6** (export) dùng `verify()` không chạm guard. **Epic 7** nghiệm thu TC-3 và `bootId` trên máy thật.
