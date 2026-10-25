---
type: input-reconciliation
input: _bmad-output/brainstorming/brainstorm-password-manager-app-2026-10-23/brainstorm-intent.md
against: prd.md, addendum.md (đã đối chiếu với .memlog.md)
date: 2026-10-25
---

# Đối chiếu đầu vào: brainstorm-intent.md → PRD

Cách đọc: mỗi mục trong nguồn được xếp vào một trong các nhóm **Đã phủ**, **Thay đổi có chủ đích** (do memlog quyết định, không tính là gap), **Gap** (PRD bỏ mất hoặc làm yếu đi mà không có quyết định trong memlog). Mức độ: **Cao / Trung bình / Thấp**.

## A. Danh sách gap

| # | Mức | Nguồn | Nội dung trong nguồn | Tình trạng trong PRD | Đề xuất |
|---|---|---|---|---|---|
| G1 | Trung bình | §2.1 | Nguyên tắc thiết kế số 1: **"Đơn giản nhất có thể."** Đây là nguyên tắc bao trùm, không chỉ riêng chuyện phân loại card. | PRD chỉ giữ hệ quả cụ thể ("không phân loại card, không field chuyên biệt", F2). Mục 1 Tầm nhìn và mục 2 chỉ nêu "bảo mật là ưu tiên số một" và nguyên tắc cân bằng bảo mật/luồng copy-dán. Nguyên tắc đơn giản không còn được nêu ra như một tiêu chí để quyết định khi có tính năng mới. Memlog không có quyết định nào bỏ nguyên tắc này. | Thêm "đơn giản nhất có thể" vào mục 1 hoặc mục 2 như nguyên tắc thứ hai, ví dụ: khi có tranh cãi về phạm vi thì chọn phương án ít thành phần, ít cài đặt hơn, miễn không vi phạm tiêu chí bảo mật. |
| G2 | Trung bình | §3 | **Threat model thực tế:** kẻ trộm phổ thông thường reset máy rồi bán, không nhắm vào vault; khả năng bị tấn công có chủ đích là **rất thấp**. Ba vector được nêu rõ: (1) script dò mật khẩu ở Login, (2) bỏ qua Login để mở thẳng nơi lưu dữ liệu, (3) chép file mã hóa ra ngoài để phân tích/giải mã offline, **kể cả dùng AI**. | PRD không có mục threat model. Vector 1 chỉ hiện gián tiếp qua FR-4; vector 2/3 qua TC-1, NFR-2 và addendum "Giới hạn của bộ đếm". Phần đánh giá mức rủi ro ("kẻ trộm phổ thông", "rất thấp") bị bỏ hẳn, trong khi đây chính là lý do biện minh cho nguyên tắc cân bằng (không khóa ngay khi chuyển app, không chặn chụp màn hình, không che ảnh đa nhiệm). | Thêm một mục ngắn "Threat model" vào PRD (hoặc addendum) gồm: mức độ rủi ro, 3 vector, export là đường rò rỉ thực tế nhất, kịch bản người chung máy bị loại. Liên kết với nguyên tắc cân bằng ở mục 2. |
| G3 | Trung bình | §1 | **Người dùng là ai:** chủ sản phẩm, sau đó **gia đình và bạn bè**, trong đó có **người lớn tuổi**. Chủ sản phẩm **tự hướng dẫn người thân**, nên app không cần thiết kế riêng cho nhóm ít rành công nghệ. | PRD không có mục đối tượng người dùng. Persona "chị Lan" không được mô tả. Ý "người lớn tuổi cũng dùng được luồng chính" và "chủ sản phẩm tự hướng dẫn" đều mất; chỉ còn non-goal "Thiết kế UX riêng cho người ít rành công nghệ" mà không còn lý do đi kèm. Memlog có đổi kênh phát hành sang store (quyết định stakes), nhưng không bỏ nhóm người dùng gia đình/bạn bè. | Thêm 2–3 dòng "Người dùng" vào mục 1: chủ sản phẩm + gia đình, bạn bè (kể cả người lớn tuổi), được chủ sản phẩm hướng dẫn trực tiếp; người dùng store khác là phụ. Giữ non-goal kèm lý do. |
| G4 | Thấp–Trung bình | §8 câu 12 | "Cách ánh xạ **chip ABC / 3 chip của sheet** với **4 công tắc** của màn hình đầy đủ?" | FR-27 trả lời phần ABC = hoa + thường. Nhưng chưa trả lời: sheet và màn hình đầy đủ **dùng chung** hay **riêng** bộ tiêu chí? FR-32 ("nhớ tiêu chí lần trước") không nói nhớ chung hay nhớ riêng từng nơi. Nếu chung, trạng thái "Uppercase bật, Lowercase tắt" ở màn hình đầy đủ hiển thị thế nào trên chip ABC? Câu hỏi không có trong mục 8 của PRD. | Chốt: tiêu chí lưu riêng cho từng nơi (đơn giản nhất), hoặc nêu quy tắc ánh xạ hai chiều. Ghi vào FR-27/FR-32. |
| G5 | Thấp | §7 | Non-goal: "**Bỏ bớt thành phần** của màn hình Tạo mật khẩu hoặc sheet edit_pass." | Quy tắc vẫn có trong phần mở đầu F3 ("giữ nguyên toàn bộ thành phần... trừ nút Back"), nhưng **không có trong danh sách Ngoài phạm vi ở mục 7**. Riêng FR-25 viết "Nhãn Password strength" và "Mật khẩu vừa tạo", không nhắc rõ ví dụ "Password strength: High" và việc mật khẩu trong sheet được tô màu (FR-30 có phủ chung, nên chỉ là thiếu rõ ràng). | Thêm dòng vào mục 7: "Bỏ bớt thành phần của màn hình Tạo mật khẩu hoặc sheet tạo mật khẩu (ngoại lệ duy nhất: nút Back)". |
| G6 | Thấp | §7 | Non-goal UX cho người ít rành công nghệ có ghi rõ phạm vi: **"(luồng chuyển app, autolock, clipboard)"**. | PRD mục 7 chỉ ghi "Thiết kế UX riêng cho người ít rành công nghệ", mất phần chỉ rõ ba khía cạnh không cần điều chỉnh riêng. | Khôi phục phần ngoặc đơn để người làm UX/architecture không hiểu sai phạm vi. |
| G7 | Thấp | §5.5 | "Tìm kiếm chỉ theo tiêu đề, nên **Note không cần đánh index**." | Không có trong PRD hay addendum. Liên quan: TC-1 yêu cầu cả tiêu đề cũng không đọc được ngoài app, nên bất kỳ chỉ mục tìm kiếm nào cũng phải mã hóa hoặc chỉ nằm trong bộ nhớ sau khi mở khóa. Điều này chưa được ghi. | Thêm vào addendum (architecture): không đánh index Note; chỉ mục tiêu đề (nếu có) phải được mã hóa hoặc chỉ dựng trong bộ nhớ sau khi đăng nhập, và bị xóa theo NFR-4. |
| G8 | Thấp | §2.3, §5.5 | Mọi dữ liệu đều không đọc được ngoài app. | NFR-1 liệt kê đủ (tiêu đề, tên đăng nhập, mật khẩu, Note, Recent, bản nháp), nhưng **TC-1** chỉ liệt kê "tiêu đề, mật khẩu, Note và Recent", **thiếu tên đăng nhập và bản nháp card**. Tiêu chí kiểm chứng yếu hơn yêu cầu. | Sửa TC-1 cho khớp NFR-1. |
| G9 | Thấp | §3 vector 3 | Phân tích/giải mã offline "**kể cả dùng AI**". | Không nhắc. Về kỹ thuật thì KDF chậm + mật khẩu mạnh đã là câu trả lời, nên đây chỉ là mất chi tiết ngữ cảnh. | Tùy chọn: nhắc trong mục threat model (G2). |

## B. Câu hỏi mở ở §8 của nguồn

| # | Câu hỏi | Trả lời trong PRD |
|---|---|---|
| 1 | Mật khẩu export: chính hay riêng | FR-48 (riêng, cùng quy tắc FR-2) |
| 2 | Import: gộp hay ghi đè | FR-53 (ghi đè), FR-58; non-goal "Import kiểu gộp" |
| 3 | File export cũ sau Change Main Password | FR-11 (không bị ảnh hưởng) |
| 4 | Icon cloud ↑↓ | FR-47 (bỏ, Import/Export là mục trong Cài đặt) |
| 5 | Bộ đếm reset khi đăng nhập đúng | FR-5 |
| 6 | Độ dài/độ mạnh tối thiểu mật khẩu chính | FR-2 (NIST, 15–128) |
| 7 | Change Main Password nhập mật khẩu cũ | FR-11 |
| 8 | Mặc định Autolock + danh sách lựa chọn | FR-13, FR-43 (3 phút; 1/3/5/10) |
| 9 | Công tắc Notifications | Bỏ (FR-43, mục 7) |
| 10 | Lock Vault vs Sign out | FR-46 (là một) |
| 11 | Khoảng độ dài + mặc định | FR-26 (4–99, mặc định 16) |
| 12 | Chip ABC + ánh xạ với 4 công tắc | **Một phần** (FR-27). Chưa rõ chung/riêng trạng thái, xem G4 |
| 13 | Cách tính Password strength | FR-31 |
| 14 | Giới hạn Recent, copy từ Recent, xác nhận Clear | FR-39, FR-36, FR-40 |
| 15 | Phạm vi Clear Clipboard | FR-34 |
| 16 | Tạo trong card có ghi Recent không | FR-33, FR-36 |
| 17 | Xóa card | FR-20, FR-22 |
| 18 | Field bắt buộc | FR-19 |
| 19 | Điều hướng / tab bar | FR-42 |

Ghi chú: mục 8 của PRD hiện chỉ nói về các `[ASSUMPTION]`, không liệt kê câu hỏi mở nào còn lại. Câu 12 (phần còn thiếu) nên được thêm vào đó nếu chưa chốt.

## C. Thay đổi có chủ đích (theo memlog, không phải gap)

- Clear Clipboard mặc định 1 phút → **3 phút** (override, để đủ thời gian cho UJ-2).
- Autolock mặc định **3 phút** (ảnh ghi 1 phút).
- Bỏ nút Back ở màn hình Tạo mật khẩu (vì đã là tab).
- Bỏ công tắc Notifications; bỏ icon cloud.
- Chia sẻ cho gia đình/bạn bè → **phát hành trên App Store + Google Play**, miễn phí (quyết định stakes). Nhóm người dùng gốc vẫn nên được nêu, xem G3.
- Thêm tính năng mới: Ngôn ngữ EN/VI, giới hạn phiên tuyệt đối 10 phút, giữ bản nháp card, máy tính bảng, dark mode, chặn sao lưu tự động của OS, không giới hạn số lần nhập sai mật khẩu export.
- Recent xếp mới nhất ở trên (ảnh mẫu xếp cũ nhất trên).

## D. Đã phủ đầy đủ

- §1: hai chức năng chính, offline 100%, mã hóa, 1 tài khoản/máy, luồng sử dụng điển hình (UJ-1).
- §2.2–2.7: offline, mã hóa, không khôi phục (FR-9, luật cứng), luật bảo mật cố định (FR-7 + mục 7), 1 tài khoản, mọi màn hình sau Login (F1).
- §3: export là đường rò rỉ thực tế nhất (mở đầu F6); loại kịch bản người chung máy (mục 7).
- §4.1: Tạo tài khoản, "Xóa & Tạo tài khoản mới" có xác nhận + không cần mật khẩu (FR-8), gỡ/cài lại (FR-10), không quên mật khẩu, giới hạn sai 1–4 / 5–9 chờ 30 phút / lần 10 xóa (FR-4).
- §4.2: card 4 field, tìm theo tiêu đề, nút nổi bật, Copy, ẩn/hiện, sửa + Lưu, hai cách đổi mật khẩu, sheet edit_pass (FR-14…FR-25).
- §4.3: màn hình Tạo mật khẩu, bộ ký tự đặc biệt, Recent (sheet, Close, thời điểm dd/MM/yyyy HH:mm, Copy, Clear), quy tắc ghi Recent chỉ khi Copy ở màn hình Tạo mật khẩu (FR-36).
- §4.4: Autolock, Clear Clipboard, Change Main Password, Lock Vault, Import/Export mã hóa.
- §5.1: bộ đếm chỉ bảo vệ Login; KDF chậm, Argon2id (NFR-2 + addendum).
- §5.2–5.3: export mã hóa ngang vault, là backup duy nhất, tính năng sống còn (NFR-3, F6, mô tả store).
- §5.4: 1 bộ đếm, lưu bền, không reset bằng chỉnh đồng hồ (FR-6, TC-3, addendum).
- §5.5: Recent và Note mã hóa trong vault (NFR-1, FR-41).
- §6: toàn bộ bảng thay đổi v1 → v2.
- §7: mọi non-goal trừ G5 (thiếu trong danh sách) và G6 (mất phần chi tiết).

## E. Quan sát phụ (ngoài phạm vi đối chiếu)

- Giới hạn phiên tuyệt đối 10 phút (FR-12) có thể làm UJ-2 phải đăng nhập lại nếu việc đăng ký app khác kéo dài. Memlog đã quyết định nên không phải gap, nhưng nên kiểm tra lại với nguyên tắc "giữ hai luồng cốt lõi thông suốt" ở mục 2–3.
- Thứ tự đánh số: FR-34 nằm trong mục F-X sau FR-58.
