---
type: architecture-review
lens: adversarial (cặp đơn vị tuân thủ mọi AD nhưng vẫn ghép không khớp)
target: ../ARCHITECTURE-SPINE.md
context: ../../../prds/prd-passwordmanager-2026-10-23/prd.md, ../../../ux-designs/ux-passwordmanager-2026-10-26/EXPERIENCE.md
reviewed: '2026-10-27'
verdict: 'CHƯA ĐẠT — sửa rồi mới giao epic/story'
---

# Review đối kháng — Architecture Spine PAK Manager

## Kết luận

**Chưa đạt. Cần sửa spine trước khi tách epic/story.** Hướng kiến trúc đúng: khóa hai tầng, `VaultSession` giữ khóa và dữ liệu, máy trạng thái guard thuần, một API Pigeon, chính sách không mạng. Nhưng spine mới chốt **ai sở hữu** dữ liệu, chưa chốt **dữ liệu có dạng gì** và **chuyện gì xảy ra ở mép vòng đời** (khóa, xóa, crash, khởi động lại). Hai agent làm hai story khác nhau, không trao đổi với nhau, có thể tuân thủ từng chữ của AD-1…AD-19 mà vẫn:

- ghi và đọc bốn file (`header`, `cards`/`recent`/`draft`, export, `settings`, `guard`) theo hai schema khác nhau, vì spine không có schema nào;
- xóa sạch dữ liệu của một vault chỉ bị hỏng header, vì AEAD không phân biệt được "hỏng" với "sai mật khẩu" (FR-7, TC-6);
- tạo lại file `draft` cũ **sau khi** đã xóa vault, làm tài khoản mới vừa tạo rơi ngay vào "Dữ liệu bị hỏng";
- để bản rõ (mật khẩu, card, bản xem trước import) sống tiếp sau `lock()` ở những chỗ AD-9 không bao phủ (widget state, `ClipboardService`, `ExportService`, `LockoutGuard`);
- làm autolock không bao giờ kích hoạt trên iOS sau khi máy ngủ, vì "đồng hồ đơn điệu" chưa được chỉ định cụ thể;
- để file vault bị sao lưu lên iCloud, vì ghi nguyên tử bằng rename tạo inode mới không còn cờ `isExcludedFromBackup` (NFR-8).

Cả 6 lỗ hổng chính đều sửa được bằng **luật bổ sung**, không phải đổi hướng. Phần cuối có nội dung đề xuất cho từng AD.

## Cách tấn công

Mỗi phát hiện dựng **hai đơn vị ở tầng dưới** (story/epic, giả định do hai agent khác nhau làm), mỗi đơn vị đọc đúng các AD liên quan và tuân thủ theo cách hiểu hợp lý nhất. Nếu hai cách hiểu cùng hợp lệ mà ghép không khớp, hoặc cùng hợp lệ mà vẫn vi phạm FR/NFR/TC, thì đó là lỗ hổng của spine.

Mức độ:
- **Critical**: mất dữ liệu (TC-6) hoặc lộ bản rõ ra ngoài vault (TC-1).
- **High**: hai bản cài đặt không tương thích, hoặc vi phạm FR/NFR bảo mật trong luồng thường gặp.
- **Medium**: lệch hành vi, rò rỉ trong điều kiện hẹp.
- **Low**: nên chốt cho gọn.

## Tóm tắt phát hiện

| # | Mức | Chủ đề | AD liên quan | Sửa bằng |
|---|---|---|---|---|
| A1 | Critical | Không có schema cho mọi file dùng chung (header, cards, recent, draft, export payload, settings, guard) | AD-4, AD-6, AD-8, AD-10, AD-13 | AD-20 mới (schema v1) |
| A2 | Critical | Header hỏng bị coi là sai mật khẩu, 10 lần thì xóa; "key check value" chưa có nghĩa cụ thể | AD-4, AD-8 | Sửa AD-4 |
| A3 | Critical | Lệnh ghi cũ chạy sau khi khóa hoặc xóa (debounce bản nháp, future import), thứ tự tạo/xóa thư mục vault, không có ai sở hữu quy trình xóa | AD-3, AD-7, AD-9 | Sửa AD-3, AD-7; AD-21 mới (WipeCoordinator) |
| A4 | High | Ngữ nghĩa file guard để ngỏ: `failCount=10` mà không có cờ, thời điểm bắt đầu chờ, `bootId` lệch không được ghi lại (chờ vô hạn), Corrupt "hoàn" hay "về 0", ghi lỗi thì cho thử (fail-open) | AD-8 | Sửa AD-8 |
| A5 | High | Bản rõ còn sống sau `lock()` ngoài Riverpod: widget subtree, `ClipboardService`, xem trước import, chuỗi sai, mật khẩu đang hiện ở generator | AD-3, AD-9, AD-17 | Sửa AD-9; AD-22 mới |
| A6 | High | Ghi bằng rename làm mất cờ loại khỏi backup trên iOS; fsync thư mục không làm được bằng Dart thuần mà Pigeon lại không có; file export tạm vi phạm AD-13 | AD-7, AD-11, AD-13 | Sửa AD-7, AD-11, AD-13 |
| A7 | High | "Đồng hồ đơn điệu" và "vào nền" chưa chỉ định: `Stopwatch` trên iOS không tính lúc máy ngủ | AD-9, AD-17 | Sửa AD-9 |
| A8 | Medium | Lưu card = ghi `cards` + xóa `draft` (hai file), trái AD-7; crash ở giữa sinh card trùng | AD-7, convention Bản nháp | Sửa AD-7 + schema draft |
| A9 | Medium | `settings` có ba nơi cùng ghi (Settings, Generator, Export, Wipe): mất cập nhật | AD-13 | Sửa AD-13 |
| A10 | Medium | Import không kiểm nội dung payload và kích thước file | AD-10 | Sửa AD-10 |
| A11 | Medium | Bản rõ lọt vào log qua `FormatException`/`FlutterError` ở bản release | AD-18 | Sửa AD-18 |
| A12 | Medium | KDF chạy trên UI isolate: đóng băng UI, trễ sự kiện vòng đời | AD-4, AD-5 | Sửa AD-5 |
| A13 | Low | Hạn 72 giờ của Recent khi đồng hồ bị chỉnh lùi; clipboard khi xóa xảy ra ở process mới | Convention Recent, AD-7 | Ghi rủi ro chấp nhận |

---

## A1 — Critical — Không có schema cho dữ liệu dùng chung

**Spine nói gì.** AD-6: file dữ liệu là "JSON UTF-8", associated data = "tên loại file + phiên bản định dạng". AD-10: payload export gồm `title`, `username`, `password`, `note`, `createdAt`, "cùng thời điểm export". AD-4: header chứa "DEK được bọc… và một key check value". AD-13: `settings` chứa "đúng các trường: ngôn ngữ, giao diện, 3 thời gian…". Sơ đồ guard: `failCount · bootId · waitStartMonotonic · wiping`. Spine **không chốt** tên key, kiểu dữ liệu, cấu trúc cấp ngoài, cách mã hóa nhị phân, hay ai được ghi.

**Cặp 1: Export và Import (FR-61, FR-62).**
- *Story "Export" (agent A)* ghi `{"exportedAt": 1761550000000, "cards": [...]}`, bỏ hẳn `note` khi Note trống, `memlimit` trong header tính bằng KiB (u32).
- *Story "Import" (agent B)* đọc `{"exported_at": "...", "items": [...]}`, đòi `note` phải là chuỗi, `memlimit` tính bằng byte (u64), như `crypto_pwhash` của libsodium.
- Cả hai đều theo AD-10, vì AD-10 chỉ liệt kê tên field ngữ nghĩa. File mẫu ở CI (AD-10) không cứu được: file mẫu v1 do agent nào commit trước thì agent đó thắng, agent kia sửa code cho khớp. Như vậy CI chỉ bảo đảm code khớp với *một* file mẫu, không bảo đảm khớp với hợp đồng. Thời điểm export trong S26 ("export ngày {dd/MM/yyyy}") lấy từ key nào cũng không có quy định.

**Cặp 2: Form card và Khôi phục bản nháp (FR-26, S6).**
- *Story "Form tạo/sửa card"* lưu bản nháp gồm `{title, username, password, note}`, đúng "một bản nháp duy nhất, ghi đè".
- *Story "Đăng nhập → S6"* cần mở "S9 hoặc S10 đúng loại với dữ liệu nháp" (EXPERIENCE), tức là cần biết bản nháp là *tạo* hay *sửa*, và *sửa card nào*. Schema của story kia không có thông tin này.
- Kết quả: khôi phục bản nháp sửa card thành form tạo card, sinh ra card trùng (TC-6).

**Cặp 3: Tạo tài khoản và Đổi mật khẩu chính (AD-4, AD-5).** Hai story cùng ghi `header`. Một story mã hóa header bằng JSON (base64), story kia dùng layout nhị phân. Mỗi story tự nối chuỗi associated data theo một kiểu (`"cards|1"` hay `"cards:v1"`). Mở vault sau khi đổi mật khẩu thì AEAD báo lỗi, rồi bị quy thành "corrupt" hoặc "sai mật khẩu".

**Cặp 4: Settings.** *Màn Cài đặt* ghi `"autolock": 180` (giây). *SessionController* đọc thành phút. *Generator screen* ghi `{upper, lower, digits, special, length}`, *sheet* ghi `{abc, num, sym, length}` (FR-35 yêu cầu dùng chung một bộ).

**Cặp 5: Guard.** *LockoutGuard* ghi `waitStartMonotonic` là ms. *Đọc ở màn S3 (đếm ngược)* hiểu là giây. Hoặc đọc giá trị `bootId` của Android (`BOOT_COUNT`, số nguyên) dưới dạng số, trong khi iOS trả về chuỗi UUID.

**Đề xuất: AD-20 mới.**

> ### AD-20 — Schema v1 của mọi file là hợp đồng, có một codec duy nhất
>
> - **Binds:** AD-4, AD-6, AD-8, AD-10, AD-13; FR-26, FR-35, FR-61, FR-62
> - **Prevents:** hai story ghi/đọc cùng một file theo hai dạng; file mẫu chỉ khớp với code của agent commit trước.
> - **Rule:** Mỗi file có đúng một codec trong `lib/core/format/` (`header_codec`, `vault_file_codec`, `export_codec`, `settings_codec`, `guard_codec`). Không nơi nào khác được gọi `jsonEncode`/`jsonDecode` hay tự ghép byte cho các file này. Số nguyên nhị phân là little-endian. Thời gian là UTC epoch ms (`int`). Id là UUIDv4 chữ thường, có gạch nối. Mọi key trong bảng đều **bắt buộc**. Thiếu key, sai kiểu hoặc `v` lạ thì codec trả về `corrupt` (riêng `settings` và `guard` theo luật riêng ở AD-13 và AD-8).
>
> | File | Dạng v1 |
> |---|---|
> | `header` (nhị phân) | `magic "PAKV"`[4] · `version` u16=1 · `kdfAlg` u8 (1 = Argon2id13) · `opslimit` u32 · `memlimit` u64 (**byte**) · `salt`[16] · `wrapNonce`[24] · `wrappedDek`[48] · `kcv`[16] · `checksum`[32]. Associated data khi bọc DEK = mọi byte từ `magic` đến hết `salt`. Ý nghĩa `kcv` và `checksum`: AD-4. |
> | Lớp bọc `cards`/`recent`/`draft` | `nonce`[24] · `ciphertext‖tag`. Associated data = ASCII `"PAK-VAULT/<type>/v1"`, với `<type>` ∈ `cards`, `recent`, `draft`. |
> | `cards` (JSON bên trong) | `{"v":1,"cards":[{"id":uuid,"title":str,"username":str,"password":str,"note":str,"createdAt":int}]}`. `note` rỗng là `""`, không bao giờ `null` hay vắng mặt. |
> | `recent` | `{"v":1,"items":[{"password":str,"recordedAt":int}]}` |
> | `draft` | `{"v":1,"mode":"create"\|"edit","cardId":uuid,"title":str,"username":str,"password":str,"note":str,"updatedAt":int}`. Với `create`, `cardId` được cấp sẵn khi mở form. Không có bản nháp = không có file `draft`. |
> | Export (nhị phân) | `magic "PAKX"`[4] · `version` u16=1 · `opslimit` u32 · `memlimit` u64 (byte) · `salt`[16] · `nonce`[24] · `ciphertext‖tag`. Associated data = mọi byte trước `ciphertext`. |
> | Payload export (JSON) | `{"v":1,"exportedAt":int,"cards":[{"title":str,"username":str,"password":str,"note":str,"createdAt":int}]}`. Không có `id`. |
> | `settings` (JSON) | `{"v":1,"language":"vi"\|"en","appearance":"system"\|"light"\|"dark","autolockMin":1\|3\|5\|10,"sessionMin":1\|3\|5\|10,"clipboardMin":1\|3\|5\|10,"gen":{"length":4..99,"upper":bool,"lower":bool,"digits":bool,"special":bool},"lastExportAt":int\|null}` |
> | `guard` (JSON) | `{"v":1,"failCount":0..10,"waitBootId":str\|null,"waitStartMono":int\|null,"wiping":bool}`. `bootId` luôn là **chuỗi** trên cả hai nền tảng. |
>
> Sheet tạo mật khẩu ánh xạ chip sang `gen` theo FR-35 (`123`→`digits`, `ABC`→`upper`, `!@#`→`special`) và không đọc/ghi `lower`. File mẫu `test/fixtures/export/v1.pakx` được sinh từ bảng này bằng script trong `tool/`, không phải bằng code app. CI còn có golden test cho `header`, `settings` và `guard`.

---

## A2 — Critical — Header hỏng bị coi là sai mật khẩu, dẫn tới xóa dữ liệu

**Spine nói gì.** AD-4: "mở bọc DEK thành công = mật khẩu đúng; sau đó mới giải mã dữ liệu, lỗi ở bước này = Dữ liệu bị hỏng". Header "chứa… một key check value độc lập với các file dữ liệu", nhưng không nói KCV được tính từ đâu và dùng để làm gì.

**Cặp: "Mở khóa" và "Định dạng header".**
- *Agent A* coi việc AEAD mở bọc DEK thành công chính là phép kiểm tra (KCV thừa, ghi 16 byte 0 cho đủ field).
- *Agent B* tính KCV = HMAC(DEK, …), nên vẫn phải mở bọc DEK trước rồi mới kiểm được KCV.
- Với cả hai, **một bit hỏng trong `wrappedDek`, `salt` hay tham số KDF** (do lỗi flash hoặc lỗi của chính app) làm *mọi* mật khẩu đều mở bọc thất bại. Kết quả bị quy thành `wrongPassword`: bộ đếm tăng, thêm 9 lần nữa thì **tự xóa**. Đây chính là điều FR-7 cấm ("Vault bị hỏng không phải là sai mật khẩu… không bao giờ kích hoạt việc xóa") và vi phạm TC-6. Người dùng đúng mật khẩu thấy "Sai mật khẩu" và không biết phải dừng lại.
- Cặp phụ: hai agent đọc dòng "Checking → Corrupt: đúng nhưng dữ liệu hỏng → **hoàn** bộ đếm" khác nhau: trừ đi 1, hay đặt về 0 như "Đăng nhập đúng thì bộ đếm về 0" (FR-5). Số lần thử còn lại hiển thị sẽ khác nhau (xem thêm A4).

**Đề xuất: sửa Rule của AD-4.** Thay câu "Thứ tự mở khóa…" bằng:

> Header có hai lớp kiểm tra tách biệt (layout ở AD-20). (1) `checksum` = BLAKE2b-256 (`crypto_generichash`, không khóa) trên mọi byte đứng trước nó. Lớp này không phụ thuộc mật khẩu. (2) `kcv` = `crypto_generichash`(16 byte, thông điệp `"PAK-KCV-v1"`, khóa = KEK). Thứ tự mở khóa:
> 1. Đọc header. Sai kích thước, sai `magic`/`version`, `checksum` lệch, hoặc tham số ngoài khoảng của AD-5 thì trả về **`corrupt`**. **Không** chạm `LockoutGuard`, không chạy KDF.
> 2. `LockoutGuard` ghi tăng bộ đếm (AD-8), rồi chạy KDF ra KEK.
> 3. So `kcv` bằng phép so khớp hằng thời gian. Lệch thì trả về **`wrongPassword`**.
> 4. `kcv` khớp thì mật khẩu đã được chứng minh là đúng: `LockoutGuard.recordSuccess()` (failCount = 0, xóa thời gian chờ) **trước** mọi bước sau. Mở bọc DEK lỗi, hoặc giải mã file dữ liệu lỗi, thì trả về **`corrupt`**.
>
> Như vậy `corrupt` không bao giờ làm tăng bộ đếm, và luôn đưa bộ đếm về 0 khi mật khẩu đúng. Đổi mật khẩu chính tính lại `salt`, tham số, `wrapNonce`, `wrappedDek`, `kcv` và `checksum` trong **một** lần ghi `header`. Kiểm tra lại mật khẩu (FR-13, FR-51) dùng bước 1, 3, 4 nhưng bỏ phần `LockoutGuard`.

Sửa sơ đồ trạng thái: `Ready --> Corrupt: header hỏng (không đếm)` và `Checking --> Corrupt: kcv đúng, dữ liệu hỏng → failCount = 0`.

---

## A3 — Critical — Ghi cũ sau khóa/xóa, và không ai sở hữu quy trình xóa

**Spine nói gì.** AD-3: `VaultSession` là nơi duy nhất ghi thư mục vault. AD-9: khi khóa, "chờ thao tác ghi đang chạy… → hủy thao tác chưa bắt đầu ghi → `VaultSession.lock()`". Convention Bản nháp: "`saveDraft` sau mỗi thay đổi form, debounce ≤ 500 ms". AD-7 mô tả các bước xóa nhưng **không nói ai chạy**: thư mục vault thuộc `VaultSession`, `guard` thuộc `LockoutGuard`, `settings` thuộc `SettingsStore`, clipboard thuộc `ClipboardService`.

**Cặp 1: Form card và SessionController, debounce bản nháp.**
- *Story "Form card"* đặt timer debounce 500 ms trong `State` của widget (convention không nói timer nằm ở đâu), và gọi `saveDraft` khi timer chạy.
- *Story "Khóa phiên"* làm đúng AD-9: thao tác "chưa bắt đầu ghi" thì hủy. Timer debounce chưa chạy nên không phải "đang ghi", và story này không biết tới timer đó.
- **Kết quả 1:** khóa mất tối đa 500 ms gõ cuối cùng. Người dùng vừa dán mật khẩu rồi chuyển app, bản nháp mở lại không có mật khẩu (FR-26).
- **Kết quả 2 (tệ hơn):** widget bị gỡ thì `dispose()` "flush" bản nháp, đúng lúc `VaultSession.lock()` đã hủy `SecureKey`. Bản nháp hoặc ném lỗi, hoặc mất.
- **Kết quả 3 (critical):** người dùng khóa, rồi bấm "Xóa & Tạo tài khoản mới". `WipeCoordinator` (ai đó) xóa thư mục vault. Đúng lúc đó timer debounce còn sót lại gọi `saveDraft` trên instance `VaultSession` cũ (singleton, `lock()` chỉ gỡ tham chiếu). `AtomicFileWriter` tạo lại thư mục để ghi file tạm, sinh ra `vault/draft` mã hóa bằng DEK cũ. Người dùng tạo tài khoản mới (chỉ ghi `header`), đăng nhập, `draft` không giải mã được bằng DEK mới, ra **"Dữ liệu bị hỏng" trên tài khoản vừa tạo**. Lúc này người dùng chỉ còn cách xóa thêm lần nữa.

**Cặp 2: Import và Khóa, future còn chạy dở.**
- *Story "Import"* gọi KDF + giải mã (~2 s), rồi `await` kết quả và đẩy sang S26. Người dùng đã bấm Xác nhận thì gọi `vaultSession.importCards`.
- *Story "Khóa phiên"* khóa trong lúc KDF đang chạy (đúng: chưa ghi thì hủy). Nhưng future KDF vẫn chạy xong. Nếu `VaultSession` là singleton và người dùng **đã đăng nhập lại** trong 2 s đó (hiếm nhưng làm được), lời gọi tiếp theo sẽ ghi vào phiên mới mà không qua xác nhận. Nếu chưa đăng nhập lại, lời gọi chạm vào một session đã khóa, và hành vi phụ thuộc cách mỗi agent cài đặt.

**Cặp 3: Tạo tài khoản và Mở khóa, thứ tự file.**
- *Story "Tạo tài khoản"* ghi `header` trước rồi `cards`/`recent` (rỗng). Crash ở giữa: có header, thiếu `cards`.
- *Story "Mở khóa"* coi thiếu `cards` là `corrupt`. Tài khoản mới thành "Dữ liệu bị hỏng".
- Ngược lại, nếu thiếu file mà coi là rỗng, thì kẻ có quyền ghi đĩa xóa `cards` sẽ ra một vault rỗng "hợp lệ", và người dùng không được cảnh báo.

**Cặp 4: Ba lối vào xóa, ba bản cài đặt.** Xóa ở lần sai thứ 10 (`LockoutGuard`), xóa qua S4 (`features/auth` gọi…?), và xóa nốt khi khởi động (bootstrap `main`) sẽ do ba story viết. AD-7 cho phép mỗi story tự sắp thứ tự. Một story xóa thư mục trước rồi mới đặt cờ `wiping`, crash giữa chừng thì còn `cards` nhưng không có `header`. Máy trạng thái coi là `NoAccount`, người dùng tạo tài khoản mới, và các file cũ nằm cạnh header mới.

**Đề xuất.**

*Sửa AD-3, thêm vào Rule:*
> Mỗi lần đăng nhập tạo **một instance `VaultSession` mới**. Sau `lock()`, instance đó vô hiệu vĩnh viễn: mọi method trả về `VaultResult.locked` và không làm I/O. Features chỉ lấy instance qua `ref.watch(unlockedSessionProvider)`. `VaultSession` tuần tự hóa mọi I/O qua một hàng đợi (mỗi lúc một lần ghi). Bản nháp: features gọi `VaultSession.updateDraft(d)` mỗi lần thay đổi. **Debounce ≤ 500 ms nằm trong `VaultSession`**, không nằm trong widget. `lock()` **flush bản nháp đang chờ trước** khi hủy `SecureKey` (flush được tính là "thao tác ghi đang chạy" theo FR-16). Widget không bao giờ ghi bản nháp trong `dispose()`.

*Sửa AD-7, thêm vào Rule:*
> `AtomicFileWriter` **không bao giờ tạo thư mục cha**: thư mục không tồn tại thì trả lỗi. Tạo tài khoản: xóa mọi thứ còn sót trong thư mục vault → tạo thư mục → ghi `cards` và `recent` rỗng → ghi `header` **cuối cùng** (header là điểm commit). Mở khóa: thiếu `cards` hoặc `recent` khi đã có `header` là `corrupt`. Thiếu `draft` là không có bản nháp. Khởi động mà không có `header` nhưng thư mục vault có file khác thì xóa các file đó trước khi hiện S1.

*AD-21 mới:*
> ### AD-21 — `WipeCoordinator` là chủ duy nhất của quy trình xóa
>
> - **Binds:** FR-4, FR-9, FR-12, TC-6; AD-3, AD-7, AD-8
> - **Prevents:** ba lối vào xóa có ba thứ tự khác nhau; xóa dở để lại file cũ cạnh tài khoản mới.
> - **Rule:** Chỉ `services/wipe_coordinator.dart` chạy quy trình xóa. Lần sai thứ 10, nút S4 và khởi động khi thấy cờ đều gọi `WipeCoordinator.wipe()`. Các bước theo thứ tự, **mỗi bước idempotent** (làm lại khi đã xong thì không lỗi): (1) `LockoutGuard.markWiping()` (một lần ghi guard) → (2) vô hiệu `VaultSession` hiện hành nếu có → (3) xóa `vault/header` **trước**, rồi các file còn lại, rồi thư mục → (4) `SettingsStore.clearLastExport()` → (5) `ClipboardService.clearIfOurs()` (chỉ có tác dụng nếu process hiện tại là process đã copy, xem A13) → (6) `LockoutGuard.reset()` (`failCount = 0`, gỡ cờ, một lần ghi). Bootstrap gọi `resumeIfNeeded()` **trước** khi quyết định hiện S1 hay S3.

---

## A4 — High — Ngữ nghĩa của file guard để ngỏ (FR-5, FR-6)

**Spine nói gì.** AD-8: tăng và ghi **trước** khi chạy KDF. Thời gian chờ đo bằng `(bootId, monotonicMs)`. `bootId` khác thì "thời gian chờ bắt đầu lại đủ 30 phút". Trạng thái lúc khởi động: `Wiping` (có cờ) / `NoAccount` / `Ready`.

**Cặp 1: Bị tắt app giữa lần kiểm tra thứ 10.** `failCount` = 10 đã được ghi, KDF chưa xong thì app bị tắt. Khởi động lại: không có cờ `wiping`, có `header`, nên sơ đồ cho vào `Ready`.
- *Agent A (máy trạng thái)* hiện "Còn 0 lần thử" và vẫn cho nhập. Lần nhập sau thành `failCount` 11, ngoài miền giá trị.
- *Agent B* coi `failCount >= 10` là phải xóa.
- PRD nói rõ (rủi ro chấp nhận, FR-5): lần đó *tính là sai và có thể dẫn đến xóa*. Agent A vi phạm FR-4/FR-5 mà không vi phạm câu nào của spine.

**Cặp 2: Lúc nào bắt đầu chờ.**
- *Agent A* ghi `waitStart` **sau** khi KDF trả về sai (lần ghi thứ hai).
- Tắt app giữa lần sai thứ 5 → `failCount` = 5, `waitStart` = null. *Agent B (S3, đếm ngược)* thấy không có thời gian chờ nên cho nhập ngay.
- Lặp lại kiểu tắt app này thì lần 5–9 không phải chờ (TC-3: "kể cả khi tắt app").

**Cặp 3: Phát hiện khởi động lại máy nhưng không ghi lại.**
- *Agent A* phát hiện `bootId` khác thì tính lại thời gian chờ **trong RAM** và đếm ngược từ 30:00.
- Người dùng chờ 29 phút, tắt app, mở lại: `bootId` trong file **vẫn** khác `bootId` hiện tại, nên lại đếm từ 30:00. Thời gian chờ thành **vô hạn** nếu người dùng không giữ app mở đủ 30 phút liền. AD-8 chỉ nói "bắt đầu lại", không nói phải ghi xuống.

**Cặp 4: `bootId` trên iOS.** AD-11 chỉ có `mach_continuous_time` cho iOS, không có nguồn `bootId`.
- *Agent iOS A* dùng `kern.boottime`. Giá trị này dịch chuyển khi người dùng chỉnh đồng hồ, nên chỉnh đồng hồ sẽ khởi động lại thời gian chờ (an toàn nhưng lệch FR-6).
- *Agent iOS B* sinh UUID mỗi lần mở process. Mỗi lần mở app là mất thời gian chờ đã chờ (lệch FR-6 "không mất khi tắt app").

**Cặp 5: Ghi lỗi (đĩa đầy).** *Agent A* bỏ qua lỗi ghi tăng bộ đếm rồi vẫn chạy KDF (fail-open). Kết quả: đĩa đầy thì thử không giới hạn.

**Cặp 6: Guard không đọc được.** *Agent A* coi là `failCount = 0`. *Agent B* coi là hỏng và chặn đăng nhập. Hai bản cài đặt cho hai trải nghiệm khác nhau, và có một bản khóa người dùng khỏi dữ liệu của chính mình (TC-6).

**Đề xuất: thêm vào Rule của AD-8.**

> Schema guard ở AD-20. Luật ghi:
> - **Trước KDF**, một lần ghi: `failCount += 1`. Nếu giá trị mới nằm trong 5–9 thì đặt luôn `waitBootId`/`waitStartMono` = thời điểm hiện tại (thời gian chờ bắt đầu ngay từ lần thử này). Ghi lỗi thì **hủy lần thử, không chạy KDF**, báo lỗi chung. Không bao giờ fail-open.
> - **Mật khẩu đúng** (kể cả khi sau đó ra `corrupt`, xem AD-4): một lần ghi `failCount = 0`, `wait* = null`.
> - **Chuẩn hóa khi khởi động**, chạy trước khi hiện S3, theo thứ tự: `wiping = true` → `WipeCoordinator.resumeIfNeeded()`. `failCount >= 10` → coi là lần sai thứ 10 (FR-5) → `WipeCoordinator.wipe()`. `failCount` 5–9 mà `wait* = null` → đặt thời gian chờ = bây giờ. `waitBootId` ≠ `bootId` hiện tại, hoặc `monotonicMs < waitStartMono` → đặt thời gian chờ = bây giờ. **Mọi lần đặt lại đều ghi xuống ngay** rồi mới hiển thị đếm ngược.
> - Guard thiếu hoặc không đọc được trong khi có `header`: tạo lại với `failCount = 0` (cùng lớp rủi ro đã chấp nhận: root sửa được guard).
> - `bootId`: Android = `Settings.Global.BOOT_COUNT` dạng chuỗi. iOS = `sysctl kern.bootsessionuuid`. Cả hai lấy qua nhóm đồng hồ của Pigeon (AD-11).
> - Chuỗi sai lần trước giữ trong RAM dưới dạng **digest có khóa** (A5), không phải chuỗi gốc.

---

## A5 — High — Bản rõ còn sống sau `lock()` ngoài phạm vi Riverpod

**Spine nói gì.** AD-3: `lock()` "bỏ mọi tham chiếu tới model giải mã". AD-9: "Mọi Riverpod provider chứa dữ liệu giải mã phải phụ thuộc provider của phiên". Không có luật nào cho widget state, cho service sống lâu hơn phiên, hay cho bản rõ không lấy từ vault.

**Cặp 1: Khóa phiên và cây widget.**
- *Agent A (SessionController)* làm "gỡ toàn bộ navigation về S3" bằng cách push S3 lên root navigator với `pushAndRemoveUntil`.
- `CupertinoTabScaffold` có **navigator riêng cho từng tab**: S20 trong tab Cài đặt và form S9 với `TextEditingController` chứa mật khẩu card không nằm trong root stack, hoặc `State` của tab được giữ lại. Bản rõ vẫn nằm trong RAM dưới màn Login cho tới khi GC thu dọn, có khi không bao giờ thu dọn.
- *Agent B* thay root. Cả hai đều theo đúng AD-9.

**Cặp 2: ClipboardService và lock().** AD-17: Android "so khớp nội dung khi trở lại tiền cảnh". *Agent clipboard* giữ `String _lastCopied` để so. Service này **không** thuộc phiên, nên sống qua lock, và mật khẩu card nằm trong RAM vô thời hạn (NFR-4). *Agent session* tin rằng lock đã dọn sạch.

**Cặp 3: ExportService và VaultSession, xem trước import.** Import giải mã payload ở `ExportService`/core rồi giữ danh sách card bản rõ trong lúc chờ S26. Như vậy có **hai nơi giữ dữ liệu giải mã**, trái tinh thần AD-3, và nơi thứ hai không bị `lock()` dọn. Export cũng giữ một `Uint8List` JSON bản rõ không bao giờ được xóa trắng.

**Cặp 4: Generator.** Mật khẩu đang hiện ở S14/S11 không phải "dữ liệu giải mã" theo chữ của AD-9, nên agent generator để provider sống suốt đời app. Sau lock, mật khẩu mới vừa dùng cho Shopee vẫn còn trong RAM, và còn hiện lại khi đăng nhập lại.

**Cặp 5: LockoutGuard.** "Chuỗi sai lần trước chỉ giữ trong RAM" là một ứng viên mật khẩu chính, thường chỉ sai một ký tự, dạng `String` không xóa được, giữ suốt process.

**Đề xuất: thêm vào AD-9, và AD-22 mới.**

*AD-9, thay câu "gỡ toàn bộ navigation về S3":*
> Toàn bộ UI sau đăng nhập (tab scaffold, navigator từng tab, mọi sheet/dialog) nằm dưới **một** `KeyedSubtree` có key là epoch của phiên. Khóa = thay subtree đó bằng S3 ở cấp root. **Cấm** push S3 lên trên UI cũ. Sheet/dialog sau đăng nhập phải mở bằng navigator nằm *trong* subtree đó (không dùng `useRootNavigator: true` ra ngoài subtree).

> ### AD-22 — Vòng đời bản rõ
>
> - **Binds:** NFR-4, FR-26, FR-65; AD-3, AD-9, AD-17
> - **Prevents:** bản rõ sống qua lock trong service, widget hoặc buffer.
> - **Rule:** Bản rõ gồm: nội dung card, Recent, bản nháp, payload import/export, mật khẩu đang hiện ở generator, và mọi chuỗi gõ vào `SecretField`. (1) Chỉ được giữ trong `VaultSession` hoặc trong provider/`State` thuộc subtree của phiên (AD-9). Payload import đã giải mã được giao cho `VaultSession.stageImport()` và bị bỏ khi `lock()` hoặc khi bấm Hủy. (2) Service sống lâu hơn phiên (`ClipboardService`, `LockoutGuard`, `SettingsStore`) **không giữ bản rõ**. Chúng chỉ giữ digest = `crypto_generichash`(16 byte, khóa ngẫu nhiên 32 byte sinh khi mở process, chỉ nằm trong RAM), cộng với `changeCount` (iOS) và hạn đơn điệu. Android so khớp bằng cách hash nội dung clipboard hiện tại. (3) Mọi `Uint8List` chứa bản rõ (kết quả giải mã, JSON export trước khi mã hóa) được `fillRange(0)` ngay sau khi dùng. (4) `SecretField` tự gọi `controller.clear()` trong `dispose()`. (5) Model chứa bí mật override `toString()` để che giá trị. (6) Có widget test: sau `lock()`, không còn `SecretField`/`SecretText` trong cây, và `ProviderContainer` không còn provider nào thuộc phiên.

---

## A6 — High — Loại khỏi backup, fsync thư mục, và file tạm

**Spine nói gì.** AD-11: "iOS: mọi file của app đặt cờ `isExcludedFromBackup`", và Pigeon có **đúng** các nhóm đồng hồ, clipboard, loại khỏi backup. AD-7: `AtomicFileWriter` trong **core** (Dart thuần) làm "ghi file tạm → fsync → rename đè → **fsync thư mục**". AD-13: ngoài vault, app **chỉ** ghi `guard` và `settings`.

**Cặp 1: Platform và AtomicFileWriter (NFR-8, rò rỉ ra iCloud).**
- *Agent platform* đặt cờ loại khỏi backup trên từng file ngay khi tạo (đúng chữ "mọi file").
- *Agent core* viết `AtomicFileWriter` theo đúng AD-7. Rename đè tạo ra **inode mới, không có cờ**: file tạm không được đánh dấu, mà core lại không được gọi platform (AD-2).
- Sau lần lưu card đầu tiên, `cards`, `header`, `guard` và `settings` đều vào iCloud Backup. Đường tấn công 3 của PRD (chép file ra rồi giải mã offline) mở ra trên mọi máy có bật iCloud Backup.

**Cặp 2: Core và AD-11, fsync thư mục.** `dart:io` không có API fsync thư mục. *Agent core* hoặc bỏ bước này (vi phạm AD-7), hoặc cần native. Nhưng AD-11 liệt kê các nhóm Pigeon theo kiểu **đóng** ("đúng các nhóm"), nên thêm hàm vào Pigeon lại vi phạm AD-11. Hai agent sẽ chọn hai cách trái nhau, và một trong hai luôn sai theo spine.

**Cặp 3: Export và AD-13.** `share_plus` cần một file trên đĩa. *Agent export* ghi `PAK-2026-10-27.pakx` vào `getTemporaryDirectory()`, vi phạm chữ "chỉ ghi `guard` và `settings`". File này đã mã hóa nhưng **sống mãi** trong cache. Trên Android, cache không thuộc `dataExtractionRules` nếu rule viết thiếu domain. *Agent import*: `file_selector` trên Android có thể copy file đã chọn vào cache, và file này cũng không được dọn.

**Đề xuất.**

*Sửa AD-11, thay câu iOS:*
> Mọi file của app nằm dưới **một** thư mục gốc `ApplicationSupport/pak/` (`vault/`, `guard`, `settings`, `tmp/`). iOS: đặt `isExcludedFromBackup` trên **thư mục `pak/`**, đặt lại ở mỗi lần khởi động **trước mọi I/O** (cờ ở thư mục bao luôn nội dung nên không mất khi rename file con). Android: `dataExtractionRules` loại trừ mọi domain (`root`, `file`, `database`, `sharedpref`, `external`) cho cả `cloud-backup` và `device-transfer`, và `fullBackupContent` tương ứng cho API < 31. Nhóm Pigeon gồm: đồng hồ (`bootId`, `monotonicMs`), clipboard, backup, **`fsyncDirectory(path)`**. Thêm nhóm khác thì phải sửa AD này.

*Sửa AD-7:*
> File tạm của `AtomicFileWriter` nằm **cùng thư mục** với file đích (`<tên>.tmp`), không bao giờ nằm ở thư mục tạm của hệ thống. Fsync thư mục đi qua port `FileSyncPort` (cài bằng Pigeon `fsyncDirectory`). Khởi động: xóa mọi `*.tmp` còn sót.

*Sửa AD-13:*
> Ngoài `vault/`, app chỉ ghi `guard`, `settings` và thư mục `pak/tmp/`. `pak/tmp/` chỉ chứa **một** file export đã mã hóa đang chờ chia sẻ. File này bị xóa khi menu chia sẻ đóng và ở mỗi lần khởi động. File do trình chọn file copy vào cache của app bị xóa ngay sau khi đọc xong.

---

## A7 — High — Đồng hồ và "vào nền" chưa chỉ định

**Spine nói gì.** AD-9: autolock và giới hạn phiên "đo bằng đồng hồ đơn điệu: lúc vào nền, lúc trở lại". AD-8 mới nói rõ nguồn đồng hồ (port, tính cả lúc ngủ) cho guard. AD-17 không nói clipboard dùng đồng hồ gì.

**Cặp: SessionController và Port đồng hồ.**
- *Agent session* dùng `Stopwatch` của Dart: đơn điệu thật, đúng chữ AD-9. Trên iOS, `Stopwatch` dựa trên `mach_absolute_time`, **không tính lúc máy ngủ**. Người dùng để app chạy nền, khóa màn hình 2 giờ rồi mở lại: Stopwatch chỉ đếm được vài giây máy thức, nên **không autolock** (FR-15) và không hết phiên (FR-14).
- *Agent clipboard* dùng `DateTime.now()` cho hạn Clear Clipboard trên Android. Người dùng chỉnh đồng hồ lùi thì không bao giờ xóa clipboard.
- "Vào nền": *agent A* bắt `AppLifecycleState.inactive`, sự kiện xảy ra cả khi kéo Control Center hoặc lúc share sheet/trình chọn file trên iOS hiện lên. *Agent B* bắt `paused`. Hai bản cho hai mốc tính autolock khác nhau.
- Khóa do quá hạn được phát hiện **lúc trở lại** (`resumed`). Lúc đó app ở tiền cảnh hay ở nền? AD-9 nói "nếu đang ở tiền cảnh thì `clearIfOurs()`". Hai agent hiểu ngược nhau, nên một bản xóa clipboard, một bản không.

**Đề xuất: thêm vào AD-9.**
> **Mọi hạn thời gian** (autolock, giới hạn phiên, Clear Clipboard trên Android, thời gian chờ guard) tính bằng `ClockPort.monotonicMs` (tính cả lúc máy ngủ). Cấm `Stopwatch`, `DateTime.now()` và `Timer` làm nguồn sự thật cho hạn. `Timer` chỉ được dùng để *đánh thức* việc kiểm tra. "Vào nền" = lần đầu nhận `AppLifecycleState.hidden` (hoặc `paused` nếu `hidden` không có) sau `resumed`. `inactive` không tính. Khi nhận `resumed`, thứ tự kiểm tra là: (1) `ClipboardService.onResume()` xóa nếu quá hạn và còn là giá trị của app; (2) `SessionController.evaluate()` khóa nếu quá hạn. Khóa phát hiện ở bước (2) được coi là khóa ở tiền cảnh (gọi `clearIfOurs()`).

---

## A8 — Medium — Lưu card ghi hai file, trái AD-7

AD-7: "Mỗi thao tác nghiệp vụ ghi đúng một file". Lưu card cần ghi `cards` **và** xóa `draft` (FR-26).
- *Agent A* theo chữ AD-7: chỉ ghi `cards`, để bản nháp nằm lại. Lần đăng nhập sau, S6 hỏi khôi phục một card đã lưu, và lưu lần nữa sinh card trùng.
- *Agent B* ghi cả hai file. Crash giữa hai lần ghi cũng sinh card trùng.

**Đề xuất (sửa AD-7, dùng `cardId` có sẵn trong schema draft ở AD-20):**
> Mỗi thao tác ghi đúng **một file dữ liệu**. Việc xóa `draft` sau Lưu là bước dọn dẹp idempotent đi sau. Lưu = **upsert theo `draft.cardId`** vào `cards`. Khi mở khóa, nếu `draft.mode = create` mà `cardId` đã có trong `cards`, hoặc `mode = edit` mà `cardId` không còn trong `cards`, thì xóa bản nháp, không hỏi S6. Export ghi file export và `settings.lastExportAt` (hai file, được phép, vì file export nằm ngoài vault).

## A9 — Medium — `settings` có nhiều nơi cùng ghi

AD-13 không nêu chủ sở hữu. Màn Cài đặt (`SettingsStore`), generator (tiêu chí FR-35), export (`lastExportAt`) và `WipeCoordinator` đều ghi. Mỗi bên tự đọc file, sửa, rồi ghi lại, nên ghi chồng làm mất cập nhật, ví dụ đổi tiêu chí generator đúng lúc export xong làm mất ngày export. Ngoài ra, slider ở sheet đổi liên tục và mỗi bước đều ghi + fsync.

**Đề xuất (thêm vào AD-13):**
> Chỉ `SettingsStore` đọc/ghi `settings`. Store giữ một bản trong RAM làm nguồn sự thật, ghi **toàn bộ snapshot** theo hàng đợi tuần tự, gom các thay đổi trong 300 ms. Field thiếu hoặc không hợp lệ thì dùng giá trị mặc định **của riêng field đó**. Ngôn ngữ mặc định lấy theo locale máy ở lần đọc đầu rồi ghi xuống. File không đọc được thì dùng toàn bộ mặc định, **không bao giờ chặn Login**.

## A10 — Medium — Import không kiểm nội dung payload và kích thước

AD-10 chỉ kiểm định dạng và tham số KDF trước khi chạy KDF. *Agent import A* đọc nguyên file 2 GB vào RAM. *Agent B* thêm card có `title` rỗng (FR-22 bắt buộc), hoặc `createdAt` âm. Lỗi kiểu này làm vỡ thứ tự sắp xếp và form sửa.

**Đề xuất (thêm vào AD-10):**
> Trước khi đọc nội dung: file > 8 MiB thì "File không hợp lệ". Sau khi giải mã: payload phải đúng AD-20, ≤ 10 000 card, mỗi card có `title`/`username`/`password` không rỗng, chuỗi ≤ 64 KiB, `createdAt` ≥ 0. Chỉ cần **một** card sai là từ chối cả file ("File không hợp lệ"). Không bao giờ import một phần.

## A11 — Medium — Bản rõ lọt vào log ở bản release

AD-18 cấm *chủ động* log bí mật. Nhưng `jsonDecode` ném `FormatException` có kèm **đoạn văn bản nguồn**, tức là JSON vừa giải mã. `FlutterError.presentError` và `print` vẫn ghi ra logcat ở bản release, và `debugPrint` không tự tắt. *Agent core* để exception đi lên. *Agent bootstrap* không cài bộ xử lý lỗi. Kết quả: nội dung card nằm trong logcat.

**Đề xuất (thêm vào AD-18):**
> Codec trong core bắt **mọi** exception và trả về `corrupt` không kèm thông điệp. Bản release: `debugPrint` = no-op; `FlutterError.onError` và `PlatformDispatcher.instance.onError` nuốt lỗi, không in ra. Lint cấm `print(` trong `lib/`.

## A12 — Medium — KDF chạy trên UI isolate

Lời gọi Argon2id 1–2 s qua FFI là lời gọi đồng bộ. *Agent A* gọi thẳng trên UI isolate, nên activity-indicator đứng hình (trái EXPERIENCE), sự kiện vòng đời và timer bị trễ, và trên Android có thể ra ANR với lần hiệu chỉnh nhiều vòng. *Agent B* dùng `Isolate.run`. Hai bản khác nhau về thời gian ở các phép đo AD-5.

**Đề xuất (thêm vào AD-5):**
> KDF và hiệu chỉnh luôn chạy ngoài UI isolate (`sodium` `runIsolated` hoặc tương đương). Kết quả trả về là `SecureKey`. Không truyền mật khẩu hay khóa qua kênh log/debug.

## A13 — Low — Rủi ro cần ghi rõ

- **Recent khi đồng hồ bị chỉnh lùi:** mục Recent có `recordedAt` > bây giờ (đồng hồ bị chỉnh lùi) sẽ không bao giờ hết hạn. Đề xuất: khi đọc, coi `recordedAt > now + 5 phút` là đã hết hạn.
- **Clipboard khi xóa ở process mới:** xóa ở lần sai thứ 10, hoặc xóa nốt khi khởi động, chạy trong một process mới. Process này không còn digest của giá trị đã copy, nên trên Android không thể "xóa clipboard nếu còn là giá trị app đã copy" (FR-12). iOS vẫn có hạn tự hết. Ghi thành rủi ro chấp nhận trong AD-21, không cố lưu digest xuống đĩa.

---

## Danh sách sửa spine

| Loại | AD | Nội dung |
|---|---|---|
| Mới | AD-20 | Schema v1 cho header, lớp bọc file vault, cards, recent, draft, export, payload, settings, guard; một codec cho mỗi file |
| Mới | AD-21 | `WipeCoordinator`: các bước idempotent, xóa header trước, bootstrap gọi `resumeIfNeeded` |
| Mới | AD-22 | Vòng đời bản rõ: service sống lâu hơn phiên chỉ giữ digest, staging import, xóa trắng buffer, test sau khi lock |
| Sửa | AD-3 | Mỗi phiên một instance; instance đã lock vô hiệu; hàng đợi I/O; debounce bản nháp nằm trong `VaultSession`, flush khi lock |
| Sửa | AD-4 | `checksum` + `kcv` cụ thể; thứ tự 4 bước; `corrupt` đưa bộ đếm về 0 |
| Sửa | AD-5 | KDF chạy ngoài UI isolate |
| Sửa | AD-7 | Không tạo thư mục cha; header ghi cuối khi tạo tài khoản; file tạm cùng thư mục; fsync qua port; "một file dữ liệu", xóa draft là bước dọn dẹp, upsert theo `cardId` |
| Sửa | AD-8 | Thời gian chờ ghi cùng lần tăng bộ đếm; chuẩn hóa khi khởi động (`failCount >= 10` thì xóa, `bootId` lệch thì ghi xuống ngay); fail-closed; guard hỏng thì tạo lại; nguồn `bootId` |
| Sửa | AD-9 | Cây UI có key theo epoch, thay root khi lock; mọi hạn dùng `ClockPort`; định nghĩa vào nền/trở lại; thứ tự xử lý khi trở lại |
| Sửa | AD-10 | Giới hạn kích thước, kiểm nội dung payload, từ chối cả file |
| Sửa | AD-11 | Một thư mục gốc `pak/` loại khỏi backup ở cấp thư mục; rule Android đủ domain; thêm `fsyncDirectory` |
| Sửa | AD-13 | `pak/tmp/` cho export; `SettingsStore` là chủ duy nhất, ghi snapshot, mặc định theo từng field |
| Sửa | AD-17 | Clipboard chỉ giữ digest có khóa; hạn đơn điệu |
| Sửa | AD-18 | Codec nuốt exception; tắt `debugPrint`/`onError` ở release; lint cấm `print` |
| Sửa | Sơ đồ trạng thái | `Ready → Corrupt` (header hỏng, không đếm); `Checking → Corrupt` đưa failCount về 0; trạng thái khởi động `failCount >= 10 → Wiping` |
