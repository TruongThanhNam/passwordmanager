---
title: 'Sprint Change Proposal — Story bổ sung cho Epic 1 từ deferred-work'
date: '2026-11-10'
author: 'namtruong'
mode: 'batch'
scope: 'minor'
status: 'approved'
---

# Sprint Change Proposal — Story bổ sung cho Epic 1 (2026-11-10)

## 1. Tóm tắt vấn đề

**Vấn đề:** Epic 1 đã xong 9/9 story, nhưng `deferred-work.md` còn nhiều mục mở do code review và build review của 1.1–1.9 để lại. Phần lớn là cổng CI chưa được kiểm, chuỗi cung ứng CI chưa ghim, và một rủi ro hiệu chỉnh KDF. Chủ sản phẩm muốn xử lý các mục làm được ngay trước khi sang Epic 2.

**Bối cảnh:** Phát hiện sau khi code review story 1.9 xong (2026-11-10), khi rà lại toàn bộ `_bmad-output/implementation-artifacts/deferred-work.md`.

**Bằng chứng:**
- Hiệu chỉnh KDF trả `null` khi lần thử đầu (t=3, m=64 MiB) lỗi, không lùi về sàn. Máy không cấp được 64 MiB sẽ không tạo được tài khoản (review 1.4 triage #4, nếu đúng là high).
- Các cổng CI (`check_android_apk.sh`, bước chặn secret) chỉ chạy trên đầu vào hợp lệ. Thu hẹp regex hoặc định dạng output lệch thì vẫn xanh.
- `actions/*@v4`, `*-latest`, clone Flutter theo tag và Gradle wrapper không checksum đều có thể đổi ngầm (repo public của một app mật khẩu).
- API Pigeon native chỉ được chứng minh là biên dịch được, chưa chạy thật lần nào trong CI.

## 2. Phân tích tác động

### Checklist

| Mục | Trạng thái | Ghi chú |
|---|---|---|
| 1.1 Story kích hoạt | [x] | Các review của 1.1, 1.2, 1.4, 1.5, 1.9 |
| 1.2 Loại vấn đề | [x] | Nợ kỹ thuật và hạng mục hoãn, không đổi yêu cầu |
| 1.3 Bằng chứng | [x] | Xem mục 1 |
| 2.1 Epic hiện tại | [x] | Epic 1 thêm 5 story, mục tiêu epic không đổi |
| 2.2 Thay đổi epic | [x] | Thêm story 1.10–1.14 vào cuối Epic 1 |
| 2.3 Epic sau | [x] | Không ảnh hưởng Epic 2–6. Epic 7 (7.1, 7.2) giữ các mục cần máy thật hoặc workflow phát hành |
| 2.4 Epic mới hoặc lỗi thời | [N/A] | |
| 2.5 Thứ tự ưu tiên | [x] | 1.10 trước tiên (rủi ro high chưa xác minh) |
| 3.1 PRD | [x] | Không sửa. Giữ NFR-10 (xem mục 3) |
| 3.2 Architecture | [x] | Không sửa. 1.10 làm đúng "sàn m=19 MiB, t=2" của AD-5. 1.11 làm rõ AD-12 và AD-18 |
| 3.3 UX | [N/A] | Không đổi màn hình |
| 3.4 Artifact khác | [!] | `epics.md`, `sprint-status.yaml`, `deferred-work.md` (cập nhật status) |
| 4.1 Điều chỉnh trực tiếp | [x] | Chọn |
| 4.2 Rollback | [N/A] | |
| 4.3 Xét lại MVP | [N/A] | |
| 4.4 Hướng đề xuất | [x] | Direct Adjustment |

### Tác động lên story

- Story đã xong không phải mở lại. Story 1.10 thay Design Notes bước 4 của spec 1.4 (probe lỗi → `null`) bằng "probe lỗi → thử ở sàn". Spec 1.4 giữ nguyên làm lịch sử.
- 7.1 (bộ nghiệm thu trên máy thật) vẫn giữ việc đo KDF trên máy mốc yếu nhất.
- 7.2 (ký app và phát hành qua CI) vẫn giữ việc quét secret ở mọi workflow.

### Mục deferred không đưa vào

| Mục | Lý do |
|---|---|
| Privacy screen / che ảnh app-switcher (review 1.9) | **Đóng: rủi ro đã chấp nhận theo PRD NFR-10** (chủ sản phẩm quyết 2026-11-10) |
| `display.size` lúc khởi động và máy gập; đo `StrengthEstimator` bản release; bàn phím với `SecretField` | Cần máy thật, thuộc story 7.1 |
| Tab cuộn về đầu và Back trong tab; cửa sổ khóa lúc chờ hook clipboard (1.8) | Cần nội dung tab hoặc hook thật, thuộc Epic 3 và 4 |
| Quét secret ở mọi workflow | Thuộc story 7.2 |

## 3. Hướng đề xuất

**Direct Adjustment:** thêm 5 story vào cuối Epic 1, làm trước Epic 2.

- **Công sức:** 1.10 nhỏ. 1.11 và 1.12 trung bình. 1.13 trung bình đến lớn (emulator và simulator trong CI). 1.14 nhỏ đến trung bình (sửa `project.pbxproj` tay).
- **Rủi ro:** thấp, chủ yếu là CI và tooling. 1.13 có thể làm CI chậm hoặc flaky, nên được phép tách sang job riêng.
- **Timeline:** Epic 2 lùi khoảng 5 story.
- **Thứ tự:** 1.10 → 1.11 → 1.12 → 1.13 → 1.14. 1.11 trước 1.13 để action emulator mới được ghim theo SHA ngay từ đầu.

## 4. Đề xuất sửa đổi chi tiết

### 4.1 `epics.md`: thêm sau Story 1.9 (trước `## Epic 2`)

```markdown
### Story 1.10: Hiệu chỉnh KDF lùi về sàn khi lần thử đầu lỗi

As a người dùng có máy cấu hình thấp,
I want app vẫn tạo được tài khoản khi máy không chạy nổi tham số khởi điểm của Argon2id,
So that tôi không bị chặn ngay từ bước đầu tiên chỉ vì máy ít RAM (AD-5, NFR-2).

**Acceptance Criteria:**

**Given** `calibrateVaultKdf` chạy lần thử đầu với m=64 MiB, t=3
**When** lần thử đó lỗi (`derive` trả `null` hoặc ném, ví dụ không cấp được bộ nhớ)
**Then** hàm thử lại đúng một lần ở sàn m=19 MiB, t=2 và trả `(params, kek)` của lần đó nếu thành công
**And** chỉ trả `null` khi cả lần thử ở sàn cũng lỗi
**And** không bao giờ trả tham số dưới sàn; mọi KEK không được trả về đều bị `dispose`

**Given** lần thử đầu thành công
**When** hiệu chỉnh tiếp tục
**Then** thuật toán giữ nguyên như story 1.4 (mục tiêu ~1 giây, trần 2 giây, chỉ giảm)
**And** unit test với `derive` giả cho các ca: probe lỗi rồi sàn thành công, cả hai lỗi, probe ném

### Story 1.11: Ghim chuỗi cung ứng và Stack trong CI

As a chủ sản phẩm,
I want mọi thứ CI tải về được ghim chính xác và mọi dependency phải khớp bảng Stack,
So that không thay đổi ngầm nào từ bên ngoài lọt vào build của app mật khẩu trong repo public (AD-12, AD-18).

**Acceptance Criteria:**

**Given** `.github/workflows/ci.yml`
**When** CI chạy
**Then** mọi `uses:` được ghim theo commit SHA đầy đủ (comment ghi tag tương ứng)
**And** runner được ghim phiên bản (`ubuntu-24.04`, `macos-15`, cùng phiên bản Xcode cụ thể), không dùng `*-latest`
**And** sau khi clone Flutter, CI kiểm revision khớp `pak_manager/.metadata`, sai thì fail
**And** `gradle-wrapper.properties` có `distributionSha256Sum`

**Given** `pubspec.yaml` và `pubspec.lock`
**When** CI chạy bước kiểm Stack (script trong `tool/ci/`, có test)
**Then** fail khi một package trực tiếp (kể cả `dev_dependencies`) không có trong bảng Stack của ARCHITECTURE-SPINE, hoặc ràng buộc không phải phiên bản chính xác
**And** danh sách gói kéo theo được phép (vd. `riverpod`, `state_notifier`, `uuid` của `flutter_riverpod`) được ghi rõ trong một file allowlist, gói kéo theo mới ngoài allowlist làm CI fail

### Story 1.12: Kiểm âm cho các cổng CI

As a chủ sản phẩm,
I want chứng minh mỗi cổng CI thực sự fail trên đầu vào xấu,
So that một cổng hỏng âm thầm không khiến mọi build trông như an toàn (AD-18, NFR-7, NFR-8).

**Acceptance Criteria:**

**Given** `tool/ci/check_android_apk.sh` được tách phần phân tích output `aapt2`/`readelf` khỏi phần gọi công cụ
**When** chạy harness kiểm âm với output mẫu
**Then** script fail với: manifest có `android.permission.INTERNET`; `.so` 64-bit căn `0x1000`; `allowBackup="true"`; thiếu `dataExtractionRules`/`fullBackupContent`; thiếu `libsodium.so` hoặc `blocklist.bloom`
**And** pass với output mẫu hợp lệ
**And** kiểm 16 KB chỉ áp cho `arm64-v8a` và `x86_64`; `.so` 32-bit căn 4 KB không làm fail

**Given** APK prod và APK dev
**When** CI kiểm `aapt2 dump badging`
**Then** prod có `applicationId` `io.github.truongthanhnam.pakmanager`, dev có hậu tố `.dev`, sai thì fail

**Given** bước chặn secret của `ci.yml` được tách thành script có test
**When** chạy harness kiểm âm
**Then** script fail với `secrets.X`, `secrets['X']`, `toJSON(secrets)` và `pull_request_target`
**And** harness kiểm âm chạy trong CI

### Story 1.13: Integration test cho API native

As a chủ sản phẩm,
I want CI chạy app thật trên emulator Android và simulator iOS để gọi các kênh native,
So that lỗi đăng ký Pigeon hoặc mất cờ loại-khỏi-backup bị bắt trước khi tới tay người dùng (AD-14, NFR-8).

**Acceptance Criteria:**

**Given** `pak_manager/integration_test/` có test cho `PlatformApi`
**When** CI chạy test trên emulator Android và simulator iOS
**Then** cả bốn kênh Pigeon trả lời được (không `PlatformException` "channel-error")
**And** sau `StorageBootstrap.run()`, kết quả là `StorageReady`
**And** trên iOS, thư mục `pak/` có `isExcludedFromBackup == true`
**And** gỡ `PlatformApiSetup.setUp` (Android) hoặc đăng ký plugin (iOS) làm test fail
**And** job integration được phép tách riêng khỏi job chính; mọi action mới (vd. emulator runner) được ghim theo SHA như story 1.11

### Story 1.14: Flavor dev cho iOS và ghi công giấy phép blocklist

As a chủ sản phẩm,
I want bản dev trên iPhone không ghi đè vault thật và app ghi công đúng giấy phép dữ liệu bên thứ ba,
So that tôi thử app an toàn trên máy của mình và repo tuân thủ giấy phép MIT của SecLists.

**Acceptance Criteria:**

**Given** dự án iOS
**When** build với `--flavor dev`
**Then** có scheme và build configuration `dev` với bundle id `io.github.truongthanhnam.pakmanager.dev`; scheme `prod` giữ bundle id gốc
**And** `flutter build ios --no-codesign` không cờ flavor vẫn build được (hoặc CI build cả hai flavor rõ ràng)
**And** CI kiểm bundle id của từng flavor

**Given** `assets/blocklist.bloom` và `test/fixtures/blocklist/sample.txt` dẫn xuất từ SecLists
**When** rà repo
**Then** có file `NOTICE` (hoặc `THIRD_PARTY_LICENSES`) chứa nguyên văn giấy phép MIT của SecLists và ghi rõ nguồn; `tool/blocklist/SOURCE` trỏ tới file đó
**And** việc đăng ký giấy phép trong app (`LicenseRegistry`) được ghi lại cho story có màn giấy phép
```

### 4.2 `sprint-status.yaml`: Epic 1

```yaml
OLD:
  1-9-tự-khóa-khi-chạy-nền-và-giới-hạn-phiên: done
  epic-1-retrospective: optional

NEW:
  1-9-tự-khóa-khi-chạy-nền-và-giới-hạn-phiên: done
  1-10-hiệu-chỉnh-kdf-lùi-về-sàn-khi-lần-thử-đầu-lỗi: backlog
  1-11-ghim-chuỗi-cung-ứng-và-stack-trong-ci: backlog
  1-12-kiểm-âm-cho-các-cổng-ci: backlog
  1-13-integration-test-cho-api-native: backlog
  1-14-flavor-dev-cho-ios-và-ghi-công-giấy-phép-blocklist: backlog
  epic-1-retrospective: optional
```

`epic-1` giữ `in-progress`.

### 4.3 `deferred-work.md`: thêm dòng `status:` vào từng mục

- Privacy screen (1.9): `status: closed — rủi ro đã chấp nhận theo PRD NFR-10 (chủ sản phẩm 2026-11-10)`
- Hiệu chỉnh KDF probe lỗi (1.4): `status: planned — story 1.10 (phần code); đo trên máy mốc vẫn ở 7.1`
- Ghim action, Flutter, Gradle; ghim runner; so `pubspec` với Stack; gói kéo theo của `riverpod`: `status: planned — story 1.11`
- Kiểm âm `check_android_apk.sh`; regex backup; ELF 16 KB 32-bit; `applicationId`; kiểm âm chặn secret: `status: planned — story 1.12`
- Integration test Pigeon và `isExcludedFromBackup`: `status: planned — story 1.13`
- Flavor dev iOS; giấy phép SecLists: `status: planned — story 1.14`

## 5. Bàn giao thực hiện

- **Phạm vi:** Minor, Developer agent làm trực tiếp.
- **Người nhận:** Developer (`bmad-build` cho từng story, sau đó `bmad-code-review`).
- **Sau khi duyệt:** áp mục 4.1–4.3 vào `epics.md`, `sprint-status.yaml` và `deferred-work.md`.
- **Tiêu chí thành công:**
  - Cả 5 story `done`, CI xanh trên cả hai job.
  - Mỗi mục deferred được ánh xạ ở 4.3 có `status: done` hoặc được ghi rõ phần còn lại thuộc 7.1 hay 7.2.
  - Sau đó chạy retrospective Epic 1 (tùy chọn) rồi sang Epic 2.
