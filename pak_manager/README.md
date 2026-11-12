# PAK Manager

Trình quản lý mật khẩu offline cho iOS và Android (Flutter 3.47.8, `cupertino_ui`).
Kiến trúc: `_bmad-output/planning-artifacts/architecture/` ở gốc repo.

## Kiểm tra cục bộ

```sh
flutter pub get
flutter analyze --fatal-infos --fatal-warnings
dart run tool/check_imports.dart
dart run tool/ci/check_stack.dart
flutter test
```

## Chuỗi cung ứng (AD-12, AD-18)

Thêm hay nâng dependency thì phải cập nhật bảng Stack trong `ARCHITECTURE-SPINE.md`
(ghim chính xác `X.Y.Z`) và thêm gói kéo theo mới vào
`tool/ci/transitive_allowlist.txt` sau khi rà code; `tool/ci/check_stack.dart`
chặn mọi lệch. Nâng action trong `.github/workflows/ci.yml` thì ghim SHA commit
mới kèm comment tag; nâng Gradle thì cập nhật `distributionSha256Sum` trong
`android/gradle/wrapper/gradle-wrapper.properties`; nâng Flutter thì đổi
`FLUTTER_VERSION` trong `ci.yml` và sửa tay `revision` trong `.metadata` cho khớp
commit của tag (`flutter upgrade` không tự cập nhật `.metadata`).

## Flavor

Android và iOS có hai flavor: `prod` (`io.github.truongthanhnam.pakmanager`) và `dev`
(hậu tố `.dev`, nhãn "PAK Manager Dev"). Mọi lệnh build/run Android phải ghi rõ
`--flavor prod` hoặc `--flavor dev`. Trên iOS, chạy bản dev bằng
`flutter run --flavor dev`; build không kèm `--flavor` (scheme `Runner`) dùng bundle id
prod và sẽ ghi đè app thật cùng vault trên máy.

Build Android release chỉ chạy trên GitHub Actions (AD-19).
