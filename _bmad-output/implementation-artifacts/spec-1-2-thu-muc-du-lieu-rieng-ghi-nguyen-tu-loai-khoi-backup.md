---
title: 'Story 1.2 — Thư mục dữ liệu riêng, ghi nguyên tử và loại khỏi backup'
type: 'feature'
created: '2026-11-02'
status: 'done'
route: 'dispatch'
baseline_commit: '008af749390a675966ea63b2e9c0c190cc109c0a'
review_loop_iteration: 0
context:
  - '{project-root}/_bmad-output/implementation-artifacts/epic-1-context.md'
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** App chưa có chỗ lưu dữ liệu, chưa có cách ghi chịu được tắt đột ngột, chưa loại dữ liệu khỏi iCloud/Google Backup, và chưa có cầu nối native (đồng hồ, backup, fsync thư mục) mà story 1.3, 1.4, 1.9 và Epic 2 cần.

**Approach:** Định nghĩa port trong `core/ports`, cài đặt bằng một API Pigeon và adapter `path_provider` trong `lib/platform/`; viết `AtomicFileWriter` và bộ dọn `*.tmp` trong `core/io`; khởi động thì tạo `pak/`, đặt cờ loại khỏi backup rồi dọn `*.tmp` trước khi chạy UI; khai báo backup rules trên Android; CI kiểm code Pigeon sinh ra và cờ backup của APK.

## Boundaries & Constraints

**Always:** Mọi file app nằm dưới `ApplicationSupport/pak/`. Pigeon: đúng một file `pigeons/platform_api.dart`, `@HostApi` đồng bộ (không `@async`), kênh mặc định, không bật FFI/JNI; chỉ ba nhóm đồng hồ, backup, `fsyncDirectory` (clipboard để Epic 3). `AtomicFileWriter` không bao giờ tạo thư mục; core/services trả kiểu kết quả sealed, không ném exception qua ranh giới lớp. Chỉ thêm `path_provider: 2.1.6` và dev `pigeon: 29.0.11`, ghim chính xác. Native iOS không dùng API "required reason" (`stat`/`fstat`/`creationDate`/`systemUptime`/`mach_absolute_time`…). Test chỉ dùng fake tự viết.

**Never:** Không ghi gì vào Keychain/Keystore. Không làm codec, `SettingsStore`, `LockoutGuard`, `AccountService`, xóa `pak/tmp/` (story 1.3+, 6.2). Không dùng `Stopwatch`/`DateTime.now()` làm nguồn thời gian. Không dùng action bên thứ ba.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Ghi mới | thư mục có, file chưa có | file đích = bytes mới; không còn `<tên>.tmp`; `fsyncDirectory(thư mục)` được gọi đúng 1 lần, sau rename | — |
| Ghi đè | file đích có nội dung cũ | file đích = bytes mới | — |
| Thiếu thư mục | thư mục cha không tồn tại | trả lỗi `parentMissing`; không tạo thư mục, không tạo file | không ném |
| Dừng trước rename | dừng ở tạo tmp / ghi / fsync file | file đích còn nguyên bytes cũ (hoặc vẫn chưa tồn tại) | trả lỗi `io` |
| Lỗi `fsyncDirectory` | port ném sau rename | file đích = bytes mới; trả lỗi `io` | — |
| Dọn tmp | `pak/a.tmp`, `pak/vault/cards.tmp`, `pak/vault/cards` | xóa mọi `*.tmp` mọi cấp; file khác còn nguyên | lỗi xóa một file không dừng các file khác |
| Khởi động | `pak/` chưa có | tạo `pak/` → `BackupPort.excludeFromBackup(pak)` → dọn `*.tmp`, theo đúng thứ tự, trước `runApp`; trả `StorageReady` | — |
| Khởi động lỗi | lấy đường dẫn lỗi, tạo `pak/` lỗi, hoặc `excludeFromBackup` lỗi | trả `StorageUnavailable`; không dọn tmp, không I/O dữ liệu; app vẫn `runApp` | không ném |

## Decisions

- **Git/CI:** nhánh `feat/1-2-data-dir-atomic-write`, commit và push lên `origin` như story 1.1; người dùng tự mở PR để CI kiểm native.
- **Khởi động lỗi = fail-closed:** bất kỳ bước bootstrap nào lỗi (kể cả cờ backup iOS) → `StorageUnavailable`; story 1.6 không được đọc/ghi dữ liệu khi nhận kết quả này. Vault không bao giờ nằm ngoài cờ loại backup.
- **Độ dài spec:** giữ một spec (~3.800 token) dù vượt mức 1.600.

</frozen-after-approval>

## Code Map

- `pak_manager/lib/main.dart` -- `main()` gọi `runWithErrorPolicy`; thêm bootstrap async trước `runApp` (cùng zone với `ensureInitialized`).
- `pak_manager/tool/check_imports.dart:150-235` -- luật features/core; thêm luật services/platform. Test ở `test/tool/check_imports_test.dart` + `test/fixtures/check_imports/**`.
- `pak_manager/analysis_options.yaml` -- thêm exclude `lib/**/*.g.dart` (code Pigeon sinh ra không theo lint strict); `check_imports` vẫn quét file này.
- `pak_manager/android/app/src/main/AndroidManifest.xml`, `.../kotlin/io/github/truongthanhnam/pakmanager/MainActivity.kt` -- hiện chỉ là template.
- `pak_manager/ios/Runner/AppDelegate.swift` -- đã có `didInitializeImplicitFlutterEngine`; đăng ký qua `engineBridge.pluginRegistry.registrar(forPlugin:)?.messenger()`.
- `pak_manager/ios/Runner.xcodeproj/project.pbxproj` -- nhóm cổ điển (không synchronized group); file Swift mới phải thêm tay `PBXBuildFile`, `PBXFileReference`, con của nhóm Runner, Sources phase (mẫu: `SceneDelegate.swift` dòng 14/52/125/286).
- `pak_manager/tool/ci/check_android_apk.sh` -- đã có dump `manifest.txt`; thêm kiểm backup cạnh kiểm `INTERNET`.
- `.github/workflows/ci.yml` -- job `android`; thêm bước Pigeon sau `pub get`.
- `_bmad-output/implementation-artifacts/deferred-work.md` -- 2 mục được giải quyết ở story này (Pigeon CI, composition root).
- Không có engine iOS trên máy Windows: Swift/Kotlin chỉ kiểm qua CI.

## Tasks & Acceptance

**Execution:**
- [x] `pak_manager/pubspec.yaml`, `pubspec.lock` -- thêm `path_provider: 2.1.6`, dev `pigeon: 29.0.11`; ghi lại trong Implementation Notes mọi package bắc cầu có native code (vd `jni`).
- [x] `pak_manager/lib/core/ports/{clock_port,file_sync_port,backup_port,app_directory_port}.dart` -- interface: `Future<int> monotonicMs()`, `Future<String> bootId()`; `Future<void> fsyncDirectory(String path)`; `Future<void> excludeFromBackup(String dirPath)`; `Future<String> applicationSupportPath()`.
- [x] `pak_manager/lib/core/io/pak_paths.dart` -- `PakPaths(root)`: `pakDir`, `vaultDir`, `guardFile`, `settingsFile`, `tmpDir` theo AD-11/AD-13.
- [x] `pak_manager/lib/core/io/atomic_file_writer.dart` -- `Future<AtomicWriteResult> write(String path, List<int> bytes)` theo I/O Matrix; tmp = `<path>.tmp`; fsync file bằng `RandomAccessFile.flush()`; nhận `FileSyncPort` và hook tùy chọn `onStep(AtomicWriteStep)` (chỉ cho test) gọi trước mỗi bước.
- [x] `pak_manager/lib/core/io/tmp_sweeper.dart` -- `Future<int> sweepTmpFiles(String pakDir)`: xóa đệ quy `*.tmp`, không theo symlink, trả số file đã xóa.
- [x] `pak_manager/lib/services/storage_bootstrap.dart` -- `Future<StorageBootstrapResult> run()`: lấy đường dẫn → tạo `pak/` (bootstrap được phép tạo) → `excludeFromBackup` → `sweepTmpFiles`; kết quả sealed `StorageReady(PakPaths)` / `StorageUnavailable`.
- [x] `pak_manager/pigeons/platform_api.dart` -- `PlatformApi`: `String bootId()`, `int monotonicMs()`, `void excludeFromBackup(String dirPath)`, `void fsyncDirectory(String dirPath)`; `@ConfigurePigeon` ra `lib/platform/platform_api.g.dart`, Kotlin `.../pakmanager/PlatformApi.g.kt`, Swift `ios/Runner/PlatformApi.g.swift`.
- [x] `pak_manager/lib/platform/{pigeon_ports,path_provider_directory}.dart` -- adapter cài port bằng code sinh ra và `getApplicationSupportDirectory()` (không import `dart:io`).
- [x] `pak_manager/android/.../pakmanager/{PlatformApiImpl.kt,MainActivity.kt}` -- `BOOT_COUNT` (thiếu → `""`), `SystemClock.elapsedRealtime()`, backup no-op (manifest lo), `Os.open(O_RDONLY)`+`Os.fsync`+`Os.close`; đăng ký trong `configureFlutterEngine`.
- [x] `pak_manager/ios/Runner/{PlatformApiImpl.swift,AppDelegate.swift}`, `project.pbxproj` -- `sysctlbyname("kern.bootsessionuuid")` (lỗi → `""`), `mach_continuous_time` × timebase → ms, `URLResourceValues.isExcludedFromBackup = true`, `open`+`fsync`+`close`; đăng ký trong `didInitializeImplicitFlutterEngine`; thêm 2 file Swift vào target Runner.
- [x] `pak_manager/android/app/src/main/{AndroidManifest.xml,res/xml/data_extraction_rules.xml,res/xml/backup_rules.xml}` -- `allowBackup="false"`, `dataExtractionRules`, `fullBackupContent`; loại mọi domain (`root`, `file`, `database`, `sharedpref`, `external`, `device_*`) với `path="."` cho `cloud-backup`, `device-transfer` và full-backup.
- [x] `pak_manager/lib/main.dart` -- `ensureInitialized` → `StorageBootstrap.run()` → `runApp` (kết quả chưa có nơi dùng; story 1.6 nối vào `SessionGate`); đây là composition root duy nhất được import `lib/platform/`.
- [x] `pak_manager/tool/check_imports.dart` + test/fixture -- `lib/services/` không import `lib/platform/`, `lib/features/`; ngoài `lib/platform/` chỉ `lib/main.dart` được import `lib/platform/`.
- [x] `pak_manager/tool/ci/check_android_apk.sh` -- fail nếu manifest đã merge không có `allowBackup=false` hoặc thiếu `dataExtractionRules`/`fullBackupContent`.
- [x] `.github/workflows/ci.yml` -- bước: `dart run pigeon --input pigeons/platform_api.dart` rồi `git status --porcelain` trên các file sinh ra phải rỗng.
- [x] `pak_manager/test/core/io/{atomic_file_writer,tmp_sweeper}_test.dart`, `test/services/storage_bootstrap_test.dart` -- mỗi dòng I/O Matrix; dừng ở từng `AtomicWriteStep` trước rename (hook ném) → file đích nguyên; bootstrap ghi thứ tự gọi qua fake port. Tên test gắn NFR-8/NFR-11/FR-11.
- [x] `_bmad-output/implementation-artifacts/deferred-work.md` -- đánh dấu xong mục Pigeon CI và mục composition root.

**Acceptance Criteria:**
- Given repo sau story, when chạy analyze, `check_imports`, `flutter test`, then tất cả pass và chạy lại Pigeon không đổi file nào.
- Given code Pigeon sinh ra bị sửa tay hoặc thiếu, when CI chạy, then bước kiểm Pigeon fail.
- Given APK prod release, when chạy `check_android_apk.sh`, then báo OK cho `INTERNET`, backup rules và 16 KB.
- Given PR mở, when CI chạy, then job iOS build được với Swift mới (đăng ký trong `FlutterImplicitEngineDelegate`).
- Given toàn bộ `lib/` và native code, when tìm `Keychain`/`SecItem`/`KeyStore`, then không có kết quả.

### Review Findings

Code review 2026-11-02 (nhánh `feat/1-2-data-dir-atomic-write` so với `main`, 4 lớp: blind, edge, verif-gap, acceptance).

- [x] [Review][Patch] Test `main()` thật không điều khiển `path_provider`: bootstrap dừng ở `resolvePath`, nên bỏ bootstrap hay nối `BackupPort` no-op trong `main()` vẫn xanh; test còn dựa vào việc plugin vắng mặt trên host, nếu có thì tạo `pak/` thật (medium) [pak_manager/test/app_test.dart:46]
- [x] [Review][Patch] Giá trị mặc định `sweepTmp = sweepTmpFiles` của `StorageBootstrap` không test nào chạy tới; đổi thành no-op vẫn xanh (medium) [pak_manager/lib/services/storage_bootstrap.dart:57]
- [x] [Review][Patch] Test crash trước rename không kiểm `<path>.tmp` đã bị xóa (low) [pak_manager/test/core/io/atomic_file_writer_test.dart:208]
- [x] [Review][Patch] Doc của `fsyncDirectory` trong Pigeon (và code sinh ra) vẫn ghi `fsync`, trong khi iOS dùng `F_FULLFSYNC`, chỉ fallback `fsync` (low) [pak_manager/pigeons/platform_api.dart:31]
- [x] [Review][Patch] Mục deferred của story 1.2 nằm dưới heading "code review of spec-1-1" (low) [_bmad-output/implementation-artifacts/deferred-work.md:42]
- [x] [Review][Patch] Test `clock_monotonic_ms_returns_host_value`, `clock_boot_id_returns_host_value` không gắn mã yêu cầu theo quy ước (low) [pak_manager/test/platform/pigeon_ports_test.dart]
- [x] [Review][Defer] Kết quả bootstrap bị bỏ trong `runPakApp`; ngoài comment, không có mục backlog nào theo dõi việc truyền kết quả vào `PakApp`/`SessionGate` [pak_manager/lib/main.dart:29] — deferred: story 1.6 sẽ dùng kết quả; ghi vào deferred-work
- [x] [Review][Defer] Regex kiểm backup mới trong `check_android_apk.sh` không có kiểm âm trên APK xấu [pak_manager/tool/ci/check_android_apk.sh:54] — deferred: có sẵn từ story 1.1 (harness kiểm âm cho script APK)

Đã sửa cả 6 patch (2026-11-02). Xác minh: `analyze` 0 issue, `check_imports` OK, `flutter test` 77 pass / 1 skip, chạy lại Pigeon khớp code đã sinh. Test `ad18_nfr8_real_main_bootstraps_storage_then_builds_app` giả kênh `plugins.flutter.io/path_provider` trỏ về thư mục tạm, nên `main()` chạy hết bootstrap (`excludeFromBackup(pak)`, dọn `*.tmp`) mà không chạm thư mục dữ liệu thật.

**Rejected:**
- `low` — Nhánh fail-closed `sweepTmp` không bao giờ chạy vì `sweepTmpFiles` nuốt mọi lỗi: `pak/` vừa tạo xong mà không liệt kê được là gần như không xảy ra; sửa phải đổi ngữ nghĩa sweeper.
- `low` — `check_imports` chặn plugin bằng denylist; services có thể dùng `MethodChannel`/`path_provider_*` (blind, edge): phải cố ý né mới gặp; sửa cần thêm allowlist cho services.
- `low` — `storage_bootstrap.dart` (services) import `dart:io`: AD-2 chỉ giới hạn `dart:io` bên trong core; test bằng FS thật vẫn chạy được.
- `low` — Code Pigeon sinh ra import `package:meta` không khai báo (blind, acceptance): Flutter SDK đã ghim `meta`; chỉ là annotation, không có mã mạng; muốn sửa phải quyết định lại bảng Stack.
- `false` — Code Map còn nhắc exclude trong `analysis_options.yaml` (blind, acceptance): sửa là sửa spec, bị loại theo quy tắc.
- `false` — `pigeon_ports_test` thiếu ca reply null (`channel-error`): test reply lỗi đã chứng minh adapter đẩy exception lên; ca null do code Pigeon sinh ra xử lý giống hệt.
- `false` — Status spec `done` lệch sprint `review` (blind, acceptance): đúng thiết kế; bước review này đồng bộ status.
- `low` — Luật plugin cho phép `lib/main.dart` import plugin: `main.dart` là composition root; đúng như patch #8 của triage trước.
- `low` — `List<int>` có giá trị ngoài 0..255 bị cắt khi ghi: codec luôn truyền `Uint8List`; sửa cần thêm guard.
- `low` — Thư mục cha bị xóa giữa `exists()` và `open()` thì trả `io` thay vì `parentMissing`: race gần như không gặp; sửa cần thêm nhánh.
- `low` — `fsync` trả `EINTR` trên iOS: rất hiếm với file thường; sửa cần thêm vòng lặp thử lại.
- `false` — `StorageReady` mà chưa có `vault/`, `tmp/`: theo AD-7 `create()` tạo `vault/`; `tmp/` thuộc story 6.2.
- `false` — Bước Pigeon CI không quét ngoài `lib android ios`: mọi output trong cấu hình hiện tại đều nằm trong ba thư mục đó.

## Implementation Notes

- **Package bắc cầu có native code** (từ `path_provider: 2.1.6`, resolve trong `pubspec.lock`):
  - Android: `path_provider_android 2.3.1` (gọi Android API qua JNI, `dartPluginClass`), `jni 1.1.1` (ffiPlugin, build `libdartjni.so` bằng CMake/NDK → `.so` này phải qua kiểm 16 KB), `jni_flutter 1.0.4+1` (plugin Java).
  - iOS: `path_provider_foundation 2.6.0` (FFI qua `objective_c`), `objective_c 9.5.0` (build hook native assets biên dịch dylib cho iOS); kèm `ffi 2.2.0`, `hooks 2.0.2`, `code_assets 1.2.1`.
  - Desktop (không ship): `path_provider_linux`, `path_provider_windows`, `xdg_directories`.
- `AtomicFileWriter` xóa `<path>.tmp` (best-effort) khi lỗi trước rename; crash thật để lại tmp và `sweepTmpFiles` dọn ở lần khởi động sau.
- `StorageBootstrap` coi đường dẫn `ApplicationSupport` rỗng là lỗi (`resolvePath`), và lỗi bất ngờ của bước dọn tmp cũng là `StorageUnavailable(sweepTmp)` (fail-closed).
- `main.dart` tách `runPakApp(StorageBootstrap, releaseMode:)` để widget test chạy cùng đường khởi động bằng port giả (không chạm plugin/hệ thống file thật); `main()` chỉ nối adapter thật.
- iOS `excludeFromBackup` đọc lại `isExcludedFromBackupKey` sau khi đặt, ném nếu cờ chưa có.
- Android manifest dùng `tools:replace` cho `allowBackup`/`fullBackupContent`/`dataExtractionRules` để manifest thư viện không ghi đè.
- Máy dev không có Android SDK/Xcode: Kotlin, Swift, manifest merge và regex `aapt2` trong `check_android_apk.sh` chỉ được kiểm qua CI.
- **CI (2026-11-03, theo người dùng xác nhận):** cả job Android (gồm bước Pigeon, kiểm `INTERNET`/backup/16 KB) và job iOS đều xanh ở `5657b59`, đáp ứng AC2–AC4.

## Spec Change Log

## Review Triage Log

| # | Nguồn | Phát hiện | Verdict | Bằng chứng | Route |
|---|-------|-----------|---------|------------|-------|
| 1 | blind, edge | iOS `fsync` không đẩy cache ổ đĩa; cần `F_FULLFSYNC` | medium | Darwin `fsync` không flush cache thiết bị; `fsyncDirectory` Swift dùng `fsync` thuần. `F_FULLFSYNC` trên fd thư mục flush toàn bộ cache ổ, gồm cả dữ liệu tmp đã `fsync` trước đó (còn một cửa sổ rất hẹp giữa rename và flush) | patch |
| 2 | blind | `io` không phân biệt "chưa đổi" với "đã rename nhưng chưa fsync thư mục" | low | Có thật nhưng chỉ khi `fsync` thư mục lỗi sau rename thành công (gần như chỉ EIO); chưa có caller; sửa cần thêm giá trị enum và đổi dòng Matrix đã đóng băng | reject |
| 3 | blind, edge | Hai `write()` đồng thời cùng path dùng chung `<path>.tmp` | low | Có thật nếu caller gọi song song; kiến trúc quy định `VaultSession`/`SettingsStore` ghi qua hàng đợi tuần tự, nhưng writer không ghi điều kiện này | patch (ghi rõ điều kiện trong doc) |
| 4 | blind, edge | Bootstrap treo vô hạn nên không bao giờ `runApp` | false | Handler Pigeon native đồng bộ; thiếu handler thì Pigeon trả `channel-error` ngay; `path_provider` gọi đồng bộ qua FFI/JNI; không có đường nào chờ mãi | reject |
| 5 | blind, edge | `registrar(forPlugin:)` trả nil thì bỏ đăng ký mà không báo gì | low | Chỉ trả nil khi key plugin bị trùng; key `PlatformApiImpl` là duy nhất; sửa phải thêm nhánh | reject |
| 6 | blind | `StorageUnavailable`/`AtomicWriteFailure` bỏ mất nguyên nhân lỗi | low | Cố ý theo AD-18 (không log, lỗi không kèm thông điệp); bước lỗi vẫn được giữ | reject |
| 7 | blind, edge | `check_imports` không cấm `lib/platform/` import services/features | low | Xác nhận: không có luật cho path `lib/platform/`; mục deferred yêu cầu cả hai chiều | patch |
| 8 | edge | services/file ngoài platform import thẳng plugin (`path_provider`, `share_plus`, `file_selector`) | low | Xác nhận: services không có allowlist package; plugin lách qua port | patch |
| 9 | blind, verif-gap | CI chỉ kiểm thuộc tính backup tồn tại, không kiểm nội dung XML | medium | `check_android_apk.sh` chỉ grep `=@`; xóa khối `<device-transfer>` vẫn xanh; Android 12+ chuyển máy chỉ dựa vào khối này | patch |
| 10 | blind, edge | Bước Pigeon CI kiểm danh sách file viết cứng | low | Output mới thêm ở Epic 3 sẽ không được kiểm; sửa trực tiếp bằng cách kiểm cả thư mục | patch |
| 11 | blind | AC5 (Keychain/SecItem/KeyStore) không có bước tự động | low | Đã kiểm tay khi build; grep code tự viết không bắt được plugin; thêm bước CI là thêm độ phức tạp | reject |
| 12 | blind | Exclude `lib/**/*.g.dart` thừa vì file đã có `ignore_for_file: type=lint` | low | Có `type=lint` ở dòng 4; nhưng strict-casts không phải lint, bỏ exclude có thể sinh lỗi | patch (chỉ bỏ nếu analyze vẫn sạch) |
| 13 | blind, verif-gap | `main()` không còn test nào chạy | medium | Test ad18 chuyển sang `runPakApp` với fake; đổi `main()` sang `releaseMode: true` hay bỏ bootstrap vẫn xanh | patch |
| 14 | blind, verif-gap | `PigeonPlatformPorts` không có test; lỗi native có thể bị nuốt | medium | Không test nào dùng adapter; `excludeFromBackup` thành no-op thì bootstrap vẫn trả `StorageReady` | patch |
| 15 | blind | Hook `onStep` public, không `@visibleForTesting` | low | `package:meta` không có trong Stack (AD-12); doc đã ghi "chỉ cho test" | reject |
| 16 | blind | Không đặt data protection class iOS cho file | low | Vault đã mã hóa ở tầng app; ngoài intent; mặc định `CompleteUntilFirstUserAuthentication` | reject |
| 17 | blind, edge | Test chmod 555 fail khi chạy bằng root | low | Runner GitHub không chạy bằng root; sửa cần thêm điều kiện skip | reject |
| 18 | blind | Status lệch giữa spec và sprint; hai cách đánh dấu xong trong deferred-work | low | Status: đúng thiết kế, bước trình bày sẽ đồng bộ. Định dạng deferred-work không thống nhất: sửa trực tiếp | patch (chỉ phần định dạng) |
| 19 | edge | Target có đuôi `.tmp` bị sweeper xóa ở lần khởi động sau | low | Mọi file app có tên cố định (`header`, `cards`…); sửa cần thêm guard | reject |
| 20 | edge | `applicationSupportPath` trả đường dẫn tương đối | low | `path_provider` luôn trả đường dẫn tuyệt đối; sửa cần thêm guard | reject |
| 21 | verif-gap | Đăng ký native và phần cài native không được kiểm khi chạy thật | medium | CI chỉ build; repo chưa có `integration_test`/simulator; kết quả bootstrap chưa có consumer tới 1.6 | defer |

## Design Notes

- **Hook `onStep` thay vì lớp FS giả:** test dùng thư mục tạm thật (`Directory.systemTemp.createTempSync`), hook ném `_SimulatedCrash` ở bước N mô phỏng tiến trình chết; writer không được nuốt crash thành "thành công". Lỗi `fsyncDirectory` sau rename vẫn trả `io` để caller biết độ bền chưa chắc.
- **Android không cần native cho backup:** manifest đủ; `excludeFromBackup` là no-op để port đồng nhất hai nền tảng.
- **`bootId` rỗng an toàn:** AD-8 coi `bootId` đổi hoặc `monotonicMs` lùi là bắt đầu lại thời gian chờ; trả `""` khi không đọc được chỉ làm mất phát hiện qua `bootId`, còn phát hiện qua monotonic.
- **iOS required-reason:** `mach_continuous_time` và `sysctlbyname` không nằm trong danh mục (review-versions V-7); privacy manifest thuộc story 7.2.

## Verification

**Commands (trong `pak_manager/`):**
- `flutter pub get --enforce-lockfile` -- resolve được.
- `dart run pigeon --input pigeons/platform_api.dart; git status --porcelain` -- không đổi.
- `flutter analyze --fatal-infos --fatal-warnings` -- 0 issue.
- `dart run tool/check_imports.dart` -- exit 0.
- `flutter test` -- mọi test pass.
- `bash -n tool/ci/check_android_apk.sh` -- cú pháp hợp lệ.

**Manual checks:**
- CI trên PR: cả job ubuntu (kể cả bước Pigeon, kiểm backup) và macOS xanh.
