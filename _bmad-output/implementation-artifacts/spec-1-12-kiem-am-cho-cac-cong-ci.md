---
title: 'Story 1.12: Kiểm âm cho các cổng CI'
type: 'chore'
created: '2026-11-12'
status: 'done'
baseline_commit: '6986a4ef2560f4bad799880d90024ce1a2d447e2'
route: 'dispatch'
review_loop_iteration: 0
context: []
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** Các cổng CI (kiểm APK, chặn secret) chỉ từng chạy trên đầu vào tốt; nếu regex lệch định dạng output `aapt2`/`readelf` hoặc bị thu hẹp, mọi build vẫn xanh (AD-18, NFR-7, NFR-8). Kiểm ELF 16 KB hiện còn áp cả `.so` 32-bit, và không gì kiểm `applicationId` prod/dev.

**Approach:** Tách phần phân tích ra hai script Dart thuần có test (`tool/ci/apk_rules.dart`, `tool/ci/check_workflow_secrets.dart`); `check_android_apk.sh` chỉ gọi công cụ, lưu output thô vào thư mục rồi gọi Dart phân tích. Test chạy output mẫu tốt/xấu trong `flutter test` (đã chạy trong CI). CI build thêm APK dev để kiểm badging.

## Boundaries & Constraints

**Always:**
- Script Dart chỉ import `dart:*` (như `check_stack.dart`): hàm thuần nhận chuỗi trả `List<String>` vi phạm, `run(args, {out, err}) → int`, `main` gọi `exit(run(...))`. Exit 1 kèm mỗi vi phạm một dòng stderr; exit 0 in "OK".
- Luật APK (từ output thô): không có `android.permission.INTERNET`; `allowBackup` = `false` hoặc `(type 0x12)0x0`; có `dataExtractionRules` và `fullBackupContent` trỏ `@`; có `lib/arm64-v8a/`; mọi `lib/<abi>/` có `libsodium.so`; có `assets/flutter_assets/assets/blocklist.bloom`; mọi segment LOAD của `.so` thuộc `arm64-v8a`/`x86_64` có align ≥ `0x4000`, `.so` không có LOAD → vi phạm; `.so` của ABI khác (32-bit) không kiểm align.
- Luật badging: `package: name='…'` đúng `io.github.truongthanhnam.pakmanager` (prod) hoặc `io.github.truongthanhnam.pakmanager.dev` (dev); thiếu dòng → vi phạm.
- Luật secret: fail khi workflow có `secrets.X`, `secrets['X']`, `secrets["X"]`, `toJSON(secrets)` (khoảng trắng tùy ý) hoặc `pull_request_target`; giữ nguyên ngữ nghĩa regex hiện tại (`secrets` theo sau ký tự không phải từ hoặc cuối dòng). Dòng comment YAML vẫn bị quét (fail-closed).
- `zipalign -c -P 16` giữ nguyên trong shell (exit code của công cụ).
- Thông điệp/comment tiếng Việt; tên test gắn AD/NFR (vd `ad18_secret_bracket_rejected`).

**Never:**
- Không thêm dependency; không đổi bảng Stack.
- Không gom/kiểm âm bước so revision Flutter, không đối chiếu Flutter/Gradle/Xcode với Stack (để lại trong deferred-work).
- Không quét workflow khác ngoài `ci.yml` (story 7.2).

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| APK hợp lệ | manifest, listing, readelf mẫu tốt | exit 0 | N/A |
| INTERNET | manifest có `uses-permission … android.permission.INTERNET` | vi phạm INTERNET | exit 1 |
| Backup bật | `allowBackup(0x01010280)=true` | vi phạm allowBackup | exit 1 |
| Thiếu rules | không có `dataExtractionRules` hoặc `fullBackupContent` | vi phạm nêu thuộc tính | exit 1 |
| 64-bit căn 4 KB | readelf `arm64-v8a/libapp.so` LOAD align `0x1000` | vi phạm nêu file | exit 1 |
| 32-bit căn 4 KB | readelf `armeabi-v7a/libapp.so` align `0x1000` | không vi phạm | N/A |
| Thiếu lib | ABI không có `libsodium.so`; thiếu `blocklist.bloom` | vi phạm tương ứng | exit 1 |
| Badging sai | prod có `.dev`, dev thiếu `.dev`, hoặc không có dòng `package:` | vi phạm applicationId | exit 1 |
| Secret | `secrets.X`, `secrets['X']`, `toJSON( secrets )`, `pull_request_target` | vi phạm nêu dòng | exit 1 |
| ci.yml thật | file repo hiện tại | không vi phạm | N/A |

</frozen-after-approval>

## Code Map

- `pak_manager/tool/ci/check_android_apk.sh` -- logic hiện tại (grep manifest, readelf `awk '$1=="LOAD"{print $NF}'`, kiểm ABI/asset). Giữ phần kiểm công cụ, `zipalign`; ghi ra `$work`: `manifest.txt`, `listing.txt` (`unzip -l`), `readelf/<abi>/<so>.txt`, rồi `dart run tool/ci/apk_rules.dart apk <work>`. Thêm tham số tùy chọn `--expect-id <id>` → `aapt2 dump badging` → `badging.txt`.
- `pak_manager/tool/ci/check_stack.dart` + `test/tool/check_stack_test.dart` -- mẫu cấu trúc `run`/`main` và test chuỗi nội tuyến.
- `.github/workflows/ci.yml` -- bước "Workflow PR không dùng secret" (grep inline) → `dart run tool/ci/check_workflow_secrets.dart ../.github/workflows/ci.yml`, nên phải chuyển xuống sau "Pub get". Bước "Kiểm APK": thêm `--expect-id`; thêm build `--flavor dev` + kiểm APK dev (`app-dev-release.apk`, id `.dev`).
- `pak_manager/android/app/build.gradle.kts:18,36` -- `applicationId`, `applicationIdSuffix = ".dev"` (không sửa).
- `_bmad-output/implementation-artifacts/deferred-work.md` -- các mục `planned — story 1.12` chuyển `done`.

## Tasks & Acceptance

**Execution:**
- [x] `pak_manager/tool/ci/apk_rules.dart` -- tạo: `checkManifest`, `checkListing`, `checkElfAligns(Map<abiPath, readelfText>)`, `checkBadging(text, expectedId)`, `run(['<workDir>', expectedId?])`.
- [x] `pak_manager/tool/ci/check_workflow_secrets.dart` -- tạo: `checkWorkflowSecrets(text) → List<String>` (dạng `dòng N: …`), `run`.
- [x] `pak_manager/tool/ci/check_android_apk.sh` -- rút gọn thành thu thập output + gọi `apk_rules.dart`.
- [x] `pak_manager/test/tool/apk_rules_test.dart`, `test/tool/check_workflow_secrets_test.dart` -- mọi dòng I/O Matrix (output mẫu nội tuyến đúng định dạng `aapt2`/`readelf -lW`), test `run` exit code, test `ci.yml` thật sạch.
- [x] `.github/workflows/ci.yml` -- như Code Map.
- [x] `deferred-work.md` -- cập nhật trạng thái.

**Acceptance Criteria:**
- Given CI trên PR, when job android chạy, then `flutter test` chạy cả hai harness kiểm âm và cả APK prod lẫn dev được kiểm badging.
- Given repo hiện tại, when `dart run tool/ci/check_workflow_secrets.dart ../.github/workflows/ci.yml`, then exit 0.

## Design Notes

Phân tích bằng Dart thay vì bash để harness chạy được trên máy dev Windows và trong `flutter test` có sẵn, không cần bats/shellcheck. Shell chỉ còn là lớp gọi công cụ mỏng; hợp đồng giữa hai lớp là cấu trúc thư mục `$work`.

## Verification

**Commands:**
- `cd pak_manager && flutter test test/tool/` -- pass
- `cd pak_manager && dart run tool/ci/check_workflow_secrets.dart ../.github/workflows/ci.yml` -- exit 0
- `cd pak_manager && flutter analyze --fatal-infos --fatal-warnings` -- sạch
- `bash -n pak_manager/tool/ci/check_android_apk.sh` -- cú pháp đúng

## Implementation Notes

## Spec Change Log

## Review Triage Log

| # | Nguồn | Phát hiện | Verdict | Bằng chứng / Route |
|---|---|---|---|---|
| 1 | edge, blind | Luật secret phân biệt hoa thường; `Secrets.X` lọt, test còn khóa lỗ hổng | medium | Context biểu thức GitHub không phân biệt hoa thường. patch |
| 2 | edge | `Pull_Request_Target` lọt | false | Tên sự kiện trong `on:` phân biệt hoa thường; viết khác thì không phải trigger. reject |
| 3 | edge | ABI 64-bit khác (riscv64) không kiểm align | low | Flutter không đóng gói riscv64; spec quy định đúng hai ABI. reject |
| 4 | edge | `lib/arm64-v8a/` chỉ có file không phải `.so` vẫn qua | low | Sửa trực tiếp một điều kiện. patch |
| 5 | edge | `.so` lồng sâu hơn `lib/<abi>/` không bị kiểm | low | Android không nạp `.so` lồng; không gặp thực tế. reject |
| 6 | edge | `run` bỏ qua tham số thừa / id rỗng | low | Chỉ CI gọi với tham số cố định; thêm nhánh. reject |
| 7 | edge, blind | Bước chặn secret chạy muộn hơn (sau setup-java, Flutter, pub get) | low | Cổng là kiểm tĩnh fail job, trước đây cũng không chặn được bước trước nó; các bước trước do chính `ci.yml` định nghĩa. reject |
| 8 | blind | Glob `secret[s]` trong `ci.yml` mong manh | low | Không khớp thì `dart run` lỗi → fail-closed. reject |
| 9 | blind | Listing parse lệch → `.so` thoát kiểm align | false | Không parse được `.so` nào → vi phạm "không có lib/*/*.so"; fail-closed. reject |
| 10 | blind | Fixture output công cụ là tự viết, không phải output thật | medium | Thật; cần output từ lần CI build thật. defer |
| 11 | vgap, blind | Lớp shell (`--expect-id` → `rule_args`, `failed=1`) không có test | medium | Bỏ truyền id thì badging bị bỏ qua mà CI vẫn xanh. defer |
| 12 | blind | Trạng thái spec/sprint/deferred lệch; ghi chú 32-bit đóng khi chưa có bằng chứng CI | low | Sprint đồng bộ ở bước cuối; luật mới không còn kiểm 32-bit nên mục đó được giải quyết theo thiết kế. reject |
| 13 | blind | Thiếu kiểm đích resource backup, quyền dư của dev, zipalign | low | Ngoài luật đã duyệt; `uses-permission-sdk-23` vẫn bị bắt vì so chuỗi con. reject |
| 14 | blind | Build dev tăng thời gian CI, không ghi chú | low | Chi phí đã biết khi duyệt AC badging dev. reject |

### Review Findings

- [x] [Review][Patch] Thêm newline cuối file cho deferred-work.md và spec này [deferred-work.md / spec-1-12-kiem-am-cho-cac-cong-ci.md]
- [x] [Review][Defer] Lớp shell check_android_apk.sh chưa có test (hợp đồng `$work`, truyền `--expect-id`, exit code) [pak_manager/tool/ci/check_android_apk.sh:78-91] — deferred: đã ghi ở triage #11, cần harness công cụ giả trên PATH
- [x] [Review][Defer] Cổng zipalign -c -P 16 không có kiểm âm và chưa được ghi deferred [pak_manager/tool/ci/check_android_apk.sh:58] — deferred: cần cùng harness công cụ giả
- [x] [Review][Defer] Không test nào khẳng định ci.yml còn chạy các cổng (bước secret, `--expect-id` cho prod/dev) [.github/workflows/ci.yml:47-65] — deferred: có từ trước, cần test parse ci.yml

#### Rejected

- Luật secret không phân biệt hoa thường, lệch "giữ nguyên regex": cố ý theo triage #1, chặt hơn (fail-closed). Sửa thì phải sửa spec.
- Code Map ghi subcommand `apk`; trạng thái spec `done` khác sprint `review`: sửa thì phải sửa spec.
- `.so` viết hoa/lồng sâu, ABI chỉ có file không phải `.so`, thừa tham số: thực tế không gặp.
- INTERNET khớp chuỗi con; `unzip || true`: fail-closed, các bước sau báo thiếu readelf.
- Bước secret chạy sau Pub get: spec yêu cầu thế (cần dart).
- Script phải chạy trong pak_manager/: đã ghi trong header, CI chạy ở đúng thư mục.
- Từ "secrets" trong comment bị chặn: fail-closed theo thiết kế, comment trong ci.yml đã ghi cách lách.
- Log khi lỗi ít chi tiết hơn bản shell cũ: vẫn nêu vi phạm và align sai; mức low.
- allowBackup không gắn với phần tử application: aapt2 chỉ in thuộc tính này trên `<application>`.
- `_prTarget` phân biệt hoa thường: tên event của GitHub phân biệt hoa thường.
- Fixture `_goodPaths` thiếu x86 và fixture tự viết tay: low; fixture tự viết đã nằm trong triage #10.
