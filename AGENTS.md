<!-- bmad:context -->
<!-- Verified 2026-11-19 against 33520b3. Managed by bmad-project-context; edits inside this block are replaced on refresh. Keep anything you want preserved outside the markers. -->

## passwordmanager

PAK Manager: trình quản lý mật khẩu offline cho iOS và Android, Flutter + `cupertino_ui`, Riverpod viết tay, libsodium (`sodium`). App nằm trong `pak_manager/`. Kế hoạch (PRD, UX, `epics.md`, `ARCHITECTURE-SPINE.md`) ở `_bmad-output/planning-artifacts/`; sprint status, spec story và `deferred-work.md` ở `_bmad-output/implementation-artifacts/`.

## Policy

- Không commit hay push thẳng lên `main`; mọi thay đổi đi qua branch và PR.
- Không sửa tay file sinh; sửa nguồn rồi chạy generator và commit cả kết quả, vì CI fail khi lệch:
  - `lib/platform/platform_api.g.dart`, `PlatformApi.g.kt`, `PlatformApi.g.swift` ← `pigeons/platform_api.dart`, chạy `dart run pigeon --input pigeons/platform_api.dart`
  - `lib/l10n/app_localizations*.dart` ← file `.arb`, chạy `flutter gen-l10n`
  - `test/fixtures/vault/v1/*` ← `dart run tool/fixtures/gen_vault_v1.dart`
  - `assets/blocklist.*` ← `dart tool/blocklist/build_blocklist.dart` (cần mạng)

## Where things are

- Sửa `lib/core/crypto/`, `lib/services/` hay vòng đời phiên: đọc trước AD tương ứng trong `ARCHITECTURE-SPINE.md` (AD-3 `VaultSession`, AD-5 KDF, AD-9 khóa, AD-22 bản rõ).
- Thêm hay nâng dependency, action CI, Gradle, Flutter: làm theo mục "Chuỗi cung ứng" trong `pak_manager/README.md`.
- Provider gốc: `pak_manager/lib/features/shared/providers.dart`, override ở `lib/main.dart`.

## Running and verifying

- Chạy mọi lệnh `flutter`/`dart` từ `pak_manager/`; test công cụ đọc đường dẫn tương đối từ đó.
- Chạy và build cục bộ luôn kèm `--flavor dev`. Trên iOS, `flutter run` không flavor dùng bundle id prod và ghi đè app thật cùng vault trên máy.
- Phân tích bằng `flutter analyze --fatal-infos --fatal-warnings`, đúng cờ CI dùng.
- `flutter test` không kiểm lệch file sinh: sau khi sửa `.arb`, `pigeons/` hay codec vault, chạy lại generator ở mục Policy.
- Test shell (`test/tool/*_sh_test.dart`) luôn bỏ qua trên Windows. Không đặt `PAK_REQUIRE_SHELL_TESTS=1` trên Windows, vì biến này biến lần bỏ qua thành fail; CI ubuntu mới chạy các test này.
- Flutter 3.47.8 ghim ở `FLUTTER_VERSION` trong `.github/workflows/ci.yml` và `revision` trong `pak_manager/.metadata`; CI dùng `flutter pub get --enforce-lockfile`.

## Conventions that differ from defaults

- Comment, doc comment, thông điệp lỗi, commit và tài liệu viết tiếng Việt; identifier và tên test viết tiếng Anh.
- Tên test bắt đầu bằng id yêu cầu viết thường, đệm 2 chữ số (`fr05_`, `ad09_`, `nfr07_`, `ux_dr07_`); nhiều id thì nối liền (`fr49_ux_dr43_…`). Mọi test mang id thật từ `epics.md` hoặc spine; test công cụ dùng AD/NFR mà nó bảo vệ (check_imports → `ad02_`), không dùng `tc04_` (TC-4 nghĩa là không có mạng).
- Commit: `type(story-X.Y): mô tả tiếng Việt`; việc cấp epic dùng `type(epic-N)`, tài liệu kế hoạch dùng `docs(prd|ux|architecture|planning)`; `type` ∈ feat|fix|test|refactor|docs|ci|chore; sửa theo review: `fix(story-X.Y): sửa theo code review — …`. Branch: `feat/X-Y-slug` cho story, `feat/epic-N-slug` hoặc `docs/slug` cho việc khác.
- Đưa service vào UI qua provider viết tay (không codegen) trong `providers.dart`, override ở `main.dart`; không truyền service qua constructor widget. `VaultSession`/`SessionController` chỉ đọc qua provider bên trong `ProviderScope` của phiên (riêng `SessionGate` giữ controller). Ngoại lệ còn lại: `SettingsStore` truyền qua constructor `PakApp`; chuyển sang provider khi Epic 5 sửa phần cài đặt.
- Kết quả dự kiến (sai mật khẩu, file hỏng, ghi lỗi) trả bằng sealed result và `switch`; không ném exception.
- Mục mới trong `deferred-work.md` mang id `DW-<story>-<n>` (vd `DW-2.1-1`); mục cũ nhận id khi được đóng hoặc trích dẫn. Đóng mục bằng `status: done — <ngày> — CI run <id từ gh run list>` hoặc SHA commit; "người dùng báo xanh" không đủ làm bằng chứng.

<!-- /bmad:context -->
