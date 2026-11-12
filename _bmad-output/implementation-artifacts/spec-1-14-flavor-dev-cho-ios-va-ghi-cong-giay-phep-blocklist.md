---
title: 'Story 1.14: Flavor dev cho iOS và ghi công giấy phép blocklist'
type: 'chore'
created: '2026-11-12'
status: 'done'
baseline_commit: '4c8de84eef866c2162e749785e4841de289e0fd0'
route: 'dispatch'
review_loop_iteration: 0
context: []
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** iOS chỉ có một bundle id nên cài bản dev lên iPhone sẽ ghi đè app thật cùng vault thật (AD-19 mới làm flavor ở Android). `assets/blocklist.bloom` và `test/fixtures/blocklist/sample.txt` dẫn xuất từ SecLists (MIT) nhưng repo chưa có file chứa nguyên văn giấy phép.

**Approach:** Thêm scheme `prod`/`dev` và build configuration `{Debug,Release,Profile}-{prod,dev}` vào dự án Xcode (giữ scheme `Runner` và cấu hình gốc để build không cờ vẫn chạy); CI build iOS cả hai flavor và kiểm bundle id. Thêm file `NOTICE` chứa nguyên văn MIT của SecLists, trỏ từ `tool/blocklist/SOURCE`, và ghi việc `LicenseRegistry` vào deferred-work.

## Boundaries & Constraints

**Always:**
- `dev` → `io.github.truongthanhnam.pakmanager.dev`, tên hiển thị "PAK Manager Dev" (giống Android); `prod` và build không cờ → `io.github.truongthanhnam.pakmanager`, "PAK Manager".
- Cấu hình flavor kế thừa đúng xcconfig của chế độ (`Debug-*` → `Debug.xcconfig`, `Release-*`/`Profile-*` → `Release.xcconfig`) và mọi build setting của cấu hình gốc tương ứng; thêm cho cả cấp project, target `Runner` và `RunnerTests`.
- CI job `ios`: `flutter build ios --release --no-codesign --flavor prod` và `--flavor dev`, sau mỗi lần đọc `CFBundleIdentifier` trong `build/ios/iphoneos/Runner.app/Info.plist` (PlistBuddy) và fail nếu lệch. Build không cờ được giữ bằng job `integration-ios` hiện có (không cờ).
- `NOTICE` (trong `pak_manager/`) chứa nguyên văn LICENSE của SecLists tại commit ghim `a1a06ab5…`, tên repo, commit, các `path` dùng, và ghi chú `rockyou` là dữ liệu bị lộ, không do SecLists viết.
- Comment và văn bản tiếng Việt (trừ nguyên văn giấy phép).

**Never:**
- Không đổi flavor Android, code Dart, luồng app, hay asset blocklist.
- Không thêm `default-flavor` vào `pubspec.yaml`; không thêm action/dependency mới.
- Không làm màn giấy phép hay gọi `LicenseRegistry.addLicense` trong story này.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Flavor dev | `flutter build ios --flavor dev --no-codesign` | bundle id `.dev` | lệch → CI đỏ |
| Flavor prod | `--flavor prod` | bundle id gốc | lệch → CI đỏ |
| Không cờ | `flutter build ios` / `flutter test integration_test -d <sim>` | scheme `Runner`, bundle id gốc | build lỗi → CI đỏ |

</frozen-after-approval>

## Code Map

- `pak_manager/ios/Runner.xcodeproj/project.pbxproj` -- cấu hình gốc: project `97C147031CF9000F007C117D`/`97C147041CF9000F007C117D`/`249021D3217E4FDB00AE95B9`, Runner `97C147061CF9000F007C117D`/`97C147071CF9000F007C117D`/`249021D4217E4FDB00AE95B9`, RunnerTests `331C8088…`/`331C8089…`/`331C808A…`; ba `XCConfigurationList` ở cuối file. Nhân bản mỗi cấu hình thành `-prod`/`-dev` với ID mới 24 hex duy nhất; Runner dev đổi `PRODUCT_BUNDLE_IDENTIFIER`, RunnerTests dev → `...pakmanager.dev.RunnerTests`. Thêm build setting `APP_DISPLAY_NAME` cho Runner (mọi cấu hình). Không dùng CocoaPods (SwiftPM qua `FlutterGeneratedPluginSwiftPackage`) — không có Podfile cần sửa.
- `pak_manager/ios/Runner/Info.plist:9-10,22-23` -- `CFBundleDisplayName`/`CFBundleName` → `$(APP_DISPLAY_NAME)`.
- `pak_manager/ios/Runner.xcodeproj/xcshareddata/xcschemes/Runner.xcscheme` -- mẫu; sao thành `prod.xcscheme`/`dev.xcscheme`, đổi `buildConfiguration` từng action sang `<Mode>-<flavor>`.
- `.github/workflows/ci.yml:130-167` -- job `ios`; thay bước build bằng hai bước flavor + kiểm bundle id. `integration-ios` (dòng ~223) giữ nguyên, không cờ.
- `pak_manager/android/app/build.gradle.kts:27-39` -- flavor Android để đối chiếu; không sửa.
- `pak_manager/tool/blocklist/SOURCE`, `pak_manager/assets/blocklist.FORMAT.md:41` -- thêm dòng trỏ `NOTICE`.
- `_bmad-output/implementation-artifacts/deferred-work.md:4-6,107-109` -- hai mục `planned — story 1.14` → `done`; thêm mục mới: gọi `LicenseRegistry.addLicense` với nội dung `NOTICE` (asset) khi có story màn giấy phép (epics hiện chưa có).

## Tasks & Acceptance

**Execution:**
- [x] `pak_manager/ios/Runner.xcodeproj/project.pbxproj` -- thêm 18 cấu hình (3 list × 6) và `APP_DISPLAY_NAME` -- flavor iOS (AD-19).
- [x] `pak_manager/ios/Runner/Info.plist` -- tên hiển thị theo build setting.
- [x] `pak_manager/ios/Runner.xcodeproj/xcshareddata/xcschemes/{prod,dev}.xcscheme` -- scheme mới.
- [x] `.github/workflows/ci.yml` -- build hai flavor + kiểm bundle id.
- [x] `pak_manager/NOTICE`, `tool/blocklist/SOURCE`, `assets/blocklist.FORMAT.md` -- ghi công MIT.
- [x] `deferred-work.md` -- cập nhật trạng thái, thêm mục `LicenseRegistry`.

**Acceptance Criteria:**
- Given PR, when CI chạy, then job `ios` build được cả `prod` và `dev` với bundle id đúng, và `integration-ios` (không cờ) xanh.
- Given `project.pbxproj` sửa tay, when `plutil -lint` (CI macOS) hoặc kiểm ID trùng bằng script, then hợp lệ và không ID trùng.
- Given repo, when `flutter analyze --fatal-infos --fatal-warnings`, `flutter test`, `dart run tool/ci/check_workflow_secrets.dart ../.github/workflows/ci.yml`, then đều sạch.

## Implementation Notes

## Spec Change Log

## Review Triage Log

| # | Nguồn | Phát hiện | Verdict | Bằng chứng / Route |
|---|---|---|---|---|
| 1 | edge, verify, blind | CI không kiểm `CFBundleDisplayName`; thiếu `APP_DISPLAY_NAME` cho tên rỗng/sai mà vẫn xanh | medium | Xcode mở rộng biến chưa định nghĩa thành chuỗi rỗng, không lỗi. patch: kiểm tên trong hai bước PlistBuddy |
| 2 | edge | Cấu hình tương lai thiếu `APP_DISPLAY_NAME` | low | Hiếm gặp; sửa cần tái cấu trúc xcconfig. reject |
| 3 | edge | Bước dev đọc `Runner.app` cũ của prod | false | `flutter build` ghi lại `Runner.app` hoặc bước build fail trước khi tới bước kiểm. reject |
| 4 | edge | NOTICE có thể không đúng nguyên văn LICENSE | false | Đã tải `LICENSE` tại commit `a1a06ab5…` từ raw.githubusercontent, khớp. reject |
| 5 | verify | `FORMAT.md` và generator có thể lệch | low | Có từ trước; cần thêm test. reject |
| 6 | blind | Build release không cờ không còn trong CI | low | Intent đã duyệt: build không cờ giữ bằng `integration-ios`; cấu hình `Release` chỉ thêm một build setting. reject |
| 7 | blind | `plutil -lint` không bắt ID trùng/tham chiếu hỏng | low | Tham chiếu hỏng làm `flutter build` fail; đã kiểm ID trùng một lần. reject |
| 8 | blind | Cấu hình flavor sao chép đầy đủ dễ lệch | low | Chưa có migration cụ thể gây hại; sửa là tái cấu trúc. reject |
| 9 | blind | Trạng thái spec/sprint/deferred lệch | low | Sprint đồng bộ ở bước cuối; sửa là sửa spec. reject |
| 10 | blind | App phát hành chưa mang giấy phép MIT | low | Intent tách `LicenseRegistry` sang story màn giấy phép, đã ghi deferred. reject |
| 11 | blind | NOTICE không tự đồng bộ với SOURCE | low | Commit ghim hiếm đổi; cần thêm test. reject |
| 12 | blind | NOTICE không ở gốc repo | low | Đặt cạnh asset và SOURCE trong `pak_manager/`. reject |
| 13 | blind | Scheme mới mang `LastUpgradeVersion` cũ | false | Giống hệt `Runner.xcscheme`. reject |
| 14 | blind | Không có bước kiểm iOS cục bộ | low | Máy dev Windows; CI macOS là bằng chứng (Design Notes). reject |

## Design Notes

Flutter chọn scheme = tên flavor và cấu hình `<Mode>-<flavor>`; không cờ thì dùng scheme `Runner` với `Release`/`Debug`. Giữ cấu hình gốc nên mọi lệnh hiện có (`flutter run`, integration test iOS) không đổi. Máy dev Windows không build được iOS, nên sửa pbxproj bằng script sinh ID và để CI macOS là bằng chứng chính; bước `plutil -lint` chạy trước build cho lỗi cú pháp rõ ràng.

## Verification

**Commands:**
- `cd pak_manager && flutter analyze --fatal-infos --fatal-warnings` -- sạch
- `cd pak_manager && flutter test` -- pass
- `cd pak_manager && dart run tool/ci/check_workflow_secrets.dart ../.github/workflows/ci.yml` -- OK

**Manual checks (if no CLI):**
- Job `ios` và `integration-ios` trên PR GitHub Actions xanh.
