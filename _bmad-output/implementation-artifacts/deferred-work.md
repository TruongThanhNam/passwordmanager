# Deferred Work

- source_spec: `_bmad-output/implementation-artifacts/spec-1-1-khoi-tao-du-an-flutter-structural-seed-ci.md`
  summary: Thêm flavor `dev` cho iOS (scheme + build configuration, bundle id hậu tố `.dev`) để bản dev không ghi đè vault thật trên iPhone.
  evidence: Story 1.1 chỉ làm flavor Android theo quyết định của người dùng; iOS cần sửa tay `project.pbxproj` và chỉ kiểm được qua CI macOS. Khi có scheme `prod`/`dev` cho iOS thì cân nhắc `flutter: default-flavor: prod` trong `pubspec.yaml` (hiện không dùng được vì làm `flutter build ios` không cờ bị fail).
  status: done (story 1.14, `spec-1-14-flavor-dev-cho-ios-va-ghi-cong-giay-phep-blocklist.md`) — scheme `prod`/`dev` và cấu hình `{Debug,Release,Profile}-{prod,dev}`; bundle id dev `io.github.truongthanhnam.pakmanager.dev`; CI job `ios` build và kiểm bundle id cả hai flavor. Chưa thêm `default-flavor` (build không cờ vẫn dùng scheme `Runner`).

- source_spec: `_bmad-output/implementation-artifacts/spec-1-1-khoi-tao-du-an-flutter-structural-seed-ci.md`
  status: done (story 1.2, `spec-1-2-thu-muc-du-lieu-rieng-ghi-nguyen-tu-loai-khoi-backup.md`) — composition root là `lib/main.dart`; `check_imports` cấm services import `lib/platform/`/`lib/features/` và mọi file ngoài `lib/platform/` trừ `lib/main.dart` import `lib/platform/`.
  summary: Mở rộng `check_imports` để kiểm phân lớp của `lib/services/` và `lib/platform/` (services không import `lib/platform/` hay `lib/features/`), sau khi chốt composition root được phép nối platform vào port.
  evidence: AD-2 nói platform chỉ được gọi qua `core/ports`, nhưng checker hiện chỉ kiểm `features` và `core`; cần quyết định file nào được import `lib/platform/` (xuất hiện ở story 1.2).

- source_spec: `_bmad-output/implementation-artifacts/spec-1-1-khoi-tao-du-an-flutter-structural-seed-ci.md`
  summary: Thêm bước CI so `pubspec.yaml` (kể cả `dev_dependencies`) với bảng Stack của ARCHITECTURE-SPINE và từ chối ràng buộc không ghim chính xác.
  evidence: AD-12 hiện chỉ được nhắc bằng comment trong `pubspec.yaml`; một lần `flutter pub add` ngoài Stack vẫn qua mọi cổng CI.
  status: done (story 1.11, `spec-1-11-ghim-chuoi-cung-ung-va-stack-trong-ci.md`) — bước `dart run tool/ci/check_stack.dart` trong `ci.yml` so `pubspec.yaml`/`pubspec.lock` với bảng Stack; gói transitive phải có trong `tool/ci/transitive_allowlist.txt`.

- source_spec: `_bmad-output/implementation-artifacts/spec-1-1-khoi-tao-du-an-flutter-structural-seed-ci.md`
  summary: Ghim chuỗi cung ứng của CI: action theo commit SHA, kiểm revision Flutter sau khi clone (khớp `.metadata`), `distributionSha256Sum` cho Gradle wrapper.
  evidence: `actions/checkout@v4`/`setup-java@v4` là tag đổi được; clone Flutter theo tag không xác minh revision; Gradle wrapper không có checksum — rủi ro với repo public của app mật khẩu.
  status: done (story 1.11) — mọi `uses:` trong `ci.yml` ghim commit SHA; có bước so revision Flutter với `.metadata`; `gradle-wrapper.properties` có `distributionSha256Sum`. Còn mở ở các mục riêng bên dưới: kiểm âm bước so revision, xác thực `gradle-wrapper.jar`.

- source_spec: `_bmad-output/implementation-artifacts/spec-1-1-khoi-tao-du-an-flutter-structural-seed-ci.md`
  summary: (Chưa xác minh, nếu đúng thì medium) Ghim image runner (`macos-15` + Xcode cụ thể, `ubuntu-24.04`) để build không gãy khi `*-latest` đổi.
  evidence: Chưa thấy lỗi; theo dõi các lần CI đầu và khi GitHub đổi `macos-latest`. Gãy build không do thay đổi repo là dấu hiệu cần ghim.
  status: done (story 1.11) — runner ghim `ubuntu-24.04` và `macos-15`; job macOS chọn Xcode 26.3 và fail nếu runner không có.

- source_spec: `_bmad-output/implementation-artifacts/spec-1-1-khoi-tao-du-an-flutter-structural-seed-ci.md`
  summary: (Chưa xác minh, nếu đúng thì medium) Kiểm ELF 16 KB trong `tool/ci/check_android_apk.sh` có thể fail oan với `.so` 32-bit (armeabi-v7a, x86); quy định 16 KB của Google chỉ áp cho ABI 64-bit.
  evidence: Lần chạy CI đầu sẽ cho biết: nếu chỉ `lib/armeabi-v7a/*.so` hoặc `lib/x86/*.so` báo align `0x1000` thì giới hạn kiểm ELF vào `arm64-v8a` và `x86_64`.
  status: done (story 1.12, `spec-1-12-kiem-am-cho-cac-cong-ci.md`) — luật tách ra `tool/ci/apk_rules.dart` và `tool/ci/check_workflow_secrets.dart`, kiểm âm trong `test/tool/`; ELF 16 KB chỉ kiểm `arm64-v8a`/`x86_64`; CI kiểm badging APK prod và dev.

- source_spec: `_bmad-output/implementation-artifacts/spec-1-1-khoi-tao-du-an-flutter-structural-seed-ci.md`
  summary: Thêm kiểm âm cho `check_android_apk.sh` (APK hoặc output `aapt2`/`readelf` giả có `INTERNET`, `.so` align 4 KB) để chắc cổng thực sự fail.
  evidence: Script chỉ chạy trên APK kỳ vọng pass; nếu pattern grep lệch định dạng output, mọi APK đều qua. Nên làm trước khi plugin đầu tiên (story 1.2) có thể kéo quyền vào manifest.
  status: done (story 1.12, `spec-1-12-kiem-am-cho-cac-cong-ci.md`) — luật tách ra `tool/ci/apk_rules.dart` và `tool/ci/check_workflow_secrets.dart`, kiểm âm trong `test/tool/`; ELF 16 KB chỉ kiểm `arm64-v8a`/`x86_64`; CI kiểm badging APK prod và dev.

## Deferred from: code review of spec-1-1-khoi-tao-du-an-flutter-structural-seed-ci (2026-11-02)

- Kiểm `applicationId` của APK prod (`io.github.truongthanhnam.pakmanager`) và hậu tố `.dev` của flavor dev bằng `aapt2 dump badging`; hiện xóa `applicationIdSuffix` hoặc tạo lại template đều không làm CI fail. Làm cùng harness kiểm âm của `check_android_apk.sh`.
  status: done (story 1.12, `spec-1-12-kiem-am-cho-cac-cong-ci.md`) — luật tách ra `tool/ci/apk_rules.dart` và `tool/ci/check_workflow_secrets.dart`, kiểm âm trong `test/tool/`; ELF 16 KB chỉ kiểm `arm64-v8a`/`x86_64`; CI kiểm badging APK prod và dev.
- Kiểm âm cho bước chặn secret của `ci.yml` (`secrets.X`, `secrets['X']`, `toJSON(secrets)`); hiện thu hẹp regex vẫn xanh. Dùng chung harness kiểm âm.
  status: done (story 1.12, `spec-1-12-kiem-am-cho-cac-cong-ci.md`) — luật tách ra `tool/ci/apk_rules.dart` và `tool/ci/check_workflow_secrets.dart`, kiểm âm trong `test/tool/`; ELF 16 KB chỉ kiểm `arm64-v8a`/`x86_64`; CI kiểm badging APK prod và dev.
- Bước chặn secret chỉ quét `ci.yml`; khi story 7.2 thêm workflow release dùng secret trên `main`/tag, cần quét mọi workflow có trigger `pull_request` (và cấm `pull_request_target` ở mọi file).
  status: planned — story 7.2
- Isolate phụ (`Sodium.runIsolated`, `compute`, `Isolate.run`) không thừa hưởng zone nuốt `print`, `debugPrint` no-op và `PlatformDispatcher.onError` của isolate chính; story 1.4 (KDF trong isolate) phải cài chính sách lỗi release bên trong isolate.
  status: done (story 1.4, `spec-1-4-ma-hoa-vault-bang-khoa-hai-tang-va-argon2id.md`) — callback KDF của `deriveKek` (`lib/core/crypto/kdf.dart`) chạy trong zone nuốt `print` và `try/catch` mọi lỗi; lỗi báo về bằng khóa rỗng, `deriveKek` trả `null`. Zone và `try/catch` đã có, nhánh lỗi có test; riêng việc nuốt `print` chưa có test tự động (`avoid_print` cấm `print` cả trong test).
- Bước CI kiểm code Pigeon sinh ra đã cập nhật (AD-19) được dời từ 1.1 sang story 1.2 cùng `pigeons/platform_api.dart`; story 1.2 phải thêm bước này vào `.github/workflows/ci.yml`.
  status: done (story 1.2, `spec-1-2-thu-muc-du-lieu-rieng-ghi-nguyen-tu-loai-khoi-backup.md`) — bước "Code Pigeon sinh ra đã cập nhật" trong job `android` của `ci.yml`.
- Kiểm ELF 16 KB cả `.so` 32-bit (đã ghi ở mục review trong build phía trên); xác nhận bằng lần CI đầu.
  status: done (story 1.12, `spec-1-12-kiem-am-cho-cac-cong-ci.md`) — luật tách ra `tool/ci/apk_rules.dart` và `tool/ci/check_workflow_secrets.dart`, kiểm âm trong `test/tool/`; ELF 16 KB chỉ kiểm `arm64-v8a`/`x86_64`; CI kiểm badging APK prod và dev.

## Deferred from: build review of spec-1-2-thu-muc-du-lieu-rieng-ghi-nguyen-tu-loai-khoi-backup (2026-11-02)

- source_spec: `_bmad-output/implementation-artifacts/spec-1-2-thu-muc-du-lieu-rieng-ghi-nguyen-tu-loai-khoi-backup.md`
  summary: Thêm kiểm tra khi chạy thật (`integration_test` trên simulator/máy) cho API Pigeon native: bốn kênh trả lời được, và sau bootstrap thư mục `pak/` trên iOS có `isExcludedFromBackup == true`.
  evidence: CI chỉ build Android/iOS nên chỉ chứng minh native biên dịch được. Bỏ `PlatformApiSetup.setUp` hoặc `registrar(forPlugin:)` trả nil thì mọi lần khởi động đều `StorageUnavailable`, mà CI vẫn xanh. Nên làm ở story 1.6, khi `SessionGate` dùng kết quả bootstrap.
  status: done (story 1.13, `spec-1-13-integration-test-cho-api-native.md`) — `pak_manager/integration_test/platform_api_test.dart` gọi mọi phương thức Pigeon, chạy `StorageBootstrap` thật và đọc cờ backup iOS qua `isExcludedFromBackup`; CI job `integration-android` (emulator API 34) và `integration-ios` (simulator).

## Deferred from: code review of spec-1-2-thu-muc-du-lieu-rieng-ghi-nguyen-tu-loai-khoi-backup (2026-11-02)

- `runPakApp` bỏ kết quả `StorageBootstrap.run()`; story 1.6 phải truyền `StorageBootstrapResult` vào `PakApp`/`SessionGate` và chặn mọi đọc/ghi dữ liệu khi nhận `StorageUnavailable` (quyết định fail-closed của story 1.2). Hiện chỉ có comment trong `lib/main.dart` nhắc việc này.
  status: done (story 1.6, `spec-1-6-tao-tai-khoan-va-vao-khung-3-tab.md`) — `runPakApp` nối kết quả vào `bootstrapResultProvider`; `StorageUnavailable` → không dựng `AccountService`, gate hiện S1 với nút vô hiệu và `create.unavailable` (test `nfr8_run_app_waits_for_storage_bootstrap`).
- Các regex kiểm `allowBackup`/`dataExtractionRules`/`fullBackupContent` mới trong `check_android_apk.sh` chưa có kiểm âm trên output `aapt2` xấu; nếu định dạng output lệch thì kiểm sai trên APK thật (fail oan hoặc lọt). Làm cùng harness kiểm âm của script APK, mục đã ghi từ story 1.1.
  status: done (story 1.12, `spec-1-12-kiem-am-cho-cac-cong-ci.md`) — luật tách ra `tool/ci/apk_rules.dart` và `tool/ci/check_workflow_secrets.dart`, kiểm âm trong `test/tool/`; ELF 16 KB chỉ kiểm `arm64-v8a`/`x86_64`; CI kiểm badging APK prod và dev.

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
  status: partly done (story 1.10, `spec-1-10-hieu-chinh-kdf-lui-ve-san-khi-lan-thu-dau-loi.md`) — probe lỗi thì `calibrateVaultKdf` (`lib/core/crypto/kdf_calibration.dart`) thử lại đúng một lần ở `KdfParams.floor` (2, 19 MiB). Còn mở: đo trên máy mốc yếu nhất (story 7.1).

## Deferred from: code review of spec-1-4-ma-hoa-vault-bang-khoa-hai-tang-va-argon2id (2026-11-09)

- (Chưa xác minh, nếu đúng thì medium) Chưa có bằng chứng CI xanh cho build native của story 1.4: libsodium cho từng ABI Android, căn 16 KB, và build iOS. `pubspec.lock` nâng `objective_c` 9.5.0→9.6.3 (iOS của `path_provider`) và nâng `code_assets`/`hooks`/`record_use` lên major mới. Kết luận được khi job ubuntu (APK) và job macOS (iOS) của CI trên nhánh `feat/1-4-vault-crypto` xanh. Nếu đỏ thì sửa trước khi merge.
  status: done (CI tại `1c7d4e4`: job ubuntu và job macOS đều xanh, theo người dùng báo 2026-11-09) — `check_android_apk.sh` đã kiểm `libsodium.so` trong mọi ABI và căn 16 KB; build iOS cùng bản `objective_c` mới qua.

## Deferred from: build of spec-1-5-luat-mat-khau-chinh-va-danh-gia-do-manh (2026-11-10)

- source_spec: `_bmad-output/implementation-artifacts/spec-1-5-luat-mat-khau-chinh-va-danh-gia-do-manh.md`
  summary: (medium) `StrengthEstimator.estimate` trên chuỗi 128 ký tự nhiều ký hiệu mất ≈80–99 ms mỗi lần (JIT, máy dev), đủ để giật khung hình nếu story 1.6 gọi đồng bộ trên UI thread ở mỗi lần gõ phím.
  evidence: Đo lúc build story 1.5: cache từ điển hoạt động (dựng ≈25–31 ms, gọi có cache với chuỗi ngắn ≈2 ms), phần chậm là matcher l33t của `zxcvbnm`. Không giảm l33t vì sẽ đổi điểm (người dùng chọn 2026-11-10). Story 1.6 nên debounce hoặc chạy ước lượng ngoài UI thread, dựng `StrengthEstimator` sớm (làm nóng từ điển), và đo trên bản release ở máy mốc yếu nhất.
  status: partly done (story 1.6) — S2 debounce 150 ms (`strengthDebounce`), `main.dart` dựng `StrengthEstimator` trước `runApp`. Còn mở: đo bản release trên máy mốc yếu nhất (story 7.1).
- source_spec: `_bmad-output/implementation-artifacts/spec-1-5-luat-mat-khau-chinh-va-danh-gia-do-manh.md`
  summary: (medium) Chưa quyết định app làm gì khi `assets/blocklist.bloom` thiếu hoặc `BlocklistFilter.parse` trả `null`; `PasswordPolicy` cần filter non-null nên story 1.6 (người nạp asset) phải chọn cách xử lý.
  evidence: Review build 1.5 (#6). Asset được đóng gói nên chỉ hỏng khi build lỗi, nhưng 1.6, 5.3 và 6.2 không được mỗi nơi xử lý một kiểu. Gợi ý: nạp một lần ở tầng services, hỏng thì fail closed (chặn tạo tài khoản và đặt mật khẩu, báo lỗi), không âm thầm bỏ luật "phổ biến".
  status: done (story 1.6) — `main.dart` nạp asset một lần; `parse` → `null` hoặc lỗi đọc → `BootstrapUnavailable`, `passwordPolicyProvider` = `null` (S2 không bao giờ bật nút). 5.3 và 6.2 đọc cùng `passwordPolicyProvider`.
- source_spec: `_bmad-output/implementation-artifacts/spec-1-5-luat-mat-khau-chinh-va-danh-gia-do-manh.md`
  summary: (Chưa xác minh; nếu đúng thì medium) Toàn bộ `flutter test` chưa chạy trên nhánh `feat/1-5-password-policy`, vì máy dev thiếu VS Build Tools cho build hook `sodium`.
  evidence: 40 test mới pass trong bản sao không `sodium`; analyze và check_imports OK. Kết luận được khi job ubuntu của CI trên nhánh này xanh (gồm cả test cũ và đóng gói asset vào APK).
  status: done (CI tại `8b63f36`: job ubuntu và job macOS đều xanh, theo người dùng báo 2026-11-10) — toàn bộ `flutter test` (gồm 44 test của story 1.5 và test cũ) pass; `check_android_apk.sh` đã kiểm `assets/flutter_assets/assets/blocklist.bloom` có trong APK (bước thêm sau code review, commit `8735293`).

## Deferred from: code review of spec-1-5-luat-mat-khau-chinh-va-danh-gia-do-manh.md (2026-11-10)

- source_spec: `_bmad-output/implementation-artifacts/spec-1-5-luat-mat-khau-chinh-va-danh-gia-do-manh.md`
  summary: (Chưa xác minh; nếu đúng thì medium) Thiếu ghi công giấy phép MIT của SecLists đi kèm `assets/blocklist.bloom` và `test/fixtures/blocklist/sample.txt`; chỉ có URL trong `tool/blocklist/SOURCE`, không có NOTICE hay `LicenseRegistry.addLicense`. Nguồn `rockyou` là dữ liệu lộ, không do SecLists viết.
  evidence: Code review 1.5 (blind-hunter). Kết luận được khi xác định Bloom filter dẫn xuất và 500 dòng mẫu có phải "copies or substantial portions" theo MIT không; nếu có thì thêm NOTICE cạnh asset và đăng ký giấy phép ở story có màn giấy phép.
  status: done (story 1.14) — thêm `pak_manager/NOTICE` chứa nguyên văn MIT của SecLists tại commit ghim, repo, các path và ghi chú về `rockyou`; `tool/blocklist/SOURCE` và `assets/blocklist.FORMAT.md` trỏ tới `NOTICE`. Phần `LicenseRegistry` tách thành mục riêng bên dưới.
- source_spec: `_bmad-output/implementation-artifacts/spec-1-14-flavor-dev-cho-ios-va-ghi-cong-giay-phep-blocklist.md`
  summary: Gọi `LicenseRegistry.addLicense` với nội dung `NOTICE` (khai báo làm asset) để ghi công SecLists hiện trong màn giấy phép của app.
  evidence: Story 1.14 chỉ thêm file `NOTICE` trong repo; epics hiện chưa có story màn giấy phép.
  status: planned — khi có story màn giấy phép
- source_spec: `_bmad-output/implementation-artifacts/spec-1-5-luat-mat-khau-chinh-va-danh-gia-do-manh.md`
  summary: (low) Chưa định nghĩa dòng độ mạnh hiện gì khi `PasswordPolicy.check` trả lỗi: `StrengthEstimator` không biết blocklist và luật lặp/tuần tự, nên UI có thể hiện `High` cạnh lỗi `PasswordCommon`/`PasswordPattern`.
  evidence: Code review 1.5 (blind-hunter). Story 1.6, 5.3 và 6.2 đều hiện dòng độ mạnh; cần quyết định chung một lần (vd ép `low` khi `check` không `PasswordOk`) để ba nơi không lệch nhau.
  status: done (quyết định người dùng 2026-11-10, spec 1.6) — vẫn hiện mức `zxcvbnm` như mockup, không ép "Thấp", không ẩn; áp chung cho 1.6/5.3/6.2.

## Deferred from: build of spec-1-6-tao-tai-khoan-va-vao-khung-3-tab (2026-11-10)

- source_spec: `_bmad-output/implementation-artifacts/spec-1-6-tao-tai-khoan-va-vao-khung-3-tab.md`
  summary: (low) Bấm tab đang chọn chưa cuộn về đầu (UX-DR29); Back hệ thống Android chỉ được `SessionGate` chuyển cho navigator gốc của cây đang hiện, chưa vào navigator riêng của từng `CupertinoTabView`.
  evidence: Thân tab ở 1.6 trống, không có nội dung cuộn hay màn push trong tab. Làm khi tab có nội dung (3.1 danh sách card, Epic 4 generator, `ModalPresenter` Epic 3).
- source_spec: `_bmad-output/implementation-artifacts/spec-1-6-tao-tai-khoan-va-vao-khung-3-tab.md`
  summary: (low) `flutter_riverpod` 3.4.3 kéo theo `riverpod`, `listen`, `state_notifier`, `uuid` (chỉ để sinh id debug/devtools); cần tính vào bước CI so `pubspec` với Stack (mục deferred của 1.1).
  evidence: Thấy trong `pubspec.lock` khi thêm package; không dùng mạng, không plugin native.
  status: done (story 1.11) — `riverpod`, `listen`, `state_notifier`, `uuid` có trong `tool/ci/transitive_allowlist.txt`, `check_stack.dart` từ chối gói transitive ngoài danh sách.

## Deferred from: build review of spec-1-6-tao-tai-khoan-va-vao-khung-3-tab (2026-11-10)

- source_spec: `_bmad-output/implementation-artifacts/spec-1-6-tao-tai-khoan-va-vao-khung-3-tab.md`
  summary: (Chưa xác minh; nếu đúng thì medium) Khi bấm mắt để hiện mật khẩu, `SecretField` gửi `TextInputType.text`; một số bàn phím Android có thể bật thanh gợi ý hoặc học từ mật khẩu chính dù `enableSuggestions`/`enableIMEPersonalizedLearning` = false.
  evidence: Review build 1.6 (blind-hunter #18). Kết luận được bằng cách thử Gboard và Samsung Keyboard trên máy Android thật với ô đang hiện: nếu thấy gợi ý hoặc từ mới trong từ điển cá nhân thì dùng `TextInputType.visiblePassword` khi ô đang hiện (kiểm cả ảnh hưởng tới bộ gõ Telex, UX-DR41). Làm cùng bộ nghiệm thu trên máy thật (story 7.1).


## Deferred from: code review of spec-1-8-khoa-vault-va-xoa-du-lieu-giai-ma-khoi-bo-nho.md (2026-11-10)

- Cửa sổ giữa `session.lock()` và `_notify()` trong `SessionController._runLock` (trong lúc await `clearClipboardIfOurs`): HomeShell vẫn hiện với phiên đã khóa, nhánh reset navigator key `_lastInSession` trong `SessionGate` chưa có test. Khi có hook clipboard thật (Epic 3/5/6): cho phép inject hook vào gate, viết test lock với hook chậm + pump một frame.

## Deferred from: code review of spec-1-9-tu-khoa-khi-chay-nen-va-gioi-han-phien.md (2026-11-10)

- Không có privacy screen: khi `hidden`/`paused`, ảnh app-switcher vẫn lộ nội dung vault, và lúc `resumed` HomeShell có thể hiện 1 frame trước khi `evaluate` khóa xong. Cần story riêng (che màn hình khi vào nền, FLAG_SECURE/iOS snapshot).
  status: closed — rủi ro đã chấp nhận theo PRD NFR-10 (chủ sản phẩm 2026-11-10)

- source_spec: `_bmad-output/implementation-artifacts/spec-1-11-ghim-chuoi-cung-ung-va-stack-trong-ci.md`
  summary: Kiểm âm bước so revision Flutter với `.metadata` và gom khối shell lặp ở hai job vào một script `tool/ci/`.
  evidence: Chỉ đường pass được chạy trên CI; đảo điều kiện hoặc bỏ `exit 1` vẫn xanh (thuộc phạm vi story 1.12).
  status: done — story 1.15
- source_spec: `_bmad-output/implementation-artifacts/spec-1-11-ghim-chuoi-cung-ung-va-stack-trong-ci.md`
  summary: Đối chiếu phiên bản Flutter (`FLUTTER_VERSION`), Gradle và Xcode trong CI với bảng Stack của spine.
  evidence: `check_stack.dart` chỉ kiểm package; spine và CI có thể lệch mà gate vẫn pass.
  status: done — story 1.16
- source_spec: `_bmad-output/implementation-artifacts/spec-1-11-ghim-chuoi-cung-ung-va-stack-trong-ci.md`
  summary: Xác thực `gradle-wrapper.jar` đã commit (vd `gradle/actions/wrapper-validation` ghim SHA).
  evidence: `distributionSha256Sum` chỉ phủ bản phân phối tải về, không phủ JAR wrapper trong repo.
  status: done — story 1.16

- source_spec: `_bmad-output/implementation-artifacts/spec-1-12-kiem-am-cho-cac-cong-ci.md`
  summary: Thay output `aapt2`/`unzip -l`/`readelf -lW` tự viết trong `apk_rules_test.dart` bằng output thật lấy từ APK prod/dev của CI làm golden fixture.
  evidence: Fixture hiện là xấp xỉ; nếu định dạng thật lệch thì test vẫn xanh còn CI fail oan (hoặc lọt).
  status: done — story 1.15
- source_spec: `_bmad-output/implementation-artifacts/spec-1-12-kiem-am-cho-cac-cong-ci.md`
  summary: Thêm test cho lớp shell `check_android_apk.sh` (công cụ giả trên PATH) để chứng minh `--expect-id` tới `apk_rules.dart` và lỗi luật làm script fail.
  evidence: Bỏ `$expect_id` khỏi `rule_args` thì `run()` bỏ qua badging, mọi test Dart và CI trên APK tốt vẫn xanh.
  status: done — story 1.15

## Deferred from: code review of spec-1-12-kiem-am-cho-cac-cong-ci (2026-11-12)

- Test cho lớp shell `check_android_apk.sh` (hợp đồng thư mục `$work`, truyền `--expect-id`, exit code). Bỏ `--expect-id` thì kiểm badging bị tắt mà CI vẫn xanh.
  status: done — story 1.15
- Kiểm âm cho cổng `zipalign -c -P 16` (APK căn sai phải làm `failed=1`); cần cùng harness công cụ giả trên PATH.
  status: done — story 1.15
- Test parse `ci.yml` để khẳng định các bước cổng (secret AD-18, kiểm APK prod/dev kèm `--expect-id`) vẫn còn.
  status: done — story 1.16

- source_spec: `_bmad-output/implementation-artifacts/spec-1-15-kiem-lop-shell-cua-cac-cong-ci.md`
  summary: Thêm kiểm âm cho các nhánh guard có sẵn từ trước của `check_android_apk.sh` (thiếu file APK, `ANDROID_HOME`/`ANDROID_SDK_ROOT` chưa đặt, thiếu `aapt2`/`zipalign`/`readelf`/`unzip`/`dart` trên PATH).
  evidence: Review code review của story 1.15 (blind-hunter): các guard này có từ trước story 1.15, không có test shell nào kiểm, dù về mặt logic các dòng `exit 1` vẫn đúng.
  status: planned

- source_spec: `_bmad-output/implementation-artifacts/spec-1-13-integration-test-cho-api-native.md`
  summary: Integration test chỉ chạy bản debug; chưa có kiểm khi chạy thật cho bản release (R8/minify có thể làm hỏng đăng ký Pigeon).
  evidence: Job integration-android dùng `flutter test` (debug); lỗi chỉ xuất hiện ở release vẫn để CI xanh.
  status: planned — story 7.2

## Deferred from: code review of spec-1-13-integration-test-cho-api-native.md (2026-11-12)

- AC1/AC2 của story 1.13 chưa có bằng chứng chạy xanh: hai job `integration-android`/`integration-ios`, `check_workflow_secrets.dart`, và kiểm âm "gỡ `PlatformApi.setUp` → CI đỏ" chưa chạy. Xác nhận qua GitHub Actions của PR và một nhánh tạm bỏ đăng ký native.
  status: done (theo người dùng báo 2026-11-13) — hai job `integration-android` và `integration-ios` đều xanh trên CI.

## Deferred from: code review of spec-1-15-kiem-lop-shell-cua-cac-cong-ci.md (2026-11-14)

- Chưa có test đọc `ci.yml` giữ `PAK_REQUIRE_SHELL_TESTS: '1'` ở bước `flutter test` job `android`, `--save-raw` ở hai bước kiểm APK và bước upload `apk-raw-output`. Gộp vào test cấu trúc ci.yml của story 1.16.
  status: done — story 1.16
- Khi kiểm APK prod fail, build/kiểm dev bị bỏ nên artifact `apk-raw-output` thiếu output thô dev. Cân nhắc `if: ${{ !cancelled() }}` cho bước dev hoặc ghi rõ giới hạn.
  note: từ story 1.16, luật `_apkDevGate` trong `tool/ci/ci_structure.dart` cấm mọi `if:` trên bước kiểm APK dev; làm ý tưởng này thì phải thêm `allowedIf` cho cổng đó và sửa test tương ứng.
- AC1 story 1.15: job `integration-ios` fail/bị hủy ở các lần chạy pha A/B (chỉ 3/4 job xanh). Lý do hoãn: lỗi runner macOS, không do thay đổi của 1.15. Cần một lần chạy CI xanh đủ 4 job để xác nhận.
  status: done (theo người dùng báo 2026-11-14) — cả 4 job đều xanh sau commit 1006917.

## Deferred from: code review of spec-1-16-ghim-toolchain-va-bao-ve-cau-truc-ci-yml.md (2026-11-14)

- `distributionSha256Sum` trong `pak_manager/android/gradle/wrapper/gradle-wrapper.properties` không được cổng nào kiểm: xóa dòng này thì mọi cổng vẫn xanh. Lỗ hổng có từ story 1.11; story 1.16 chỉ thêm so phiên bản `distributionUrl` trong `check_stack.dart`. Hướng sửa: kiểm có dòng `distributionSha256Sum=` 64 hex, kèm kiểm âm.
  status: done — action item `epic-1-retro-item-2` (retro Epic 1, `epic-1-retro-2026-11-18.md` mục B1): `checkToolchain` trong `tool/ci/check_stack.dart` đòi đúng một dòng `distributionSha256Sum=<64 hex>`, kèm kiểm âm ở `test/tool/check_stack_test.dart`. Chưa có id run CI. Dòng status `done` trước đây ở mục này thuộc mục AC1 story 1.15 ngay trên, bị đặt lệch khi giải xung đột merge `737b616`.

## Deferred from: code review of spec-epic-1-retro-item-9-gom-fake-test-support.md (2026-11-19)

- id: DW-retro1.9-1
  source_spec: `_bmad-output/implementation-artifacts/spec-epic-1-retro-item-9-gom-fake-test-support.md`
  summary: AGENTS.md chưa có luật "fake port/timer/`SecureKey` đặt trong `test/support/port_fakes.dart`, helper UI trong `account_fakes.dart`, không chép fake inline, import trực tiếp".
  evidence: Retro Epic 1 C2/C3 cho thấy mỗi story lại chép fake inline; Epic 2 (`LockoutGuard`, `WipeCoordinator`) cần fake clock/timer/file. Sửa chạm file ngữ cảnh agent nên hoãn; làm bằng `bmad-project-context` (refresh hoặc record).
- id: DW-retro1.9-2
  source_spec: `_bmad-output/implementation-artifacts/spec-epic-1-retro-item-9-gom-fake-test-support.md`
  summary: Chưa có kiểm tự động cho bất biến "`port_fakes.dart` không import Flutter" và "fake implements port/`Timer`/`SecureKey` chỉ nằm trong `test/support/`, trừ fake cục bộ có lý do".
  evidence: `tool/check_imports.dart:26` chỉ quét `lib/`; bất biến hiện chỉ kiểm bằng grep tay trong spec. Theo retro D1, mục CI mới vào backlog CI riêng, không thành story chen trước Epic 2.
- id: DW-retro1.9-3
  source_spec: `_bmad-output/implementation-artifacts/spec-epic-1-retro-item-9-gom-fake-test-support.md`
  summary: `FakeSecureKey` dùng chung không ném khi dùng sau `dispose` và không theo dõi bản `copy()`, nên test có thể không bắt lỗi dùng-sau-hủy hay rò key.
  evidence: Chưa xác minh (maybe-false, nếu đúng là medium). Cần rà code `lib/` gọi `runUnlocked*`/`extractBytes`/`copy` trên `SecureKey` và xem test nào dùng `FakeSecureKey` cho các đường đó; nếu có đường dùng key sau `dispose` mà test không bắt thì sửa fake ném `StateError` sau `dispose`.

## Deferred from: code review of spec-2-1-dem-lan-nhap-sai-ben-vung.md (2026-11-21)

- id: DW-2.1-1
  source_spec: `_bmad-output/implementation-artifacts/spec-2-1-dem-lan-nhap-sai-ben-vung.md`
  summary: Trên Windows, `tearDown` gọi `sandbox.deleteSync(recursive: true)` thỉnh thoảng fail với errno 145 (thư mục chưa rỗng), làm test pass bị báo fail (`account_service_test`, `settings_store_test`, `lockout_guard_test`).
  evidence: Có từ trước story 2.1: baseline `92c25d2` fail 2/8 lần chạy `account_service_test` + `settings_store_test` với đúng lỗi này; nhánh 2.1 fail 1 test ở 2/2 lần chạy đầy đủ (`lockout_guard_test` dọn thư mục cùng cách). CI chạy ubuntu nên không gặp. Hướng sửa: helper dọn sandbox dùng chung trong `test/support/` có thử lại vài lần.
- id: DW-2.1-2
  source_spec: `_bmad-output/implementation-artifacts/spec-2-1-dem-lan-nhap-sai-ben-vung.md`
  summary: Tài khoản mới có thể kế thừa trạng thái guard của tài khoản trước: `normalize(hasAccount: false)` nạp `failCount` từ `guard` còn sót, `create()` không đặt lại file lẫn digest chuỗi sai trong RAM; `failCount` cũ là 10 thì tài khoản mới bị chặn ngay.
  evidence: Medium. Story 2.1 chưa có đường nào để lại `guard` mà mất `header` (chỉ khi `header` bị mất ngoài ý muốn); digest chỉ lọt qua khi có S3 → S1 cùng process (chưa có). Spec 2.1 cấm `create()` chạm `guard`. Story 2.3/2.4 phải bảo đảm `WipeCoordinator` gọi `LockoutGuard.reset()` (đặt file về 0 và bỏ digest), và cân nhắc `normalize` không nạp `failCount` khi không có `header`; test hiện có `ad08_create_never_reads_or_writes_guard` không chạy `bootstrap()` trước `create()` nên không bắt được.
- id: DW-2.1-3
  source_spec: `_bmad-output/implementation-artifacts/spec-2-1-dem-lan-nhap-sai-ben-vung.md`
  summary: Mật khẩu đúng nhưng lần ghi `recordSuccess()` lỗi thì đĩa vẫn giữ `failCount` đã tăng; tắt app trước lần thử kế tiếp thì lần mở sau thấy số cũ, ở lần thứ 10 sẽ bị chặn (và bị xóa khi 2.3 nối `normalize` → `WipeCoordinator`) dù người dùng đã đăng nhập đúng.
  evidence: Medium, hiếm (lần ghi ngay sau một lần ghi thành công phải lỗi). Spec 2.1 chủ ý cho đăng nhập tiếp khi ghi lỗi. Story 2.3 cần chốt cách xử lý trước khi nối xóa ở `failCount ≥ 10`, ví dụ thử ghi lại khi khóa phiên, hoặc từ chối mở khóa khi không ghi được lần đặt lại.
- id: DW-2.1-4
  source_spec: `_bmad-output/implementation-artifacts/spec-2-1-dem-lan-nhap-sai-ben-vung.md`
  summary: Tài liệu kế hoạch chưa có hai kết quả mới của `unlock`. UX-DR42 (EXPERIENCE.md, epics.md) không có trạng thái S3 cho `UnlockUnavailable` (không ghi được lần thử xuống `guard`), S3 dùng lại `create.unavailable` mà UX chưa chốt. Danh sách `UnlockResult` ở ARCHITECTURE-SPINE.md:414 và epics.md chỉ ghi `success`/`wrongPassword`/`lockedOut`/`corrupt` (spine ghi "vd", không bắt buộc đủ).
  evidence: Low. Code review vòng 2 story 2.1 (blind-hunter). Spec 2.1 (Always) chủ ý dùng `createUnavailable`, nên code đúng spec; chỉ tài liệu UX/kiến trúc lệch. Sửa bằng `docs(ux)`/`docs(planning)`, nên làm trước story 2.5, vì 2.5 thêm một kết quả "thử lại" vào cùng chỗ.

## Deferred from: code review of spec-2-2-thoi-gian-cho-30-phut-khong-phu-thuoc-dong-ho-may.md (2026-11-21)

- id: DW-2.2-1
  source_spec: `_bmad-output/implementation-artifacts/spec-2-2-thoi-gian-cho-30-phut-khong-phu-thuoc-dong-ho-may.md`
  summary: Mở rộng DW-2.1-2. `guard` cũ còn `failCount` 5–9 khi mất `header` thì sau `create()` tài khoản mới vào S3 ở trạng thái chờ 30:00, `unlock` trả `UnlockLockedOut`, và `waitRemaining` neo lại rồi ghi mốc vào `guard` cũ.
  evidence: Code review story 2.2 (edge-case-hunter). Có từ trước: `normalize(hasAccount: false)` nạp `failCount` từ file sót, `create()` không đặt lại (spec 2.1 cấm). Story 2.2 đổi hậu quả từ "ít lượt hơn" sang "bị chờ 30 phút". Sửa cùng DW-2.1-2 (story 2.3/2.4: `LockoutGuard.reset()` khi tạo hoặc xóa, hoặc `normalize` không nạp khi không có `header`).

## Deferred from: code review of spec-2-3-tu-xoa-du-lieu-o-lan-sai-thu-10.md (2026-11-22)

- id: DW-2.3-1
  source_spec: `_bmad-output/implementation-artifacts/spec-2-3-tu-xoa-du-lieu-o-lan-sai-thu-10.md`
  summary: `bootstrap` suy ra "không có tài khoản" từ một lần `FileSystemEntity.type(vault/header)` (Dart đổi mọi lỗi `stat` thành `notFound`), rồi `WipeCoordinator.resumeIfNeeded` dọn im lặng `vault/` và `guard` còn sót.
  evidence: Chưa xác minh (maybe-false, nếu đúng là medium: mất vault không hỏi). Cần kiểm xem `stat` trên `header` có trả `notFound` khi file còn sống hay không (EIO, EACCES, iOS data protection khi máy khóa lúc app khởi động nền). Nếu có, thêm lần kiểm thứ hai (liệt kê `vault/` hoặc mở `header` để đọc) trước khi dọn im lặng, hoặc chỉ dọn khi `wiping`.
- id: DW-2.3-2
  source_spec: `_bmad-output/implementation-artifacts/spec-2-3-tu-xoa-du-lieu-o-lan-sai-thu-10.md`
  summary: Giảm nhẹ DW-2.1-3 chưa đóng hẳn: mật khẩu đúng ở lần thứ 10 mà `recordSuccess()` ghi lỗi thì `unlock` trả `UnlockUnavailable`, RAM về 0 còn đĩa giữ `failCount` 10; tắt app thì lần mở sau xóa vault của người vừa nhập đúng, còn thử lại cùng phiên thì ghi đè đĩa về 1.
  evidence: Medium, hiếm (ghi `guard` lỗi hai lần liên tiếp, ví dụ đầy bộ nhớ). Spec 2.3 chủ ý chỉ chặn đăng nhập ở `failCount` 10 (Design Notes). Hướng sửa: thử ghi lại `guard` khi hủy phiên hoặc giữ RAM ở 10 và chặn mở khóa tới khi khởi động lại; cần quyết định UX cho trạng thái "không ghi được".

## Deferred from: code review of spec-2-3-tu-xoa-du-lieu-o-lan-sai-thu-10.md, vòng 2 (2026-11-22)

- id: DW-2.3-3
  source_spec: `_bmad-output/implementation-artifacts/spec-2-3-tu-xoa-du-lieu-o-lan-sai-thu-10.md`
  summary: Lần thứ 10 mà KDF lỗi (`_deriveKek` trả `null`, ví dụ thiếu bộ nhớ Argon2) → `unlock` trả `UnlockCorrupt`. `failCount` 10 đã được ghi trước KDF nên lần mở sau `bootstrap` trả `BootstrapWiping` và xóa vault dù mật khẩu chưa được kiểm; trong phiên đó S3 chỉ còn `UnlockLockedOut`, không có đường xóa hay thử lại.
  evidence: Medium, hiếm (cần chín lần sai rồi KDF lỗi đúng ở lần 10). Có thật: `account_service.dart` đoạn `kek == null` → `UnlockCorrupt`, `failCount` 10 còn trên đĩa, `resumeIfNeeded` coi `exhausted` là `pending`. Spec 2.3 chủ ý giữ (ranh giới `corrupt`/KDF thuộc story 2.5) và `fr07_fr04_tenth_attempt_with_kdf_failure_stays_corrupt` ghim hành vi này. Hướng sửa ở story 2.5: kết quả "thử lại" riêng cho KDF lỗi, và hoàn lại hoặc không tính lần thử khi KDF lỗi ở `failCount` 10 (cần quyết định có hoàn lượt không, vì FR-5 yêu cầu lần thử vẫn tính khi tắt app).

## Deferred from: code review of spec-2-4-xoa-tao-tai-khoan-moi-khi-quen-mat-khau-chinh.md (2026-11-22)

- id: DW-2.4-1
  source_spec: `_bmad-output/implementation-artifacts/spec-2-4-xoa-tao-tai-khoan-moi-khi-quen-mat-khau-chinh.md`
  summary: hold-confirm-button chưa có hành động thay thế cho VoiceOver/TalkBack: `Semantics(button, label, excludeSemantics)` không có `onTap`/`onLongPress`/custom action, nên người dùng đọc màn hình không xóa được qua S4 (lối còn lại là sai 10 lần).
  evidence: Medium. Có thật: `hold_confirm_button.dart` chỉ nghe `Listener` pointer down/up/cancel và `ux_dr14_semantics_label_marks_button` chỉ kiểm nhãn. Spec 2.4 (Design Notes) chủ ý chưa làm và dặn ghi mục này; planning không có NFR trợ năng cho riêng nút. Hướng sửa: thêm `onLongPress` hoặc custom semantics action chạy cùng 3 giây (hoặc bước xác nhận thứ hai), cần quyết định UX; dialog cũng nên có `Semantics(scopesRoute, namesRoute)` và `barrierLabel`.

## Deferred from: code review of spec-2-4-xoa-tao-tai-khoan-moi-khi-quen-mat-khau-chinh.md, vòng 2 (2026-11-22)

- id: DW-2.4-2
  source_spec: `_bmad-output/implementation-artifacts/spec-2-4-xoa-tao-tai-khoan-moi-khi-quen-mat-khau-chinh.md`
  summary: hold-confirm-button chỉ dừng nhờ `PointerUp`/`PointerCancel`; nếu ứng dụng vào nền giữa lúc giữ mà không có `PointerCancel`, khi quay lại `AnimationController` có thể báo `completed` và `onConfirmed` xóa vault.
  evidence: Medium chưa kiểm chứng (maybe-false). Cần thử trên máy thật iOS và Android với `--flavor dev`: giữ nút, để cuộc gọi hoặc thông báo hệ thống chen vào quá 3 giây, rồi xem `onConfirmed` có chạy khi quay lại không. Nếu có, thêm `WidgetsBindingObserver` hủy lần giữ khi `inactive`/`paused` kèm test.

- id: DW-2.4-3
  source_spec: `_bmad-output/implementation-artifacts/spec-2-4-xoa-tao-tai-khoan-moi-khi-quen-mat-khau-chinh.md`
  summary: màn có từ trước dùng thẳng `PakColors.inkPrimary/inkSecondary` (`CupertinoDynamicColor`) làm màu `TextStyle` mà không `CupertinoDynamicColor.resolve`, nên ở chế độ tối chữ vẫn là màu sáng: `login_screen.dart:269`, `wiping_screen.dart:71`, `create_account_screen.dart:211`, `inline_message.dart:37`, `secret_field.dart:135`.
  evidence: Medium, có thật. Test thử: `Text` với `TextStyle(color: PakColors.inkPrimary)` dưới `CupertinoApp` có `brightness: Brightness.dark` nhận `0xff000000`. Hướng sửa: resolve màu tại chỗ dùng (hoặc một helper trong `features/shared/theme/`) và thêm test độ sáng tối cho từng màn. Bản mới trong `erase_dialog.dart` được sửa ngay ở story 2.4.

## Deferred from: code review of spec-2-5-du-lieu-bi-hong-khong-bao-gio-dan-toi-xoa.md (2026-11-22)

- id: DW-2.5-1
  source_spec: `_bmad-output/implementation-artifacts/spec-2-5-du-lieu-bi-hong-khong-bao-gio-dan-toi-xoa.md`
  summary: KDF hỏng vĩnh viễn (máy không cấp phát đủ bộ nhớ Argon2 cho tham số trong header) thì `unlock` luôn trả `UnlockRetry` (hoàn lượt, không đếm), nên người dùng lặp `login.retry` mãi, không có lối thoát hay thông báo khác.
  evidence: Medium, hiếm (header ghi ở 64 MiB trên máy khác hoặc lúc rảnh, rồi máy chỉ còn ít bộ nhớ lâu dài). Có thật: `account_service.dart` nhánh `kek == null` không đếm số lần `UnlockRetry` liên tiếp. Trước story 2.5 mỗi lần KDF lỗi đều được đếm (`UnlockCorrupt`), nên người dùng không kẹt vô hạn mà đi tới xóa vault ở lần 10 (lỗi `DW-2.3-3`); story 2.5 đổi "xóa có giới hạn" thành "lặp không giới hạn". Cần quyết định UX: đếm lần liên tiếp rồi hiện thông báo khác (gợi ý khởi động lại máy hoặc dùng "Xóa & Tạo tài khoản mới"), hay giữ nguyên. Gộp với kiểm KDF trên máy yếu của story 7.1.

- id: DW-2.5-2
  source_spec: `_bmad-output/implementation-artifacts/spec-2-5-du-lieu-bi-hong-khong-bao-gio-dan-toi-xoa.md`
  summary: `AccountService.maxDataFileBytes` (16 MiB) chỉ là trần đọc; chưa có trần ghi cho `cards`/`recent`, nên vault vượt 16 MiB ghi được rồi bị `UnlockCorrupt` vĩnh viễn khi mở.
  evidence: Medium chưa xảy ra: chưa có đường ghi `cards` (Epic 3) hay import (Epic 6: ≤ 10 000 card, mỗi chuỗi ≤ 64 KiB, nên về lý thuyết vượt 16 MiB). Con số 16 MiB do story 2.5 tự chọn, không có căn cứ AD/NFR. Khi dựng Epic 3 (ghi `cards`) và Epic 6 (import) phải chặn ghi vượt `maxDataFileBytes` hoặc nâng trần có căn cứ, kèm test "ghi được thì mở được".

- id: DW-2.5-3
  source_spec: `_bmad-output/implementation-artifacts/spec-2-5-du-lieu-bi-hong-khong-bao-gio-dan-toi-xoa.md`
  summary: Lỗi I/O tạm thời khi đọc `header`/`cards`/`recent` (EIO, khóa file, iOS data protection khi máy khóa) hiện thành `UnlockCorrupt` (`login.corrupt` gợi ý "Xóa & Tạo tài khoản mới"), không tách khỏi file thật sự hỏng.
  evidence: Medium, có từ trước story 2.5 (`readAsBytes` ném cũng ra `UnlockCorrupt`); `_readCapped` giữ nguyên hành vi. Không tự xóa gì (người dùng tự chọn), nhưng nên có kết quả "đọc không được lúc này" kiểu `UnlockRetry`/`UnlockUnavailable` cho lỗi I/O khác `notFound`. Liên quan `DW-2.3-1` (cùng nghi vấn `stat`/đọc trả lỗi khi file còn sống). Cần thử trên máy thật iOS khóa máy lúc app khởi động nền.

## Deferred from: code review of spec-2-5-du-lieu-bi-hong-khong-bao-gio-dan-toi-xoa.md, vòng 2 (2026-11-22)

- id: DW-2.5-4
  source_spec: `_bmad-output/implementation-artifacts/spec-2-5-du-lieu-bi-hong-khong-bao-gio-dan-toi-xoa.md`
  summary: Hệ điều hành giết app giữa lúc Argon2 đang chạy (iOS jetsam, Android LMK vì thiếu bộ nhớ) xảy ra sau `recordAttempt` và trước `revertAttempt`, nên lần thử vẫn tính là sai. Mười lần bị giết như vậy dẫn tới xóa vault dù chưa kiểm mật khẩu nào.
  evidence: Medium (unverified về tần suất), có từ trước story 2.5 và do FR-5 yêu cầu ("tắt app trước khi hoàn lượt vẫn tính là sai", test `fr06_tc06_app_killed_before_revert_still_counts`). Không phân biệt được "bị giết" với "tắt app để né đếm" nếu không có marker "lần thử đang chờ KDF" mà `bootstrap` xử lý khác, tức phải đổi FR-5 và spec 2.5 (Never: không sửa `bootstrap`). Cần kiểm trên máy yếu thật xem Argon2 64 MiB có bị giết không rồi mới quyết định. Gộp với kiểm KDF trên máy yếu của story 7.1 (như `DW-2.5-1`).

- Ghi chú vòng 2: các phát hiện lặp lại `DW-2.5-1` (lặp `login.retry` không giới hạn), `DW-2.5-2` (trần 16 MiB một chiều) và `DW-2.5-3` (lỗi I/O thành `corrupt`) đã có mục, không tạo mục trùng.
