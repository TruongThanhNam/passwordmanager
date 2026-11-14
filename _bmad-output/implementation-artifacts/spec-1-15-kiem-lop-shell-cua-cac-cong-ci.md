---
title: 'Story 1.15: Kiểm lớp shell của các cổng CI'
type: 'chore'
created: '2026-11-13'
status: 'done'
baseline_commit: '9f95c415a8185406d5b9769cb1aa7ef3068f0fc3'
route: 'dispatch'
review_loop_iteration: 0
context: []
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** Luật của các cổng CI đã có kiểm âm, nhưng lớp shell gọi luật thì chưa: bỏ `$expect_id` khỏi `check_android_apk.sh`, đảo điều kiện `zipalign` hay khối so revision Flutter (đang lặp ở 4 job) đều không làm test nào đỏ. Fixture của `apk_rules_test.dart` là output viết tay, có thể lệch định dạng thật.

**Approach:** Thêm harness chạy `check_android_apk.sh` với công cụ giả; gom khối so revision Flutter vào một script có kiểm âm; cho CI lưu output thô của `aapt2`/`unzip`/`readelf` thành artifact rồi lấy chính artifact đó làm golden fixture cho `apk_rules_test.dart`.

## Boundaries & Constraints

**Always:**
- Làm hai pha. Pha A: script lưu output thô + bước upload artifact, commit, push nhánh `feat/1-15-ci-shell-gate-tests` (đã được duyệt), chờ job `android` xanh, tải artifact bằng `gh run download`. Pha B: golden fixture, harness, script revision, viết lại test.
- Golden nằm ở `test/fixtures/apk/{prod,dev}/` đúng cấu trúc `$work`, giữ nguyên từng byte; `test/fixtures/apk/SOURCE` ghi commit, run id và phiên bản build-tools.
- Ca kiểm âm của `apk_rules_test.dart` dựng bằng cách sửa golden (thay/chèn/xóa dòng); giữ nguyên tập luật được phủ hiện nay.
- Harness và test script revision cần `bash`: bỏ qua kèm lý do khi không có `bash` hoặc chạy trên Windows; khi `PAK_REQUIRE_SHELL_TESTS=1` (đặt ở bước `flutter test` của job `android`) thì thiếu `bash` là fail, không bỏ qua.
- Action mới ghim SHA đầy đủ kèm comment tag: `actions/upload-artifact@cf430e030ddbb5b0abf93d22962f4752f3646cd9 # v7.0.2`.
- Comment và thông báo tiếng Việt; tên test theo tiền tố AD/NFR.

**Never:**
- Không đổi luật trong `apk_rules.dart`, `check_stack.dart`, `check_workflow_secrets.dart`.
- Không thêm dependency Dart; không dùng thư viện mock.
- Không làm test cấu trúc `ci.yml` tổng quát, không ghim Gradle/Xcode (story 1.16).
- Không force-push, không push lên `main`.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| APK hợp lệ | công cụ giả phát golden prod, `--expect-id` prod | exit 0; `apk_rules.dart` nhận `<work> <id>`, `<work>` có `manifest.txt`, `listing.txt`, `badging.txt`, `readelf/<abi>/<so>.txt` | N/A |
| Sai applicationId | badging giả là id dev, kỳ vọng prod | exit ≠ 0 | in vi phạm |
| Vi phạm luật | manifest giả có `android.permission.INTERNET` | exit ≠ 0 | in vi phạm |
| zipalign lỗi | `zipalign` giả exit 1, phần còn lại hợp lệ | exit ≠ 0 | `FAIL: zipalign` |
| Lưu output thô | thêm `--save-raw <dir>` | `<dir>` có bản sao output thô và `build-tools.txt`, kể cả khi script fail | N/A |
| Revision khớp | `git` giả trả đúng revision của `.metadata` | exit 0 | N/A |
| Revision lệch | `git` giả trả revision khác | exit ≠ 0 | thông báo hai revision |
| Thiếu dòng revision | `.metadata` không có `  revision:` | exit ≠ 0 | thông báo |

</frozen-after-approval>

## Code Map

- `pak_manager/tool/ci/check_android_apk.sh` -- vòng `case` tham số (dòng 18-29), `trap` xóa `$work` (54), zipalign (58-65), thu thập output (69-82), gọi `dart run tool/ci/apk_rules.dart "${rule_args[@]}"` (86). Thêm `--save-raw`; không đổi phần còn lại.
- `pak_manager/tool/ci/apk_rules.dart` -- hợp đồng `<workDir> [expectedApplicationId]`; KHÔNG sửa.
- `pak_manager/test/tool/apk_rules_test.dart` -- helper viết tay `_manifest`, `_listing`, `_readelf`, `_badging`, `_goodPaths`, `_goodElf` (dòng 7-122): thay bằng đọc golden; giữ tên và ý nghĩa các ca.
- `.github/workflows/ci.yml` -- khối so revision lặp ở dòng 41-52, 145-156, 243-254, 291-302 (`defaults.run.working-directory: pak_manager`); bước kiểm APK prod/dev ở 121-128; bước `Unit + widget test` ở 115. Đường dẫn của `upload-artifact` tính từ gốc repo, không theo `working-directory`.
- `pak_manager/.metadata:7` -- `  revision: "737ba8f8…"` (có ngoặc kép); các dòng `create_revision` thụt sâu hơn nên `^  revision:` chỉ khớp một dòng.
- `.gitattributes` -- `pak_manager/test/fixtures/** -text` đã giữ byte cho fixture mới.
- `pak_manager/test/tool/check_stack_test.dart` -- mẫu quy ước test công cụ (import tương đối `../../tool/ci/…`, thư mục tạm).
- `_bmad-output/implementation-artifacts/deferred-work.md:145-172` -- năm mục `planned — story 1.15`.

## Tasks & Acceptance

**Execution:**
- [x] `pak_manager/tool/ci/check_android_apk.sh` -- thêm `--save-raw <dir>`: trước khi thoát (kể cả fail) chép `manifest.txt`, `listing.txt`, `badging.txt`, `zipalign.txt`, `readelf/` và ghi `build-tools.txt` vào `<dir>` -- nguồn artifact.
- [x] `.github/workflows/ci.yml` -- hai bước kiểm APK thêm `--save-raw build/apk-raw/{prod,dev}`; thêm bước `upload-artifact` (tên `apk-raw-output`, `if: ${{ !cancelled() }}`, `retention-days: 14`) -- pha A, rồi commit + push + chờ CI + tải artifact.
- [x] `pak_manager/test/fixtures/apk/{prod,dev}/**`, `pak_manager/test/fixtures/apk/SOURCE` -- golden từ artifact, không sửa tay.
- [x] `pak_manager/tool/ci/check_flutter_revision.sh` -- `<thư-mục-flutter> [file-metadata=.metadata]`, `set -euo pipefail`, cùng logic khối hiện tại -- một nguồn duy nhất.
- [x] `.github/workflows/ci.yml` -- 4 job gọi `bash tool/ci/check_flutter_revision.sh "$RUNNER_TEMP/flutter"`; xóa khối lặp; đặt `PAK_REQUIRE_SHELL_TESTS: '1'` cho bước `flutter test`.
- [x] `pak_manager/test/tool/shell_harness.dart` -- helper dùng chung: tìm `bash`, quyết định bỏ qua/fail, tạo thư mục công cụ giả (script bash đọc biến môi trường), chạy script với `PATH`/`ANDROID_HOME` tạm.
- [x] `pak_manager/test/tool/check_android_apk_sh_test.dart` -- các ca APK trong ma trận; `dart` giả ghi lại tham số và cây `$work` rồi gọi `dart` thật.
- [x] `pak_manager/test/tool/check_flutter_revision_sh_test.dart` -- ba ca revision; thêm ca đọc `ci.yml`: không còn `rev-parse HEAD`, số lần gọi script bằng số lần `git clone` Flutter.
- [x] `pak_manager/test/tool/apk_rules_test.dart` -- chuyển sang golden prod và dev; kiểm âm bằng cách sửa golden.
- [x] `_bmad-output/implementation-artifacts/deferred-work.md` -- năm mục `planned — story 1.15` → `done — story 1.15`.

**Acceptance Criteria:**
- Given nhánh đã push, when CI chạy, then cả 4 job xanh, job `android` chạy harness (không bỏ qua) và lần chạy có artifact `apk-raw-output` chứa output prod và dev.
- Given bỏ `rule_args+=("$expect_id")` hoặc `failed=1` của zipalign trong script, when chạy harness trên máy có `bash`, then có test đỏ.
- Given golden prod và dev, when `flutter test test/tool/apk_rules_test.dart`, then pass và file test không còn hàm dựng output viết tay.


### Review Findings

- [x] [Review][Defer] AC1: `integration-ios` chưa xanh (3/4 job) [.github/workflows/ci.yml] — resolved: theo người dùng báo 2026-11-14, cả 4 job đều xanh sau commit 1006917
- [x] [Review][Patch] Test partial readelf không kiểm các `.so` đã thu thập trước chỗ fail (`readelf_done`) được lưu; nên xóa fixture của .so cuối theo thứ tự glob và khẳng định các .so trước đó có trong save-raw [pak_manager/test/tool/check_android_apk_sh_test.dart:238]
- [x] [Review][Patch] `unzip` giả không ghi log tham số; bỏ `-o`/`-q`/`'lib/*'` trong script không làm test nào đỏ — dùng `_logArgs` và khẳng định cả hai lời gọi [pak_manager/test/tool/shell_harness.dart:124]
- [x] [Review][Patch] Chưa kiểm `$work` được dọn khi script fail (trap `finish`) — thêm khẳng định ở ca fail [pak_manager/test/tool/check_android_apk_sh_test.dart]
- [x] [Review][Patch] `git rev-parse` fail thì thoát với lỗi git thô, không có thông báo của cổng — thêm `|| { echo ... >&2; exit 1; }` [pak_manager/tool/ci/check_flutter_revision.sh:22]
- [x] [Review][Defer] Chưa có test đọc `ci.yml` để giữ `PAK_REQUIRE_SHELL_TESTS: '1'`, `--save-raw` và bước upload [.github/workflows/ci.yml] — deferred: thuộc test cấu trúc ci.yml của story 1.16
- [x] [Review][Defer] Khi kiểm APK prod fail, bước build/kiểm dev bị bỏ nên artifact thiếu output thô dev [.github/workflows/ci.yml] — deferred: đổi luồng job, ngoài phạm vi 1.15

**Rejected**
- Rejected (low): `expected` có thể nhiều dòng nếu dòng revision chứa 2 SHA — `.metadata` do Flutter sinh chỉ có một SHA.
- Rejected (low): `copyTree` hỏng khi đường dẫn có `/` cuối — mọi caller truyền đường dẫn không có `/` cuối.
- Rejected (low): `detectShell` coi file không thực thi tên bash là có bash — hiếm gặp; vẫn fail ồn ào.
- Rejected (low): harness kế thừa env cha (`PAK_FAKE_*`, PATH thật) — không ai đặt các biến này ngoài test.
- Rejected (low): `zipalign_ok=1` ở nhánh fail — chủ ý: output khi fail là thứ cần lưu để debug.
- Rejected (low): `finish()` im lặng khi cp lỗi — hiếm (hết đĩa), cần thêm nhánh.
- Rejected (low): `build-tools.txt` golden (37.0.0) khác bản giả (36.1.0) — không ảnh hưởng luật nào.
- Rejected (low): setup fail gây `LateInitializationError` và rò thư mục tạm — chỉ khi chmod lỗi.
- Rejected (low): test shell bị bỏ qua trên Windows — đúng ràng buộc spec.
- Rejected (low): dòng INTERNET viết tay trong test shell — ràng buộc sửa golden áp cho `apk_rules_test.dart`.
- Rejected (low): spec `done` khác sprint `review`; sửa `deferred-work.md`/tài liệu planning ngoài phạm vi — chỉ là sổ sách, không có hại cụ thể.
- Rejected (false): commit 6894443 nói "xóa sạch thư mục" — commit f7d97ef đã đính chính, code chỉ xóa file do script ghi.

## Implementation Notes

- `ci.yml` chỉ chạy trên `pull_request` và push lên `main`, nên pha A phải mở PR nháp #15 thì CI mới chạy; push nhánh không thôi là không đủ.
- Golden lấy từ run `43451120658` (commit `843205e`, build-tools 37.0.0).
- Fake `git` không được đặt trước `PATH` khi chạy `check_android_apk.sh`: wrapper `dart` của Flutter SDK tự gọi `git`. Chỉ test revision dùng `fakeGit: true`.
- Sau review: `finish()` dùng cờ thu thập thành công thay vì `-f`. Khi dọn `--save-raw` thì chỉ xóa đúng các file script ghi, không `rm -rf` cả thư mục (người dùng có thể truyền `.` hay `build`); có test kiểm file lạ được giữ.
- `integration-ios` fail ở lần chạy lại của pha A (`Connecting to the VM Service timed out` sau khi build Xcode xong) và bị hủy ở cả hai lần thử của pha B. Ở commit pha A, job này giống hệt `main`, và trên `main` nó xanh tới 12/11, nên lỗi nằm ở runner/simulator macOS chứ không phải ở story này. Ba job còn lại xanh, và harness shell đã chạy thật trên ubuntu (không bị bỏ qua).

## Spec Change Log

## Review Triage Log

| # | Nguồn | Phát hiện | Verdict | Bằng chứng / Route |
|---|---|---|---|---|
| 1 | verify, blind, edge | `finish()` copy theo `-f` nên nhầm file rỗng/một phần (do redirect `>` tạo file trước khi lệnh chạy) với output thật khi `aapt2`/`unzip`/`readelf` lỗi giữa chừng; không test nào ép một lệnh thu thập lỗi để kiểm `--save-raw` | medium | verification-gap đã xác minh sẵn (pre-verified); edge-case-hunter chỉ ra cơ chế redirect tạo file rỗng. patch: `finish()` phân biệt "đã thu thập" với "file tồn tại"; thêm ca ép `readelf` lỗi (xóa một file `readelf/*.txt` trong fixture copy), kiểm `--save-raw` vẫn có `build-tools.txt`/những gì thu được trước đó, exit khác 0, không có `dart_args.txt` |
| 2 | blind, edge | `finish()` không dọn `$save_raw` trước khi ghi (chỉ `readelf/` có `rm -rf`): dùng lại cùng `--save-raw` với cờ khác (vd bỏ `--expect-id`) để lại `badging.txt` cũ; lỗi `mkdir`/`cp` trong trap (dưới `set -e`) có thể chặn `rm -rf "$work"` | low | Không tái hiện được trong `ci.yml` hiện tại (mỗi flavor luôn dùng `--expect-id` và thư mục riêng), nhưng sửa trực tiếp, không thêm độ phức tạp. patch: dọn `$save_raw` trước khi ghi; tách `rm -rf "$work"` khỏi phần có thể lỗi của `finish()` |
| 3 | blind | Công cụ giả (`_logCall` dùng `$*`, `aapt2`/`readelf` giả chỉ khớp 2 từ đầu) không phát hiện được cờ bị bỏ (vd mất `--file AndroidManifest.xml` hay `-lW`) — đúng loại lỗi câu Intent nêu ("một tham số bị bỏ sót... không được âm thầm tắt cổng") | medium | Đã đọc `shell_harness.dart`: `_fakeAapt2` dùng `case "${1:-} ${2:-}"`, `_fakeReadelf` dùng `"${*: -1}"`, không kiểm cờ còn lại. patch: ghi tham số một dòng một (như `_fakeDart`), kiểm đúng câu lệnh `aapt2 dump xmltree --file AndroidManifest.xml <apk>`, `aapt2 dump badging <apk>`, `readelf -lW <so>` trong ca APK hợp lệ |
| 4 | blind | `--save-raw` thiếu giá trị (`--save-raw` ở cuối, không có thư mục) không có ca kiểm | low | Xác nhận: không có ca nào trong `check_android_apk_sh_test.dart`. patch: thêm ca như `ad19_unknown_argument_exit_nonzero` nhưng cho `--save-raw` thiếu giá trị |
| 5 | blind | `build-tools` giả chỉ có `34.0.0` (rỗng) và `36.1.0`: `sort` thường (không `-V`) vẫn chọn đúng `36.1.0`, không chứng minh được `sort -V` | low | Xác nhận bằng cách đọc `FakeTools.create()`. patch: thêm thư mục build-tools thứ ba kiểu `9.0.0` (có công cụ) để lệch thứ tự giữa sort thường và sort version, giữ assertion chọn `$fakeBuildToolsVersion` |
| 6 | blind | `expectRawSaved` chỉ kiểm fixture có mặt trong `--save-raw`, không kiểm `--save-raw` không có file thừa | low | Thật nhưng giá trị thấp: cần đổi logic save-raw thực sự mới lọt qua. reject |
| 7 | blind | Golden `zipalign.txt` của ca `zipalign` lỗi không có dòng "BAD"/misalign thật, chỉ ép exit code | low | Đúng, nhưng cổng thật dựa vào exit code, không dựa vào nội dung in ra; dựng dòng BAD thật cần hiểu định dạng zipalign, không phải sửa trực tiếp. reject |
| 8 | blind | `ad12_ci_checks_revision_after_every_flutter_clone` đếm theo chuỗi con trên toàn file, dòng comment trùng chuỗi vẫn được tính | low | Thật nhưng khó gặp; kiểm cấu trúc `ci.yml` tổng quát đã được Intent giao cho story 1.16 (mục Never). reject |
| 9 | blind | `findOnPath` không kiểm quyền thực thi; `realDart = findOnPath('dart')!` có thể ném null-check nếu thiếu `dart` | low | `dart` luôn nằm cạnh `flutter` trong `flutter/bin` (chính `PATH` CI/dev thêm); kịch bản thiếu khó xảy ra, và lỗi vẫn fail rõ ràng chứ không âm thầm sai. reject |
| 10 | blind | `copyGolden` (apk_rules_test.dart) trùng `copyTree` (shell_harness.dart); `nfr7_shell_tests_run_when_required` lặp ở hai file `_sh_test.dart` | low | Thật nhưng không có hậu quả hành vi, thuộc phạm vi dọn trùng lặp (simplify), không phải lỗi. reject |
| 11 | blind | `upload-artifact` không đặt `if-no-files-found` | low | Mặc định `warn` đã đúng ý: build fail trước khi có output thì upload chỉ cảnh báo, không làm CI đỏ oan. reject |
| 12 | blind | Comment "một nguồn duy nhất cho cả bốn job CI" sẽ lệch nếu số job đổi | low | Comment, không ảnh hưởng hành vi. reject |
| 13 | blind | `ad19_run_good_work_dir_exit_0` dùng chung `work` cho cả hai flavor, không dọn giữa hai lần `copyGolden` | false | Đã so `find` đệ quy của `test/fixtures/apk/{prod,dev}`: hai cây có đúng cùng tập đường dẫn, nên `copyGolden` (ghi đè theo đường dẫn) ghi đè toàn bộ, không có file nào của prod còn sót khi copy dev |
| 14 | blind | `deferred-work.md` đánh dấu 5 mục `done — story 1.15` trong khi `sprint-status.yaml` vẫn `in-progress` | false | Hai hệ theo dõi khác việc: `deferred-work.md` theo dõi việc hoãn cụ thể đã xong hay chưa (đã xong), `sprint-status.yaml` theo dõi vòng đời cả story (đúng quy trình BMAD là `in-progress`/`in-review` tới khi step-05 đánh dấu `done`) |
| 15 | blind | Thiếu test cho các nhánh guard đã có từ trước (`check_android_apk.sh`): thiếu APK, `ANDROID_HOME` chưa đặt, thiếu `aapt2`/`zipalign`/`readelf`/`unzip`/`dart` | low (nếu đúng) | Các dòng guard này có từ trước story 1.15 (đối chiếu bản gốc script), không phải lỗi do thay đổi lần này. defer |
| 16 | blind | `epic-1-context.md` viết công việc của story 1.16 (bảng Stack Gradle/Xcode, kiểm `FLUTTER_VERSION`) ở thì đã xong, trong khi 1.16 còn `backlog` | low | Xác nhận bằng diff; nội dung này do một tác vụ biên dịch epic-context trước khi viết spec 1.15 tạo ra, không phải code của story này, và sẽ ảnh hưởng tới việc lập kế hoạch cho 1.16. Sửa trực tiếp văn bản `epic-1-context.md` sang thì tương lai, không qua vòng patch của implementer |
| 17 | blind | Không có hướng dẫn refresh golden khi Flutter/AGP/build-tools đổi; artifact hết hạn 14 ngày nên `run_id` trong `SOURCE` không còn tra được | low | Hại mơ hồ, không có kịch bản hỏng cụ thể; cải thiện tài liệu, không phải lỗi. reject |
| 18 | blind | `SOURCE`/`build-tools.txt` ghi phiên bản build-tools nguồn nhưng không có gì đối chiếu với build-tools runner đang dùng để phát hiện lệch | low | Không có kịch bản hỏng cụ thể (chỉ là tăng cường theo dõi trôi dạt); ngoài Tasks & Acceptance đã định. reject |

## Design Notes

Máy dev là Windows: `bash` trên `PATH` của tiến trình Dart có thể là WSL, và công cụ giả dạng shebang không chạy được, nên harness bỏ qua ở Windows và CI ubuntu là bằng chứng chính. Biến `PAK_REQUIRE_SHELL_TESTS` chặn việc harness âm thầm bỏ qua trên CI. Trước khi push, chạy tay script với công cụ giả trong Git Bash để bắt lỗi sớm.

Công cụ giả đọc thư mục fixture qua biến môi trường: `aapt2 dump xmltree` → `manifest.txt`, `dump badging` → `badging.txt`, `unzip -l` → `listing.txt`, `unzip … 'lib/*' -d` tạo file `.so` rỗng theo listing, `readelf -lW` → file tương ứng trong `readelf/`.

## Verification

**Commands:**
- `cd pak_manager && flutter analyze --fatal-infos --fatal-warnings` -- expected: sạch
- `cd pak_manager && flutter test` -- expected: pass (harness shell bỏ qua kèm lý do trên Windows)
- `cd pak_manager && dart run tool/ci/check_workflow_secrets.dart ../.github/workflows/ci.yml` -- expected: OK
- `gh run watch` trên nhánh -- expected: 4 job xanh

**Manual checks (if no CLI):**
- Log bước `Unit + widget test` của job `android` cho thấy các test `*_sh_test.dart` chạy, không bị bỏ qua.
