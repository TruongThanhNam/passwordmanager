# Deferred Work

- source_spec: `_bmad-output/implementation-artifacts/spec-1-1-khoi-tao-du-an-flutter-structural-seed-ci.md`
  summary: Thêm flavor `dev` cho iOS (scheme + build configuration, bundle id hậu tố `.dev`) để bản dev không ghi đè vault thật trên iPhone.
  evidence: Story 1.1 chỉ làm flavor Android theo quyết định của người dùng; iOS cần sửa tay `project.pbxproj` và chỉ kiểm được qua CI macOS. Khi có scheme `prod`/`dev` cho iOS thì cân nhắc `flutter: default-flavor: prod` trong `pubspec.yaml` (hiện không dùng được vì làm `flutter build ios` không cờ bị fail).

- source_spec: `_bmad-output/implementation-artifacts/spec-1-1-khoi-tao-du-an-flutter-structural-seed-ci.md`
  status: done (story 1.2, `spec-1-2-thu-muc-du-lieu-rieng-ghi-nguyen-tu-loai-khoi-backup.md`) — composition root là `lib/main.dart`; `check_imports` cấm services import `lib/platform/`/`lib/features/` và mọi file ngoài `lib/platform/` trừ `lib/main.dart` import `lib/platform/`.
  summary: Mở rộng `check_imports` để kiểm phân lớp của `lib/services/` và `lib/platform/` (services không import `lib/platform/` hay `lib/features/`), sau khi chốt composition root được phép nối platform vào port.
  evidence: AD-2 nói platform chỉ được gọi qua `core/ports`, nhưng checker hiện chỉ kiểm `features` và `core`; cần quyết định file nào được import `lib/platform/` (xuất hiện ở story 1.2).

- source_spec: `_bmad-output/implementation-artifacts/spec-1-1-khoi-tao-du-an-flutter-structural-seed-ci.md`
  summary: Thêm bước CI so `pubspec.yaml` (kể cả `dev_dependencies`) với bảng Stack của ARCHITECTURE-SPINE và từ chối ràng buộc không ghim chính xác.
  evidence: AD-12 hiện chỉ được nhắc bằng comment trong `pubspec.yaml`; một lần `flutter pub add` ngoài Stack vẫn qua mọi cổng CI.

- source_spec: `_bmad-output/implementation-artifacts/spec-1-1-khoi-tao-du-an-flutter-structural-seed-ci.md`
  summary: Ghim chuỗi cung ứng của CI: action theo commit SHA, kiểm revision Flutter sau khi clone (khớp `.metadata`), `distributionSha256Sum` cho Gradle wrapper.
  evidence: `actions/checkout@v4`/`setup-java@v4` là tag đổi được; clone Flutter theo tag không xác minh revision; Gradle wrapper không có checksum — rủi ro với repo public của app mật khẩu.

- source_spec: `_bmad-output/implementation-artifacts/spec-1-1-khoi-tao-du-an-flutter-structural-seed-ci.md`
  summary: (Chưa xác minh, nếu đúng thì medium) Ghim image runner (`macos-15` + Xcode cụ thể, `ubuntu-24.04`) để build không gãy khi `*-latest` đổi.
  evidence: Chưa thấy lỗi; theo dõi các lần CI đầu và khi GitHub đổi `macos-latest`. Gãy build không do thay đổi repo là dấu hiệu cần ghim.

- source_spec: `_bmad-output/implementation-artifacts/spec-1-1-khoi-tao-du-an-flutter-structural-seed-ci.md`
  summary: (Chưa xác minh, nếu đúng thì medium) Kiểm ELF 16 KB trong `tool/ci/check_android_apk.sh` có thể fail oan với `.so` 32-bit (armeabi-v7a, x86); quy định 16 KB của Google chỉ áp cho ABI 64-bit.
  evidence: Lần chạy CI đầu sẽ cho biết: nếu chỉ `lib/armeabi-v7a/*.so` hoặc `lib/x86/*.so` báo align `0x1000` thì giới hạn kiểm ELF vào `arm64-v8a` và `x86_64`.

- source_spec: `_bmad-output/implementation-artifacts/spec-1-1-khoi-tao-du-an-flutter-structural-seed-ci.md`
  summary: Thêm kiểm âm cho `check_android_apk.sh` (APK hoặc output `aapt2`/`readelf` giả có `INTERNET`, `.so` align 4 KB) để chắc cổng thực sự fail.
  evidence: Script chỉ chạy trên APK kỳ vọng pass; nếu pattern grep lệch định dạng output, mọi APK đều qua. Nên làm trước khi plugin đầu tiên (story 1.2) có thể kéo quyền vào manifest.

## Deferred from: code review of spec-1-1-khoi-tao-du-an-flutter-structural-seed-ci (2026-11-02)

- Kiểm `applicationId` của APK prod (`io.github.truongthanhnam.pakmanager`) và hậu tố `.dev` của flavor dev bằng `aapt2 dump badging`; hiện xóa `applicationIdSuffix` hoặc tạo lại template đều không làm CI fail. Làm cùng harness kiểm âm của `check_android_apk.sh`.
- Kiểm âm cho bước chặn secret của `ci.yml` (`secrets.X`, `secrets['X']`, `toJSON(secrets)`); hiện thu hẹp regex vẫn xanh. Dùng chung harness kiểm âm.
- Bước chặn secret chỉ quét `ci.yml`; khi story 7.2 thêm workflow release dùng secret trên `main`/tag, cần quét mọi workflow có trigger `pull_request` (và cấm `pull_request_target` ở mọi file).
- Isolate phụ (`Sodium.runIsolated`, `compute`, `Isolate.run`) không thừa hưởng zone nuốt `print`, `debugPrint` no-op và `PlatformDispatcher.onError` của isolate chính; story 1.4 (KDF trong isolate) phải cài chính sách lỗi release bên trong isolate.
  status: done (story 1.4, `spec-1-4-ma-hoa-vault-bang-khoa-hai-tang-va-argon2id.md`) — callback KDF của `deriveKek` (`lib/core/crypto/kdf.dart`) chạy trong zone nuốt `print` và `try/catch` mọi lỗi; lỗi báo về bằng khóa rỗng, `deriveKek` trả `null`. Zone và `try/catch` đã có, nhánh lỗi có test; riêng việc nuốt `print` chưa có test tự động (`avoid_print` cấm `print` cả trong test).
- Bước CI kiểm code Pigeon sinh ra đã cập nhật (AD-19) được dời từ 1.1 sang story 1.2 cùng `pigeons/platform_api.dart`; story 1.2 phải thêm bước này vào `.github/workflows/ci.yml`.
  status: done (story 1.2, `spec-1-2-thu-muc-du-lieu-rieng-ghi-nguyen-tu-loai-khoi-backup.md`) — bước "Code Pigeon sinh ra đã cập nhật" trong job `android` của `ci.yml`.
- Kiểm ELF 16 KB cả `.so` 32-bit (đã ghi ở mục review trong build phía trên); xác nhận bằng lần CI đầu.

## Deferred from: build review of spec-1-2-thu-muc-du-lieu-rieng-ghi-nguyen-tu-loai-khoi-backup (2026-11-02)

- source_spec: `_bmad-output/implementation-artifacts/spec-1-2-thu-muc-du-lieu-rieng-ghi-nguyen-tu-loai-khoi-backup.md`
  summary: Thêm kiểm tra khi chạy thật (`integration_test` trên simulator/máy) cho API Pigeon native: bốn kênh trả lời được, và sau bootstrap thư mục `pak/` trên iOS có `isExcludedFromBackup == true`.
  evidence: CI chỉ build Android/iOS nên chỉ chứng minh native biên dịch được. Bỏ `PlatformApiSetup.setUp` hoặc `registrar(forPlugin:)` trả nil thì mọi lần khởi động đều `StorageUnavailable`, mà CI vẫn xanh. Nên làm ở story 1.6, khi `SessionGate` dùng kết quả bootstrap.

## Deferred from: code review of spec-1-2-thu-muc-du-lieu-rieng-ghi-nguyen-tu-loai-khoi-backup (2026-11-02)

- `runPakApp` bỏ kết quả `StorageBootstrap.run()`; story 1.6 phải truyền `StorageBootstrapResult` vào `PakApp`/`SessionGate` và chặn mọi đọc/ghi dữ liệu khi nhận `StorageUnavailable` (quyết định fail-closed của story 1.2). Hiện chỉ có comment trong `lib/main.dart` nhắc việc này.
- Các regex kiểm `allowBackup`/`dataExtractionRules`/`fullBackupContent` mới trong `check_android_apk.sh` chưa có kiểm âm trên output `aapt2` xấu; nếu định dạng output lệch thì kiểm sai trên APK thật (fail oan hoặc lọt). Làm cùng harness kiểm âm của script APK, mục đã ghi từ story 1.1.

## Deferred from: build review of spec-1-3-giao-dien-sang-toi-hai-ngon-ngu-cai-dat-mac-dinh (2026-11-09)

- source_spec: `_bmad-output/implementation-artifacts/spec-1-3-giao-dien-sang-toi-hai-ngon-ngu-cai-dat-mac-dinh.md`
  summary: Xác nhận trên máy Android thật rằng `FlutterView.display.size` khác 0 lúc khởi động (hoặc có metrics ngay sau đó), để điện thoại luôn bị khóa dọc; nếu không thì fallback sang `view.physicalSize`.
  evidence: maybe-false, nếu đúng là medium. `applyOrientationPolicy` bỏ qua khi size rỗng và chờ `didChangeMetrics`; chưa kiểm được trên máy thật (máy dev không có Android SDK). Làm ở story 7.1 (bộ nghiệm thu trên máy thật).

## Deferred from: code review of spec-1-3-giao-dien-sang-toi-hai-ngon-ngu-cai-dat-mac-dinh (2026-11-09)

- (Chưa xác minh; nếu đúng thì medium) Trên máy gập, `FlutterView.display.size` có thể không cập nhật khi gập hoặc mở. Khi đó `applyOrientationPolicy` trong `didChangeMetrics` (`pak_manager/lib/features/shared/orientation.dart:40`) vẫn giữ chính sách phone/tablet cũ. Cần kiểm trên máy gập Android thật hoặc emulator foldable. Nếu `display.size` không đổi thì tính lại từ `view.physicalSize / devicePixelRatio`. Làm cùng mục `display.size` ở trên (story 7.1).

## Deferred from: build review of spec-1-4-ma-hoa-vault-bang-khoa-hai-tang-va-argon2id (2026-11-09)

- source_spec: `_bmad-output/implementation-artifacts/spec-1-4-ma-hoa-vault-bang-khoa-hai-tang-va-argon2id.md`
  summary: (Chưa xác minh, nếu đúng thì high) Hiệu chỉnh KDF trả `null` khi lần probe (3, 64 MiB) lỗi, không lùi về sàn (2, 19 MiB), nên máy không cấp được 64 MiB sẽ không tạo được tài khoản (story 1.6).
  evidence: Đúng Design Notes bước 4 của story 1.4. Cần chạy `calibrateVaultKdf` trên máy mốc yếu nhất (Android 7, RAM 2 GB; iPhone 6s/SE đời 1) để biết Argon2id 64 MiB có cấp được bộ nhớ không. Nếu không, thêm lần thử ở sàn sau khi probe lỗi.

## Deferred from: code review of spec-1-4-ma-hoa-vault-bang-khoa-hai-tang-va-argon2id (2026-11-09)

- (Chưa xác minh, nếu đúng thì medium) Chưa có bằng chứng CI xanh cho build native của story 1.4: libsodium cho từng ABI Android, căn 16 KB, và build iOS. `pubspec.lock` nâng `objective_c` 9.5.0→9.6.3 (iOS của `path_provider`) và nâng `code_assets`/`hooks`/`record_use` lên major mới. Kết luận được khi job ubuntu (APK) và job macOS (iOS) của CI trên nhánh `feat/1-4-vault-crypto` xanh. Nếu đỏ thì sửa trước khi merge.
