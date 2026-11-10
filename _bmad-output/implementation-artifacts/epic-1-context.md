# Epic 1 Context: Tạo tài khoản, đăng nhập và khóa vault an toàn

<!-- Compiled from planning artifacts. Edit freely. Regenerate with compile-epic-context if planning docs change. -->

## Goal

Người dùng cài PAK Manager (app quản lý mật khẩu offline, Flutter cho iOS và Android), tạo tài khoản bằng mật khẩu chính đạt chuẩn NIST, đăng nhập vào khung 3 tab và khóa vault, thủ công hoặc tự động khi chạy nền quá lâu hay hết hạn phiên. Vault được mã hóa trên máy, không nằm trong backup của OS, app không có kết nối mạng. Epic này dựng toàn bộ nền dùng chung cho các epic sau: cấu trúc dự án và CI, theme token, ARB vi/en, component shared, `AtomicFileWriter`, codec `header`/`settings`/vault, `VaultSession`, `SessionController`, Pigeon (đồng hồ/backup/fsync). Story 1.10–1.14 được thêm sau để xử lý nợ kỹ thuật từ review: lùi KDF về sàn, ghim chuỗi cung ứng CI, kiểm âm cổng CI, integration test native, flavor dev iOS và ghi công giấy phép. Ở epic này nhập sai chỉ báo "Sai mật khẩu", chưa đếm số lần (việc đếm thuộc Epic 2).

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

- **Tạo tài khoản:** máy chưa có tài khoản thì Login chỉ có "Tạo tài khoản". Người dùng đặt mật khẩu chính và nhập lại. Trước khi tạo phải cảnh báo rõ: quên mật khẩu chính là mất toàn bộ dữ liệu. Không có bất kỳ cơ chế khôi phục nào (quên mật khẩu, gợi ý, câu hỏi bảo mật, khóa khôi phục).
- **Luật mật khẩu chính:** dài 15–128; chỉ ASCII in được (0x20–0x7E, kể cả khoảng trắng); không bắt buộc chữ hoa, số hay ký tự đặc biệt; từ chối mật khẩu có trong blocklist offline; từ chối chuỗi lặp một ký tự hoặc dãy tuần tự. Lỗi báo theo thứ tự: không ASCII → độ dài → phổ biến → lặp/tuần tự. Khi gõ, hiện một dòng chữ độ mạnh Low/Medium/High (zxcvbnm: 0–2/3/4), không vẽ thanh. Cách tính này tách biệt với độ mạnh theo entropy của generator.
- **Đăng nhập:** nút "Đăng nhập" vô hiệu khi < 15 ký tự hoặc có ký tự không ASCII, và chuỗi đó không bao giờ được gửi đi kiểm tra. Đúng thì vào tab Quản lý mật khẩu. Sai thì báo "Sai mật khẩu." và giữ nội dung ô. Header hỏng, hoặc mật khẩu đúng nhưng giải mã lỗi, thì báo "Dữ liệu bị hỏng" và không xóa gì.
- **Khóa:** Lock Vault khóa ngay, không hỏi, đồng thời là Sign out (không có nút Sign out riêng). Giới hạn phiên tuyệt đối tính từ lúc đăng nhập (mặc định 10 phút), khóa cả khi đang thao tác, không cảnh báo trước. Autolock khi chạy nền quá hạn (mặc định 3 phút). Hai điều kiện độc lập, cái nào đến trước thì khóa theo cái đó. Đang ghi thì khóa sau khi ghi xong hoặc hoàn tác; thao tác chưa bắt đầu ghi thì bị hủy.
- **Bảo mật:** toàn bộ vault được mã hóa, chỉ giải mã sau khi đăng nhập đúng. Lấy file dữ liệu ra khỏi máy thì không đọc được gì. Mở khóa mất ~1 giây, tối đa 2 giây trên máy yếu nhất. Khi khóa, bỏ mọi tham chiếu tới khóa và dữ liệu giải mã.
- **Offline và riêng tư:** không có kết nối mạng, không SDK analytics/quảng cáo/crash reporting. Manifest Android release không được chứa `INTERNET` (CI kiểm). Dữ liệu bị loại khỏi iCloud/Google Backup và chuyển máy. Gỡ app xóa sạch: không ghi gì vào Keychain/Keystore.
- **Ô mật khẩu:** tắt đề nghị lưu mật khẩu của OS, tự sửa, gợi ý từ và học từ của bàn phím.
- **Độ bền:** mọi thao tác ghi đều nguyên tử; tắt đột ngột không làm hỏng vault.
- **Nền tảng:** iOS 15.0+, Android minSdk 24; điện thoại và tablet; sáng/tối; đủ chuỗi English và Tiếng Việt.
- Tab bar 3 tab (Quản lý mật khẩu, Tạo mật khẩu, Cài đặt), mặc định Quản lý mật khẩu.

## Technical Decisions

- **Stack ghim (chỉ được dùng các package này):** Flutter 3.47.8 stable (Dart 3.13); Android compileSdk/targetSdk 36; `cupertino_ui` 1.1.4, `cupertino_icons` 2.0.0, `sodium` 4.1.2 (`SodiumSumoInit`), `flutter_riverpod` 3.4.3 (viết tay, không codegen), `pigeon` 29.0.11 (dev), `zxcvbnm` 1.1.1, `path_provider` 2.1.6, `share_plus` 13.3.1, `file_selector` 1.1.0, `flutter_localizations`, `flutter_test`. Không dùng starter template; tạo bằng `flutter create`. App ID `io.github.truongthanhnam.pakmanager`, flavor `dev` thêm hậu tố `.dev`.
- **Phân lớp:** features → services → core; platform chỉ gọi qua interface trong `core/ports`. `lib/core` là Dart thuần, chỉ `lib/core/io/` được import `dart:io`. `lib/features` chỉ import `core/model`, `core/policy`, `core/search`. Cấm `package:flutter/material.dart`, `package:flutter/cupertino.dart`, `material_ui`, `HttpClient`/`Socket`, `package:http`, `dart:math Random`. `tool/check_imports.dart` (không dependency, có test) chặn các vi phạm này trong CI. Lint khai báo trực tiếp trong `analysis_options.yaml` và cấm `print(` trong `lib/`.
- **CI (GitHub Actions):** phân tích tĩnh, `check_imports`, unit + widget test, kiểm code Pigeon sinh ra đã cập nhật, build release Android (fail nếu có `INTERNET` hoặc `.so` không căn 16 KB), build iOS `--no-codesign` trên macOS. Workflow PR không truy cập secret. Ở bản release, `debugPrint` không làm gì; `FlutterError.onError` và `PlatformDispatcher.instance.onError` nuốt lỗi. Không log bí mật.
- **Lưu trữ:** mọi file nằm dưới `ApplicationSupport/pak/` (`vault/{header,cards,recent,draft}`, `guard`, `settings`, `tmp/`). iOS đặt `isExcludedFromBackup` trên `pak/` ở mỗi lần khởi động, trước mọi I/O. Android: `allowBackup=false`, `dataExtractionRules` loại mọi domain cho `cloud-backup` và `device-transfer`, kèm `fullBackupContent`.
- **`AtomicFileWriter`:** ghi `<tên>.tmp` cùng thư mục → fsync → rename → `fsyncDirectory`. Không bao giờ tạo thư mục cha. Khởi động thì xóa mọi `*.tmp` còn sót. Mỗi thao tác nghiệp vụ commit đúng một file.
- **Pigeon:** một API duy nhất `pigeons/platform_api.dart` (`@HostApi` đồng bộ, kênh mặc định). Epic này dùng các nhóm đồng hồ (`bootId`: Android `BOOT_COUNT`, iOS `kern.bootsessionuuid`; `monotonicMs`: `elapsedRealtime`/`mach_continuous_time`), backup và `fsyncDirectory`. iOS đăng ký trong `FlutterImplicitEngineDelegate`.
- **Crypto:** DEK 32 byte ngẫu nhiên, sinh một lần. KEK = Argon2id13 (`pwhash.callRaw`, p=1), chạy qua `Sodium.runIsolated`, trả `SecureKey`. Hiệu chỉnh trên máy: khởi điểm m=64 MiB, t=3, mục tiêu ~1 giây, trần 2 giây, sàn m=19 MiB, t=2; lần thử đầu lỗi (`null` hoặc ném) thì thử lại đúng một lần ở sàn và nhận kết quả, không bao giờ dưới sàn, KEK không trả về phải dispose. Tham số ngoài [m 19–128 MiB, t 2–10] bị từ chối trước KDF. Mọi số ngẫu nhiên lấy từ `randombytes` qua `RandomSource`.
- **Header (nhị phân, little-endian):** `PAKV`[4] · version u16 · kdfAlg u8 · opslimit u32 · memlimit u64 · salt[16] · wrapNonce[24] · wrappedDek[48] · kcv[16] · checksum[32]. AD khi bọc DEK là các byte từ magic đến hết salt. `kcv` = BLAKE2b-16 khóa KEK trên `PAK-KCV-v1`; `checksum` = BLAKE2b-256 không khóa trên mọi byte trước nó. Có golden test.
- **File dữ liệu:** nonce[24] · ciphertext‖tag (XChaCha20-Poly1305 bằng DEK), nonce mới mỗi lần ghi, AD `PAK-VAULT/<loại>/v1`. `cards` = `{"v":1,"cards":[{id,title,username,password,note,createdAt}]}`, `recent` = `{"v":1,"items":[{password,recordedAt}]}`. Note rỗng là `""`; id là UUIDv4 chữ thường; thời gian là UTC epoch ms; mọi key bắt buộc. Thiếu key, sai kiểu, `v` lạ hoặc AEAD lỗi → `corrupt` không kèm thông điệp. Mỗi file chỉ có một codec trong `lib/core/format/`. Fixture `test/fixtures/vault/v1/` được sinh bằng script trong `tool/fixtures/`.
- **Mở khóa:** (1) đọc header; sai kích thước/magic/version, checksum lệch hoặc tham số ngoài khoảng → `corrupt`, không chạy KDF. (2) Chạy KDF. (3) So `kcv` bằng phép so hằng thời gian; lệch → `wrongPassword`. (4) Mở bọc DEK và giải mã `cards`/`recent` vào RAM; lỗi → `corrupt`. Có `header` mà thiếu `cards`/`recent` → `corrupt`.
- **Tạo tài khoản:** dọn `vault/` → tạo thư mục → ghi `cards` và `recent` rỗng → ghi `header` cuối cùng (điểm commit). Tắt app trước khi ghi header thì lần mở sau vẫn ở S1.
- **`AccountService`:** lối vào duy nhất cho `bootstrap()`, `create()`, `unlock()` (trả `VaultSession` mới) và `verify()`. Kết quả là kiểu sealed `UnlockResult` (`success`, `wrongPassword`, `corrupt`); không ném exception qua ranh giới lớp. UI ánh xạ kết quả sang key microcopy.
- **`VaultSession`:** mỗi lần mở khóa tạo một instance mới. Đây là chủ duy nhất của DEK và dữ liệu giải mã; mọi I/O đi qua một hàng đợi tuần tự. Sau `lock()`, mọi method trả `locked` và không làm I/O.
- **`SessionController`:** nơi duy nhất gọi `lock()`. Mọi hạn đo bằng `ClockPort.monotonicMs`; `Timer` chỉ để đánh thức, không bao giờ dùng `Stopwatch`/`DateTime.now()` làm nguồn sự thật. "Vào nền" = lần đầu nhận `hidden` (hoặc `paused`) sau `resumed`; `inactive` không tính. Khi `resumed` thì gọi `evaluate()`. Trình tự khóa: flush bản nháp → chờ ghi xong/hoàn tác → hủy thao tác chưa ghi → `VaultSession.lock()` → xóa clipboard nếu khóa ở tiền cảnh → tăng epoch. Bước nào chưa có tính năng thì để hook rỗng. Kết quả `await` trên port sau khi epoch đổi bị bỏ. Đổi cài đặt thời gian có hiệu lực từ lần đếm kế tiếp. OS kill = khóa, không dùng state restoration.
- **`SettingsStore`:** chủ duy nhất của file `settings` (`{"v":1,language,appearance,autolockMin,sessionMin,clipboardMin,gen{length,upper,lower,digits,special},lastExportAt}`). Mặc định: `language=null` (máy tiếng Việt → vi, khác → en), `appearance=system`, 3/10/3 phút, gen độ dài 16 với mọi loại bật. Trường thiếu/sai dùng mặc định riêng; file hỏng dùng toàn bộ mặc định, không chặn Login. Nạp trước frame đầu tiên, giữ một bản trong RAM, ghi qua hàng đợi gom 300 ms. Có golden test.
- **Vòng đời bản rõ:** bản rõ chỉ nằm trong `VaultSession` hoặc provider/State thuộc cây UI của phiên. Ghi đè 0 lên `Uint8List` bản rõ ngay sau khi dùng. Model chứa bí mật phải che giá trị trong `toString()`.
- **Blocklist:** nguồn SecLists ghim commit trong `tool/blocklist/SOURCE`. Chỉ giữ chuỗi ASCII in được dài 15–128, chuyển chữ thường, đóng gói Bloom filter ≤ 2 MB, dương tính giả ≤ 0,1%, tại `assets/blocklist.bloom`; định dạng mô tả trong `assets/blocklist.FORMAT.md`. `PasswordPolicy` (`core/policy`) là nơi duy nhất kiểm tra mật khẩu.
- **Khung UI:** `CupertinoApp.builder` chứa `SessionGate`. Gate hiện S1–S3 khi chưa mở khóa, hoặc cây sau đăng nhập bọc `KeyedSubtree` (key = epoch) gồm `CupertinoTabScaffold` với navigator riêng mỗi tab. Khóa = thay cả cây; cấm push S3 lên UI cũ. Mọi sheet/dialog mở qua `ModalPresenter` (tối đa 2 tầng sheet, chính sách Back khai báo theo từng kiểu, Android dùng `PopScope`). Toast host nằm trong `Overlay`, bị xóa khi khóa. Locale và theme đọc từ `SettingsStore` phía trên `CupertinoApp`.
- **Quy ước:** file `snake_case.dart`, provider `xxxProvider`, thư mục feature `auth`/`cards`/`generator`/`settings`/`transfer`/`shared`. Tên test gắn FR (vd `fr02_repeated_char_rejected`). Test chỉ dùng fake tự viết, không thư viện mock, chỉ dữ liệu giả.

## UX & Interaction Patterns

- **Dáng iOS trên cả Android:** không Material, không ripple, chuyển cảnh mặc định của iOS. Chỉ dùng `CupertinoIcons`; icon tab (chìa khóa, đũa phép, núm xoay) vẽ bằng `CustomPainter` trong `features/shared/icons/`. Điện thoại khóa dọc; tablet xoay mọi hướng, nội dung nằm trong `ContentColumn` (căn giữa, tối đa 672 pt). `textScaler` kẹp tối đa 1,3.
- **Theme:** mọi color token trong DESIGN.md có cặp light/dark, resolve theo `CupertinoTheme.brightnessOf`. Không có màu đỏ/destructive hay màu trạng thái: lỗi và độ mạnh chỉ là chữ `ink-secondary`. Có 11 token chữ dùng font hệ thống, token spacing (lưới 4pt) và token bo góc. Elevation phẳng: chỉ slider/công tắc, sheet, picker, alert và FAB có bóng.
- **Chuỗi:** dùng `flutter gen-l10n`; key ARB = key microcopy trong EXPERIENCE.md đổi sang camelCase (vd `create.warning` → `createWarning`). Không hard-code chuỗi; có test hai file ARB cùng tập key. Giọng văn ngắn gọn, trung tính, xưng "bạn", không dấu chấm than, không emoji.
- **S1/S3 (Login):** "PAK Manager" large-title căn giữa, cách status bar ~120, không nav-bar. S1 chỉ có nút "Tạo tài khoản" đặt đúng chỗ ô mật khẩu của S3. S3 có ô mật khẩu không placeholder (cách tên 48), inline-message cách ô 6, nút "Đăng nhập" cách 24. Khi đang kiểm tra, nút hiện spinner, ô và nút bị khóa.
- **S2 (Tạo tài khoản, màn push, chỉ có chevron back):** `create.warning` → ô `create.field.main` → strength-meter rồi inline-message → ô `create.field.confirm` → nút. `pw.mismatch` chỉ hiện khi ô nhập lại dài bằng ô đầu. Nút chỉ bật khi mật khẩu hợp lệ và hai ô khớp. Return chuyển sang ô kế; ở ô cuối thì gửi nếu nút đang bật.
- **Ký tự không ASCII (bộ gõ Telex/VNI):** không chặn phím, không tự xóa. Hiện `pw.nonAscii` và vô hiệu nút chính; xóa ký tự đó thì thông báo ẩn.
- **`SecretField`:** không autofill hints, `autocorrect=false`, `enableSuggestions=false`, `enableIMEPersonalizedLearning=false`, không có Copy/Cut nhưng vẫn Dán được, gọi `controller.clear()` trong `dispose()`. Không dùng `CupertinoTextField` trực tiếp cho bí mật.
- **Nút:** `button-primary` cao 48 với ba trạng thái thường / vô hiệu / bận (spinner on-accent, chặn bấm lặp); `button-text` chữ accent. Tab bar cao 49, chọn = accent; bấm tab đang chọn thì cuộn về đầu.
- **Cài đặt (epic này):** chỉ có khối "Khóa Vault", là button-text trong ô riêng (inset-grouped). Các khối khác thêm ở epic sau.
- **Khóa:** gỡ mọi sheet/dialog, về S3, không báo lý do. Quay lại trong thời hạn autolock thì giữ nguyên màn hình và trạng thái đã rời.

## Cross-Story Dependencies

- 1.1 là nền cho mọi story. 1.2 (port, `AtomicFileWriter`, Pigeon) là tiền đề cho 1.3, 1.4 và 1.9. 1.4 và 1.5 là tiền đề cho 1.6. 1.6 dựng `SessionGate`, khung tab và component shared mà 1.7 và 1.8 dùng. 1.8 dựng trình tự khóa và epoch mà 1.9 dùng.
- **Epic 2** bổ sung `LockoutGuard` (ghi trước KDF, sau khi `kcv` khớp thì reset), `WipeCoordinator`, `lockedOut` trong `UnlockResult`, các bước trong `bootstrap()`, dòng số lần thử và trạng thái S4/S5. Vì vậy code `unlock`/`bootstrap` ở epic này phải chừa chỗ cho các bước đó.
- **Các epic sau** lấp hook rỗng trong trình tự khóa: Epic 3 thêm flush bản nháp và xóa clipboard, Epic 5 và Epic 6 thêm thao tác ghi đang chạy. Epic 5 thêm picker cho 3 cài đặt thời gian, ngôn ngữ và giao diện (epic này chỉ dùng giá trị mặc định).
