---
title: 'Story 1.1 — Khởi tạo dự án Flutter theo Structural Seed và cổng CI'
type: 'chore'
created: '2026-11-02'
status: 'done'
route: 'dispatch'
baseline_commit: '1e425e8f576a1d7c114145d61d3beb929286631d'
review_loop_iteration: 0
context:
  - '{project-root}/_bmad-output/implementation-artifacts/epic-1-context.md'
  - '{project-root}/_bmad-output/planning-artifacts/architecture/architecture-passwordmanager-2026-10-27/ARCHITECTURE-SPINE.md'
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** Repo mới chỉ có tài liệu. Chưa có dự án Flutter, chưa có luật phân lớp được máy kiểm, chưa có CI, nên story sau có thể lệch kiến trúc, lọt quyền mạng hoặc log lỗi ở bản release.

**Approach:** Tạo `pak_manager/` bằng `flutter create` (Flutter 3.47.8), dựng cây thư mục theo Structural Seed, ghim dependency, viết `tool/check_imports.dart` có test, lint khai báo trực tiếp, chính sách lỗi cho bản release và workflow GitHub Actions cho PR.

## Boundaries & Constraints

**Always:** Version đúng bảng Stack, ghim chính xác (không `^`). App ID `io.github.truongthanhnam.pakmanager`; Android minSdk 24, compile/targetSdk 36; iOS 15.0. `lib/` chỉ dùng `package:cupertino_ui`. Script trong `tool/` là Dart thuần, không dependency, xuất bằng `stdout`/`stderr`. Workflow PR chỉ có `permissions: contents: read`, không tham chiếu `secrets.*`, dùng `pull_request` (không `pull_request_target`).

**Never:** Không thêm package ngoài Stack, kể cả `flutter_lints`. Không dùng starter template. Không làm phần thuộc story sau: backup/manifest `allowBackup` (1.2), Pigeon (1.2), l10n/theme (1.3), crypto (1.4). Không dùng action bên thứ ba để cài Flutter.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Sạch | `lib/` đúng luật | exit 0, không in vi phạm | N/A |
| Cấm toàn `lib/` | import `package:flutter/material.dart`, `flutter/cupertino.dart`, `package:material_ui/…`, `package:http/…` | exit 1, `path:line: lý do` | liệt kê mọi vi phạm, không dừng ở cái đầu |
| features → core cấm | `lib/features/x.dart` import `core/crypto|format|io|ports`, `lib/platform/` hoặc `dart:io` (dạng `package:pak_manager/…` hay tương đối) | exit 1 | đường dẫn tương đối được chuẩn hóa trước khi so |
| core không thuần | `lib/core/**` import `package:flutter/…`, `dart:ui`, package ngoài `{pak_manager/core, sodium, zxcvbnm}` | exit 1 | — |
| `dart:io` trong core | `lib/core/model/a.dart` import `dart:io` | exit 1; `lib/core/io/a.dart` thì hợp lệ | — |
| API cấm | file trong `lib/` import `dart:io` và dùng `HttpClient`/`Socket`/`RawSocket`/`SecureSocket`/`ServerSocket`/`WebSocket`, hoặc import `dart:math` và dùng `Random` | exit 1 | bỏ qua comment khi dò token |
| Release lỗi | bản release, gọi `debugPrint` / lỗi framework / lỗi async chưa bắt | không in gì; `PlatformDispatcher.onError` trả `true` | — |

## Decisions

- **Flutter cục bộ:** agent cài Flutter 3.47.8 vào `C:\src\flutter` (`git clone -b 3.47.8 --depth 1`), thêm `C:\src\flutter\bin` vào PATH user, rồi chạy `flutter create`/analyze/test tại chỗ.
- **Flavor `dev`:** chỉ Android ở story này. Flavor iOS để sau (đã ghi deferred-work).
- **Git/CI:** làm trên nhánh `feat/1-1-project-seed-ci`, commit và push lên `origin`; người dùng tự mở PR để xem CI.
- **Độ dài spec:** giữ nguyên một spec (~3.500 token) dù vượt mức 1.600.

</frozen-after-approval>

## Code Map

- `_bmad-output/planning-artifacts/architecture/.../ARCHITECTURE-SPINE.md` — AD-1, AD-2, AD-12, AD-18, AD-19, Stack, Structural Seed: nguồn sự thật.
- `_bmad-output/planning-artifacts/architecture/.../reviews/review-versions.md` — V-1 (`cupertino_ui` tách package), V-5 (3.47.8), V-6 (16 KB, libsodium cần bash+make).
- Repo hiện không có code, không có `.gitignore` ở gốc, không có `.github/`. Không sửa gì trong `_bmad*/`, `screens/`, `idea.txt`.

## Tasks & Acceptance

**Execution:**
- [x] `pak_manager/` -- `flutter create --org io.github.truongthanhnam --project-name pak_manager --platforms android,ios .`; xóa code mẫu Material -- nền đúng chuẩn, không template.
- [x] `pak_manager/android/app/build.gradle.kts` (+ thư mục Kotlin `MainActivity`) -- `namespace`/`applicationId` = `io.github.truongthanhnam.pakmanager`; minSdk 24, compile/targetSdk 36; `flavorDimensions "env"`, `prod` và `dev` (`applicationIdSuffix ".dev"`, nhãn "PAK Manager Dev") -- AD-19.
- [x] `pak_manager/ios/Runner.xcodeproj/project.pbxproj`, `ios/Podfile` (nếu có) -- bundle id `io.github.truongthanhnam.pakmanager`, `IPHONEOS_DEPLOYMENT_TARGET = 15.0`.
- [x] `pak_manager/pubspec.yaml`, `pubspec.lock` -- `sdk: ^3.13.0`; dependencies `cupertino_ui: 1.1.4`, `cupertino_icons: 2.0.0`; dev `flutter_test` (sdk); bỏ `flutter_lints`; commit lock.
- [x] `pak_manager/lib/{core/{model,crypto,format,guard,policy,generator,search,ports,io},services,platform,features/{auth,cards,generator,settings,transfer,shared},l10n}/`, `pigeons/`, `assets/`, `docs/` -- `.gitkeep` cho thư mục rỗng.
- [x] `pak_manager/lib/main.dart`, `lib/error_policy.dart` -- `PakApp` placeholder bằng `cupertino_ui` (không chuỗi hiển thị); `installReleaseErrorPolicy()` gán `debugPrint` no-op, `FlutterError.onError` và `PlatformDispatcher.instance.onError` nuốt lỗi; `main()` gọi khi `kReleaseMode` -- AD-18.
- [x] `pak_manager/analysis_options.yaml` -- không `include:`; `strict-casts/inference/raw-types`; liệt kê rule trực tiếp (có `avoid_print`, nâng thành `error`); exclude `test/fixtures/**` -- AD-12, AD-18.
- [x] `pak_manager/tool/check_imports.dart` -- hàm thuần `List<Violation> checkSource(String relPath, String source)` + `checkTree(String root)` + `main` (exit 0/1) theo I/O Matrix.
- [x] `pak_manager/test/tool/check_imports_test.dart`, `test/fixtures/check_imports/**` -- một file mẫu cho mỗi dòng của I/O Matrix + một cây hợp lệ.
- [x] `pak_manager/test/app_test.dart`, `test/error_policy_test.dart` -- widget test `PakApp` dựng được; test chính sách release (lưu và khôi phục handler trong `try/finally`).
- [x] `pak_manager/tool/ci/check_android_apk.sh` -- `aapt2 dump xmltree` manifest của APK: fail nếu có `android.permission.INTERNET`; `zipalign -c -P 16 -v 4` và `readelf -lW` cho mọi `lib/*/*.so`: fail nếu `LOAD` align < `0x4000`.
- [x] `.github/workflows/ci.yml` (gốc repo) -- `pull_request` + `push` lên `main`; job ubuntu: cài Flutter bằng `git clone -b 3.47.8`, Java 17, `flutter analyze --fatal-infos --fatal-warnings`, `dart run tool/check_imports.dart`, `flutter test`, `flutter build apk --release --flavor prod`, chạy script trên; job macOS: `flutter build ios --release --no-codesign`; bước khẳng định file workflow không chứa `secrets.`.

**Acceptance Criteria:**
- Given repo sau story, when liệt kê `pak_manager/`, then đủ thư mục của Structural Seed và `pubspec.yaml` chỉ chứa package trong Stack với đúng version.
- Given `lib/` sạch, when chạy analyze, `check_imports`, `flutter test`, then tất cả pass; thêm `print(` vào `lib/` thì analyze fail.
- Given PR mở, when CI chạy, then đủ 2 job xanh và không job nào truy cập secret.

## Implementation Notes

- **`default-flavor` không dùng:** 3.47.8 có hỗ trợ (`FlutterManifest.defaultFlavor`), nhưng giá trị này áp cho mọi nền tảng; iOS chưa có scheme `prod` nên `flutter build ios` sẽ fail (`schemeFor` → `reportFlavorNotFoundAndExit`). Vì vậy mọi lệnh Android ghi rõ `--flavor`, iOS build không cờ. Xem lại khi làm flavor iOS (deferred-work).
- **Nhãn app theo flavor:** `manifestPlaceholders["appLabel"]` (`PAK Manager` / `PAK Manager Dev`), manifest dùng `${appLabel}`.
- **`check_imports`:** features chỉ được import `core/model|policy|search` (chặt hơn danh sách 4 thư mục trong I/O Matrix, đúng AD-2). Token API cấm được dò trên bản nguồn đã xóa comment và nội dung chuỗi (vẫn dò code trong `${…}`), bỏ qua trong chính directive (`hide HttpClient`). Ngoài 6 tên trong matrix còn chặn `HttpServer`, `RawSecureSocket`, `RawServerSocket`, `SecureServerSocket`, `RawSecureServerSocket`, `RawDatagramSocket`. `main` gọi `run()` trả exit code để test được.
- **Không kiểm cục bộ được:** `check_android_apk.sh` và workflow chỉ chạy được trên CI (máy dev không có Android SDK, đúng AD-19); cục bộ chỉ `bash -n`.
- **Push trước review:** agent triển khai đã commit (`212d279`, `4f77502`) và push nhánh `feat/1-1-project-seed-ci` ngay sau khi làm xong, trước bước review. Sửa đổi từ review sẽ là commit mới trên cùng nhánh.
- **Xác minh lại (điều phối):** `pub get --enforce-lockfile`, `analyze` 0 issue, `check_imports` OK, `flutter test` 21/21 pass. AC3 (CI xanh) chờ PR.

## Spec Change Log

## Review Triage Log

| # | Nguồn | Phát hiện | Verdict | Bằng chứng | Route |
|---|-------|-----------|---------|------------|-------|
| 1 | edge, verif-gap | `import'dart:io';` (không khoảng trắng) lọt `check_imports` | medium | `_directiveKeyword` dùng `\s+`; verif-gap đã chạy thử và nhận `OK` | patch |
| 2 | blind, edge, verif-gap | Re-export `dart:io`/`dart:math` (vd `lib/core/io` `export 'dart:io' show HttpClient`) cho file khác dùng API cấm mà không bị dò | medium | Token scan chỉ chạy khi file tự import `dart:io`/`dart:math`; verif-gap đã tái hiện | patch |
| 3 | blind, edge | API mạng khác của `dart:io` (`InternetAddress`, `NetworkInterface`, `HttpOverrides`) không bị chặn | low | Không có trong `_apiToken`; sửa trực tiếp bằng thêm tên | patch |
| 4 | verif-gap | Luật "URI không hỗ trợ" (`file:`/tuyệt đối) không có test | low | Không test nào dùng `file:`; xóa nhánh thì features vượt AD-2 mà test vẫn xanh | patch |
| 5 | blind | Thiếu test `math.Random` qua prefix và features → `core/guard`/`core/generator` | low | Không fixture nào; luật chặt hơn matrix không được ghim | patch |
| 6 | verif-gap, blind | `main()` gọi chính sách release không có test | medium | Đổi `kReleaseMode` thành `!kReleaseMode` thì 21 test vẫn xanh | patch |
| 7 | blind, edge | Bản release vẫn để `print` của package phụ thuộc ra logcat/os_log | medium | `installReleaseErrorPolicy` chỉ thay `debugPrint` và hai hook lỗi; AD-18 cấm log ở mọi build | patch |
| 8 | blind, edge, verif-gap | Bước chặn secret bỏ sót `secrets['X']`/`toJSON(secrets)` | low | Regex `secrets[.]` chỉ khớp dạng chấm | patch |
| 9 | blind, edge | `cancel-in-progress: true` hủy CI của commit `main` trước | low | Cùng group `ci-CI-refs/heads/main`; sửa một dòng | patch |
| 10 | blind, edge | `part` file dùng API cấm không bị dò | low | Đúng, nhưng `lib/` không có `part`; sửa cần lan truyền import từ thư viện cha | reject |
| 11 | blind | services/platform không bị kiểm phân lớp (services → `lib/platform/`, lên features) | medium | Đúng là thiếu; cần quyết định composition root (nơi được nối platform vào port), xuất hiện ở story 1.2 | defer |
| 12 | blind | Danh sách dependency so với bảng Stack không được máy kiểm | medium | Chỉ có comment trong `pubspec.yaml`; cần script mới | defer |
| 13 | blind | Action/Flutter/Gradle không ghim SHA hay checksum | medium | `@v4` là tag đổi được; clone theo tag không kiểm revision; không có `distributionSha256Sum` | defer |
| 14 | edge | `macos-latest`/`ubuntu-latest` trôi Xcode/SDK làm build gãy | maybe-false | Chưa thấy lỗi; cần lần CI đầu và theo dõi image | defer |
| 15 | edge | Kiểm ELF 16 KB cả `.so` 32-bit, có thể làm CI đỏ oan | maybe-false | Quy định 16 KB chỉ cho ABI 64-bit; chưa biết `libflutter.so` armeabi-v7a có căn 16 KB không; lần CI đầu sẽ rõ | defer |
| 16 | verif-gap | Script kiểm APK chưa bao giờ chạy với APK xấu | medium | Chỉ chạy trên APK kỳ vọng pass; cần harness giả `aapt2`/`readelf` | defer |
| 17 | edge | `'$RawSocket'` nội suy ngắn không bị dò | false | Nội suy ngắn chỉ tham chiếu được định danh, không gọi được constructor; không có truy cập mạng | reject |
| 18 | edge | URI có escape/chuỗi kề (`'dart:\x69o'`) lọt kiểm | low | Chỉ có khi cố ý né; sửa cần bộ giải escape | reject |
| 19 | edge | Symlink trong `lib/` không được quét | low | Repo không có symlink; khó gặp | reject |
| 20 | edge | `checkTree` ném lỗi khi thiếu `lib/` | low | Chỉ `run()` (đã chặn) và test gọi | reject |
| 21 | edge | Lỗi đọc file làm exit 255 thay vì 1 | low | CI vẫn fail (khác 0), đúng chiều | reject |
| 22 | blind | Release build type ký bằng debug key | false | CI không upload artifact; ký thật thuộc story 7.2 | reject |
| 23 | blind | Design Notes cũ về `default-flavor`, status lệch sprint, vị trí `deferred-work.md` | false | Sửa spec bị loại theo quy tắc; status sprint đồng bộ ở bước trình bày; vị trí `deferred-work.md` do workflow quy định | reject |
| 24 | blind | Điện thoại chưa khóa dọc | low | Thuộc story 1.3 (epics.md:511), nằm trong Never của intent | reject |
| 25 | blind | CI thiếu `dart format`, không build flavor `dev`, không cache, `environment: flutter` chưa ghim | low | Code đã format (chỉ fixture cố ý lệch nên cần cơ chế loại trừ); flavor `dev` chỉ khác hậu tố; còn lại là tối ưu | reject |
| 26 | blind | Thiếu kiểm `dart:ffi` trong core | false | AD-2 không cấm `dart:ffi` trong core | reject |

## Design Notes

- **Workflow ở gốc repo, không ở `pak_manager/.github/`:** GitHub chỉ đọc `.github/workflows/` ở gốc. Dùng `defaults.run.working-directory: pak_manager`. Lệch so với Structural Seed có chủ đích.
- **Chỉ thêm dependency khi dùng tới:** story này chỉ cần `cupertino_ui`, `cupertino_icons`. `sodium` (1.4) có build hook biên dịch libsodium cho host khi `flutter test`, cần bash+make trên Windows (V-6) — để story 1.4 xử lý; `path_provider`/`pigeon` (1.2), `flutter_localizations` (1.3), `zxcvbnm` (1.5), `flutter_riverpod` (1.6), `share_plus`/`file_selector` (epic 6).
- **Bước kiểm code Pigeon sinh ra** thêm vào CI ở story 1.2 cùng `pigeons/platform_api.dart`.
- Nếu `flutter: default-flavor: prod` trong `pubspec.yaml` được 3.47.8 hỗ trợ thì dùng, để `flutter run` không cờ chạy `prod`; nếu không thì mọi lệnh build ghi rõ `--flavor`.

## Verification

**Commands (trong `pak_manager/`):**
- `flutter pub get` -- resolve được với version ghim.
- `flutter analyze --fatal-infos --fatal-warnings` -- 0 issue.
- `dart run tool/check_imports.dart` -- exit 0.
- `flutter test` -- mọi test pass.

**Manual checks:**
- Sau khi push: CI trên PR xanh cả job ubuntu và macOS; log job Android in kết quả kiểm `INTERNET` và 16 KB.
