---
title: 'Sprint Change Proposal — Story 1.15 và 1.16 cho Epic 1 từ deferred-work'
date: '2026-11-13'
author: 'namtruong'
mode: 'batch'
scope: 'minor'
status: 'approved'
---

# Sprint Change Proposal — Story 1.15 và 1.16 cho Epic 1 (2026-11-13)

## 1. Tóm tắt vấn đề

**Vấn đề:** Epic 1 đã xong 14/14 story, nhưng code review của 1.11, 1.12 và 1.13 để lại một nhóm mục mở trong `deferred-work.md`, tất cả đều về cổng CI. Luật của các cổng đã có kiểm âm (story 1.12), còn lớp shell gọi luật và chính file `ci.yml` thì chưa. Chủ sản phẩm muốn xử lý nhóm này trước khi sang Epic 2.

**Bối cảnh:** Phát hiện khi rà lại `_bmad-output/implementation-artifacts/deferred-work.md` sau khi merge story 1.14 (2026-11-13).

**Bằng chứng:**
- Bỏ `$expect_id` khỏi `rule_args` trong `tool/ci/check_android_apk.sh` thì `apk_rules.dart` bỏ qua kiểm badging; mọi test Dart và CI trên APK tốt vẫn xanh.
- Nhánh `failed=1` của cổng `zipalign -c -P 16` chưa bao giờ chạy trong test.
- Khối shell so revision Flutter với `.metadata` lặp ở bốn job của `ci.yml`; đảo điều kiện hoặc bỏ `exit 1` vẫn xanh.
- Fixture `aapt2`/`unzip -l`/`readelf -lW` trong `apk_rules_test.dart` là xấp xỉ viết tay; định dạng thật lệch thì test vẫn xanh còn CI fail oan hoặc lọt.
- Xóa một bước cổng khỏi `ci.yml` (kiểm secret, kiểm APK kèm `--expect-id`) không làm gì fail.
- `check_stack.dart` chỉ kiểm package; `FLUTTER_VERSION`, Gradle (`gradle-9.3.1`) và Xcode (26.3) trong CI có thể lệch spine. Bảng Stack hiện chỉ ghi Flutter 3.47.8, chưa ghi Gradle và Xcode.
- `distributionSha256Sum` chỉ phủ bản phân phối Gradle tải về, không phủ `gradle-wrapper.jar` đã commit.

## 2. Phân tích tác động

### Checklist

| Mục | Trạng thái | Ghi chú |
|---|---|---|
| 1.1 Story kích hoạt | [x] | Code review của 1.11, 1.12, 1.13 |
| 1.2 Loại vấn đề | [x] | Nợ kỹ thuật và hạng mục hoãn, không đổi yêu cầu |
| 1.3 Bằng chứng | [x] | Xem mục 1 |
| 2.1 Epic hiện tại | [x] | Epic 1 thêm 2 story, mục tiêu epic không đổi |
| 2.2 Thay đổi epic | [x] | Thêm story 1.15, 1.16 vào cuối Epic 1 |
| 2.3 Epic sau | [x] | Không ảnh hưởng Epic 2–6. Epic 7 giữ các mục cần máy thật (7.1) và workflow phát hành (7.2) |
| 2.4 Epic mới hoặc lỗi thời | [N/A] | |
| 2.5 Thứ tự ưu tiên | [x] | 1.15 trước 1.16 (1.16 khẳng định các bước mà 1.15 tạo ra vẫn còn trong `ci.yml`) |
| 3.1 PRD | [x] | Không sửa |
| 3.2 Architecture | [!] | Bảng Stack của ARCHITECTURE-SPINE thêm 2 dòng: Gradle và Xcode (story 1.16 làm). Không đổi AD nào |
| 3.3 UX | [N/A] | Không đổi màn hình |
| 3.4 Artifact khác | [!] | `epics.md`, `sprint-status.yaml`, `deferred-work.md` (cập nhật status), `ci.yml` (trong story) |
| 4.1 Điều chỉnh trực tiếp | [x] | Chọn. Công sức thấp đến trung bình, rủi ro thấp |
| 4.2 Rollback | [N/A] | |
| 4.3 Xét lại MVP | [N/A] | |
| 4.4 Hướng đề xuất | [x] | Direct Adjustment |

### Tác động lên story

- Story đã xong không phải mở lại. 1.15 và 1.16 mở rộng test của 1.11 và 1.12, không đổi luật hiện có.
- Epic 2 không phụ thuộc về chức năng, nhưng story 2.2 thêm API native (`bootId`/`monotonicMs`) và sẽ đi qua chính các cổng này.

### Mục deferred không đưa vào

| Mục | Lý do |
|---|---|
| Kiểm khi chạy thật cho bản release (R8/minify có thể làm hỏng đăng ký Pigeon, từ 1.13) | Hợp với lúc ký và build release, đề xuất chuyển sang story 7.2 |
| `display.size` lúc khởi động và máy gập; đo KDF trên máy mốc; đo `StrengthEstimator` bản release; bàn phím với `SecretField` | Cần máy thật, thuộc story 7.1 |
| Quét secret ở mọi workflow, cấm `pull_request_target` ở mọi file | Thuộc story 7.2 |
| `LicenseRegistry.addLicense` cho `NOTICE` | Chờ story có màn giấy phép |
| Tab cuộn về đầu và Back trong tab; cửa sổ khóa lúc chờ hook clipboard (1.8) | Cần nội dung tab hoặc hook thật, thuộc Epic 3 |

## 3. Hướng đề xuất

**Direct Adjustment:** thêm 2 story vào cuối Epic 1, làm trước Epic 2.

- **Công sức:** 1.15 trung bình (harness công cụ giả, một vòng CI để lấy output thật). 1.16 nhỏ đến trung bình.
- **Rủi ro:** thấp, chỉ đụng CI và test. Harness shell cần `bash`, nên test tự bỏ qua trên máy không có `bash` và bắt buộc chạy ở job ubuntu.
- **Timeline:** Epic 2 lùi 2 story.
- **Thứ tự:** 1.15 → 1.16.

## 4. Đề xuất sửa đổi chi tiết

### 4.1 `epics.md`: thêm sau Story 1.14 (trước `## Epic 2`)

```markdown
### Story 1.15: Kiểm lớp shell của các cổng CI

As a chủ sản phẩm,
I want lớp shell gọi các cổng CI cũng được chứng minh là fail trên đầu vào xấu,
So that một tham số bị bỏ sót hoặc một điều kiện bị đảo trong script không âm thầm tắt cổng (AD-18, AD-19, NFR-7).

**Acceptance Criteria:**

**Given** harness test trong `test/tool/` chạy `tool/ci/check_android_apk.sh` với `aapt2`, `zipalign`, `readelf`, `unzip` giả (qua `ANDROID_HOME` và `PATH` tạm)
**When** chạy script với `--expect-id`
**Then** `apk_rules.dart` nhận đúng thư mục `$work` (có `manifest.txt`, `listing.txt`, `readelf/<abi>/<tên>.so.txt`, `badging.txt`) và đúng `applicationId` kỳ vọng
**And** `badging` giả sai `applicationId` làm script exit khác 0
**And** output giả vi phạm một luật (vd. có `android.permission.INTERNET`) làm script exit khác 0
**And** `zipalign` giả trả lỗi làm script exit khác 0 dù mọi luật khác pass
**And** bộ công cụ giả hợp lệ cho exit 0
**And** harness chạy trong job ubuntu của CI; trên máy không có `bash` thì test tự bỏ qua kèm lý do

**Given** khối shell so revision Flutter với `.metadata` đang lặp ở các job của `ci.yml`
**When** gom vào một script trong `tool/ci/`
**Then** mọi job gọi cùng script đó, `ci.yml` không còn bản sao của khối so sánh
**And** test kiểm âm: revision khác `.metadata` thì fail; `.metadata` thiếu dòng `revision` thì fail; khớp thì pass

**Given** APK prod và dev do CI build
**When** CI chạy `check_android_apk.sh`
**Then** output thô của `aapt2 dump xmltree`, `aapt2 dump badging`, `unzip -l`, `readelf -lW` được lưu thành artifact của lần chạy (action upload ghim theo SHA)
**And** `test/fixtures/` có golden fixture lấy từ artifact đó cho cả prod và dev, ghi rõ commit và phiên bản build-tools nguồn
**And** `apk_rules_test.dart` pass trên golden fixture; các ca kiểm âm được dựng bằng cách sửa golden, không dùng output viết tay nữa

### Story 1.16: Ghim toolchain và bảo vệ cấu trúc ci.yml

As a chủ sản phẩm,
I want phiên bản toolchain của CI khớp bảng Stack và các bước cổng không thể bị gỡ khỏi `ci.yml` mà không ai biết,
So that spine, CI và build thật không lệch nhau, và một lần sửa workflow không âm thầm tắt cổng an toàn (AD-12, AD-18).

**Acceptance Criteria:**

**Given** `.github/workflows/ci.yml`
**When** chạy test cấu trúc workflow trong `test/tool/`
**Then** test fail nếu thiếu một trong các bước: kiểm secret (`check_workflow_secrets.dart`), kiểm Stack (`check_stack.dart`), so revision Flutter ở mọi job cài Flutter, kiểm APK prod kèm `--expect-id io.github.truongthanhnam.pakmanager`, kiểm APK dev kèm `--expect-id` có hậu tố `.dev`
**And** test fail nếu một bước cổng có `continue-on-error: true` hoặc điều kiện `if:` làm nó bị bỏ qua
**And** có kiểm âm trên bản `ci.yml` mẫu bị gỡ từng bước

**Given** bảng Stack của ARCHITECTURE-SPINE được bổ sung dòng Gradle và Xcode (giá trị đang dùng: Gradle 9.3.1, Xcode 26.3)
**When** CI chạy bước kiểm Stack
**Then** fail khi `FLUTTER_VERSION` trong `ci.yml` khác phiên bản Flutter SDK của bảng Stack
**And** fail khi phiên bản trong `distributionUrl` của `gradle-wrapper.properties` khác dòng Gradle
**And** fail khi phiên bản Xcode mà job macOS chọn khác dòng Xcode
**And** có kiểm âm cho từng trường hợp lệch

**Given** `gradle-wrapper.jar` đã commit trong repo
**When** CI chạy job build Android
**Then** JAR được xác thực bằng `gradle/actions/wrapper-validation` ghim theo commit SHA (comment ghi tag), trước mọi bước gọi Gradle
**And** bước xác thực nằm trong danh sách bước bắt buộc của test cấu trúc workflow
```

### 4.2 `sprint-status.yaml`: Epic 1

```yaml
OLD:
  1-14-flavor-dev-cho-ios-và-ghi-công-giấy-phép-blocklist: done
  epic-1-retrospective: optional

NEW:
  1-14-flavor-dev-cho-ios-và-ghi-công-giấy-phép-blocklist: done
  1-15-kiểm-lớp-shell-của-các-cổng-ci: backlog
  1-16-ghim-toolchain-và-bảo-vệ-cấu-trúc-ci-yml: backlog
  epic-1-retrospective: optional
```

`epic-1` giữ `in-progress`. `last_updated` đổi thành `2026-11-13`.

### 4.3 `deferred-work.md`: thêm dòng `status:` vào từng mục

- Kiểm âm bước so revision Flutter và gom khối shell (1.11): `status: planned — story 1.15`
- Golden fixture từ output thật (1.12): `status: planned — story 1.15`
- Test lớp shell `check_android_apk.sh` (1.12, hai mục trùng nhau): `status: planned — story 1.15`
- Kiểm âm cổng `zipalign -c -P 16` (review 1.12): `status: planned — story 1.15`
- Đối chiếu Flutter, Gradle, Xcode với bảng Stack (1.11): `status: planned — story 1.16`
- Xác thực `gradle-wrapper.jar` (1.11): `status: planned — story 1.16`
- Test parse `ci.yml` (review 1.12): `status: planned — story 1.16`
- Kiểm bản release với R8/minify (1.13): `status: planned — story 7.2`

### 4.4 ARCHITECTURE-SPINE (do story 1.16 thực hiện, không sửa lúc duyệt)

Bảng Stack thêm hai dòng: `Gradle (wrapper) | 9.3.1` và `Xcode (CI) | 26.3`. Không đổi quyết định kiến trúc nào; chỉ ghi lại giá trị CI đang dùng để có mốc đối chiếu.

## 5. Bàn giao thực hiện

- **Phạm vi:** Minor, Developer agent làm trực tiếp.
- **Người nhận:** Developer (`bmad-build` cho từng story, sau đó `bmad-code-review`).
- **Sau khi duyệt:** áp mục 4.1–4.3 vào `epics.md`, `sprint-status.yaml` và `deferred-work.md`.
- **Tiêu chí thành công:**
  - Cả 2 story `done`, CI xanh trên mọi job.
  - Mỗi mục deferred ánh xạ ở 4.3 có `status: done`, hoặc ghi rõ phần còn lại thuộc 7.1 hay 7.2.
  - Sau đó chạy retrospective Epic 1 (tùy chọn) rồi sang Epic 2.
