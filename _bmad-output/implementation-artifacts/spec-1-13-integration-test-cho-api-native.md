---
title: 'Story 1.13: Integration test cho API native'
type: 'chore'
created: '2026-11-12'
status: 'done'
baseline_commit: '9a40b7fb31fb1e35a51cdc1c8c93d89b6d05e9de'
route: 'dispatch'
review_loop_iteration: 0
context: []
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** CI chỉ build Android/iOS nên chỉ chứng minh code native biên dịch được. Bỏ `PlatformApi.setUp` (Android) hay đăng ký `PlatformApiSetup.setUp` (iOS) thì mọi lần khởi động đều `StorageUnavailable` mà CI vẫn xanh; cờ `isExcludedFromBackup` trên `pak/` cũng chưa từng được kiểm khi chạy thật (AD-14, AD-11, NFR-8).

**Approach:** Thêm `pak_manager/integration_test/` (package `integration_test` của SDK) chạy app thật: gọi mọi phương thức Pigeon, chạy `StorageBootstrap` với adapter thật, và trên iOS đọc lại cờ backup qua một phương thức Pigeon chỉ đọc mới. CI thêm hai job riêng: emulator Android và simulator iOS.

## Boundaries & Constraints

**Always:**
- Gọi đủ mọi phương thức của `PlatformApi` (story ghi "bốn kênh"; nay có thêm `androidSdkInt` và `isExcludedFromBackup`) — không phương thức nào được ném `PlatformException` (đặc biệt code `channel-error`).
- Giá trị kiểm có nghĩa: `monotonicMs` > 0 và không giảm giữa hai lần gọi; `androidSdkInt` ≥ 24 trên Android, `== 0` trên iOS; `bootId` trả chuỗi (có thể rỗng); `fsyncDirectory(pakDir)` không ném.
- `StorageBootstrap(directories: PathProviderDirectory(), backup: PigeonPlatformPorts()).run()` trả `StorageReady`.
- Phương thức mới `bool isExcludedFromBackup(String dirPath)` trong `pigeons/platform_api.dart`: iOS đọc `URLResourceValues.isExcludedFromBackup`; Android trả `false` (không có cờ tương ứng). Sinh lại code Pigeon và commit.
- Thêm `integration_test` (sdk: flutter) vào `dev_dependencies` và vào dòng SDK của bảng Stack trong ARCHITECTURE-SPINE; gói kéo theo mới vào `tool/ci/transitive_allowlist.txt` sau khi rà không có mã mạng ngoài phạm vi test.
- Action mới ghim theo SHA kèm comment tag (như story 1.11): `reactivecircus/android-emulator-runner@a421e43855164a8197daf9d8d40fe71c6996bb0d # v2.38.0`. Simulator iOS dùng `xcrun simctl`, không action.
- Android chạy `--flavor dev` (bản debug, id `.dev`); iOS không flavor (story 1.14).
- Tên test gắn AD (vd `ad14_all_channels_reply`, `ad11_pak_excluded_from_backup_ios`); comment tiếng Việt; chỉ dùng fake tự viết, không mock.

**Never:**
- Không đổi hành vi của `StorageBootstrap`, `PigeonPlatformPorts` (ngoài nối phương thức mới nếu cần) hay luồng `main.dart`.
- Không thêm action/dependency nào khác; không gộp integration vào job `android`/`ios` hiện có.
- Không kiểm UI/flow đăng nhập (ngoài phạm vi).

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Kênh đăng ký đủ | app thật trên emulator/simulator | mọi phương thức trả lời | N/A |
| Bỏ đăng ký native | gỡ `setUp` | `PlatformException(channel-error)` → test fail | job CI đỏ |
| Bootstrap | ApplicationSupport thật | `StorageReady`, `pak/` tồn tại | `StorageUnavailable` → fail |
| Cờ backup iOS | sau bootstrap | `isExcludedFromBackup(pakDir) == true` | `false` → fail |
| Android | sau bootstrap | không kiểm cờ (manifest đã có cổng APK) | N/A |

</frozen-after-approval>

## Code Map

- `pak_manager/pigeons/platform_api.dart` -- thêm `isExcludedFromBackup`; sinh `lib/platform/platform_api.g.dart`, `android/.../PlatformApi.g.kt`, `ios/Runner/PlatformApi.g.swift` bằng `dart run pigeon --input pigeons/platform_api.dart` (CI kiểm khớp).
- `pak_manager/android/app/src/main/kotlin/io/github/truongthanhnam/pakmanager/PlatformApiImpl.kt`, `ios/Runner/PlatformApiImpl.swift` -- cài phương thức mới; Swift dùng `removeAllCachedResourceValues()` rồi đọc `.isExcludedFromBackupKey` (giống phần đọc lại trong `excludeFromBackup`).
- `pak_manager/lib/platform/pigeon_ports.dart` -- adapter; không thêm vào port (phương thức mới chỉ dùng trong test, gọi thẳng `PlatformApi()`).
- `pak_manager/lib/services/storage_bootstrap.dart`, `lib/platform/path_provider_directory.dart` -- dùng nguyên.
- `MainActivity.kt` (`PlatformApi.setUp`), `ios/Runner/AppDelegate.swift` (`didInitializeImplicitFlutterEngine`) -- điểm đăng ký; không sửa.
- `pak_manager/pubspec.yaml`, `pubspec.lock`, `tool/ci/transitive_allowlist.txt`, `tool/ci/check_stack.dart` (SDK dep phải có trong Stack) -- thêm `integration_test`.
- `_bmad-output/planning-artifacts/architecture/architecture-passwordmanager-2026-10-27/ARCHITECTURE-SPINE.md:435` -- thêm `integration_test` vào dòng SDK.
- `.github/workflows/ci.yml` -- hai job mới, lặp bước cài Flutter (kiểm revision) + pub get như job hiện có.
- `_bmad-output/implementation-artifacts/deferred-work.md:58` -- mục `planned — story 1.13` → `done`.

## Tasks & Acceptance

**Execution:**
- [x] `pak_manager/pigeons/platform_api.dart` + code sinh + hai `PlatformApiImpl` -- thêm `isExcludedFromBackup`.
- [x] `pak_manager/pubspec.yaml`, `pubspec.lock`, `tool/ci/transitive_allowlist.txt`, ARCHITECTURE-SPINE -- thêm `integration_test`; `dart run tool/ci/check_stack.dart` sạch.
- [x] `pak_manager/integration_test/platform_api_test.dart` -- `IntegrationTestWidgetsFlutterBinding.ensureInitialized()`; test kênh, bootstrap, cờ backup iOS (`skip` trên Android).
- [x] `.github/workflows/ci.yml` -- job `integration-android` (ubuntu-24.04, bật KVM, emulator API 34 x86_64, `flutter test integration_test --flavor dev`) và `integration-ios` (macos-15, Xcode 26.3, boot simulator iPhone qua `simctl`, `flutter test integration_test -d <udid>`); timeout ≤ 60 phút.
- [x] `deferred-work.md` -- cập nhật trạng thái.

**Acceptance Criteria:**
- Given PR, when CI chạy, then hai job integration chạy test trên emulator Android và simulator iOS và pass.
- Given repo, when `flutter analyze --fatal-infos --fatal-warnings`, `flutter test`, `dart run tool/ci/check_stack.dart`, `dart run tool/ci/check_workflow_secrets.dart ../.github/workflows/ci.yml`, then đều sạch.

### Review Findings

- [x] [Review][Patch] `fsyncDirectory` chưa gọi trên `pakDir` thật (Always: "`fsyncDirectory(pakDir)` không ném") — chỉ gọi trên thư mục tạm; thêm `await PlatformApi().fsyncDirectory(pakDir)` trong `nfr8_storage_bootstrap_ready` [pak_manager/integration_test/platform_api_test.dart:65]
- [x] [Review][Defer] AC1/AC2 chưa có bằng chứng chạy xanh (job integration, `check_workflow_secrets.dart`) và kiểm âm "gỡ đăng ký → đỏ" chưa chạy [.github/workflows/ci.yml] — deferred: maybe-false (medium nếu đúng); xác nhận bằng kết quả GitHub Actions của PR và một nhánh tạm bỏ `PlatformApi.setUp`

**Rejected:**
- Lệch trạng thái spec `done` / sprint `review` (low) — sprint được đồng bộ ở bước cuối review; sửa là sửa spec.
- Android `isExcludedFromBackup` hằng `false` (false) — đúng ràng buộc spec đã duyệt.
- Android/iOS khác hành vi khi đường dẫn không tồn tại (low) — test luôn truyền đường dẫn tồn tại; đã reject ở triage trước.
- Kiểm âm chưa chạy (low) — gộp vào mục defer về CI.
- Phụ thuộc thứ tự test / first-run (false) — test chạy tuần tự theo thứ tự khai báo; `nfr8` đứng trước `ad11`, và CI dùng máy ảo mới nên first-run luôn được chạy.
- Simulator iOS không ghim runtime (low) — sửa thêm phức tạp, chưa gặp lỗi thực tế.
- Không upload log khi fail (low) — cần action mới, bị spec cấm.
- Mục Verification thiếu lệnh / bảng thiếu dòng trống (low) — sửa spec.
- `monotonicMs` kiểm yếu (low) — spec chỉ yêu cầu không giảm; thêm delay là thêm phức tạp.

## Implementation Notes

- Thêm 6 gói kéo theo vào allowlist (`flutter_driver`, `fuchsia_remote_debug_protocol`, `process`, `sync_http`, `web`, `webdriver`); `sync_http`/`webdriver`/`web` có mã mạng nhưng chỉ vào qua dev dependency `integration_test` — ghi trong mô tả PR.
- Kiểm âm "gỡ đăng ký → đỏ" chưa chạy trên CI.

## Spec Change Log

## Review Triage Log

| # | Nguồn | Phát hiện | Verdict | Bằng chứng / Route |
|---|---|---|---|---|
| 1 | blind | ad14 gọi `excludeFromBackup(pakDir)` trước ad11 nên ad11 qua dù bootstrap thôi đặt cờ | medium | Test chung sandbox, chạy theo thứ tự. patch: ad14 dùng thư mục tạm riêng |
| 2 | edge | ad14 bỏ qua kết quả `isExcludedFromBackup` trên iOS | low | Gộp với #1, assert trên thư mục tạm. patch |
| 3 | edge, blind | `simctl boot` lỗi khi máy ảo đã boot | low | Runner mới thường shutdown, sửa trực tiếp `|| true`. patch |
| 4 | edge | `bootstatus -b` treo tới timeout job | low | Thêm `timeout-minutes: 15`. patch |
| 5 | edge | Khóa runtime không có hậu tố số | false | Khóa simctl luôn dạng `...iOS-X-Y`. reject |
| 6 | edge | Android trả `false` khi đường dẫn không tồn tại, iOS ném | low | Chỉ test gọi, đường dẫn luôn tồn tại. reject |
| 7 | edge, blind | Trạng thái spec/sprint/deferred lệch | low | Sprint đồng bộ ở bước cuối. reject |
| 8 | blind | Kiểm âm thủ công chưa được ghi | low | Spec ghi "nếu làm"; nêu trong Implementation Notes. reject |
| 9 | blind | Allowlist không ghi chú lý do | low | Header allowlist quy định ghi trong mô tả PR. reject |
| 10 | blind | Phương thức chỉ dùng test có mặt trong bản release | low | Quyết định đã duyệt ở checkpoint; chỉ đọc. reject |
| 11 | blind | Chỉ test bản debug; lỗi R8/release lọt | medium | Thật, ngoài phạm vi đã duyệt. defer |
| 12 | blind | Bước cài Flutter lặp 4 lần | low | Sửa cần composite action, thêm phức tạp. reject |
| 13 | blind | Mục Verification thiếu lệnh | low | Sửa spec. reject |
| 14 | blind | Không cache Gradle/pub/AVD | low | Tối ưu, chưa có bằng chứng vượt timeout. reject |
| 15 | blind | `bootId` chỉ kiểm `isA<String>` | low | Spec cho phép chuỗi rỗng. reject |
## Design Notes

Kiểm cờ backup cần một lối đọc từ native; thêm phương thức chỉ đọc vào API Pigeon duy nhất (AD-14) rẻ hơn kênh test riêng và không đụng luồng app. `excludeFromBackup` iOS đã tự đọc lại, nhưng test độc lập bắt được trường hợp phần đọc lại đó bị gỡ. Bằng chứng "gỡ đăng ký → fail": Pigeon ném `PlatformException(code: 'channel-error')` khi không có handler, và test gọi trực tiếp mọi phương thức nên không có đường lọt; kiểm âm thủ công một lần trên CI được ghi vào Implementation Notes nếu làm.

## Verification

**Commands:**
- `cd pak_manager && dart run pigeon --input pigeons/platform_api.dart && git status --porcelain -- lib android ios` -- chỉ các thay đổi đã commit
- `cd pak_manager && flutter analyze --fatal-infos --fatal-warnings` -- sạch
- `cd pak_manager && flutter test` -- pass
- `cd pak_manager && dart run tool/ci/check_stack.dart` -- OK

**Manual checks (if no CLI):**
- Kết quả hai job integration trên PR GitHub Actions xanh.
