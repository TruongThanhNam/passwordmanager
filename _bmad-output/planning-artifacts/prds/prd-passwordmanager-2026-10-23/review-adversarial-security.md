---
title: PAK Manager PRD — Adversarial Security & QA Review
reviewed: prd.md (updated 2026-10-25), addendum.md, .memlog.md (for deliberate decisions), research-digest.md (for cross-check)
date: 2026-10-25
reviewer stance: hostile security reviewer + pedantic QA lead
---

# Adversarial review: PAK Manager PRD

## Kết luận

**Chưa đủ an toàn để chuyển sang UX/architecture.** Các luật bảo mật được viết như những mệnh đề độc lập ("10 lần thì xóa", "3 phút thì xóa clipboard", "khóa thì giữ bản nháp", "import thì ghi đè"). Không có chỗ nào mô tả chúng tương tác với nhau, với vòng đời process của iOS/Android, hay với bàn phím tiếng Việt. Có hai lỗ hổng mà **chính app sẽ phá hủy dữ liệu của người dùng một cách đúng quy định**: chuẩn hóa Unicode/IME (C1) và vault hỏng bị tính là nhập sai (C2). Cả hai vi phạm TC-6 trực tiếp. Có thêm 11 vấn đề mức high, phần lớn là "requirement không thực thi được trên OS thật" hoặc "developer sẽ làm theo hai cách khác nhau".

| Mức | Số lượng |
|---|---|
| Critical | 2 |
| High | 11 |
| Medium | 12 |
| Low | 7 |
| **Tổng** | **32** |

## Rà soát các rủi ro đã chấp nhận (không tranh luận lại, chỉ kiểm hậu quả có được ghi không)

| Rủi ro đã chấp nhận (memlog) | PRD có nêu hậu quả? | Ghi chú |
|---|---|---|
| Không chặn chụp màn hình (NFR-9) | **Không đủ** | Không nói ảnh chụp tự động lên iCloud Photos / Google Photos, không nói Circle to Search / "Ask about screen" đọc được màn hình. Xem M1. |
| Không che ảnh màn hình đa nhiệm (NFR-9) | **Không** | Ảnh snapshot được OS ghi thành **file trong container của app**. Điều này mâu thuẫn trực tiếp với TC-1. Xem M1. |
| Nhập sai mật khẩu cũ ở Change Main Password không bị đếm (FR-11) | Có | FR-11 nêu rõ lý do và hậu quả. OK. |
| Không giới hạn số lần nhập sai mật khẩu export (FR-52) | Một phần | FR-52 nêu luật nhưng không nói câu hệ quả: "file bị lộ thì brute-force offline không giới hạn, lớp bảo vệ duy nhất là độ mạnh mật khẩu export + KDF". Thêm một câu là đủ. (Gộp vào L2.) |
| Không khóa ngay khi chuyển app | Có | Mục 2 và UJ-1 nêu rõ. OK. |
| Người chung máy cố tình nhập sai để xóa dữ liệu | Có | Mục 2 và mục 7. OK. Lưu ý: điều này **không** bao gồm trường hợp *vô tình* xóa (H2). |

---

## CRITICAL

### C1. Mật khẩu có dấu tiếng Việt: app sẽ tự khóa người dùng ra ngoài rồi xóa vault, và file backup trở thành rác

**Vị trí:** FR-2 (chấp nhận Unicode, tiếng Việt có dấu), FR-48 (mật khẩu export theo FR-2), FR-4, addendum "Chuẩn hóa Unicode".

**Tấn công / tai nạn:**
- Addendum nói NFKC giải quyết vấn đề NFC/NFD. **Sai một nửa.** NFKC không hợp nhất được **kiểu đặt dấu cũ/mới**: `hoà` (o + à) và `hòa` (ò + a) là hai chuỗi khác nhau sau mọi dạng chuẩn hóa Unicode. Tương tự `thuý`/`thúy`, `quỳ`… Laban Key, Gboard và bàn phím tiếng Việt của iOS đều có tùy chọn "đặt dấu kiểu cũ/mới", và mặc định khác nhau giữa các bàn phím.
- Nhiều IME **tắt chế độ ghép dấu (Telex/VNI) trong ô mật khẩu**. Ô secure của iOS còn chặn luôn bàn phím bên thứ ba. Người dùng có thể đặt mật khẩu có dấu ở màn hình tạo tài khoản (nếu ô đó cho ghép dấu) nhưng **không gõ lại được** ở màn hình Login. Điều này cần kiểm chứng trên từng bàn phím, nhưng PRD hoàn toàn không đề cập.
- Hậu quả trên Login: mỗi lần gõ "đúng" nhưng sai byte đều tính là một lần sai. Đến lần thứ 5 phải chờ 30 phút, đến lần thứ 10 vault bị xóa. App làm đúng FR-4, và người dùng mất toàn bộ dữ liệu.
- Hậu quả trên Export (UJ-3): mật khẩu export được gõ **một lần**, rồi gõ lại vài năm sau **trên máy khác, OS khác, bàn phím khác**. Đây chính là kịch bản tệ nhất của vấn đề này. File backup "sống còn" (F6) trở thành rác. TC-5 fail.
- FR-2 nói "15 đến 128 ký tự" nhưng không nói đếm theo đơn vị nào: code point, grapheme hay UTF-16, trước hay sau chuẩn hóa. `Ngân hàng` dạng NFD dài hơn dạng NFC. Hai developer sẽ cài đặt hai cách khác nhau, và giá trị biên 15 sẽ cho kết quả khác nhau giữa iOS và Android.

**Đề xuất sửa:**
1. Định nghĩa **một pipeline chuẩn hóa cố định** (ví dụ NFC → chuẩn hóa vị trí dấu thanh tiếng Việt về một kiểu → NFKC), ghi vào PRD như một luật, **đóng băng vĩnh viễn** và gắn vào version của định dạng file export (FR-57).
2. Đếm độ dài theo **grapheme cluster, sau chuẩn hóa**. Ghi rõ như vậy trong FR-2.
3. Khi mật khẩu chính hoặc mật khẩu export chứa ký tự ngoài ASCII: hiện cảnh báo rõ ràng ("có thể không gõ lại được trên bàn phím/máy khác"), và bắt nhập lại xác nhận **trong đúng loại ô secure dùng ở Login/Import**.
4. Thêm acceptance test: ma trận {iOS VN keyboard, Gboard, Laban Key} × {Telex, VNI} × {dấu cũ, dấu mới} phải unlock được cùng một vault và import được cùng một file.

### C2. Vault bị hỏng sẽ bị tính là "nhập sai mật khẩu", rồi bị app tự xóa ở lần thứ 10

**Vị trí:** FR-4, FR-5, NFR-10, TC-6.

**Vấn đề:** PRD chỉ có hai kết quả đăng nhập: đúng hoặc sai. Nếu file vault bị hỏng (lỗi flash, OS update lỗi, bug migration ở phiên bản sau, ghi dở do bug trong chính cơ chế "nguyên tử"), thì mật khẩu **đúng** cũng giải mã thất bại. Một cài đặt ngây thơ sẽ đếm đó là lần sai. Người dùng gõ đúng 10 lần, và app **xóa nốt bằng chứng duy nhất có thể khôi phục được**. NFR-10 cố gắng ngăn hỏng file, nhưng PRD không có trạng thái nào cho trường hợp NFR-10 thất bại.

**Đề xuất sửa:** Thêm FR mới:
- Tách bước *kiểm tra mật khẩu* (key-check hoặc verifier có MAC riêng) khỏi bước *kiểm tra toàn vẹn dữ liệu*. Key-check đúng mà payload hỏng thì là **"Dữ liệu bị hỏng"**: **không** tính vào bộ đếm, **không bao giờ** tự xóa, và hiển thị thông báo kèm hướng dẫn import từ file export.
- Nếu chính verifier bị hỏng (không phân biệt được hai trường hợp) thì cũng không auto-wipe. Hiển thị trạng thái lỗi, chỉ cho phép "Xóa & Tạo tài khoản mới" thủ công.
- Thêm test cho TC-6: làm hỏng 1 byte trong vault → nhập mật khẩu đúng 10 lần → dữ liệu vẫn còn trên đĩa.

---

## HIGH

### H1. FR-34 (Clear Clipboard) không cài đặt được đúng như viết, và hỏng đúng ở hai luồng cốt lõi

**Vị trí:** FR-34, NFR-8, UJ-1, UJ-2.

**Vấn đề:**
- Timer 3 phút chạy trong khi người dùng **đang ở app khác** (UJ-1: Facebook, UJ-2: Shopee + OTP). iOS suspend app sau vài giây (tối đa khoảng 30 giây với background task). Android có thể kill process hoặc trì hoãn bằng Doze. **Timer không chạy.**
- Điều kiện "chỉ xóa nếu clipboard còn đúng giá trị app đã copy" đòi hỏi **đọc** clipboard. Android 10+ **cấm** đọc clipboard khi app không có focus. iOS 16+ hiện hộp thoại "Allow Paste" khi đọc nội dung do app khác copy, tức là đúng lúc người dùng đã copy thứ khác. Như vậy chính điều kiện bảo vệ lại là thứ gây lỗi.
- Không nói clipboard sẽ ra sao khi app khóa, bị kill, khi vault bị xóa ở lần thứ 10, hay khi bấm "Xóa & Tạo tài khoản mới".
- Hệ quả: mật khẩu có thể nằm trong clipboard và trong lịch sử clipboard của bàn phím (Gboard, Samsung, Laban) **vô thời hạn** trên Android dưới 13. Trên Android 13+ là khoảng 1 giờ, do OS tự xóa chứ không phải 3 phút như PRD hứa.

**Đề xuất sửa:** Viết lại FR-34 theo từng nền tảng:
- **iOS:** dùng `UIPasteboard` với `.expirationDate` (OS tự xóa, không cần app chạy) và `.localOnly`. So sánh bằng `changeCount` thay vì đọc nội dung.
- **Android:** timer trong lúc foreground. Khi app quay lại foreground thì xóa nếu đã quá hạn và clipboard vẫn là giá trị của app. Ghi rõ giới hạn: khi app ở nền, việc xóa phụ thuộc OS (Android 13+ khoảng 1 giờ).
- Thêm luật: khi khóa, wipe hoặc Delete&Recreate thì xóa clipboard nếu nó còn là giá trị của app.
- Ghi phần "giới hạn đã chấp nhận" vào PRD để QA không viết test cho một hành vi không thể có.

### H2. "Xóa & Tạo tài khoản mới" chỉ cần một hộp thoại xác nhận, với người dùng gồm cả người lớn tuổi

**Vị trí:** FR-8, TC-6 ("xóa nhầm"), mục 1 (người thân lớn tuổi).

**Vấn đề:** Memlog đã chốt "không cần mật khẩu", và điều đó hợp lý. Nhưng **độ mạnh của bước xác nhận** chưa bao giờ được chốt. Một lần chạm nhầm cộng một lần bấm "OK" là mất toàn bộ vault, không có cách hoàn tác. Nút này nằm **ngay trên màn hình Login**, tức màn hình người dùng thấy nhiều nhất trong ngày, gần nút Đăng nhập. Tình huống "người chung máy cố tình phá" đã bị loại khỏi phạm vi, nhưng **tai nạn** thì không. TC-6 nói rõ không được "xóa nhầm".

**Đề xuất sửa:** Xác nhận hai bước. Bước 1 là cảnh báo không thể hoàn tác và nhắc tới file export. Bước 2 bắt **gõ một từ xác nhận** (ví dụ `XÓA` / `DELETE`), hoặc nhấn giữ 3 giây. Đặt nút ở vị trí phụ (text link, cách xa nút Đăng nhập). Không cần mật khẩu, nên vẫn giữ nguyên quyết định trong memlog.

### H3. Export không yêu cầu xác thực lại: cầm điện thoại đang mở trong 30 giây là lấy được toàn bộ vault

**Vị trí:** FR-48–FR-51, mục 2 ("đường rò rỉ thực tế nhất là file export"), FR-11 (so sánh).

**Tấn công:** Đồng nghiệp hoặc người nhà cầm điện thoại khi app đang mở (phiên còn tối đa 10 phút) → Cài đặt → Export → tự đặt một mật khẩu 15 ký tự → gửi qua Zalo hoặc email cho chính họ. Toàn bộ vault bị lấy đi, **mật khẩu do kẻ tấn công chọn**, và chủ máy không để lại dấu vết gì để phát hiện. PRD bắt nhập mật khẩu cũ để *đổi* mật khẩu chính, nhưng không bắt gì cho thao tác nguy hiểm nhất mà chính PRD đã tự nhận diện.

**Đề xuất sửa:** Export bắt nhập lại **mật khẩu chính** trước khi đặt mật khẩu export. Lần nhập sai ở đây có tính vào bộ đếm FR-4 hay không thì cần chốt rõ (đề xuất: có tính, vì đây là đường exfil). Áp dụng tương tự cho Import (xem H4).

### H4. Import ghi đè bằng file cũ sẽ xóa sạch các card mới mà không có đường lui. TC-6 bị vi phạm "đúng quy định"

**Vị trí:** FR-53, FR-54, FR-58, TC-6.

**Vấn đề:** FR-54 chỉ bảo vệ khỏi *lỗi kỹ thuật* (sai mật khẩu, file hỏng, gián đoạn). Nó không bảo vệ khỏi *lỗi người dùng*: chọn nhầm file export của 6 tháng trước thì toàn bộ card tạo sau đó biến mất. Hộp thoại FR-53 chỉ nói "N card hiện có sẽ bị thay thế", **không nói file chứa bao nhiêu card và được export ngày nào**, nên người dùng không có thông tin để nhận ra mình chọn nhầm. Import cũng không cần xác thực lại, nên người cầm máy đang mở có thể xóa vault bằng một file bất kỳ (chỉ cần biết mật khẩu của chính file đó).

**Đề xuất sửa:**
1. Hộp thoại xác nhận phải hiện: số card hiện có, số card trong file, **ngày export của file**. Cảnh báo đỏ nếu file có ít card hơn hoặc cũ hơn card mới nhất trong vault.
2. Thêm nút "Export bản hiện tại trước" ngay trong hộp thoại.
3. Hoặc giữ một snapshot mã hóa của vault trước import cho tới lần đăng nhập thành công kế tiếp, kèm thao tác "Hoàn tác import".
4. Import bắt nhập lại mật khẩu chính.

### H5. Khóa (FR-12/FR-13) có thể xảy ra giữa một thao tác ghi quan trọng, và PRD không định nghĩa chuyện gì xảy ra

**Vị trí:** FR-12 ("kể cả khi người dùng đang thao tác"), FR-13, FR-11, FR-48–FR-54, NFR-4, NFR-10.

**Vấn đề:** Giới hạn phiên là *tuyệt đối*, tối thiểu 1 phút. NFR-4 bắt xóa key khi khóa. Vậy nếu phiên hết hạn khi đang:
- **Change Main Password:** đang chạy KDF 1–2 giây × 2 rồi re-encrypt toàn bộ card, Recent và bản nháp.
- **Import:** đang giải mã file rồi ghi đè vault.
- **Export:** đang mã hóa và ghi file.
- **Trong file picker hoặc share sheet:** trên Android, file picker (SAF) và share sheet là activity khác, nên app **vào nền** và Autolock bắt đầu đếm. Chọn một thư mục Drive hay một liên hệ Zalo mất hơn 1 phút là app khóa giữa luồng.

Developer A sẽ hoãn khóa, developer B sẽ khóa ngay và wipe key giữa lúc ghi. NFR-10 chỉ nói về "tắt đột ngột", không nói về chính cơ chế khóa của app.

**Đề xuất sửa:** Thêm luật **"vùng tới hạn"** (critical section): khóa vì FR-12/FR-13 bị hoãn cho tới khi thao tác ghi đang chạy kết thúc (commit hoặc rollback), rồi khóa ngay sau đó. Với file picker và share sheet: chốt rõ hoặc là tạm dừng tính Autolock, hoặc là khi khóa thì hủy luồng import đang dở (đề xuất: hủy, không giữ trạng thái import qua lần khóa). Ghi rõ màn hình nào hiện sau khi đăng nhập lại.

### H6. FR-23 (giữ bản nháp) có nhiều lỗ hơn là luật

**Vị trí:** FR-23, NFR-1, NFR-4, FR-11, FR-53, UJ-2.

**Vấn đề:**
- **Lưu bản nháp lúc nào?** Nếu chỉ lưu khi FR-12/FR-13 kích hoạt, thì trường hợp phổ biến nhất (iOS/Android kill app trong nền khi người dùng đang ở Shopee chờ OTP) **không bao giờ** có sự kiện "khóa". Bản nháp mất, mâu thuẫn với lý do memlog đưa ra cho FR-23 (theo TC-6).
- **Mã hóa bằng key nào?** NFR-4 bắt xóa key khi khóa. Bản nháp phải được mã hóa *trước* khi xóa key, và ghi nguyên tử. Trên iOS, khi bị kill thì không có callback nào cả.
- FR-23 không bao gồm: Lock Vault thủ công, app crash, process death.
- Có bao nhiêu bản nháp? Bản nháp tạo mới và bản nháp sửa có khác nhau không? Người dùng rời bản nháp mà không lưu thì bản nháp bị hủy hay giữ lại? Bản nháp có hết hạn không?
- Bản nháp đang sửa card X, rồi Import ghi đè làm card X không còn tồn tại → bấm Lưu thì sao?
- Đổi mật khẩu chính trong khi có bản nháp (nếu bản nháp tồn tại lâu dài): bản nháp có được re-encrypt không?
- Đang mở sheet "Tạo mật khẩu" trong card thì mật khẩu vừa tạo nhưng chưa bấm Use Password có được giữ không?

**Đề xuất sửa:** Viết lại FR-23: "Form tạo/sửa card được **lưu liên tục** (debounce khoảng 1 giây) thành **một** bản nháp mã hóa bằng key vault, ghi nguyên tử. Sau khi đăng nhập lại, app mở lại form. Bản nháp bị hủy khi người dùng Lưu, bấm Hủy, hoặc khi wipe/Delete&Recreate/Import. Nếu card gốc không còn tồn tại thì bản nháp được lưu thành card mới (hoặc hỏi người dùng)." Đồng thời yêu cầu FR-11 re-encrypt cả bản nháp và Recent.

### H7. Bộ đếm sai có nhiều trường hợp biên chưa định nghĩa, và một số dẫn thẳng tới xóa dữ liệu

**Vị trí:** FR-4, FR-5, FR-6, addendum "Ghi bộ đếm trước khi kiểm tra mật khẩu", TC-3.

**Vấn đề:**
- **App bị kill giữa lúc chạy KDF** (1–2 giây). Addendum ghi bộ đếm trước khi kiểm tra, và điều đó đúng để chống kẻ tấn công kill app để né đếm. Nhưng nếu người dùng nhập **đúng** ở lần thứ 10 rồi app crash hoặc bị kill → lần mở sau thấy counter = 10 → **wipe**. PRD không chọn giữa "attempt đang treo = sai" và "attempt đang treo = bỏ qua".
- **Bấm Đăng nhập hai lần nhanh** (hoặc hai cửa sổ trên tablet, xem M7): hai lần kiểm tra chạy song song, gây race đọc–ghi bộ đếm (mất một lần đếm, hoặc đếm hai lần).
- **Ô trống hoặc ngắn hơn 15 ký tự** có tính là một lần sai không? Nếu có, trẻ con bấm nút Đăng nhập 4 lần là đã tốn 4 lượt. Hai developer sẽ làm khác nhau.
- **Nhập lại đúng chuỗi sai vừa nhập** có tính không? iOS passcode **không** tính (research-digest §2). Không tính sẽ giảm rủi ro cho C1 mà không giảm bảo mật.
- **Wipe ở lần thứ 10 bị gián đoạn** (hết pin giữa chừng): lần mở sau ở trạng thái nào? Phải đảm bảo khởi động lại thì wipe được chạy tiếp, không bao giờ quay lại trạng thái "vault còn, counter = 0".
- Addendum nói iOS `systemUptime` không dùng được, nhưng **không chỉ ra thứ dùng được**. Developer sẽ quay về dùng wall clock, và TC-3 fail.

**Đề xuất sửa:** Bổ sung vào FR-4/FR-6:
- (a) Nút Đăng nhập bị vô hiệu khi input dưới 15 ký tự (sau chuẩn hóa). Các trường hợp này không tính.
- (b) Lặp lại đúng chuỗi sai vừa nhập thì không tính.
- (c) Các lần kiểm tra được tuần tự hóa. Nút bị khóa trong lúc KDF chạy.
- (d) Attempt đang treo khi app chết được tính là sai. Đây là đánh đổi có chủ ý và phải ghi rõ hậu quả.
- (e) Wipe là crypto-erase (xóa key/salt trước), idempotent, và được chạy tiếp khi khởi động lại.
- (f) Addendum chỉ rõ đồng hồ cần dùng: iOS dùng `mach_continuous_time()` (tính cả lúc ngủ, reset khi khởi động lại), Android dùng `elapsedRealtime()`.

### H8. Dữ liệu rời khỏi máy qua AutoFill, bàn phím và menu chọn văn bản. Tầm nhìn "không bao giờ rời khỏi điện thoại" bị phá

**Vị trí:** Mục 1 (tầm nhìn), TC-1, NFR-6, F2 form card, FR-1/FR-3 ô mật khẩu chính.

**Vấn đề:** Đây là những lỗ không thuộc các rủi ro đã chấp nhận:
- **AutoFill / Password Manager của OS:** ô "Tên đăng nhập" + "Mật khẩu" trong form card trông giống form đăng nhập. iOS sẽ hỏi "Lưu mật khẩu vào iCloud Keychain?", Google Autofill hoặc Samsung Pass cũng sẽ hỏi lưu. Người dùng bấm "Lưu" và card bị đồng bộ lên cloud. Ô tạo mật khẩu chính có thể được iOS gợi ý "Strong Password" và lưu vào iCloud.
- **Bàn phím học từ:** Gboard, SwiftKey và Laban Key học các từ gõ vào ô Tiêu đề, Tên đăng nhập và **Note** (Note là nơi người dùng sẽ ghi PIN, mã khôi phục, câu hỏi bảo mật). Từ điển cá nhân có thể đồng bộ lên cloud. Bàn phím bên thứ ba có "Full Access" thì truyền được mọi thứ người dùng gõ.
- **Chọn văn bản:** nếu mật khẩu đã hiện hoặc Note là text chọn được, menu hệ thống có Copy (bỏ qua FR-34 và `.localOnly`), Share, **Translate / Look Up / Search Web** (gửi ra mạng qua dịch vụ của OS), và kéo-thả trên tablet.

**Đề xuất sửa:** Thêm một NFR "Chống rò rỉ qua dịch vụ OS":
- Tắt autofill cho mọi ô của app (Android `importantForAutofill="noExcludeDescendants"`, iOS dùng `textContentType` phù hợp để không kích hoạt hộp thoại lưu mật khẩu).
- Tắt autocorrect, spellcheck và gợi ý từ. Đặt `IME_FLAG_NO_PERSONALIZED_LEARNING` cho mọi ô nhập.
- Mật khẩu và Note **không chọn được và không kéo được**. Chỉ copy qua nút của app, để luôn đi qua FR-34.
- Thêm test: tạo card trên máy có bật iCloud Keychain / Google Autofill thì không được xuất hiện hộp thoại lưu mật khẩu.

### H9. TC-4 không kiểm chứng được trên iOS

**Vị trí:** TC-4, NFR-6.

**Vấn đề:** "Kiểm tra bằng danh sách permission khi build". iOS **không có** permission truy cập Internet, mọi app đều mở socket được. Trên Android, quyền `INTERNET` có thể bị một thư viện bên thứ ba chèn vào merged manifest. Một số framework cross-platform (ví dụ Flutter) cũng cần quyền này ở bản debug. Một tiêu chí "trượt là thất bại" mà chỉ kiểm được trên một nửa số nền tảng thì không dùng làm cổng chất lượng được.

**Đề xuất sửa:** Viết lại TC-4:
- (a) Android: merged manifest của **bản release** không có `INTERNET` / `ACCESS_NETWORK_STATE` (kiểm tự động trong CI).
- (b) Cả hai nền tảng: audit dependency, không có thư viện networking, analytics hay crash reporting.
- (c) Test runtime: chạy toàn bộ luồng qua proxy hoặc packet capture, kết quả là 0 kết nối đi ra.

### H10. Thời gian KDF mâu thuẫn, và việc hiệu chỉnh theo từng máy làm hỏng import chéo thiết bị

**Vị trí:** NFR-2 ("1–2 giây"), addendum ("0,5–1 giây", "hiệu chỉnh"), NFR-3, FR-56, TC-5.

**Vấn đề:**
- PRD nói ≤ 1–2 giây, addendum nói 0,5–1 giây. Kiến trúc sư sẽ theo con số nào?
- Nếu tham số được "hiệu chỉnh" theo máy và áp cho cả **file export**, thì file tạo trên iPhone đời mới (tham số nặng) có thể mất hơn 10 giây hoặc **OOM** trên Android cấu hình thấp. Import fail, TC-5/UJ-3 fail.
- Import đọc tham số KDF từ header file. Một file độc hại với `m = 4 GiB` sẽ làm app crash hoặc treo (DoS). Ngược lại, file có tham số quá yếu cũng không bị từ chối.
- "Máy yếu nhất được hỗ trợ" chưa được định nghĩa, nên NFR-2 hiện không kiểm được.

**Đề xuất sửa:** Chốt một con số trong PRD. **Tham số KDF của file export là cố định** (không hiệu chỉnh), ghi trong version của định dạng file. Import chỉ chấp nhận tham số nằm trong một khoảng [min, max] định sẵn, ngoài khoảng thì báo "file không hợp lệ". Định nghĩa thiết bị tham chiếu thấp nhất ở bước architecture và gắn NFR-2 vào thiết bị đó.

### H11. Backup "sống còn" nhưng không kiểm chứng được, không nhắc nhở, và quên mật khẩu export là mất trắng mà PRD không nói

**Vị trí:** F6, FR-48, FR-52, mục 6 ("cần export định kỳ").

**Vấn đề:**
- Mỗi lần export là một mật khẩu mới, tối thiểu 15 ký tự, không gợi ý (tinh thần FR-9), và gõ lại có thể vài năm sau. PRD **không nói** quên mật khẩu export thì file vô dụng. Đây là hậu quả cần ghi ra, giống cách FR-1 cảnh báo về mật khẩu chính.
- Không có cách **kiểm tra file backup** mà không ghi đè vault, vì import luôn ghi đè (FR-53). Người dùng chỉ biết backup hỏng hay mật khẩu sai vào đúng ngày cần dùng nó.
- Không có chỉ báo "lần export gần nhất". Store bảo "export định kỳ" nhưng app không giúp gì.
- Nếu Import kiểm lại mật khẩu export theo blocklist hoặc luật FR-2 *của phiên bản mới* (blocklist được cập nhật), người dùng sẽ bị chặn khỏi chính file của họ.

**Đề xuất sửa:**
1. Thêm cảnh báo trong FR-48 (quên mật khẩu export = file vô dụng), kèm gợi ý ghi lại mật khẩu ở nơi an toàn ngoài app.
2. Thêm "Kiểm tra file export" (giải mã và đếm card, không ghi gì). Nếu muốn giữ đơn giản thì gộp vào bước 1 của Import: hiện số card và ngày export *trước* khi xác nhận ghi đè (cũng là sửa cho H4).
3. Hiển thị "Lần export gần nhất: dd/MM/yyyy" trong Cài đặt.
4. Ghi rõ FR-2 chỉ áp dụng lúc **đặt** mật khẩu, không bao giờ áp dụng lúc nhập để import hoặc đăng nhập.

---

## MEDIUM

### M1. NFR-9 (không che app switcher, không chặn chụp màn hình) mâu thuẫn với TC-1, và hậu quả không được nêu
Snapshot đa nhiệm trên iOS được ghi thành file ảnh trong container của app. Lấy file ra qua jailbreak (đúng kịch bản TC-1) sẽ thấy mật khẩu đang hiện hoặc Note. Ảnh chụp màn hình tự đồng bộ lên iCloud Photos / Google Photos, tức dữ liệu rời khỏi máy. Android Circle to Search và các trợ lý đọc màn hình đọc được nội dung vì không có `FLAG_SECURE`. Ngoài ra, khi quay lại app sau thời hạn Autolock, frame cuối (nội dung vault) vẫn hiện một lúc trước khi app khóa.
**Sửa:** Không cần tranh luận lại quyết định. Chỉ cần (a) sửa TC-1 thành "ngoại trừ ảnh snapshot đa nhiệm và ảnh người dùng tự chụp, là rủi ro đã chấp nhận theo NFR-9", (b) liệt kê hậu quả trong NFR-9, (c) bắt buộc mật khẩu tự ẩn lại khi app vào nền (rẻ, không phá UJ-1) để snapshot ít khi chứa mật khẩu, (d) màn hình khóa phải được render *trước* frame đầu tiên khi quay lại sau thời hạn Autolock.

### M2. Ngữ nghĩa Autolock ở chế độ nền chưa được định nghĩa
"Chạy nền" là gì: màn hình tắt? Split-screen mà app vẫn hiện nhưng không focus (Android multi-resume)? iPad Slide Over? Khóa *đúng hạn* thì cần chạy nền, điều iOS không cho phép. Khóa *khi quay lại* thì key nằm trong bộ nhớ của process bị suspend vô thời hạn, nghĩa là NFR-4 chỉ đúng một nửa. Session và Autolock đo bằng đồng hồ nào? Chỉnh lùi đồng hồ có kéo dài được phiên không?
**Sửa:** Định nghĩa "nền" = không còn cửa sổ nào của app hiển thị (ProcessLifecycle `ON_STOP` / scene background), và màn hình tắt cũng là nền. Cho phép khóa lười (kiểm tra khi quay lại) nhưng ghi rõ hậu quả cho NFR-4. Xóa key ngay nếu OS cho thời gian chạy nền đủ tới hạn. Mọi timer (phiên, Autolock, clipboard) dùng đồng hồ đơn điệu.

### M3. Change Main Password: thiếu yêu cầu về tính nguyên tử và phạm vi
FR-11 không nói việc re-encrypt (hoặc re-wrap key) phải nguyên tử và bao gồm cả Recent và bản nháp. Không nói có cho phép mật khẩu mới trùng mật khẩu cũ, cũng không nói phiên có được reset sau khi đổi. Kết hợp với H5, một lần khóa giữa chừng có thể để lại vault mà nửa này mở bằng mật khẩu cũ, nửa kia bằng mật khẩu mới.
**Sửa:** "Đổi mật khẩu chính là một giao dịch nguyên tử: hoặc mọi dữ liệu (card, Recent, bản nháp) mở bằng mật khẩu mới, hoặc tất cả vẫn mở bằng mật khẩu cũ." Khuyến nghị kiến trúc dùng envelope (DEK được bọc bởi KEK) để thao tác chỉ còn là re-wrap. Từ chối mật khẩu mới trùng mật khẩu cũ. Phiên tiếp tục với thời hạn còn lại.

### M4. Hạn 3 ngày của Recent dựa vào wall clock
Chỉnh lùi đồng hồ thì mục Recent không bao giờ hết hạn. Đồng hồ nhảy tới (đổi múi giờ, máy chạy sai giờ) thì mục **vừa tạo trong UJ-2** có thể biến mất trước khi người dùng quay lại lưu card. Lúc vault đang khóa thì không xóa được (dữ liệu đang mã hóa). Định dạng `dd/MM/yyyy HH:mm` hiển thị theo múi giờ nào?
**Sửa:** Ghi rõ FR-39 là **vệ sinh dữ liệu, không phải kiểm soát bảo mật** (Recent đã nằm trong vault mã hóa), nên thao túng đồng hồ không phải mối đe dọa. Lưu UTC, chỉ dọn mục hết hạn khi vault đang mở, không bao giờ xóa mục có timestamp ở tương lai, hiển thị theo giờ địa phương.

### M5. Ghi Recent phải bền trước khi trả quyền điều khiển cho người dùng
Trong UJ-2, mật khẩu Shopee mới chỉ tồn tại trong clipboard và Recent. Nếu ghi Recent chậm hoặc thất bại (đầy bộ nhớ, bị kill ngay sau khi Copy), người dùng mất mật khẩu của một tài khoản vừa đăng ký. FR-36 không nói về độ bền hay lỗi.
**Sửa:** "Copy trên màn hình Tạo mật khẩu chỉ đặt giá trị vào clipboard sau khi mục Recent đã được ghi bền (nguyên tử). Ghi thất bại thì báo lỗi và không copy."

### M6. Luồng đổi mật khẩu của một tài khoản có sẵn làm mất mật khẩu cũ
Sửa card → Tạo mật khẩu → Use Password (FR-33 **không** ghi Recent) → Lưu → sang website đổi mật khẩu. Nếu website từ chối (sai luật ký tự, hết phiên, rớt mạng) thì card giữ mật khẩu mới, website giữ mật khẩu cũ, và **mật khẩu cũ không còn ở đâu cả**. Người dùng bị khóa khỏi tài khoản. Sheet cũng không có nút Copy, nên người dùng buộc phải Lưu trước rồi mới copy được.
**Sửa:** Chọn một trong hai: (a) khi Lưu một card có đổi mật khẩu thì ghi **mật khẩu cũ** vào Recent (hạn 3 ngày), hoặc (b) giữ một bản "mật khẩu trước đó" trong card. Phương án (a) rẻ hơn và không thêm field.

### M7. Tablet: đa cửa sổ, split-screen, kéo-thả
NFR-11 có hỗ trợ tablet nhưng không nói gì về iPad multi-scene hay Android multi-instance. Hai cửa sổ PAK nghĩa là hai màn hình Login (race bộ đếm, xem H7), hai phiên, hai bản nháp. Kéo-thả văn bản sang app bên cạnh bỏ qua FR-34.
**Sửa:** "App chỉ có một cửa sổ (single scene / single task). Hỗ trợ split-screen với app khác. Không hỗ trợ kéo-thả từ app ra ngoài." Định nghĩa trạng thái nền theo M2.

### M8. FR-2 còn mơ hồ ở nhiều điểm
"Chuỗi lặp hoặc tuần tự" chưa được định nghĩa: `abcabcabcabcabc`? `Matkhau123456789`? Chỉ cả chuỗi hay cả một phần? Danh sách mật khẩu phổ biến lấy từ nguồn nào, bao nhiêu mục, có phân biệt hoa thường không, có mật khẩu phổ biến của người Việt (`anhyeuem…`, `matkhau…`) không? Thanh độ mạnh của mật khẩu chính dùng thuật toán gì? Entropy theo bộ ký tự (FR-31) vô nghĩa với mật khẩu do người đặt, còn research-digest gợi ý zxcvbn. Các kiểm tra chạy trước hay sau chuẩn hóa?
**Sửa:** Liệt kê luật kiểm tra chính xác (ví dụ: từ chối nếu ≥ 50% chuỗi là một ký tự lặp hoặc một chuỗi tuần tự dài ≥ 8), nêu nguồn và kích thước blocklist (kèm bổ sung từ phổ biến tiếng Việt), chọn zxcvbn (hoặc tương đương) cho thanh độ mạnh, và kiểm tra **sau** chuẩn hóa C1. Luật phải giống hệt nhau trên iOS và Android.

### M9. NFR-4 ("xóa khỏi bộ nhớ") không kiểm chứng được như đang viết
Trên runtime có quản lý bộ nhớ (Swift/Kotlin String, Dart, JS), string là bất biến và GC quyết định lúc giải phóng. Không ai chứng minh được rằng dữ liệu đã giải mã đã "bị xóa".
**Sửa:** Viết lại: "Key và buffer chứa key là mảng byte có thể ghi đè và được ghi đè bằng 0 khi khóa. Mọi tham chiếu tới dữ liệu đã giải mã bị bỏ. Không có plaintext nào được ghi ra đĩa (cache, log, state restoration)." Kèm phương pháp test: heap dump sau khi khóa không tìm thấy key.

### M10. Import/Export thiếu các trường hợp lỗi và vệ sinh file
Chưa có: file từ **phiên bản mới hơn** app (FR-57 chỉ nói chiều cũ → mới), file rất lớn, đầy bộ nhớ trong lúc import, file không phải của PAK. File tạm mà export tạo ra trước khi mở share sheet nằm lại trong container bao lâu? Header file lộ những gì ở dạng rõ (số card, tên máy, ngày)? Tên file mặc định là gì?
**Sửa:** Bổ sung FR: file mới hơn thì báo "cập nhật app", giới hạn kích thước, kiểm tra dung lượng trước khi import. File tạm export bị xóa sau khi share sheet đóng và khi khởi động. Header rõ chỉ chứa magic, version và tham số KDF, mọi thứ khác (kể cả số card và ngày export) nằm trong phần mã hóa xác thực (AEAD). Tên file không chứa thông tin cá nhân.

### M11. Thiếu trạng thái lỗi hệ thống
Đầy bộ nhớ khi Lưu card, ghi Recent hay đổi mật khẩu. Migration định dạng **vault** khi cập nhật app (FR-57 chỉ nói về file export). Restore máy từ backup (vault bị loại khỏi backup, vậy người dùng thấy gì: màn hình "Tạo tài khoản" mà không có lời giải thích?).
**Sửa:** Thêm FR cho từng trường hợp: thông báo lỗi và đảm bảo dữ liệu cũ còn nguyên. Migration vault phải nguyên tử, và có test nâng cấp từ mọi phiên bản trước.

### M12. "Xóa toàn bộ dữ liệu" (FR-4, FR-8, FR-10) chưa được định nghĩa
Có bao gồm cài đặt (ngôn ngữ, thời hạn), tiêu chí tạo mật khẩu, file tạm export, mục Keychain/Keystore, clipboard không? Xóa file trên flash không ghi đè dữ liệu thật. Thứ tự xóa ra sao để một lần crash giữa chừng không để lại trạng thái nửa vời?
**Sửa:** Định nghĩa một thủ tục wipe duy nhất dùng chung cho FR-4, FR-8 và FR-10: (1) crypto-erase (hủy salt/wrapped key), (2) xóa vault, bản nháp, Recent và file tạm, (3) xóa Keychain/Keystore, (4) xóa clipboard nếu là giá trị của app, (5) reset bộ đếm, (6) chốt rõ cài đặt và ngôn ngữ được giữ hay reset. Thủ tục này idempotent và được chạy tiếp khi khởi động lại.

---

## LOW

### L1. Ngữ nghĩa khi thay đổi cài đặt thời gian
Rút giới hạn phiên từ 10 xuống 1 phút khi đã ở phút thứ 5 thì có khóa ngay không? Giới hạn phiên nhỏ hơn Autolock (1 so với 3) có được phép không? Đổi Clear Clipboard khi đang có timer chạy thì timer nào thắng? File cài đặt (lưu ngoài vault để màn hình Login còn biết ngôn ngữ) bị sửa hoặc hỏng thì sao?
**Sửa:** Giá trị mới áp dụng ngay, tính từ mốc ban đầu. Cho phép mọi tổ hợp. Khi đọc cài đặt thì kẹp về tập {1, 3, 5, 10}, giá trị không hợp lệ thì dùng mặc định.

### L2. Các `[ASSUMPTION]` còn treo ở những FR về bảo mật
FR-1 (nhập lại xác nhận mật khẩu chính, với một mật khẩu **không khôi phục được** thì đây phải là luật cứng), FR-6, FR-34, NFR-2, NFR-8. Memlog cho thấy Finalize đã chạy mà các nhãn này vẫn còn. Cần thêm một câu hệ quả cho FR-52 (xem bảng rủi ro đã chấp nhận).
**Sửa:** Chốt hoặc gỡ từng nhãn trước khi chuyển sang architecture. FR-1 bỏ nhãn.

### L3. Thông báo quanh wipe và thời gian chờ
Ở lần thử cuối, không có cảnh báo rõ "lần sai tiếp theo sẽ XÓA toàn bộ dữ liệu". Sau khi wipe, không có màn hình giải thích điều vừa xảy ra. Sau khi khởi động lại máy, đồng hồ đếm ngược về 30:00 mà không có lời giải thích.
**Sửa:** Thêm ba thông báo trên vào FR-4 và FR-6.

### L4. Trạng thái hiện/ẩn mật khẩu
Mật khẩu đã hiện có tự ẩn lại khi khóa, khi rời màn hình hay khi app vào nền không? Ô mật khẩu chính ở Login không có nút hiện/ẩn, nên gõ sai nhiều hơn với chuỗi dài 15+ ký tự có dấu (liên quan C1 và H7).
**Sửa:** Mật khẩu tự ẩn khi rời màn hình hoặc vào nền. Thêm nút hiện/ẩn cho ô mật khẩu chính.

### L5. Accessibility hoàn toàn vắng mặt
Người dùng có cả người lớn tuổi, nhưng PRD không nói gì về Dynamic Type / cỡ chữ hệ thống. Có quyết định nào về việc VoiceOver/TalkBack **đọc to mật khẩu** khi đang hiện không? Các nút Copy chỉ có icon thì có label không?
**Sửa:** Thêm NFR: hỗ trợ cỡ chữ hệ thống. Nút chỉ có icon phải có label. Mật khẩu đang ẩn được đọc là "mật khẩu đã ẩn".

### L6. FR-10 và chức năng Offload/Archive
iOS "Gỡ bỏ ứng dụng không dùng" (Offload) và Android 15 "Archive" xóa app nhưng **giữ dữ liệu**. Khi cài lại thì vault và bộ đếm vẫn còn. Điều này không gây hại, nhưng FR-10 viết "Cài lại app thì máy trở về như mới" sẽ fail khi QA test theo đúng chữ.
**Sửa:** "Gỡ app hoặc xóa dữ liệu app xóa sạch mọi thứ. Offload/Archive của OS giữ dữ liệu, và đó là hành vi mong muốn."

### L7. Các điểm lặt vặt ở bộ tạo mật khẩu
Tắt hết công tắc thì UI hiển thị "tắt hết" nhưng mật khẩu vẫn có chữ thường, tức UI mô tả sai thực tế. Ánh xạ ABC ↔ Uppercase không đối xứng: công tắc Lowercase ở màn hình đầy đủ không có tác dụng ở sheet. NFR-5 không yêu cầu chọn ký tự không thiên lệch (rejection sampling) và trộn ngẫu nhiên sau khi chèn ký tự bắt buộc (FR-29).
**Sửa:** Khi tắt hết thì tự bật lại Lowercase (hoặc không cho tắt công tắc cuối cùng). Ghi rõ sheet bỏ qua công tắc Lowercase. NFR-5 thêm "phân phối đều (rejection sampling) và trộn Fisher–Yates bằng CSPRNG".

---

## Gợi ý thứ tự sửa
1. C1, C2 (dữ liệu bị app tự hủy). Phải sửa trước khi làm architecture.
2. H5, H6, H7 (vòng đời process, khóa và bản nháp). Đây là các luật mà architecture cần để thiết kế state machine.
3. H1, H8, H9, H10 (requirement không thực thi được hoặc không kiểm được).
4. H2, H3, H4, H11 (UX của các thao tác phá hủy và backup). Chuyển kèm cho bmad-ux.
5. Medium/Low: gom vào một lượt chỉnh PRD.
