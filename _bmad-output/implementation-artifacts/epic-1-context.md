# Epic 1 Context: Tạo tài khoản, đăng nhập và khóa vault an toàn

<!-- Compiled from planning artifacts. Edit freely. Regenerate with compile-epic-context if planning docs change. -->

## Goal

Người dùng cài PAK Manager, tạo tài khoản bằng mật khẩu chính đạt chuẩn, đăng nhập vào khung 3 tab và khóa vault, kể cả tự khóa khi chạy nền quá lâu hoặc hết hạn phiên. Dữ liệu được mã hóa trên máy, không nằm trong backup của OS, và app không có kết nối mạng nào. Epic này cũng dựng toàn bộ nền dùng chung cho các epic sau: cấu trúc dự án và CI, theme token, ARB vi/en, `ContentColumn`, `ModalPresenter`, toast, `SecretField`, `AtomicFileWriter`, codec `header`/`settings`, `VaultSession`, `SessionController`, Pigeon đồng hồ/backup/fsync. Story 1.10–1.14 được thêm sau để xử lý nợ kỹ thuật từ review: lùi KDF về sàn, ghim chuỗi cung ứng CI, kiểm âm cổng CI, integration test native, flavor dev iOS và ghi công giấy phép. Ở epic này nhập sai chỉ báo "Sai mật khẩu", chưa đếm lần.

## Stories

- Story 1.1: Khởi tạo dự án Flutter theo Structural Seed và cổng CI
- Story 1.2: Thư mục dữ liệu riêng, ghi nguyên tử và loại khỏi backup
- Story 1.3: Giao diện sáng/tối, hai ngôn ngữ và cài đặt mặc định
- Story 1.4: Mã hóa vault bằng khóa hai tầng và Argon2id
- Story 1.5: Luật mật khẩu chính và đánh giá độ mạnh
- Story 1.6: Tạo tài khoản và vào khung 3 tab
- Story 1.7: Đăng nhập bằng mật khẩu chính
- Story 1.8: Khóa Vault và xóa dữ liệu giải mã khỏi bộ nhớ
- Story 1.9: Tự khóa khi chạy nền và giới hạn phiên
- Story 1.10: Hiệu chỉnh KDF lùi về sàn khi lần thử đầu lỗi
- Story 1.11: Ghim chuỗi cung ứng và Stack trong CI
- Story 1.12: Kiểm âm cho các cổng CI
- Story 1.13: Integration test cho API native
- Story 1.14: Flavor dev cho iOS và ghi công giấy phép blocklist

## Requirements & Constraints

- Chưa có tài khoản: Login chỉ có "Tạo tài khoản"; tạo cần nhập mật khẩu hai lần, kèm cảnh báo rõ rằng quên mật khẩu chính là mất hết dữ liệu. Không có bất kỳ cơ chế khôi phục nào (không gợi ý, câu hỏi bảo mật hay khóa khôi phục).
- Luật mật khẩu chính: 15–128 ký tự ASCII in được (kể cả khoảng trắng); không bắt buộc loại ký tự; từ chối mật khẩu trong blocklist offline, chuỗi lặp một ký tự hoặc dãy tuần tự; khi gõ hiện một dòng chữ độ mạnh Low/Medium/High.
- Đã có tài khoản: Login hiện "PAK Manager", ô mật khẩu, nút "Đăng nhập" bị vô hiệu khi dưới 15 ký tự; đúng thì vào tab Quản lý mật khẩu (mặc định trong 3 tab: Quản lý mật khẩu, Tạo mật khẩu, Cài đặt).
- Giới hạn phiên tuyệt đối (mặc định 10 phút) và Autolock khi chạy nền (mặc định 3 phút), độc lập nhau, cái nào tới trước thì khóa. Đang ghi dữ liệu thì khóa sau khi ghi xong/hoàn tác; thao tác chưa bắt đầu ghi thì bị hủy. Lock Vault = Sign out, khóa ngay về Login.
- Khi khóa, bỏ mọi tham chiếu tới khóa và dữ liệu giải mã, giữ thời gian bản rõ trong RAM ngắn nhất có thể.
- Toàn bộ vault mã hóa trên máy; mở khóa trên máy yếu nhất ~1 giây, tối đa 2 giây.
- Không mạng: manifest Android release không có `INTERNET` (kiểm tự động khi build); không SDK analytics/quảng cáo/crash. Dữ liệu loại khỏi iCloud/Google Backup và chuyển máy. Gỡ app xóa sạch mọi thứ.
- Mọi ô mật khẩu tắt autofill/lưu mật khẩu của OS, tự sửa, gợi ý và học từ của bàn phím.
- Mọi thao tác ghi nguyên tử; tắt đột ngột không làm hỏng vault.
- iOS 15.0+, Android minSdk 24; điện thoại và tablet; sáng/tối; đủ chuỗi English và Tiếng Việt.

## Technical Decisions

- Flutter 3.47.8 / Dart 3.13, greenfield `flutter create` theo Structural Seed (`lib/core`, `lib/services`, `lib/platform`, `lib/features`, `lib/l10n`, `pigeons/`, `assets/`, `tool/`, `test/`, `docs/`, `.github/workflows/`). Dependency chỉ từ bảng Stack, ghim phiên bản chính xác; thêm dependency phải cập nhật spine kèm rà soát network code.
- Phụ thuộc một chiều features → services → core; `lib/core` là Dart thuần (chỉ `core/io/` dùng `dart:io`); features chỉ import `core/model`, `core/policy`, `core/search`; platform chỉ qua port trong `core/ports`. `tool/check_imports.dart` thực thi trong CI. Widget từ `cupertino_ui`, cấm `flutter/cupertino.dart`/`material.dart`; chỉ `CupertinoIcons`. Riverpod viết tay, không codegen.
- Lỗi qua kiểu kết quả sealed (vd `UnlockResult`), không ném exception qua ranh giới lớp; UI ánh xạ sang key microcopy.
- Khóa hai tầng: DEK 32 byte ngẫu nhiên; KEK = Argon2id13 (`pwhash.callRaw`, p=1) chạy ngoài UI isolate. Hiệu chỉnh khi tạo tài khoản: khởi điểm m=64 MiB t=3, mục tiêu ~1 giây, trần 2 giây, sàn m=19 MiB t=2; lần thử đầu lỗi thì thử lại đúng một lần ở sàn, không bao giờ dưới sàn, KEK không dùng phải dispose. Tham số ngoài [m 19–128 MiB, t 2–10] → `corrupt` trước KDF. `kcv` = BLAKE2b 16 byte khóa KEK trên `PAK-KCV-v1`, so hằng thời gian; `checksum` = BLAKE2b-256 trên header.
- `vault/` gồm `header`, `cards`, `recent`, `draft`; mỗi file JSON mã hóa XChaCha20-Poly1305 bằng DEK, nonce mới mỗi lần ghi, AD `PAK-VAULT/<loại>/v<N>`. Tạo tài khoản: dọn `vault/` → ghi `cards`, `recent` rỗng → ghi `header` cuối (điểm commit). Codec duy nhất mỗi file trong `lib/core/format/`; little-endian, UTC epoch ms, thiếu key/sai kiểu → `corrupt`; golden test cho `header`, `settings`.
- File app dưới `ApplicationSupport/pak/`. `AtomicFileWriter`: ghi `.tmp` → fsync → rename → `fsyncDirectory`; không tạo thư mục cha; khởi động dọn `*.tmp`.
- `AccountService` là lối vào duy nhất: `bootstrap()`, `create()`, `unlock()` (trả `VaultSession` mới), `verify()`. `VaultSession` là chủ duy nhất của DEK và bản rõ, I/O qua hàng đợi tuần tự, sau `lock()` vô hiệu vĩnh viễn. Bản rõ dạng `Uint8List` ghi đè 0 sau dùng; model bí mật override `toString()`. Ngẫu nhiên chỉ từ libsodium `randombytes`.
- `SessionController` là nguồn duy nhất quyết định khóa; mọi hạn đo bằng `ClockPort.monotonicMs` (tính cả lúc ngủ), `Timer` chỉ để đánh thức; "vào nền" = `hidden`/`paused` đầu tiên sau `resumed`. Trình tự khóa: flush bản nháp → chờ ghi → hủy thao tác chưa ghi → `VaultSession.lock()` → tăng epoch và thay cây UI. Mọi `await` trên port so lại epoch. OS kill = khóa, không state restoration.
- `SettingsStore` chủ duy nhất của `settings`, nạp trước frame đầu, gom ghi 300 ms, file hỏng dùng mặc định. `PasswordPolicy` (core) kiểm tra theo thứ tự: không ASCII → độ dài → blocklist → lặp/tuần tự; độ mạnh dùng `zxcvbnm` (0–2 Low, 3 Medium, 4 High). Blocklist: Bloom filter ≤ 2 MB, FP ≤ 0,1% từ SecLists (ghim commit), kèm giấy phép MIT.
- Pigeon một `@HostApi` đồng bộ, bốn nhóm: đồng hồ, clipboard, loại khỏi backup, `fsyncDirectory`; iOS đăng ký qua `FlutterImplicitEngineDelegate`. Không ghi Keychain/Keystore. iOS đặt `isExcludedFromBackup` trên `pak/` mỗi lần khởi động; Android `allowBackup=false` + `dataExtractionRules`/`fullBackupContent`.
- `SessionGate` trong `CupertinoApp.builder`, cây sau đăng nhập bọc `KeyedSubtree` key = epoch; khóa = thay cả cây. `CupertinoTabScaffold` navigator riêng mỗi tab; mọi modal qua `ModalPresenter`.
- Bảo mật repo/CI: secret chỉ trong GitHub Secrets trên `main`/tag; không log bí mật; cấm `print(`; release nuốt lỗi. App ID `io.github.truongthanhnam.pakmanager`, flavor `dev` thêm `.dev` (cả Android và iOS). Mỗi PR: phân tích tĩnh, `check_imports`, kiểm Pigeon đã sinh, unit + widget test, build Android release (không `INTERNET`, `.so` 64-bit căn 16 KB), build iOS `--no-codesign`. Action ghim SHA, runner ghim phiên bản, kiểm revision Flutter, Gradle có checksum; cổng CI phải có test kiểm âm. Test dùng `flutter_test` + fake tự viết, tên test gắn FR.

## UX & Interaction Patterns

- Color token light/dark một nơi trong `features/shared/theme/`; không màu đỏ/trạng thái — lỗi, độ mạnh chỉ bằng chữ `ink-secondary`. Font hệ thống, phẳng, một màu nhấn teal-green; Android vẽ dáng iOS, không Material/ripple.
- `ContentColumn` tối đa 672 pt; điện thoại khóa dọc; `textScaler` kẹp ≤ 1,3.
- Login S1/S3: không nav-bar, "PAK Manager" large-title; S1 chỉ có "Tạo tài khoản" tại vị trí ô mật khẩu. S2 (màn push): cảnh báo → ô mật khẩu chính → dòng độ mạnh/inline-message → ô nhập lại → nút.
- `inline-message` một dòng footnote dưới field, ưu tiên không ASCII → độ dài → phổ biến → lặp/tuần tự → không khớp ("không khớp" chỉ hiện khi ô nhập lại đủ độ dài). Ký tự không ASCII không bị chặn/xóa (giữ Telex/VNI) nhưng vô hiệu nút chính.
- Khi chạy KDF: spinner trên nút, chặn bấm lặp và chặn Back. Khóa gỡ mọi sheet/dialog, về S3, không báo lý do.
- Mọi chuỗi qua gen-l10n (`app_vi.arb`, `app_en.arb`), key = key microcopy camelCase; giọng ngắn gọn, xưng "bạn", không dấu chấm than. Ngôn ngữ mặc định theo máy, giao diện mặc định Theo hệ thống.

## Cross-Story Dependencies

- 1.1 là nền cho mọi story; 1.2 (lưu trữ nguyên tử, Pigeon) → 1.4 (crypto/vault) → 1.6/1.7 (tạo tài khoản, đăng nhập) → 1.8 (khóa) → 1.9 (tự khóa/giới hạn phiên). 1.3 cung cấp theme, ARB và `SettingsStore`; 1.5 cung cấp `PasswordPolicy` cho 1.6.
- 1.10 sửa hiệu chỉnh KDF của 1.4 (ưu tiên cao nhất trong nhóm bổ sung); 1.11–1.13 củng cố CI của 1.1/1.2; 1.13 kiểm Pigeon và cờ backup của 1.2; 1.14 thêm flavor iOS và ghi công giấy phép blocklist của 1.5.
- Epic 2 xây `LockoutGuard`, `WipeCoordinator` và đếm sai trên luồng unlock của epic này; Epic 5 thêm UI chỉnh các cài đặt mà Epic 1 chỉ dùng mặc định.
