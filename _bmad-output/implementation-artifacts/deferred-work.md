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
- [Đã xong ở story 1.2: bước "Code Pigeon sinh ra đã cập nhật" trong job `android` của `ci.yml`] Bước CI kiểm code Pigeon sinh ra đã cập nhật (AD-19) được dời từ 1.1 sang story 1.2 cùng `pigeons/platform_api.dart`; story 1.2 phải thêm bước này vào `.github/workflows/ci.yml`.
- Kiểm ELF 16 KB cả `.so` 32-bit (đã ghi ở mục review trong build phía trên); xác nhận bằng lần CI đầu.
