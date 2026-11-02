# Deferred Work

- source_spec: `_bmad-output/implementation-artifacts/spec-1-1-khoi-tao-du-an-flutter-structural-seed-ci.md`
  summary: Thêm flavor `dev` cho iOS (scheme + build configuration, bundle id hậu tố `.dev`) để bản dev không ghi đè vault thật trên iPhone.
  evidence: Story 1.1 chỉ làm flavor Android theo quyết định của người dùng; iOS cần sửa tay `project.pbxproj` và chỉ kiểm được qua CI macOS. Khi có scheme `prod`/`dev` cho iOS thì cân nhắc `flutter: default-flavor: prod` trong `pubspec.yaml` (hiện không dùng được vì làm `flutter build ios` không cờ bị fail).
