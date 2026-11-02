# PAK Manager

Trình quản lý mật khẩu offline cho iOS và Android (Flutter 3.47.8, `cupertino_ui`).
Kiến trúc: `_bmad-output/planning-artifacts/architecture/` ở gốc repo.

## Kiểm tra cục bộ

```sh
flutter pub get
flutter analyze --fatal-infos --fatal-warnings
dart run tool/check_imports.dart
flutter test
```

## Flavor

Android có hai flavor: `prod` (`io.github.truongthanhnam.pakmanager`) và `dev`
(hậu tố `.dev`, nhãn "PAK Manager Dev"). Mọi lệnh build/run Android phải ghi rõ
`--flavor prod` hoặc `--flavor dev`. iOS chưa có flavor: build không kèm `--flavor`.

Build Android release chỉ chạy trên GitHub Actions (AD-19).
