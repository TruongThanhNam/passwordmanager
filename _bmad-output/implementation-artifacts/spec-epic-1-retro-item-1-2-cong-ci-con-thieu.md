---
title: 'Retro Epic 1 action item 1–2: ci_structure đòi mọi bước cổng, cổng distributionSha256Sum'
type: 'chore'
created: '2026-11-19'
status: 'done'
route: 'dispatch'
review_loop_iteration: 0
baseline_commit: 'c9698a6ee0f7121e225a80c9688617cd94afe7fb'
context:
  - '{project-root}/_bmad-output/implementation-artifacts/epic-1-retro-2026-11-18.md'
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** Retro Epic 1 (A1, B1, C1) cho thấy hai lỗ hổng. Thứ nhất, `ci_structure` chỉ đòi một phần bước cổng: gỡ khỏi `ci.yml` các bước check_imports, analyze, Pigeon, l10n, fixture, `--enforce-lockfile`, integration_test hay kiểm bundle id iOS thì CI vẫn xanh. Thứ hai, không cổng nào kiểm `distributionSha256Sum`, nên xóa dòng đó thì Gradle tải bản phân phối mà không xác minh. Thêm vào đó, parser YAML bị chép ở hai file và hai bản `_stripComment` đã lệch nhau.

**Approach:** Thêm các cổng còn thiếu vào `ci_structure`, mỗi cổng có kiểm âm. Thêm kiểm `distributionSha256Sum` vào `checkToolchain` của `check_stack`. Gom parser YAML và các hàm `stripComment`/`unquote` vào một file dùng chung, có xử lý dấu nháy.

## Boundaries & Constraints

**Always:**
- Nhận bước cổng theo nội dung (`run`/`uses`/`with`/`env`), không theo `name`. Lệnh cổng phải khớp nguyên dòng, để thêm hậu tố `|| true` hay `; true` thì không còn khớp.
- Mọi cổng mới đi qua cơ chế chung hiện có: cấm `if:` và `continue-on-error` khác `false`.
- Mỗi cổng mới có ít nhất hai ca âm: gỡ bước, và tắt bước bằng `if:`/`continue-on-error`. Ca âm dựng bằng cách sửa `ci.yml` thật, theo đúng lối của `ci_structure_test.dart`.
- Dart thuần, không thêm dependency. `ci.yml` thật và repo thật phải sạch: exit 0, in `OK`.
- Tag test giữ định dạng hiện có (`ad19_`, `ad12_`).

**Never:**
- Không sửa `ci.yml`, trừ khi một cổng mới đòi đổi hình dạng lệnh. Nếu vậy, ghi lại trong Implementation Notes.
- Không gom 5 bản CLI thành `_cli.dart`, không chuyển `check_workflow_secrets` sang dùng model, không đổi cách `checkToolchain` đọc `FLUTTER_VERSION`/Xcode. Các việc này ngoài action item, vào backlog CI theo D1.
- Không kiểm giá trị checksum có khớp bản Gradle hay không. Gradle tự xác minh khi tải.

## I/O & Edge-Case Matrix

| Kịch bản | Đầu vào | Kết quả mong đợi |
|---|---|---|
| Repo thật | `ci.yml` và `gradle-wrapper.properties` hiện tại | Không vi phạm |
| Gỡ hoặc tắt bước cổng mới | Bỏ bước, hoặc thêm `if: false` | `job X: thiếu bước cổng <nhãn>`, hoặc vi phạm `if:` |
| Cổng sinh code bị nới | Đổi `exit 1` thành `exit 0`, hoặc đổi đường dẫn `git status --porcelain` | Thiếu bước cổng l10n, Pigeon hoặc fixture |
| Thu hẹp lệnh | `flutter analyze` bỏ cờ fatal; integration_test thêm `--name` | Thiếu bước cổng tương ứng |
| Thiếu build iOS | Gỡ `flutter build ios … --flavor prod` | Thiếu cổng bundle id iOS prod, vì bước kiểm prod lúc này đọc plist của build không cờ |
| Thiếu hoặc hỏng checksum | Không có dòng; dòng bị comment; 63 hex; giá trị rỗng; hai dòng | Vi phạm `distributionSha256Sum` |

</frozen-after-approval>

## Code Map

- `pak_manager/tool/ci/ci_structure.dart`:
  - `:39-325`: model (`CiStep`, `CiJob`, `CiWorkflow`) và `parseCiWorkflow`. Chuyển sang file dùng chung và re-export, vì test import `parseCiWorkflow` từ đây.
  - `:331-465`: `_Gate` và các cổng.
  - `:543-568`: chọn cổng theo job.
  - `_mentionsFlutter`: điều kiện để áp cổng pub get.
- `pak_manager/tool/ci/check_stack.dart`:
  - `:76-92`: `_stripComment` và `_unquote`, trùng với bản ở `ci_structure` (bản này cắt ` #` cả trong chuỗi có nháy).
  - `:319-385`: `checkToolchain` đã nhận nội dung `gradleProps`.
- `.github/workflows/ci.yml`: hình dạng chuẩn của từng bước cổng mới.
  - android: `:58-59`, `:74-117`.
  - ios: `:175-232`.
  - integration-android: `:272-284`, với `script` nằm trong `with:` của emulator runner.
  - integration-ios: `:314-315`, `:337-338`.
- `pak_manager/test/tool/ci_structure_test.dart`:
  - `_gates` (`:99-119`) sinh sẵn ca gỡ và ca tắt cho mỗi dòng.
  - Có sẵn các helper `_removeStep`, `_stepRange`, `_moveStepAfter`.
- `pak_manager/test/tool/check_stack_test.dart`: `_toolchain(props:)` và nhóm `toolchain` (`:231-309`).
- `pak_manager/android/gradle/wrapper/gradle-wrapper.properties:6`: dòng checksum thật.

## Tasks & Acceptance

**Execution:**
- [x] `pak_manager/tool/ci/ci_yaml.dart` (mới) -- Chứa model và `parseCiWorkflow` chuyển từ `ci_structure`. Chứa `stripComment` bỏ phần sau `#` đứng đầu hoặc sau khoảng trắng, nằm ngoài nháy đơn/kép, và giữ thụt đầu dòng. Chứa `unquote`. -- C1: một parser, một cách bỏ comment.
- [x] `pak_manager/tool/ci/ci_structure.dart` -- Import và export `ci_yaml.dart`. Thêm các cổng sau:
  - Cho mọi job nhắc tới flutter: `flutter pub get --enforce-lockfile`.
  - android: `dart run tool/check_imports.dart`; `flutter analyze --fatal-infos --fatal-warnings`.
  - android: ba cổng "sinh lại rồi so", gồm l10n (`lib/l10n`), Pigeon (`lib android ios`) và fixture (`test/fixtures/vault`). Mỗi cổng đòi theo thứ tự: lệnh sinh, `changes="$(git status --porcelain -- <đường dẫn>)"`, `if [[ -n "$changes" ]]; then`, `exit 1`.
  - integration-android: emulator runner có `with.script` đúng `flutter test integration_test --flavor dev`.
  - integration-ios: dòng `flutter test integration_test -d "$SIM_UDID"`.
  - ios: ba cặp build→kiểm (không cờ, prod, dev). Bước kiểm đọc `CFBundleIdentifier` và `CFBundleDisplayName` bằng PlistBuddy, so đúng id và tên, có `exit 1`. Bước kiểm phải đứng sau build của nó và trước build iOS kế tiếp.
  -- A1.
- [x] `pak_manager/tool/ci/check_stack.dart` -- Dùng `stripComment`/`unquote` của `ci_yaml.dart`. Trong `checkToolchain`, đòi đúng một dòng có khóa `distributionSha256Sum`, dạng `distributionSha256Sum=<64 hex>`; ngoài ra là vi phạm. -- B1.
- [x] `pak_manager/test/tool/ci_structure_test.dart` -- Thêm dòng `_gates` cho mỗi cổng mới, cộng ca âm cho từng dòng ở I/O Matrix.
- [x] `pak_manager/test/tool/check_stack_test.dart` -- Thêm ca âm checksum theo I/O Matrix. Thêm test cho `stripComment` với `#` trong nháy và `#` sau khoảng trắng.
- [x] `_bmad-output/implementation-artifacts/sprint-status.yaml`, `deferred-work.md` -- Đặt `epic-1-retro-item-1`/`-2` thành `done`, và mục `distributionSha256Sum` (`deferred-work.md:202-203`) thành `done`. Chỉ làm sau khi verification xanh.

**Acceptance Criteria:**
- Given `ci.yml` thật, when gỡ bất kỳ bước nào retro A1 liệt kê, then `dart run tool/ci/ci_structure.dart` exit 1 và nêu tên bước đó.
- Given repo thật, when chạy `ci_structure.dart` và `check_stack.dart`, then cả hai exit 0, in `OK`.
- Given `ci_structure.dart` và `check_stack.dart` sau khi gom, when grep `_stripComment|_unquote`, then không còn định nghĩa riêng nào.

## Design Notes

Cặp build→kiểm iOS là cần thiết vì hai bước kiểm (không cờ và prod) cùng đòi id prod. Nếu chỉ đòi bước kiểm, gỡ build prod vẫn xanh: bước kiểm prod đọc lại plist của build không cờ. Ghép mỗi bước kiểm với bước `flutter build ios` gần nhất đứng trước nó (theo cờ `--flavor`) sẽ chặn được trường hợp này.

## Verification

**Commands** (chạy trong `pak_manager/`):
- `dart run tool/ci/ci_structure.dart` -- in `OK`, exit 0.
- `dart run tool/ci/check_stack.dart` -- in `OK`, exit 0.
- `flutter test test/tool` -- pass hết.
- `flutter analyze --fatal-infos --fatal-warnings` -- không có issue.
- `dart run tool/check_imports.dart` -- in `OK`.

## Implementation Notes

- Không sửa `ci.yml`: mọi cổng mới khớp hình dạng lệnh hiện có.
- `ci_yaml.dart`: dấu nháy chỉ mở chuỗi khi đứng đầu dòng hoặc sau khoảng trắng, `:`, `[`, `{`, `,` (để `don't # x` vẫn bỏ comment). Trong nháy kép, `\` thoát ký tự kế tiếp; trong nháy đơn, `''` là một dấu nháy. Plain scalar YAML kiểu `echo "a #b"` bị coi là có nháy (YAML thật cắt comment ở đó); không ảnh hưởng cổng, vì khối `run: |` không đi qua `stripComment`.
- Cổng "sinh lại rồi so" và bước kiểm iOS: `exit 1` phải nằm trước dòng `fi` kế tiếp sau `if … then`, để dời `exit 1` ra ngoài nhánh cũng bị bắt.
- iOS: thêm ba cổng build (`flutter build ios --release --no-codesign [--flavor X] --build-number "$GITHUB_RUN_NUMBER"`, khớp nguyên dòng) bên cạnh ba cổng kiểm, để `if:`/`continue-on-error` trên bước build cũng bị bắt. Bước kiểm ghép với dòng `flutter build ios` (nhận lỏng) cuối cùng của bước gần nhất đứng trước nó; dòng đó phải khớp nguyên văn build cùng flavor.
- `_Gate` có thêm `inJob` (điều kiện theo vị trí bước trong job) và `matchedIn`; các cổng cũ không đổi.
- `distributionSha256Sum`: khóa nhận ở đầu dòng (bỏ qua dòng `#`/`!`); đúng một dòng, dạng `distributionSha256Sum=<64 hex>` (chấp nhận hex hoa/thường, thụt đầu dòng); sau review: chấp nhận cả dấu phân cách `=`/`:` có khoảng trắng của file properties Java.
- Sau review: mọi bước cổng cấm khóa cấp bước `shell:` và `working-directory:` (vd `shell: sh` làm `[[` lỗi trong `if`, cổng sinh lại luôn xanh); emulator runner phải có `with.working-directory: pak_manager`.

## Spec Change Log

## Review Triage Log

Vòng review 1 (blind-hunter, edge-case-hunter, verification-gap).

| # | Nguồn | Phát hiện | Verdict | Bằng chứng / xử lý |
|---|---|---|---|---|
| 1 | verification-gap | Guard `_lastIosBuild(s) != null` trong `_iosCheckGate` không có test | medium | Gap đã xác minh sẵn. Xóa guard thì mọi test vẫn xanh. **patch**: thêm `ad19_ios_check_step_with_own_build_rejected` |
| 2 | blind | Ca "dời `exit 1` ra sau `fi`" chưa có cho bước kiểm iOS | low | Cùng `_guardedExit` nhưng bước kiểm iOS dùng anchor khác; thêm test là việc trực tiếp. **patch**: thêm `ad19_ios_check_exit_after_fi_rejected` |
| 3 | blind, edge | Bước cổng có `shell:` hoặc `working-directory:` (cả `with.working-directory` của emulator) | medium | Đã xác minh: `shell: sh` làm `[[` lỗi trong `if`, cổng sinh lại luôn xanh mà `checkCiStructure` trả rỗng. Dễ lỡ tay đổi shell. **patch**: cấm hai khóa, ghim `working-directory: pak_manager` |
| 4 | blind | `distributionSha256Sum = <hex>` và `distributionSha256Sum:<hex>` hợp lệ theo Java properties nhưng bị từ chối | low | Chặn nhầm một file hợp lệ; sửa regex là việc trực tiếp. **patch**: `\s*[=:]\s*` |
| 5 | blind | `'ios'` vẫn là literal trong khi các job khác có hằng | low | Đổi tên job phải sửa hai chỗ. **patch**: thêm `iosJob` |
| 6 | blind | `stripComment` tạo hai `RegExp` ở mỗi ký tự | low | Sửa trực tiếp. **patch**: đưa lên `final` cấp top-level |
| 7 | blind | `last_updated: 11-19-2026 12:00` là giá trị giữ chỗ | low | **patch**: đặt mốc thời gian thật |
| 8 | blind | Đánh dấu item 1–2 `done` trước khi review xong và khi chưa có id run CI | low | Trạng thái sẽ đúng khi review đóng. Id run CI ghi khi CI của PR chạy (D3). Loại |
| 9 | blind | Code Map trỏ số dòng cũ | low | Cách sửa là sửa spec của chính build này. Loại |
| 10 | blind, edge | Dòng cổng khớp nhưng không chạy: `exit 0` đặt trước, bọc `if false`, nối dòng `\`/`\|\|`/`&&`, `run: >` gộp `\|\| true` vào dòng, `eval`/`xcodebuild` thay build | low | Đều đòi cố ý viết lại `ci.yml` (thấy rõ trong diff PR). Cổng cũ cũng có lớp này, nhưng các bypass mới đã được kiểm (`exit 0`, `changes=""`, `run: >`) thì có thật. Cách vá phải dựng ngữ nghĩa shell. Loại (mức thấp, phức tạp) |
| 11 | blind, edge | `_guardedExit` bỏ qua dòng chen giữa anchor (`changes=""`, `git checkout`, `if false` lồng, `Set :CFBundleIdentifier`) | low | Cùng lớp với #10: cố ý né trong diff. Loại |
| 12 | blind | `pub get --enforce-lockfile` không bị ràng thứ tự | low | Phải cố ý dời bước. Ràng thứ tự là thêm guard. Loại |
| 13 | blind, edge | Dòng properties trước đó kết thúc bằng `\` thì nuốt dòng checksum | low | Phải viết `\` cuối dòng, hiếm gặp. Phải hiện thực cách nối dòng logic của Properties. Loại |
| 14 | edge | `stripComment` gặp nháy không đóng (`Rock 'n roll # c`) thì giữ lại comment | low | Ở dòng dep trong pubspec, `#` đứng trước nháy nên vẫn bị cắt. Chỉ xảy ra với giá trị lạ. Loại |
| 15 | edge | `firstMatch(...)!` ở cấp `main()` làm cả file test lỗi nếu file thật mất checksum | low | Vẫn fail ồn ào, và `ad12_real_toolchain_matches_stack` cũng fail. Loại |
| 16 | blind | Test file thật chỉ nhận `[0-9a-f]` trong khi checker nhận cả hex hoa | false | Test khẳng định tính chất của file thật, chặt hơn checker cũng không gây hại cụ thể nào |
| 17 | blind | `ad19_generate_after_compare_rejected` chỉ phủ l10n | false | Ba cổng sinh lại cùng một hàm `_regenGate` có tham số; nhánh thứ tự đã được phủ |
| 18 | blind | Bọc build prod trong `if false` thì cặp build→kiểm vẫn xanh | low | Cùng lớp với #10. Mục tiêu Design Notes (gỡ bước build) đã có test chặn. Loại |
