---
title: 'Story 1.11: Ghim chuỗi cung ứng và Stack trong CI'
type: 'chore'
created: '2026-11-10'
status: 'done'
baseline_commit: '63bfc70062fa1544a80a090074008344147d3f4b'
route: 'dispatch'
review_loop_iteration: 0
context:
  - '{project-root}/_bmad-output/planning-artifacts/architecture/architecture-passwordmanager-2026-10-27/ARCHITECTURE-SPINE.md'
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** CI tải action theo tag trôi (`@v4`), runner `*-latest`, Flutter theo tag không kiểm revision, Gradle wrapper không có checksum, và không gì chặn một dependency ngoài bảng Stack (AD-12, AD-18). Một thay đổi ngầm từ bên ngoài có thể lọt vào build của app mật khẩu trong repo public.

**Approach:** Ghim mọi thứ CI tải về (SHA action, image runner + Xcode, revision Flutter, checksum Gradle) và thêm script Dart thuần `tool/ci/check_stack.dart` (có test) so `pubspec.yaml`/`pubspec.lock` với bảng Stack của spine cùng file allowlist gói kéo theo.

## Boundaries & Constraints

**Always:**
- Mọi `uses:` dạng `owner/repo@<SHA 40 ký tự> # vX.Y.Z`.
- Runner `ubuntu-24.04` và `macos-15`; iOS chọn Xcode bằng `sudo xcode-select -s /Applications/Xcode_26.3.app` rồi in `xcodebuild -version`.
- Sau khi clone Flutter (cả hai job), so `git -C "$RUNNER_TEMP/flutter" rev-parse HEAD` với `revision:` trong `pak_manager/.metadata`; lệch → exit 1 kèm thông điệp.
- `check_stack.dart` là Dart thuần, không import package nào ngoài `dart:*` (giống `check_imports.dart`), tự parse YAML theo dòng cho đúng các phần cần. Exit 0 khi sạch, exit 1 và in mỗi vi phạm một dòng ra stderr.
- Luật kiểm: (a) mỗi gói trong `dependencies` và `dev_dependencies` phải có tên trong bảng Stack; (b) gói không phải SDK phải có ràng buộc là phiên bản chính xác `X.Y.Z` (không `^`, `>=`, `any`, git, path) và bằng phiên bản trong bảng; (c) gói `sdk: flutter` chỉ cần có tên trong Stack (riêng `flutter` luôn được phép); (d) mọi gói `dependency: transitive` trong `pubspec.lock` phải có trong `tool/ci/transitive_allowlist.txt`; (e) phiên bản trong lock của gói trực tiếp phải khớp bảng Stack.
- Tên trong bảng Stack = token đầu ở cột Name (bỏ phần ngoặc); ô chứa `/` hoặc `,` tách thành nhiều tên (`flutter_localizations`, `flutter_test`). Không tìm thấy mục `## Stack` hoặc file → vi phạm, không lặng lẽ pass.
- Thông điệp và comment bằng tiếng Việt; tên test gắn AD (vd `ad12_caret_constraint_rejected`).

**Never:**
- Không thêm dependency vào `pubspec.yaml`; không sửa bảng Stack.
- Không ghim phiên bản trong allowlist (lockfile + `--enforce-lockfile` đã ghim).
- Không đổi các bước CI hiện có ngoài phạm vi ghim/kiểm ở trên; kiểm âm cổng CI thuộc story 1.12.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Sạch | pubspec + lock hiện tại, spine, allowlist | exit 0, in "OK" | N/A |
| Gói ngoài Stack | `dependencies: http: 1.2.0` | vi phạm nêu `http` | exit 1 |
| Dev dep ngoài Stack | `dev_dependencies: mocktail: 1.0.4` | vi phạm nêu `mocktail` | exit 1 |
| Ràng buộc lỏng | `sodium: ^4.1.2` | vi phạm "không ghim chính xác" | exit 1 |
| Lệch phiên bản | `sodium: 4.1.1` | vi phạm "khác bảng Stack 4.1.2" | exit 1 |
| Gói kéo theo mới | lock có `foo` transitive, không trong allowlist | vi phạm nêu `foo` | exit 1 |
| Spine thiếu | đường dẫn spine sai hoặc không có `## Stack` | vi phạm "không đọc được bảng Stack" | exit 1 |

</frozen-after-approval>

## Code Map

- `.github/workflows/ci.yml` -- `actions/checkout@v4` (2 chỗ), `actions/setup-java@v4`, `runs-on: ubuntu-latest`/`macos-latest`, bước "Cài Flutter" (2 job). Thêm bước "Kiểm Stack" sau "Pub get" ở job android: `dart run tool/ci/check_stack.dart`.
- SHA đã tra (git ls-remote, tag nhẹ = commit): `actions/checkout` v4.4.0 = `11d5960a326750d5838078e36cf38b85af677262`; `actions/setup-java` v4.9.1 = `cf277c60eb25467037889841efdb72551f06f6c3`. Tag Flutter `3.47.8` = `737ba8f885dc774b53b442759999a312c9461e4e` = `.metadata`.
- `pak_manager/android/gradle/wrapper/gradle-wrapper.properties` -- thêm `distributionSha256Sum=17f277867f6914d61b1aa02efab1ba7bb439ad652ca485cd8ca6842fccec6e43` (từ `gradle-9.3.1-all.zip.sha256` chính thức).
- `pak_manager/tool/check_imports.dart` + `test/tool/check_imports_test.dart` -- mẫu: hàm thuần nhận chuỗi trả `List<Violation>`, `main` đọc file; test dùng `flutter_test`, fixture trong `test/fixtures/`.
- `ARCHITECTURE-SPINE.md` dòng ~419 `## Stack` -- bảng 2 cột Name|Version; CI chạy trong `pak_manager/`, nên đường dẫn mặc định là `../_bmad-output/planning-artifacts/architecture/architecture-passwordmanager-2026-10-27/ARCHITECTURE-SPINE.md` (cho phép ghi đè qua tham số).
- `pak_manager/pubspec.lock` -- ~70 gói `transitive`; allowlist khởi tạo bằng đúng tập tên này.

## Tasks & Acceptance

**Execution:**
- [x] `pak_manager/tool/ci/check_stack.dart` -- tạo: `parseStackTable`, `checkStack(pubspec, lock, spine, allowlist) → List<String>`, `main([pubspecDir, spinePath])` -- cổng AD-12.
- [x] `pak_manager/tool/ci/transitive_allowlist.txt` -- tạo: header comment (`#`) giải thích cách thêm (rà network code, ghi gói cha), mỗi dòng một tên, sắp xếp -- nguồn duy nhất cho gói kéo theo.
- [x] `pak_manager/test/tool/check_stack_test.dart` -- test mọi dòng I/O Matrix bằng chuỗi nội tuyến, cộng một test chạy trên file thật của repo trả rỗng.
- [x] `pak_manager/android/gradle/wrapper/gradle-wrapper.properties` -- thêm checksum.
- [x] `.github/workflows/ci.yml` -- ghim SHA, runner, Xcode, kiểm revision Flutter, bước Kiểm Stack.
- [x] `pak_manager/README.md` -- thêm một đoạn ngắn: thêm dependency phải cập nhật Stack + allowlist; nâng action/Gradle thì cập nhật SHA/checksum.

**Acceptance Criteria:**
- Given `ci.yml`, when grep `uses:`, then mọi dòng có SHA 40 hex và comment tag; không còn chuỗi `-latest`.
- Given clone Flutter khác revision `.metadata`, when CI chạy, then bước cài Flutter fail.
- Given repo hiện tại, when `dart run tool/ci/check_stack.dart` trong `pak_manager/`, then exit 0.
- Given Gradle wrapper, when build Android, then wrapper xác minh checksum (build vẫn qua).

## Spec Change Log

## Review Triage Log

| # | Nguồn | Phát hiện | Verdict | Bằng chứng / Route |
|---|---|---|---|---|
| 1 | blind, edge, vgap | `dependency_overrides` bỏ qua mọi kiểm | medium | Parser chỉ đọc `dependencies`/`dev_dependencies`; lock ghi `direct overridden` nên allowlist cũng bỏ qua. patch |
| 2 | blind, edge | Gói lock không phải `transitive` và không khai báo trong pubspec không bị kiểm | medium | Vòng kiểm lock chỉ lọc `transitive`. patch |
| 3 | blind, edge, vgap | `source` trong lock không được kiểm (git/path lọt qua) | medium | `source` được parse nhưng không dùng. patch |
| 4 | blind, edge | Pubspec thụt lề ≠ 2 → không parse được gì → in OK | low | `indent == 2` cứng; sửa chỉ thêm một điều kiện. patch |
| 5 | vgap, edge | `main()` (exit code, thiếu file) không có test | medium | Test chỉ gọi `checkStack`. patch (tách `run`) |
| 6 | vgap, blind | Nhánh SDK dep ngoài Stack không có test âm | low | Mọi test âm dùng gói hosted. patch |
| 7 | edge, blind | Xcode 26.3 thiếu trên image → lỗi khó hiểu | low | `xcode-select` fail mờ; sửa một dòng. patch |
| 8 | vgap, blind | Kiểm revision Flutter chưa được kiểm âm; khối shell lặp ở 2 job | medium | Thật; kiểm âm cổng CI thuộc story 1.12. defer |
| 9 | blind | Flutter/Gradle/Xcode trong CI không đối chiếu bảng Stack | medium | Thật, ngoài AC 1.11. defer |
| 10 | blind | `gradle-wrapper.jar` chưa được xác thực | medium | Checksum chỉ phủ distribution. defer |
| 11 | blind | Allowlist còn tên không dùng | low | Thật, nhưng sửa là thêm tính năng, hiếm gặp. reject |
| 12 | blind, edge, vgap | `_stripComment` cắt ` #` trong chuỗi quote | low | Giá trị dependency không chứa ` #`; hiếm. reject |
| 13 | edge | Tên trùng trong bảng Stack: dòng sau thắng | low | Bảng không có tên trùng; cần thêm guard. reject |
| 14 | edge | Phiên bản prerelease bị từ chối | false | Spec quy định ràng buộc chính xác `X.Y.Z`; hành vi đúng thiết kế. reject |
| 15 | edge, blind | Test repo thật phụ thuộc cwd | low | `flutter test` luôn chạy trong `pak_manager/`. reject |
| 16 | blind | Ô version "theo Flutter SDK" parse thành `theo` | low | Gói SDK không so phiên bản; vô hại. reject |
| 17 | blind | Test lệch phiên bản chỉ kiểm `v.first` | low | Thẩm mỹ test. reject |

## Design Notes

macOS: `macos-latest` hiện trỏ `macos-26`; AC yêu cầu `macos-15`. Image `macos-15` có Xcode 26.3 nên chọn 26.3 để toolchain iOS gần với lần CI đang xanh nhất, thay vì 16.4 mặc định. Nếu build iOS gãy vì Xcode thì ghi vào Implementation Notes, không lùi về `*-latest`.

## Verification

**Commands:**
- `cd pak_manager && flutter test test/tool/check_stack_test.dart` -- pass
- `cd pak_manager && dart run tool/ci/check_stack.dart` -- exit 0
- `cd pak_manager && flutter analyze --fatal-infos --fatal-warnings` -- sạch
- `grep -nE 'uses:|runs-on:' .github/workflows/ci.yml` -- chỉ SHA + runner ghim

## Implementation Notes

### Review Findings

- [x] [Review][Patch] README: hướng dẫn nâng Flutter chưa nói phải đổi `FLUTTER_VERSION` trong `ci.yml` cùng lúc với `revision` trong `.metadata` (`flutter upgrade` không tự cập nhật `.metadata`) [pak_manager/README.md:23]
- [x] [Review][Defer] Chưa có kiểm âm cho bước so revision Flutter (lệch/rỗng → fail) [.github/workflows/ci.yml:54] — deferred: đã ghi trong deferred-work.md, thuộc story 1.12

**Rejected:**
- false — Dòng dep thụt 4 bị nuốt làm con của dep trước: pub sẽ coi là direct trong lock mà không khai báo → vi phạm "dependency không khớp".
- false — `dependencies: {..}` dạng flow: không parse dep nào, nhưng gói direct trong lock không được khai báo → vẫn fail.
- false — `###`/backtick trong bảng Stack làm rơi mục: rơi mục → dep báo "không có trong bảng Stack", fail-closed.
- false — grep `^  revision:` phụ thuộc thụt lề: lệch thì `expected` rỗng → fail-closed.
- false — Checksum Gradle chưa kiểm: wrapper tự xác minh khi build Android trên CI.
- low — Lock `direct main` nhưng pubspec ở `dev_dependencies`: lock do pub sinh, không xảy ra thực tế.
- low — Ô Version của Stack không phải X.Y.Z cho thông báo khó hiểu: vẫn fail, chỉ là thông điệp; sửa cần thêm nhánh.
- low — `hosted` từ registry khác pub.dev không bị chặn (không đọc `description.url`): gói pub.dev không thể phụ thuộc host khác; thêm guard không đáng.
- low — Không đối chiếu ràng buộc Dart SDK với Stack: ngoài luật (a)–(e); Flutter/Gradle/Xcode đã được defer.
- low — Allowlist không kiểm sắp xếp/trùng/mục thừa: đã bác ở triage #11 của spec.
- low — Thiếu vài test (dev dep lệch lock, run() thiếu allowlist, CRLF Stack…): đường code chung đã được phủ.
- low — Kiểm thêm source/overrides/direct ngoài luật (a)–(e): phù hợp ý đồ spec, đã ghi triage #1–#3.
- low — Spec `status: done` lệch sprint `review`: sửa bằng bước cập nhật trạng thái của review này.
- low — Thông báo `revision ''` khó hiểu khi `.metadata` thiếu revision: vẫn fail-closed.
- low — Không chạy lại lệnh verify: test `ad12_real_repo_files_are_clean` chạy trong CI.
