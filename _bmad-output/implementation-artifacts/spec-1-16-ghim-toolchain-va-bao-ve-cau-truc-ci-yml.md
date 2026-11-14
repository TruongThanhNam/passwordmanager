---
title: 'Story 1.16: Ghim toolchain và bảo vệ cấu trúc ci.yml'
type: 'chore'
created: '2026-11-14'
status: 'done'
baseline_commit: 'd4f2f9ba874572b87923d22564334d10350cdbce'
route: 'dispatch'
review_loop_iteration: 0
context: []
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** Gỡ một bước cổng khỏi `ci.yml`, thêm `continue-on-error`/`if:` cho nó, hay đổi `FLUTTER_VERSION`/Gradle/Xcode lệch bảng Stack đều không làm gì đỏ. `gradle-wrapper.jar` cũng chưa được xác thực bằng `wrapper-validation`.

**Approach:** Thêm luật cấu trúc workflow (Dart thuần, có kiểm âm trên bản `ci.yml` thật bị sửa); mở rộng `check_stack.dart` so `FLUTTER_VERSION`, `distributionUrl` và Xcode với bảng Stack (thêm dòng Gradle 9.3.1, Xcode 26.3); thêm bước `gradle/actions/wrapper-validation` trước mọi bước gọi Gradle.

## Boundaries & Constraints

**Always:**
- Bước cổng bắt buộc (job `android`): kiểm secret trên chính `ci.yml`, kiểm Stack, `flutter test` có `PAK_REQUIRE_SHELL_TESTS: '1'`, kiểm APK prod (`--expect-id io.github.truongthanhnam.pakmanager`, `--save-raw`) và dev (`--expect-id …pakmanager.dev`, `--save-raw`), upload `apk-raw-output`, `wrapper-validation`. Mọi job nhắc tới `flutter` phải clone Flutter rồi gọi `check_flutter_revision.sh` sau clone. Mọi job macOS phải `xcode-select -s`.
- Bước cổng không được có `if:` hay `continue-on-error` khác `false`; riêng upload artifact chỉ được `if: ${{ !cancelled() }}`. Job chứa cổng cũng không được có `if:`/`continue-on-error`. Workflow phải chạy trên `pull_request` và `push` lên `main`.
- Mọi `uses:` ghim SHA 40 hex kèm comment tag; `runs-on` không `*-latest`.
- `wrapper-validation`: `gradle/actions/wrapper-validation@8da46b539cd8fe6ab27ca75128919a18d757604c # v6.4.1`, đặt trước bước đầu tiên gọi Gradle ở mọi job build Android (`android`, `integration-android`).
- Kiểm âm mỗi luật bằng cách sửa bản `ci.yml` thật (gỡ bước, thêm `if:`/`continue-on-error`, đổi phiên bản), không viết tay workflow mẫu.
- Comment và thông báo tiếng Việt; tên test theo tiền tố AD/NFR.
- Quyết định (chủ sản phẩm 2026-11-14): commit `pak_manager/android/gradle/wrapper/gradle-wrapper.jar`, `pak_manager/android/gradlew`, `pak_manager/android/gradlew.bat` do Flutter sinh (giữ nguyên byte) và bỏ 3 dòng ignore tương ứng trong `pak_manager/android/.gitignore`.
- Quyết định (chủ sản phẩm 2026-11-14): chỉ verify cục bộ; người dùng tự push và chạy CI.

**Never:**
- Không push, không mở PR (người dùng tự làm).
- Không thêm dependency Dart (kể cả `yaml`), không thư viện mock.
- Không đổi luật hiện có của `apk_rules.dart`, `check_workflow_secrets.dart`, phần kiểm package của `check_stack.dart`.
- Không đổi quyết định kiến trúc nào ngoài hai dòng Stack mới.
- Không force-push, không push lên `main`.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Workflow thật | `ci.yml` hiện tại (sau story) | không vi phạm | N/A |
| Gỡ bước cổng | xóa từng bước bắt buộc | vi phạm nêu tên bước | N/A |
| Cổng bị tắt | thêm `if: false` / `continue-on-error: true` vào bước hoặc job | vi phạm | N/A |
| Thứ tự wrapper | `wrapper-validation` sau `flutter build apk` | vi phạm | N/A |
| Toolchain khớp | spine 3.47.8 / 9.3.1 / 26.3, CI giống | `OK` | N/A |
| `FLUTTER_VERSION` lệch | `'3.47.9'` | exit 1 | nêu hai giá trị |
| Gradle lệch | `gradle-9.3.0-all.zip` | exit 1 | nêu hai giá trị |
| Xcode lệch | `Xcode_26.2.app` ở một job | exit 1 | nêu hai giá trị |
| Thiếu dòng/giá trị | spine thiếu dòng Gradle, hoặc `ci.yml` không có `Xcode_*.app` | exit 1 | thông báo thiếu |

</frozen-after-approval>

## Code Map

- `.github/workflows/ci.yml` -- `env.FLUTTER_VERSION` (19), `defaults.run.working-directory: pak_manager`; job `android` 27-136 (secret 56-59 dùng glob `secret[s]`, Stack 61-62, `flutter test` 109-114, build/kiểm APK 116-126, upload 130-136); `ios` 138 (Xcode 147-151); `integration-android` 225 (Gradle qua `reactivecircus/android-emulator-runner`, 260-269); `integration-ios` 272 (Xcode 281-285). Mỗi job có bước clone Flutter + `check_flutter_revision.sh`.
- `pak_manager/tool/ci/check_stack.dart` -- `parseStackTable` (20) lấy token đầu của tên sau khi bỏ ngoặc: `Flutter SDK (Dart 3.13)` → `Flutter`; dòng `Gradle (wrapper)` → `Gradle`, `Xcode (CI)` → `Xcode`. `run(args)` (314) nhận `[pubspecDir, spinePath]`; thêm tham số 3/4 = đường dẫn `ci.yml` (mặc định `$dir/../.github/workflows/ci.yml`) và `gradle-wrapper.properties` (mặc định `$dir/android/gradle/wrapper/gradle-wrapper.properties`). Không sửa `checkStack`.
- `pak_manager/test/tool/check_stack_test.dart` -- nhóm `run` (209-246) dựng thư mục tạm chỉ có spine/pubspec/lock: phải ghi thêm `ci.yml` và properties rồi truyền đủ 4 tham số.
- `pak_manager/android/gradle/wrapper/gradle-wrapper.properties` -- `distributionUrl=…gradle-9.3.1-all.zip` (`\:` đã escape).
- `pak_manager/android/.gitignore:16-20` -- ignore `gradle-wrapper.jar`, `/gradlew`, `/gradlew.bat`: bỏ 3 dòng này. Flutter chỉ chép file wrapper còn thiếu từ cache SDK, nên file đã commit được giữ. Lấy file bằng `flutter build apk --config-only` (hoặc từ cache `bin/cache/artifacts/gradle_wrapper/`).
- `_bmad-output/planning-artifacts/architecture/architecture-passwordmanager-2026-10-27/ARCHITECTURE-SPINE.md:419-437` -- bảng Stack.
- `pak_manager/test/tool/check_flutter_revision_sh_test.dart:141-160` -- test chuỗi con trên `ci.yml` của 1.15; giữ nguyên.
- `pak_manager/test/tool/check_workflow_secrets_test.dart:88` -- mẫu đọc `../.github/workflows/ci.yml` từ cwd `pak_manager`.
- `_bmad-output/implementation-artifacts/deferred-work.md` -- 3 mục `planned — story 1.16` (dòng ~150-174) và mục `PAK_REQUIRE_SHELL_TESTS`/`--save-raw` (dòng ~193).

## Tasks & Acceptance

**Execution:**
- [x] `ARCHITECTURE-SPINE.md` -- thêm `| Gradle (wrapper) | 9.3.1 |` và `| Xcode (CI) | 26.3 |` vào bảng Stack.
- [x] `pak_manager/tool/ci/check_stack.dart` -- thêm `checkToolchain(stack, ciYaml, gradleProps)` trả vi phạm (bảng thiếu `Flutter`/`Gradle`/`Xcode`, không tìm thấy giá trị, hoặc lệch); `run` gọi nó cùng `checkStack`, file thiếu là vi phạm.
- [x] `pak_manager/tool/ci/ci_structure.dart` -- parser theo dòng cho cấu trúc của `ci.yml` (job, bước, khóa cấp bước, khối `run: |`, `with:`) giữ vị trí dòng mỗi bước; `checkCiStructure(String yaml)` trả vi phạm theo các luật ở Boundaries.
- [x] `pak_manager/android/.gitignore`, `pak_manager/android/gradlew`, `pak_manager/android/gradlew.bat`, `pak_manager/android/gradle/wrapper/gradle-wrapper.jar` -- bỏ ignore, thêm file wrapper Flutter sinh; `gradlew` giữ quyền thực thi (`git update-index --chmod=+x`); `.gitattributes` giữ nhị phân cho `*.jar` và LF cho `gradlew`.
- [x] `.github/workflows/ci.yml` -- thêm bước `wrapper-validation` vào `android` (sau checkout) và `integration-android` (trước emulator runner).
- [x] `pak_manager/test/tool/ci_structure_test.dart` -- `ci.yml` thật sạch; kiểm âm gỡ từng bước bắt buộc, thêm `if:`/`continue-on-error` cho từng bước cổng và cho job, chuyển wrapper sau bước Gradle, `uses:` theo tag, `runs-on: ubuntu-latest`, bỏ trigger `pull_request`.
- [x] `pak_manager/test/tool/check_stack_test.dart` -- ca toolchain trong ma trận (khớp, lệch từng loại, thiếu dòng/giá trị) dựng từ file thật bị sửa; cập nhật nhóm `run`.
- [x] `_bmad-output/implementation-artifacts/deferred-work.md`, `epic-1-context.md` -- đánh dấu `done — story 1.16`; câu "(story 1.16, chưa làm)" sang đã làm.

**Acceptance Criteria:**
- Given nhánh của story, when `flutter test test/tool/` và `dart run tool/ci/check_stack.dart`, then pass/`OK` trên file thật.
- Given CI chạy trên PR, when job `android` và `integration-android` chạy, then bước `wrapper-validation` xanh trước bước Gradle đầu tiên và bước Kiểm Stack xanh.

### Review Findings

_Code review 2026-11-14 (Blind Hunter, Edge Case Hunter, Verification Gap, Acceptance Auditor)._

- [x] [Review][Patch] Nhánh vi phạm của `run()` (exit 1 + stderr) chưa có test; bước CI `dart run tool/ci/ci_structure.dart` chỉ làm đỏ job qua exit code này — thêm `ad19_run_violation_returns_1` ghi `ci.yml` thật bị gỡ một bước cổng ra file tạm, kỳ vọng 1 và stderr chứa `thiếu bước cổng` [pak_manager/tool/ci/ci_structure.dart:612]
- [x] [Review][Patch] Chỉ job `android` bị đòi tồn tại: xóa hoặc đổi tên cả job `integration-android`/`ios`/`integration-ios` làm mất luôn cổng wrapper/clone Flutter/xcode-select mà vẫn `OK` (trái Always: wrapper ở `integration-android`; trái câu "fail khi thiếu bước cổng bắt buộc" ở `epic-1-context.md:50`) — đòi đủ 4 job, thêm kiểm âm xóa từng job [pak_manager/tool/ci/ci_structure.dart:484]
- [x] [Review][Patch] Bước `wrapper-validation` thêm `with: allow-checksums: …` (hoặc `min-wrapper-count: 0`) vẫn được nhận là cổng, JAR bị sửa vẫn qua — cấm `with:` trên bước wrapper, thêm kiểm âm [pak_manager/tool/ci/ci_structure.dart:392]
- [x] [Review][Patch] `uses:` cấp job (reusable workflow) ghim đúng vẫn luôn bị báo vì `job.keys` đã bỏ comment `# tag` trước khi so `_pinnedUses` — giữ giá trị thô như `CiStep.usesRaw` [pak_manager/tool/ci/ci_structure.dart:242]
- [x] [Review][Patch] `gradlew.bat` lưu trong git ở dạng LF (`text eol=crlf` chuẩn hóa blob), không giữ nguyên byte như quyết định 2026-11-14 — đổi sang `-text` và add lại bản CRLF từ cache Flutter [.gitattributes:9]
- [x] [Review][Patch] Mục hoãn "Cân nhắc `if: ${{ !cancelled() }}` cho bước dev" trong `deferred-work.md` chưa ghi rằng làm vậy giờ sẽ vi phạm luật `_apkDevGate` (chỉ ghi trong spec) — thêm ghi chú vào mục đó [_bmad-output/implementation-artifacts/deferred-work.md:195]
- [x] [Review][Defer] `distributionSha256Sum` trong `gradle-wrapper.properties` không được kiểm: xóa dòng này thì mọi cổng vẫn xanh [pak_manager/tool/ci/check_stack.dart] — deferred: lỗ hổng có từ trước (story 1.11), story này chỉ thêm so phiên bản `distributionUrl`

**Rejected:**
- low — Trigger thu hẹp bằng `types:`/chỉ `tags:`, thêm `workflow_dispatch`/`pull_request_target`: trùng triage #12; `pull_request_target` cần luật AD-18 mới.
- low — `permissions`, `defaults.run.shell`, `shell:` cấp bước, `set +e`/`exit 0` trước lệnh cổng không bị kiểm: cần thêm luật mới; phá theo cách này lộ rõ trong diff của PR.
- low — `_callsGradle` không nhận `flutter run`/`drive`/`build aar`: trùng triage #21.
- low — `runs-on` dạng matrix/danh sách/`self-hosted` né luật `-latest` và cổng Xcode: trùng triage #19.
- low — Test hardcode `3.47.8`/`9.3.1`/`26.3` và đường dẫn `ci.yml`: khi nâng phiên bản test fail ồn ào; sửa bằng cách đọc từ spine thêm độ phức tạp.
- low — `_stripComment` cắt ở ` #`; `'1' # x` không bỏ được comment: chỉ gây báo nhầm ồn ào, không làm lọt (mọi `if:` khác giá trị cho phép đều bị báo).
- low — Job cổng bị bỏ qua qua `needs:`: trùng triage #14.
- low — Merge key `<<: *anchor` mang `if:`: trùng triage #19.
- low — Đặt lại `FLUTTER_VERSION=` trong shell trước `git clone`: phá có chủ ý, lộ trong diff; neo `^git clone` không đóng được dạng `export`.
- low — Báo nhầm action cục bộ `./`/`docker://`: trùng triage #15.
- false — Trạng thái lệch giữa sprint-status, spec và deferred-work: trùng triage #16, đúng vòng đời BMAD.
- low — `_mentionsFlutter` chỉ xét `run`/`with`/`uses`, không xét `env:`: trùng triage #8; cả 4 job thật đều bị đòi clone.
- false — CI chưa chạy để xác nhận wrapper-validation nhận JAR 2.10: đã ghi ở Verification/Manual checks, không phải lỗi code.
- false — Mục AC1 của 1.15 (cần một lần chạy xanh đủ 4 job) không được cập nhật: không do thay đổi của story này.

## Implementation Notes

- File wrapper lấy từ cache Flutter (`bin/cache/artifacts/gradle_wrapper`), giống từng byte. JAR có manifest Gradle 2.10 (checksum khớp bản chính thức nên `wrapper-validation` nhận) và vẫn đọc `distributionSha256Sum`. Chưa kiểm cục bộ được rằng Flutter giữ nguyên file đã commit lúc build (máy không có Android SDK).
- Sau review: thêm bước riêng `dart run tool/ci/ci_structure.dart` vào job `android` để luật cấu trúc không phụ thuộc bước `flutter test` mà nó bảo vệ. Lệnh cổng neo cả dòng; dòng kiểm APK chỉ nhận `--expect-id`/`--save-raw`, thêm cờ mới cho `check_android_apk.sh` phải sửa luật.
- Luật cấm `if:` trên bước cổng mâu thuẫn với ý tưởng hoãn "thêm `if: ${{ !cancelled() }}` cho bước kiểm APK dev" trong `deferred-work.md`; làm ý tưởng đó thì phải sửa luật.
- CI chưa chạy: người dùng tự push.

## Spec Change Log

## Review Triage Log

| # | Nguồn | Phát hiện | Verdict | Bằng chứng / Route |
|---|---|---|---|---|
| 1 | verify, blind | Luật cấu trúc chỉ chạy trong bước `flutter test` mà nó bảo vệ; sửa bước đó (`flutter test test/core` hoặc `continue-on-error: true`) tắt luật mà CI vẫn xanh | medium | Pre-verified; `ci.yml` không có bước `ci_structure.dart`. patch: thêm bước `dart run tool/ci/ci_structure.dart` vào job `android` + gate tương ứng + mục `_gates` trong test |
| 2 | verify, blind, edge | Xcode kiểm theo toàn file: một job macOS chuyển sang `xcode-select -s /Applications/Xcode.app` vẫn lọt cả hai kiểm | medium | Đã đọc `_xcodeGate` (chỉ cần `xcode-select -s`) và `checkToolchain` (gom `Xcode_*.app` toàn file). patch: `_xcodeGate` đòi `xcode-select -s …Xcode_<ver>.app` trong mỗi job macOS |
| 3 | blind, edge | `if:`/`continue-on-error:` cấp bước viết dạng khối (`if: >-`) không được ghi vào `keys`, cổng bị tắt mà luật không báo | medium | Đã đọc nhánh `default:` của `parseCiWorkflow`: giá trị khối chỉ đặt `block = 'skip'`. patch: ghi giá trị khác null (vd nội dung khối) để bị coi là `if:` |
| 4 | blind, edge | Lệnh cổng thêm `\|\| true`/`; true` vẫn khớp (Stack, APK, revision không neo cuối dòng) | medium | Đã đọc regex `_stackGate`, `_isApkCheck` (`contains`), `_revisionRe`. patch: neo cuối dòng cho ba cổng như `_secretGate`; thêm kiểm âm |
| 5 | blind | `flutter test` thu hẹp bằng cờ (`--name`, `--tags`, `--total-shards`) vẫn được nhận | low | `_isFullFlutterTest` nhận mọi token `-…`. patch: chỉ nhận đúng `flutter test` không tham số |
| 6 | blind | Clone Flutter với `--branch` cứng (không `$FLUTTER_VERSION`) vẫn qua | low | `_cloneRe` không đòi biến. patch: clone phải dùng `--branch "$FLUTTER_VERSION"` |
| 7 | blind, verify, edge | `wrapper-validation` ở `integration-android` chỉ bị đòi khi `_callsGradle` nhận ra emulator runner; đổi cách chạy sẽ bỏ yêu cầu | low | Spec Always nêu rõ hai job `android`, `integration-android`. patch: đòi `_wrapperGate` cố định cho job `integration-android` |
| 8 | edge | Job cài Flutter qua `uses: subosito/flutter-action` không bị đòi clone+revision | low | `_mentionsFlutter` chỉ xét `commandText`, không xét `uses`. patch: xét cả `uses` |
| 9 | edge | Đổi `path` upload (vd `build/apk-raw-x`) vẫn qua vì dùng `contains` | low | patch: so đúng `pak_manager/build/apk-raw` |
| 10 | blind | JAR wrapper 2.10 bỏ qua `distributionSha256Sum` | false | `WrapperExecutor.class` và `Install.class` trong JAR có chuỗi `distributionSha256Sum`, nên JAR có đọc thuộc tính này. Đây cũng là JAR mà Flutter vẫn chép vào lúc build trước story này. reject |
| 11 | blind | `gradlew`/`gradlew.bat` là script đời 2015 | false | Đúng các file Flutter vẫn chép từ cache lúc build trước story (giống byte), không đổi hành vi CI. reject |
| 12 | blind, edge | Trigger thu hẹp bằng `types:`/chỉ `tags:` không bị bắt | low | Khó gặp; sửa cần thêm nhánh. reject |
| 13 | blind | `defaults.run.working-directory` đổi làm lệnh cổng trỏ chỗ khác | false | Lệnh cổng dùng đường dẫn tương đối `tool/ci/…` sẽ fail ồn ào, không âm thầm xanh. reject |
| 14 | blind, edge | Job cổng bị bỏ qua qua `needs:`; `strategy`/matrix `continue-on-error` | low | Khó gặp, sửa cần thêm luật mới. reject |
| 15 | blind, edge | `_pinnedUses` nhận comment bất kỳ; báo nhầm action cục bộ/`docker://`/reusable workflow | low | Repo chưa có các dạng này; nếu thêm sẽ fail ồn ào. reject |
| 16 | blind | Trạng thái story lệch giữa sprint-status, spec, deferred-work | false | Đúng vòng đời BMAD: step-05 đặt `done`; deferred-work theo dõi việc hoãn đã làm xong. reject |
| 17 | blind | Spec còn mục trống, số dòng Code Map lệch | low | Sửa bằng cách sửa spec. reject |
| 18 | blind | `ad12_run_missing_ci_or_props_returns_1` có thể rò trạng thái giữa vòng lặp khi fail | low | Chỉ ảnh hưởng thông báo khi test đã fail. reject |
| 19 | edge | `run: >` (folded) ghép dòng `\|\| true`; `shell: bash {0}`; anchor YAML; thụt lề `-   run:`; `runs-on` matrix | low | Khó gặp trong workflow này, sửa cần thêm nhánh parser. reject |
| 20 | edge | Upload không đặt `if-no-files-found: error` | low | Story 1.15 đã chủ ý giữ mặc định `warn` (triage 1.15 #11). reject |
| 21 | blind, edge | `_callsGradle` không nhận `flutter test integration_test`/`run`/`drive` | low | Thêm vào sẽ đòi wrapper ở job iOS (`integration-ios` chạy `flutter test integration_test`); cần nhánh theo runner. Hậu quả chính được #7 xử lý. reject |

## Design Notes

Không dùng gói `yaml`: luật cấu trúc là parser theo dòng chỉ cần nhận đúng hình dạng `ci.yml` của repo (job ở thụt 2, `- ` bước ở thụt 6, khóa bước ở thụt 8). Bước gọi Gradle = `run` chứa `flutter build apk`/`appbundle`/`gradlew`, hoặc `uses: reactivecircus/android-emulator-runner`. Nhận bước cổng theo nội dung (`run`/`uses`), không theo `name`, để đổi tên bước không làm lọt.

## Verification

**Commands:**
- `cd pak_manager && flutter analyze --fatal-infos --fatal-warnings` -- expected: sạch
- `cd pak_manager && flutter test test/tool/` -- expected: pass
- `cd pak_manager && dart run tool/ci/check_stack.dart` -- expected: `OK`
- `cd pak_manager && dart run tool/ci/check_workflow_secrets.dart ../.github/workflows/ci.yml` -- expected: `OK`

**Manual checks (if no CLI):**
- Người dùng push và chạy CI: `android`, `integration-android` xanh, bước `wrapper-validation` chạy trước bước Gradle đầu tiên.
