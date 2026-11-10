---
title: 'Story 1.5 — Luật mật khẩu chính và đánh giá độ mạnh'
type: 'feature'
created: '2026-11-10'
status: 'done'
route: 'dispatch'
baseline_commit: 'e470e4cfa7342566a2c18155f24e38f195d6789d'
review_loop_iteration: 0
context:
  - '{project-root}/_bmad-output/implementation-artifacts/epic-1-context.md'
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** Chưa có nơi nào kiểm tra mật khẩu chính/export (FR-2, FR-52) hay đánh giá độ mạnh. Story 1.6 (tạo tài khoản), 5.3 (đổi mật khẩu) và 6.2 (export) cần chung một luật theo AD-15, kèm blocklist offline.

**Approach:** Thêm `core/policy/` thuần Dart: `PasswordPolicy` trả kết quả sealed theo thứ tự AD-15, `BlocklistFilter` đọc Bloom filter, `StrengthEstimator` bọc `zxcvbnm` 1.1.1. Thêm script `tool/blocklist/` tải danh sách SecLists ghim commit, sinh `assets/blocklist.bloom` + `FORMAT.md` + mẫu kiểm thử.

## Boundaries & Constraints

**Always:**
- `lib/core/policy/` là Dart thuần, chỉ import `zxcvbnm` ngoài SDK; không `dart:io`, không Flutter. Policy không ném, không giữ chuỗi mật khẩu sau khi trả kết quả.
- Thứ tự lỗi: không ASCII (ký tự ngoài 0x20–0x7E) → độ dài (< 15 `tooShort(n)`, > 128 `tooLong`) → phổ biến (blocklist, so trên bản chữ thường) → lặp/tuần tự. Không luật thành phần (chữ hoa/số/ký hiệu).
- Lặp/tuần tự xét **cả chuỗi**: cả chuỗi là một ký tự lặp (chữ cái không phân biệt hoa thường); hoặc cả chuỗi toàn chữ số, hoặc toàn chữ cái (không phân biệt hoa thường), mỗi bước cùng là +1 hoặc cùng là −1, vòng quanh (`9→0`, `z→a`).
- Độ mạnh: điểm `zxcvbnm` 0–2 → `low`, 3 → `medium`, 4 → `high`; từ điển `en` của gói (đã gồm `common`). Không dùng chung với FR-34.
- Blocklist: nguồn và commit ghi trong `tool/blocklist/SOURCE`; chỉ giữ dòng ASCII in được dài 15–128 sau khi bỏ `\r`, chuyển chữ thường, khử trùng. Asset ≤ 2 MB, tỷ lệ dương tính giả thiết kế ≤ 0,1%. Script tất định: cùng nguồn → cùng byte.
- Tên test gắn FR/AD (`fr02_…`, `ad15_…`); test chỉ dùng fake tự viết, dữ liệu giả.

**Never:** Không làm UI, chuỗi ARB `pw.*`, nạp asset bằng `rootBundle` hay provider (story 1.6). Không thêm package ngoài Stack. Không gọi mạng trong `lib/` hay CI (asset được commit; CI không tải lại SecLists).

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Hợp lệ, chỉ chữ thường + khoảng trắng | `correct horse battery staple` (không trong blocklist) | `PasswordOk` | N/A |
| Không ASCII, kể cả khi quá ngắn | `mậtkhẩu`, `aé`, `\t` + 20 ký tự | `nonAscii` | ưu tiên trước độ dài |
| Độ dài | 14 ký tự; 15; 128; 129 | `tooShort(14)`; ok; ok; `tooLong` | — |
| Phổ biến | một dòng mẫu trong nguồn, viết HOA hoặc trộn hoa thường | `common` | ưu tiên trước lặp/tuần tự |
| Lặp | `aaaaaaaaaaaaaaa`, `aAaAaAaAaAaAaAa`, 15 khoảng trắng | `pattern` | — |
| Tuần tự | `123456789012345`, `987654321098765`, `abcdefghijklmno`, `XYZABCDEFGHIJKL` | `pattern` | — |
| Không phải tuần tự | `1234567890123456 x`, `abcabcabcabcabc`, `13579135791357 9` | không phải `pattern` | — |
| Bloom hỏng | bytes rỗng, sai magic/version, `k`=0, độ dài mảng bit ≠ header | `BlocklistFilter.parse` → `null` | không ném |
| Độ mạnh | `""`; `password`; `vortex lunar pickle magnet 7 drizzle` | `low`; `low`; `high` (ánh xạ 0–2/3/4 test riêng bằng hàm `strengthForScore`) | — |

## Decisions

- **Độ dài spec (người dùng chọn 2026-11-10):** giữ một spec (~3.700 token) dù vượt mức 1.600; không tách script blocklist.
- **Git:** làm trên nhánh `feat/1-5-password-policy` tạo từ `main` (`e470e4c`). Commit/push do bước sau của workflow, không làm trong lúc implement.

</frozen-after-approval>

## Code Map

- `pak_manager/pubspec.yaml` -- thêm `zxcvbnm: 1.1.1` (ghim, AD-12) và mục `flutter: assets: [assets/blocklist.bloom]`; lock do `flutter pub get` sinh. Gói kéo theo `algorithmic` 0.0.11 và `intl` (< 0.21; lock hiện có `intl` transitive qua `flutter_localizations`). Nếu xung đột `intl` thì HALT (spine:546 cho phép vendor, nhưng phải hỏi).
- `pak_manager/tool/check_imports.dart:151` -- `_coreAllowedPackages` đã có `zxcvbnm`; `lib/features` đã được import `core/policy` (:165). Không sửa.
- `pak_manager/lib/core/policy/.gitkeep`, `tool/blocklist/.gitkeep`, `assets/.gitkeep` -- xóa khi thêm file thật.
- `pak_manager/lib/core/crypto/random_source.dart` -- mẫu phong cách (`abstract interface`, doc tiếng Việt, `final class`).
- `pak_manager/tool/fixtures/gen_vault_v1.dart` -- mẫu script tool: guard chạy trong `pak_manager/`, ghi README, chạy hai lần ra cùng byte.
- `.gitattributes` -- thêm `pak_manager/assets/*.bloom binary`.
- `.github/workflows/ci.yml` -- không sửa (Never: CI không tải SecLists).
- API `zxcvbnm` 1.1.1 (đã đọc tarball): `Zxcvbnm(options: Options(dictionaries: en.dictionaries))`, `zxcvbnm(password).score` (int 0–4); `package:zxcvbnm/languages/en.dart` export `dictionaries`. **Bẫy hiệu năng:** `call()` luôn gọi `options.copyWith(userInputs: …)` tạo `Options` mới nên dựng lại từ điển xếp hạng mỗi lần; `Options` không `final`, nên dùng lớp con có `copyWith` trả `this` khi mọi tham số `null` (giữ cache `rankedDictionaries`).

## Tasks & Acceptance

**Execution:**
- [x] Nhánh `feat/1-5-password-policy` từ `main`; `pak_manager/pubspec.yaml`, `pubspec.lock` -- thêm `zxcvbnm`, khai báo asset.
- [x] `pak_manager/tool/blocklist/SOURCE` -- repo `danielmiessler/SecLists`, commit `a1a06ab57c3f4efc450d80738a72c11597aac81a`, danh sách đường dẫn nguồn (xem Design Notes), giấy phép MIT.
- [x] `pak_manager/tool/blocklist/build_blocklist.dart` -- đọc `SOURCE`, tải từng file qua `https://raw.githubusercontent.com/<repo>/<commit>/<path>` (giải nén `.tar.gz` một file bằng `gzip` + đọc tar), lọc theo Always, sắp xếp, dựng Bloom theo `FORMAT.md`, ghi `assets/blocklist.bloom`, `assets/blocklist.FORMAT.md`, và `test/fixtures/blocklist/sample.txt` (500 mục chọn tất định: mỗi mục thứ ⌊n/500⌋ của danh sách đã sắp xếp). Không import `lib/`. Lỗi mạng/định dạng → exit ≠ 0, không ghi đè asset. Asset vượt 2 MB → exit ≠ 0.
- [x] `pak_manager/lib/core/policy/blocklist_filter.dart` -- `BlocklistFilter.parse(Uint8List) → BlocklistFilter?`, `bool contains(String lowerAscii)`; cài đặt MurmurHash3 x86_32 độc lập với script.
- [x] `pak_manager/lib/core/policy/password_policy.dart` -- sealed `PasswordCheck` (`PasswordOk`, `PasswordNonAscii`, `PasswordTooShort(int length)`, `PasswordTooLong`, `PasswordCommon`, `PasswordPattern`); `PasswordPolicy(BlocklistFilter)`.`check(String)`; hằng `minLength=15`, `maxLength=128`; `static bool meetsLoginGate(String)` (ASCII in được và ≥ 15, cho S3/S25 theo AD-15).
- [x] `pak_manager/lib/core/policy/strength_estimator.dart` -- `enum PasswordStrength {low, medium, high}`, `StrengthEstimator.estimate(String) → PasswordStrength`; một instance `Zxcvbnm` dùng lại, `Options` cache như Code Map.
- [x] `pak_manager/assets/blocklist.bloom`, `assets/blocklist.FORMAT.md`, `test/fixtures/blocklist/sample.txt` -- sinh bằng script, commit.
- [x] Test: `test/core/policy/{password_policy,blocklist_filter,strength_estimator}_test.dart`, `test/tool/build_blocklist_test.dart` (hàm Bloom/Murmur của script khớp core trên vector chuẩn và cùng chuỗi). Phủ mọi dòng Matrix.

**Acceptance Criteria:**
- Given `assets/blocklist.bloom` đã commit, when parse và tra mọi dòng trong `sample.txt` (kể cả bản viết HOA), then `PasswordPolicy.check` trả `PasswordCommon` cho từng dòng; và asset ≤ 2 097 152 byte.
- Given 100 000 chuỗi ASCII ngẫu nhiên dài 20 (sinh tất định trong test) không có trong nguồn, when tra filter, then số dương tính ≤ 150 (0,15%, biên cho dao động quanh 0,1%).
- Given MurmurHash3 x86_32, when băm các vector chuẩn công khai (`""`/0 → `0x00000000`, `""`/1 → `0x514E28B7`, `"test"`/0 → `0xBA6BD213`, `"The quick brown fox jumps over the lazy dog"`/0 → `0x2E4FF723`), then core và script đều ra đúng giá trị.
- Given `StrengthEstimator`, when gọi 2 lần liên tiếp với chuỗi 128 ký tự, then lần thứ hai không dựng lại từ điển (ghi số đo vào Implementation Notes). Ngưỡng tuyệt đối 50 ms đã bỏ (người dùng chọn 2026-11-10): thời gian khớp mẫu của `zxcvbnm` phụ thuộc nội dung; chuyển việc tránh giật UI sang story 1.6 qua `deferred-work.md`.
- Given `meetsLoginGate`, when chuỗi 14 ký tự hoặc có ký tự không ASCII, then `false`; 15 ký tự ASCII → `true`.

## Implementation Notes

- **Dependency:** `zxcvbnm: 1.1.1` ghim; lock thêm `zxcvbnm` (direct) và `algorithmic` 0.0.11 (transitive). `intl` giữ nguyên 0.20.3, không xung đột. Asset khai báo trong `flutter: assets:`. `.gitattributes` thêm `pak_manager/assets/*.bloom binary`; `sample.txt` đã nằm dưới `test/fixtures/** -text`.
- **Blocklist sinh ra:** n = **647 380** (khớp đếm lúc lập spec), mBits = 9 307 763, k = 10, asset 1 163 491 byte (≤ 2 097 152). Số dòng hợp lệ trước khử trùng: Pwdb 124 037, xato 141 032, rockyou 399 299 (spec ghi số đã khử trùng trong từng file nên lệch nhẹ; tổng hợp sau khử trùng khớp). Mục mẫu đầu tiên là 15 khoảng trắng: chuỗi này có trong blocklist thật, nên với asset thật nó ra `common` (ưu tiên trước `pattern`); test luật lặp/tuần tự dùng filter giả rỗng.
- **Tất định:** chạy script hai lần, SHA-256 của `blocklist.bloom`, `blocklist.FORMAT.md`, `sample.txt` không đổi. Script ghi file qua `.tmp` + rename, chỉ sau khi tải/lọc/dựng xong và qua kiểm 2 MiB.
- **`dart run` trên máy dev Windows:** `dart run …` và `flutter test` kích hoạt build hook của `sodium`, hook đòi Visual Studio (`vswhere`) mà máy hiện không có. Script chỉ dùng SDK nên đã chạy bằng `dart tool/blocklist/build_blocklist.dart` (không qua hook); trên Linux/CI `dart run` chạy bình thường.
- **MurmurHash3:** core (`murmur3X86x32`) và script (`murmur3`) cài độc lập (cách nhân 32-bit tách nửa 16 bit khác nhau, xử lý đuôi khác nhau); cả hai khớp 4 vector của spec cùng 6 vector công khai khác (seed `0xFFFFFFFF`, `"Hello, world!"`/1234, đuôi 1–3 byte), đã đối chiếu với bản Python tham chiếu thứ ba. Test so hai bản trên 500 dòng mẫu + 2 000 chuỗi ngẫu nhiên với seed ngẫu nhiên.
- **Dương tính giả:** 100 000 chuỗi ngẫu nhiên dài 20 → test qua ngưỡng 150 (lý thuyết 0,1000%).
- **`StrengthEstimator` và AC hiệu năng (đo bằng `flutter test`, JIT, máy dev Windows):** cache `Options` hoạt động: lớp con `_ReusableOptions.copyWith()` trả `this` khi mọi tham số `null`. Dựng từ điển `en` ≈ 25–31 ms; gọi có cache với chuỗi ngắn ≈ 2 ms; bản gốc không cache với chuỗi 128 ký tự ≈ 104–121 ms. Lần gọi thứ hai (có cache) với chuỗi 128 ký tự: passphrase chữ thường + khoảng trắng ≈ 36–37 ms, chữ thường ngẫu nhiên ≈ 8 ms, **ASCII in được ngẫu nhiên nhiều ký hiệu ≈ 80–99 ms**. Phần còn lại là chi phí khớp mẫu của `zxcvbnm` (chủ yếu matcher l33t: với `l33tMaxSubstitutions: 0` giảm còn ≈ 34 ms), không phải dựng lại từ điển. Không đổi tham số l33t vì sẽ đổi cách chấm điểm (spec không cho phép). Do đó ngưỡng ≤ 50 ms đạt với passphrase/chữ thường nhưng **không đạt** với chuỗi 128 ký tự nhiều ký hiệu trên JIT; bản release AOT chưa đo. Test `ad15_dictionaries_not_rebuilt_on_second_call` kiểm tính chất cache bằng tỷ lệ cùng máy (gọi có cache < ¼ thời gian dựng từ điển), không dùng ngưỡng tuyệt đối; đã thử đột biến (bỏ override) thì test đỏ.
- **`Options.currentYear`** của `zxcvbnm` được tính lúc tạo instance; dùng lại một instance thì năm không cập nhật nếu app chạy qua giao thừa (ảnh hưởng nhỏ tới ước lượng ngày tháng).
- **Verification (máy dev, 2026-11-10):** `flutter pub get --enforce-lockfile` OK; `flutter analyze --fatal-infos --fatal-warnings` 0 issue; `dart tool/check_imports.dart` OK; script chạy hai lần ra cùng byte. `flutter test` toàn repo **không chạy được trên máy này** (build hook `sodium` thiếu Visual Studio Build Tools); 40 test mới (`test/core/policy/*`, `test/tool/build_blocklist_test.dart`) chạy pass trong bản sao tối giản của package (chỉ `zxcvbnm`, không `sodium`) ở scratchpad. Test cũ không bị đụng tới. Cần CI để xác nhận toàn bộ.
- **Kiểm lại ở bước verify (2026-11-10):** `flutter test` toàn repo xác nhận lỗi hook `sodium` (`Unable to find vswhere`). Cài lại VS 2022 Build Tools qua winget bị hủy (mã 1602); người dùng chọn dựa vào CI cho toàn bộ suite. Chạy lại độc lập 40 test mới trong bản sao không `sodium`: 40/40 pass. `flutter analyze --fatal-infos --fatal-warnings` 0 issue, `check_imports` OK trên repo thật.

## Spec Change Log

## Review Triage Log

Review 2026-11-10 (diff `e470e4c..` cây làm việc, bỏ `blocklist.bloom`/`sample.txt`; 3 lớp: blind, edge, verif-gap — verif-gap không có phát hiện).

| # | Nguồn | Phát hiện | Verdict | Bằng chứng | Route |
|---|-------|-----------|---------|------------|-------|
| 1 | blind | Cuối spec còn thẻ `</content>`/`</invoke>` thừa | low | Có thật (lỗi lúc ghi spec); đã xóa ngay, sửa là sửa spec | reject |
| 2 | blind | Sprint `in-progress` lệch spec `in-review` | false | Đúng thiết kế: bước trình bày đồng bộ sprint-status (như 1.4 #21) | reject |
| 3 | blind | Đổi AC hiệu năng mà Spec Change Log trống; Matrix ghi 15 khoảng trắng → `pattern` | false | Change Log chỉ cho loopback bad_spec; đổi AC do người dùng chọn đã ghi trong AC và deferred-work. Dòng Matrix là luật `pattern` khi tách riêng; với asset thật `common` đứng trước đúng thứ tự AD-15 | reject |
| 4 | blind | Mục deferred thiếu `status:`; thiếu mục CI chưa chạy, thời gian AOT, `currentYear` | low/maybe-false | Mẫu deferred không có `status` cho mục mở. Thời gian release đã nằm trong mục deferred 1.6. Toàn bộ suite chưa chạy cục bộ: maybe-false, nếu đúng là medium → defer. `currentYear` lệch qua giao thừa: chỉ ảnh hưởng ước lượng ngày tháng, sửa cần thêm cơ chế làm mới | defer (suite) / reject (còn lại) |
| 5 | blind | Verification ghi `flutter test` pass dù chưa chạy toàn bộ | false | Verification liệt kê lệnh cần chạy, không phải kết quả; Implementation Notes nói rõ chưa chạy và chờ CI | reject |
| 6 | blind | Chưa quyết định khi asset blocklist thiếu/hỏng (`parse` → `null`) | medium | `PasswordPolicy` bắt buộc filter non-null; người nạp asset là story 1.6 (Never của spec). Mỗi caller có thể tự xử theo kiểu khác | defer |
| 7 | blind | Không kiểm SHA-256 file tải; tar không kiểm checksum header | low | URL raw ghim theo commit SHA là bất biến; tar hỏng làm size/định dạng lệch thì đã ném. Sửa cần thêm trường SOURCE và nhánh | reject |
| 8 | blind, edge | Ghi 3 file lần lượt: lỗi ở file 2/3 để lại bộ file lệch và `.tmp` | low | Có thật nhưng chỉ ở script dev, chạy lại là khắc phục; sửa phải dựng lại luồng ghi | reject |
| 9 | blind | Tài liệu ghi `dart run …`, lệnh này lỗi trên máy dev Windows (hook `sodium`) | low | Implementation Notes xác nhận; sửa là đổi chữ | patch |
| 10 | blind, edge | Test cache dựa trên tỷ lệ thời gian, có thể chập chờn trên CI | low | Lấy min của 5 và 3 lần đo; biên ≈12× (2 ms vs 25 ms) so với ngưỡng 4×. Kiểm cấu trúc cần lộ `options` riêng tư | reject |
| 11 | blind | Không hỗ trợ `userInputs` cho zxcvbnm | false | AD-15/FR-2 không yêu cầu; không có caller | reject |
| 12 | blind, edge | `parseSource` nhận khóa trùng | low | `SOURCE` do dev sửa, có test; sửa cần thêm guard | reject |
| 13 | blind | `contains` để bản chữ thường của mật khẩu trong `Uint8List` không wipe | medium | Trái AD-22 (ghi 0 `Uint8List` bản rõ) và Always "không giữ chuỗi mật khẩu"; sửa một `finally` | patch |
| 14 | blind | Test `fr52_…` không kiểm gì riêng cho export | false | Ý của AD-15 là export dùng cùng policy; test ghi lại điều đó, không có hậu quả xấu | reject |
| 15 | blind | `PasswordCheck` không có `==`/`toString` | low | Chưa caller nào so sánh; thêm là thêm public surface | reject |
| 16 | blind, edge | Test dương tính giả chỉ loại 500 dòng mẫu, không loại cả nguồn | false | Chuỗi ngẫu nhiên nằm trong nguồn chỉ làm test chặt hơn, không lỏng hơn; xác suất ≈ 0 | reject |
| 17 | edge | `HttpClient` không có timeout, script có thể treo | low | Script dev, chạy tay, Ctrl-C được; sửa thêm guard | reject |
| 18 | edge | Nguồn nén định dạng lạ bị đọc như text | low | `SOURCE` do dev kiểm soát và có test ghim danh sách; sửa thêm guard | reject |
| 19 | edge | `contains` với chữ HOA từ caller khác cho âm tính giả | false | Hợp đồng ghi rõ người gọi phải chuyển chữ thường; AD-15 cho `PasswordPolicy` là caller duy nhất | reject |

## Design Notes

- **Định dạng Bloom (little-endian):** `PAKB`[4] · version u8 = 1 · k u8 · reserved u16 = 0 · mBits u32 · n u32 · seed u32 · bits[⌈mBits/8⌉]. Bit `i` ở byte `i>>3`, bit `i&7` (LSB trước). Chỉ số thứ `j` (0 ≤ j < k): `(h1 + j·h2) mod mBits` với `h1 = murmur3_32(s, seed)`, `h2 = murmur3_32(s, seed ^ 0x9E3779B9) | 1`, tính bằng số nguyên 64-bit không tràn. `s` là byte ASCII của chuỗi chữ thường. Tham số: p = 0,001 → `mBits = ⌈−n·ln p / (ln 2)²⌉`, `k = 10`; seed cố định `0x50414B31` ("PAK1").
- **Nguồn SecLists:** `Passwords/Common-Credentials/Pwdb_top-10000000.txt`, `Passwords/Common-Credentials/xato-net-10-million-passwords.txt`, `Passwords/Leaked-Databases/rockyou.txt.tar.gz` (tar chứa một file `rockyou.txt`). Đếm thử lúc lập spec (lọc như Always, khử trùng): 122 425 / 140 899 / 397 177, hợp **647 380** mục → ~9,31 Mbit ≈ 1,16 MB. Trần 2 MB ứng với n ≈ 1,16 triệu; vượt thì script fail, không tự hạ p.
- **Vì sao lặp/tuần tự xét cả chuỗi:** PRD nói "chỉ gồm một ký tự lặp lại hoặc một dãy tuần tự"; mẫu con (`aaa` trong passphrase) do `zxcvbnm` phạt qua độ mạnh, không chặn. Ví dụ `123456789012345` buộc phải vòng `9→0`.
- **Không chặn > 128 khi gõ:** policy trả `tooLong`; UI (1.6) quyết định cách hiện.

## Verification

**Commands (trong `pak_manager/`):**
- `flutter pub get --enforce-lockfile` -- resolve được.
- `dart run tool/blocklist/build_blocklist.dart` chạy hai lần; `git status --porcelain -- assets test/fixtures/blocklist` rỗng sau lần đầu đã commit.
- `flutter analyze --fatal-infos --fatal-warnings` -- 0 issue.
- `dart run tool/check_imports.dart` -- exit 0.
- `flutter test` -- mọi test pass.
