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
- AC1 story 1.15: job `integration-ios` fail/bị hủy ở các lần chạy pha A/B (chỉ 3/4 job xanh). Lý do hoãn: lỗi runner macOS, không do thay đổi của 1.15. Cần một lần chạy CI xanh đủ 4 job để xác nhận.
