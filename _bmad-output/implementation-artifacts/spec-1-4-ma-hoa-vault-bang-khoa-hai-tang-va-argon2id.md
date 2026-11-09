---
title: 'Story 1.4 — Mã hóa vault bằng khóa hai tầng và Argon2id'
type: 'feature'
created: '2026-11-09'
status: 'done'
route: 'dispatch'
baseline_commit: '24abe79df9c0082e9c12d014b6e95a5826da8349'
review_loop_iteration: 0
context:
  - '{project-root}/_bmad-output/implementation-artifacts/epic-1-context.md'
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** Chưa có lớp crypto và codec cho `vault/`. Story 1.6/1.7 (tạo tài khoản, đăng nhập) cần sẵn KDF, header khóa hai tầng và codec `cards`/`recent` đúng hợp đồng AD-20; thiếu chúng thì file chép ra ngoài máy không được bảo vệ.

**Approach:** Thêm `sodium` 4.1.2 (`SodiumSumoInit`). Viết trong `lib/core/`: `RandomSource`, KDF Argon2id chạy trong isolate kèm hàm hiệu chỉnh, `header_codec` (checksum, kcv, bọc/mở DEK) và `vault_file_codec` (XChaCha20-Poly1305 + JSON v1), model `VaultCard`/`RecentEntry`. Thêm script `tool/fixtures/` sinh fixture `test/fixtures/vault/v1/` độc lập với code app, cùng golden test.

## Boundaries & Constraints

**Always:**
- Chỉ code Dart thuần trong `lib/core/` (không Flutter). Chỉ dùng `package:sodium/sodium_sumo.dart`. Mọi byte ngẫu nhiên lấy qua `RandomSource` (`randombytes.buf`).
- Codec và hàm crypto không ném qua ranh giới: lỗi đầu vào (kể cả `SodiumException`) trả `corrupt`/`null`, không kèm thông điệp.
- Ghi đè 0 mọi `Uint8List` chứa bản rõ (JSON plaintext, DEK đã mở bọc, bản sao mật khẩu trong isolate) ngay sau khi dùng. `toString()` của model chứa bí mật không lộ giá trị.
- Header 155 byte đúng layout AD-20, little-endian. Offset: magic 0, version 4, kdfAlg 6, opslimit 7, memlimit 11, salt 19, wrapNonce 35, wrappedDek 59, kcv 107, checksum 123. AD bọc DEK = byte [0,35). `checksum` trên [0,123).
- KDF: Argon2id13, `pwhash.callRaw`, outLen 32, chạy trong `Sodium.runIsolated`. Callback chạy trong zone nuốt `print` và bắt mọi lỗi (trả `null`), thay cho chính sách lỗi release mà isolate phụ không thừa hưởng.
- Tham số cho phép: ops ∈ [2,10], mem ∈ [19 MiB, 128 MiB] (byte, 1 MiB = 1 048 576). Ngoài khoảng thì từ chối trước khi gọi KDF.
- Script fixture không import `lib/` của app. Fixture là dữ liệu giả, sinh tất định.

**Never:** Không làm `AccountService`, `VaultSession`, `LockoutGuard`, ghi file vào `vault/` hay UI (story 1.6–1.8). Không làm codec `draft`/export (story 3.6/6.1). Không dùng `dart:math Random`, `Stopwatch` ngoài hàm hiệu chỉnh, hay package ngoài Stack.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Header hợp lệ, mật khẩu đúng | fixture `header` + mật khẩu fixture | decode ok → KDF → kcv khớp → mở bọc ra DEK fixture | N/A |
| Mật khẩu sai | header hợp lệ, mật khẩu khác | decode ok, kcv lệch → `wrongPassword` | so bằng `sodium.memcmp` |
| Header hỏng | dài ≠ 155; magic ≠ `PAKV`; version ≠ 1; checksum lệch (lật 1 byte bất kỳ trong [0,123) hoặc trong checksum); kdfAlg ≠ 1; ops/mem ngoài khoảng (checksum tính lại) | `corrupt` | KDF không chạy |
| DEK bọc bị sửa | lật byte `wrappedDek`, checksum tính lại | kcv khớp, mở bọc → `corrupt` | — |
| File dữ liệu hợp lệ | fixture `cards`/`recent` + DEK | đúng danh sách card/Recent giả | N/A |
| File dữ liệu hỏng | < 40 byte; tag sai; DEK khác; đổi AD (đọc `cards` như `recent`); JSON không hợp lệ; `v` ≠ 1; thiếu key; sai kiểu (note `null`, thời gian `3.0`/âm); id không phải UUIDv4 chữ thường | `corrupt` | không ném |
| Encode | cùng dữ liệu, encode hai lần | nonce khác nhau; JSON đúng thứ tự key AD-20, không khoảng trắng; decode lại ra dữ liệu ban đầu | — |
| Tham số KDF ngoài khoảng | ops 1/11, mem 19 MiB − 1 / 128 MiB + 1 | `null`, KDF không chạy | — |

## Decisions

- **Môi trường cục bộ (người dùng chọn 2026-11-09):** agent cài Flutter 3.47.8 vào `C:\src\flutter` (`git clone -b 3.47.8 --depth 1`, thêm `bin` vào PATH user) và Visual Studio 2022 Build Tools, workload C++ (winget), để build hook của `sodium` build được libsodium cho Windows. Mọi test, kể cả test crypto, chạy trên máy trước khi push.
- **Git/CI:** làm trên nhánh `feat/1-4-vault-crypto`, commit rồi push lên `origin` như các story trước. Người dùng tự mở PR và kiểm CI.
- **Độ dài spec:** giữ một spec (~4.200 token) dù vượt mức 1.600.

</frozen-after-approval>

## Code Map

- `pak_manager/pubspec.yaml` -- chưa có `sodium`. Thêm `sodium: 4.1.2` (ghim chính xác, AD-12); `pubspec.lock` phải do `flutter pub get` sinh.
- `pak_manager/tool/check_imports.dart:151` -- `_coreAllowedPackages = {'sodium', 'zxcvbnm'}`: core được import `sodium`. Không cần sửa.
- `pak_manager/lib/core/format/settings_codec.dart` -- mẫu phong cách codec (`abstract final class`, doc AD-20, không ném). Không sửa.
- `pak_manager/lib/core/io/pak_paths.dart` -- đã có `headerFile`, `cardsFile`, `recentFile`. Story này không ghi file.
- `pak_manager/lib/error_policy.dart` -- chính sách lỗi release dùng Flutter; core không dùng được, nên isolate KDF tự nuốt `print`/lỗi.
- `.github/workflows/ci.yml:77-106` -- chuỗi bước job ubuntu; thêm bước kiểm fixture vault sau bước Pigeon. Runner ubuntu đã có gcc/make cho build hook; job macOS build iOS cũng build libsodium.
- `pak_manager/tool/ci/check_android_apk.sh` -- sẽ kiểm `libsodium.so` căn 16 KB. Builder Android của `sodium` đặt `-Wl,-z,max-page-size=16384`.
- `.gitattributes` -- `pak_manager/test/fixtures/** -text` đã giữ nguyên byte fixture.
- `_bmad-output/implementation-artifacts/deferred-work.md` -- mục "Isolate phụ … story 1.4 phải cài chính sách lỗi release bên trong isolate": đóng bằng zone trong callback KDF.
- API `sodium` 4.1.2 (đã đọc từ tarball): `SodiumSumoInit.init()` đồng bộ, trả `SodiumSumo`. `runIsolated<T>((secureKeys, keyPairs) {…})` cho callback bắt `sodium` qua closure và trả được `SecureKey`. Các API khác: `crypto.pwhash.callRaw({outLen, Int8List password, salt, opsLimit, memLimit, alg: CryptoPwhashAlgorithm.argon2id13})`, `crypto.aeadXChaCha20Poly1305IETF.encrypt/decrypt({message|cipherText, nonce, key, additionalData})`, `crypto.genericHash({message, outLen, key})`, `memcmp`, `secureCopy`, `SecureKey.runUnlockedSync`/`extractBytes`/`dispose`. Decrypt sai tag ném `SodiumException`.

## Tasks & Acceptance

**Execution:**
- [x] Môi trường theo Decisions; nhánh `feat/1-4-vault-crypto`; `pak_manager/pubspec.yaml`, `pubspec.lock` -- thêm `sodium: 4.1.2`.
- [x] `pak_manager/lib/core/crypto/random_source.dart` -- `abstract interface class RandomSource { Uint8List bytes(int length); }`, `SodiumRandomSource(SodiumSumo)`, `String uuidV4(RandomSource)` (đặt nibble version 4, variant `10xx`, hex chữ thường có gạch).
- [x] `pak_manager/lib/core/crypto/wipe.dart` -- `void wipe(Uint8List)` ghi 0.
- [x] `pak_manager/lib/core/crypto/kdf.dart` -- `KdfParams(opsLimit, memLimitBytes)` có `isAllowed` và hằng min/max/khởi điểm/sàn. `Future<SecureKey?> deriveKek(SodiumSumo, Uint8List password, Uint8List salt, KdfParams)`: params ngoài khoảng hoặc salt ≠ 16 byte → `null` (không chạy KDF). Callback isolate: zone nuốt `print`, `try/catch` → `null`, wipe bản sao mật khẩu trong isolate.
- [x] `pak_manager/lib/core/crypto/kdf_calibration.dart` -- `Future<CalibratedKek?> calibrateVaultKdf({password, salt, derive, nowMs})` trả `(params, kek)` của lần chạy cuối. `derive` và `nowMs` inject được, mặc định `deriveKek` và `Stopwatch`. Thuật toán theo Design Notes. Mọi KEK không được trả về phải bị `dispose`.
- [x] `pak_manager/lib/core/model/vault_card.dart`, `recent_entry.dart` -- `VaultCard{id,title,username,password,note,createdAt}`, `RecentEntry{password,recordedAt}`: bất biến, có `==`/`hashCode`, `toString()` chỉ lộ `id`/thời gian.
- [x] `pak_manager/lib/core/format/header_codec.dart` -- `VaultHeader` (các trường AD-20, không có checksum). `HeaderCodec(SodiumSumo)`:
  - `decode(List<int>)` → sealed `HeaderDecodeResult` (`HeaderOk(VaultHeader)` | `HeaderCorrupt`), kiểm theo thứ tự Matrix.
  - `create({kek, dek, salt, params, random})` → `VaultHeader`: bọc DEK, tính kcv.
  - `encode(VaultHeader)` → 155 byte, có checksum.
  - `kcvMatches(header, kek)` → bool, so bằng `memcmp`.
  - `unwrapDek(header, kek)` → `SecureKey?` (null = corrupt), wipe buffer DEK tạm.
- [x] `pak_manager/lib/core/format/vault_file_codec.dart` -- `VaultFileCodec(SodiumSumo, RandomSource)`. `encodeCards`/`encodeRecent(…, SecureKey dek)` → `nonce‖ct`. `decodeCards`/`decodeRecent(bytes, dek)` → sealed `VaultFileResult<T>` (`VaultFileOk` | `VaultFileCorrupt`). AD `PAK-VAULT/cards/v1`, `PAK-VAULT/recent/v1`. Wipe plaintext sau encode/decode. Key lạ bị bỏ qua.
- [x] `pak_manager/tool/fixtures/gen_vault_v1.dart` + `pak_manager/test/fixtures/vault/v1/{header,cards,recent,README.md}` -- script tự ghép byte theo AD-20 bằng `sodium` (không import `lib/`). Đầu vào cố định ghi trong README: mật khẩu ASCII giả, ops 2, mem 19 MiB, DEK/salt/nonce là dãy byte cố định, 2 card (một note rỗng, một note có tiếng Việt) và 1 Recent. Chạy hai lần ra cùng byte. Xóa `.gitkeep` của `tool/fixtures`, `test/fixtures/vault`, `lib/core/crypto`.
- [x] `.github/workflows/ci.yml` -- bước "Fixture vault khớp script" sau bước Pigeon: `dart run tool/fixtures/gen_vault_v1.dart`, rồi `git status --porcelain -- test/fixtures/vault` phải rỗng.
- [x] `_bmad-output/implementation-artifacts/deferred-work.md` -- thêm dòng `status: done (story 1.4 …)` dưới mục isolate.
- [x] Test (`ad04_`/`ad05_`/`ad16_`/`ad20_`/`ad22_`): `test/core/crypto/{random_source,kdf,kdf_calibration}_test.dart`, `test/core/format/{header_codec,vault_file_codec}_test.dart`, `test/core/model/vault_models_test.dart`. Phủ mọi dòng Matrix; test hiệu chỉnh dùng `derive`/đồng hồ giả.

**Acceptance Criteria:**
- Given fixture `v1` và các đầu vào cố định trong README, when `HeaderCodec.create` + `encode` và `VaultFileCodec.encode*` chạy với `RandomSource` giả trả đúng các byte đó, then output trùng từng byte với `header`, `cards`, `recent` của fixture (golden).
- Given header fixture, when lật checksum hoặc dùng sai mật khẩu, then test phân biệt được: lật checksum → `HeaderCorrupt` và `derive` giả không được gọi; sai mật khẩu → `HeaderOk` nhưng `kcvMatches == false`.
- Given `derive` giả với probe 1000 ms, when hiệu chỉnh, then trả (ops 3, 64 MiB) sau đúng 1 lần chạy. Given probe 300 ms, then ops 10, mem 64 MiB. Given probe 6000 ms và lần kiểm vẫn > 2000 ms, then dừng ở tham số ≥ sàn (ops ≥ 2, mem ≥ 19 MiB) sau tối đa 3 lần chạy.
- Given `deriveKek` thật, when gọi với mật khẩu/salt/params fixture, then ra KEK có kcv khớp header fixture, và callback chạy trên isolate khác isolate gọi.
- Given `VaultCard`/`RecentEntry`, when `toString()`, then không chứa title, username, password hay note.

## Implementation Notes

- **Môi trường:** Flutter 3.47.8 clone vào `C:\src\flutter`, `bin` thêm vào PATH user; VS 2022 Build Tools + workload `VCTools` cài qua winget. Build hook của `sodium` build libsodium cho Windows cả trong `flutter test` lẫn `dart run tool/fixtures/gen_vault_v1.dart`.
- **`SodiumSumoInit.init()` về mặt tĩnh là `FutureOr<SodiumSumo>`:** analyzer chọn nhánh fallback của conditional export, nên code luôn `await SodiumSumoInit.init()` (script fixture, helper test `initSodium()`); lúc chạy trên FFI nó vẫn đồng bộ.
- **`runIsolated` không trả được `SecureKey?`:** `IsolateResult` assert `T == SecureKey` (bản debug ném, bản release thì không), nên callback có kiểu `SodiumIsolateCallback<SecureKey>`. Khi callback bắt lỗi, nó trả khóa rỗng (`secureAlloc(0)`) thay cho `null`; `deriveKek` thấy độ dài ≠ 32 thì `dispose` rồi trả `null`. Lỗi do chính isolate (spawn/transfer) bị `try/catch` ở isolate gọi bắt, cũng trả `null`. `deriveKek` không chép thêm mật khẩu ở isolate gọi: closure bị chép sang isolate KDF và bản đó bị wipe trong `finally`.
- **`deriveKek(…, {debugInIsolate})`:** hook chỉ cho test, chạy trong isolate KDF trước KDF. Test dùng nó để chứng minh callback chạy ở isolate khác (biến top-level chỉ isolate test đặt), KDF không chạy khi tham số/salt sai, và lỗi trong isolate → `null`. Không test được việc nuốt `print` vì lint `avoid_print` cấm `print` cả trong test.
- **`calibrateVaultKdf` nhận `derive` bắt buộc:** `deriveKek` cần `SodiumSumo`, nên mặc định production là `kekDeriver(sodium)` (bao `deriveKek`), test truyền fake. `nowMs` mặc định là `Stopwatch` tạo trong hàm. Bước 3 tổng quát hóa bước 2 quanh tham số hiện tại: t' = max(2, floor(t·f)), m' = clamp(floor(m·t·f/t') MiB, 19 MiB, m) (chỉ giảm, bộ nhớ không bao giờ tăng). T ≤ 0 (đồng hồ giả) được xem như f lớn → t = 10. `derive` ném cũng trả `null`.
- **Không ném nên vài kiểu trả về nullable:** `HeaderCodec.create` trả `VaultHeader?` (salt/DEK/KEK sai độ dài, tham số ngoài khoảng, khóa đã dispose → `null`); `VaultFileCodec.encodeCards/encodeRecent` trả `Uint8List?`, kể cả khi có mục mà decode sẽ từ chối (id không phải UUIDv4 chữ thường, thời gian âm; dùng chung hàm kiểm của decode). `VaultHeader` có constructor private nên chỉ codec tạo được, mọi trường luôn đúng độ dài; các `Uint8List` trong đó là bản sao chỉ đọc. `HeaderCodec.encode` vì thế không cần nhánh lỗi.
- **Wipe:** `create` bọc DEK bằng `dek.runUnlockedSync` (không chép DEK ra heap Dart); `unwrapDek` wipe buffer DEK tạm sau `secureCopy`; codec file dữ liệu wipe plaintext UTF-8 trong `finally` cả khi encode lẫn decode. Chuỗi Dart sinh ra từ `jsonEncode`/`utf8.decode` không ghi đè được (giới hạn của Dart, giống mật khẩu dạng `String`).
- **Decode file dữ liệu:** `v` phải là `int` 1 (`1.0` → `corrupt`); thời gian phải là `int` ≥ 0; danh sách trả về là unmodifiable. Không kiểm id trùng lặp (AD-20 không yêu cầu). `recordedAt` ở tương lai không bị codec xét (thuộc tầng dùng Recent).
- **Fixture:** script ghi cả `README.md` (bảng đầu vào hex + bản rõ JSON) để README không lệch byte; chạy hai lần ra cùng SHA-256, và bản `.dart` có CRLF (checkout Windows) cũng ra cùng byte. Hằng đầu vào được lặp lại trong `test/core/vault_fixture.dart` (test không import `tool/`).
- `flutter pub get` trên Windows sinh lại `lib/l10n/*.dart` chỉ khác CRLF/LF; đã `git checkout` trước khi commit.
- **Verification (máy dev, 2026-11-09):** `flutter pub get --enforce-lockfile` OK; script fixture chạy lại không đổi `test/fixtures/vault`; `flutter analyze --fatal-infos --fatal-warnings` 0 issue; `dart run tool/check_imports.dart` OK; `flutter test` 254 pass, 1 skip (có sẵn). Chưa build APK/iOS cục bộ; chưa chạy CI.

## Spec Change Log

## Review Triage Log

Review 2026-11-09 (diff `24abe79..2381d6a`, bỏ spec; 3 lớp: blind, edge, verif-gap).

| # | Nguồn | Phát hiện | Verdict | Bằng chứng | Route |
|---|-------|-----------|---------|------------|-------|
| 1 | blind | `_reduce` tăng `m` ở lần chạy thứ 3: (10, 64 MiB) + 2200 ms → (4, 72 MiB); (6, 64 MiB) + 2100 ms → (2, 91 MiB) | medium | `kdf_calibration.dart:98`: m' = m·t·f/t' > m khi floor làm t' < t·f. Trái Design Notes bước 3 "chỉ giảm"; máy vừa đo là chậm lại bị cấp thêm bộ nhớ | patch |
| 2 | blind | Test hiệu chỉnh không bắt được #1 (thiếu ca [300, 2200, x], không kiểm chi phí giảm dần) | medium | Cùng gốc #1; `ad05_every_calibrated_params_is_allowed` chỉ kiểm `isAllowed` | patch (gộp #1) |
| 3 | edge, blind | `encodeCards`/`encodeRecent` ghi được dữ liệu mà decode từ chối (id không phải UUIDv4 chữ thường, thời gian âm) → cả vault thành `corrupt` | medium | `vault_file_codec.dart:61-91` không kiểm; `_card`/`_recent` từ chối. Một card sai từ caller khóa toàn bộ dữ liệu ở lần mở sau | patch |
| 4 | edge, blind | Probe (3, 64 MiB) lỗi (vd. không cấp được bộ nhớ) → hiệu chỉnh trả `null`, không lùi về sàn, không tạo được tài khoản | maybe-false | Đúng Design Notes bước 4. Cần chạy trên máy mốc yếu nhất (Android 7, RAM 2 GB) để biết 64 MiB có cấp được không; nếu đúng là high | defer |
| 5 | verif-gap | Test `VaultHeader.toString` chỉ dò chữ `salt`/`kcv`, không dò byte thật | low | `header_codec_test.dart:316-322`; in `$kcv` vẫn xanh. Sửa trực tiếp trong test | patch |
| 6 | verif-gap | Nhánh `derive` ném trong `calibrateVaultKdf` chưa test nào chạy | low | Harness chỉ trả `null`. Thêm một ca là sửa trực tiếp | patch |
| 7 | verif-gap, blind | Zone nuốt `print` trong isolate KDF không có test, mà `deferred-work.md` ghi done | low | Gỡ `runZoned` vẫn xanh. Không code nào trong isolate gọi `print`; sửa dòng status cho đúng sự thật | patch |
| 8 | edge, blind | Helper `derive` trong `kdf_test` chờ cố định 50 ms rồi đọc `calls` | low | Hai cổng khác nhau, không bảo đảm thứ tự; runner CI chậm có thể làm `calls == 1` fail. Sửa trong test | patch |
| 9 | blind | `check_android_apk.sh` không kiểm `libsodium.so` có trong APK; build hook không đóng gói thì CI vẫn xanh | medium | Script chỉ cần có ít nhất một `.so`. Hook đặt tên `libraryFileName('sodium')` → `libsodium.so` | patch |
| 10 | verif-gap | Test lỗi trong isolate không phân biệt catch trong isolate với catch ở `deriveKek` | low | Kết quả với caller như nhau | reject |
| 11 | edge | `uuidV4` ném `RangeError` khi `RandomSource` trả thiếu byte | false | Hợp đồng `RandomSource.bytes(n)` trả đúng n byte; `SodiumRandomSource` luôn đúng; fake sai là lỗi test, ném to là đúng | reject |
| 12 | edge | Mật khẩu là view unmodifiable → `wipe` trong `finally` ném, KEK bị bỏ không dispose | low | Caller (1.6) dùng `ascii.encode` (modifiable); kết quả vẫn là `null` an toàn. Sửa cần thêm nhánh | reject |
| 13 | edge | Surrogate lẻ bị `utf8.encode` thay bằng U+FFFD | low | Ô nhập của Flutter không sinh surrogate lẻ; sửa cần thêm guard | reject |
| 14 | edge | Không từ chối id trùng khi decode | low | AD-20 không yêu cầu; id do `uuidV4` sinh. Sửa cần thêm luật | reject |
| 15 | edge | Sửa `kcv` rồi tính lại checksum → báo sai mật khẩu thay vì hỏng | false | Đúng thiết kế AD-4: checksum bắt hỏng ngẫu nhiên; ai tính lại được checksum là có chủ đích, AD-8 chấp nhận rủi ro root | reject |
| 16 | edge | `List<int>` có giá trị ngoài 0–255 bị cắt | low | Đầu vào là bytes đọc từ file (`Uint8List`); không caller nào truyền khác | reject |
| 17 | edge | `vault_fixture.dart` đọc đường dẫn tương đối theo cwd | false | `flutter test` luôn chạy ở gốc package; các test có sẵn (`theme_test`) dùng cùng cách | reject |
| 18 | edge | `derive` bắt buộc, trái "mặc định `deriveKek`" | low | Lệch đã ghi Implementation Notes (`deriveKek` cần `SodiumSumo`); sửa là sửa spec | reject |
| 19 | edge | "Wipe plaintext" nhưng chuỗi Dart còn trên heap | false | Spec chỉ yêu cầu `Uint8List` (Always, Design Notes nói rõ chuỗi không ghi đè được) | reject |
| 20 | blind | Thiếu test cho vài nhánh lỗi của codec (khóa đã dispose, nonce sai độ dài, KEK sai mật khẩu khi `unwrapDek`) | low | Đều rơi vào cùng một `on Object` đã có test chạm tới; ít khả năng gặp | reject |
| 21 | blind | Sprint `in-progress` lệch spec `in-review` | false | Đúng thiết kế: bước trình bày đồng bộ sprint-status | reject |
| 22 | blind | File `cards`/`recent` không chống tráo bản cũ (AD không gắn header/bộ đếm) | low | Thiết kế AD-6/AD-20 đã chốt; kẻ ghi được `vault/` là root/jailbreak, AD-8 chấp nhận rủi ro. Sửa là đổi kiến trúc | reject |
| 23 | blind | `debugInIsolate` là tham số public của `lib/core` | low | Caller nào cũng đã có mật khẩu; không có hại cụ thể. Sửa cần thêm cơ chế | reject |

## Design Notes

- **Hiệu chỉnh:** chi phí Argon2 xấp xỉ tỉ lệ m·t. Mọi lần chạy dùng đúng mật khẩu và salt thật, nên KEK của lần chạy cuối dùng luôn cho tài khoản (story 1.6 không phải chạy thêm).
  1. Probe (3, 64 MiB) → T. Nếu 500 ≤ T ≤ 1500 ms thì nhận.
  2. Hệ số f = 1000/T. Nếu f > 1: t = min(10, round(3f)), m = 64 MiB (không tăng bộ nhớ vì máy yếu dễ OOM). Nếu f < 1: t = max(2, floor(3f)), m = max(19 MiB, floor(64 MiB · 3f/t), làm tròn xuống theo MiB). Chạy lại → T'.
  3. T' ≤ 2000 ms, hoặc tham số đã ở sàn (2, 19 MiB), thì nhận. Ngược lại hạ thêm một lần theo bước 2 với f = 1000/T' (chỉ giảm), chạy, nhận kết quả dù chậm. Tối đa 3 lần chạy.
  4. KDF lỗi (null) ở bất kỳ lần nào → trả `null`.
- **Codec nhận `SodiumSumo`:** checksum/kcv cần BLAKE2b, nên codec là instance chứ không static như `SettingsCodec`.
- **Mật khẩu là `Uint8List`:** chuỗi Dart không ghi đè được. Caller (1.6) mã hóa ASCII rồi wipe bản của mình; bản sao bên isolate do `deriveKek` wipe.

## Verification

**Commands (trong `pak_manager/`):**
- `flutter pub get --enforce-lockfile` -- resolve được.
- `dart run tool/fixtures/gen_vault_v1.dart; git status --porcelain -- test/fixtures/vault` -- rỗng sau lần sinh đầu đã commit.
- `flutter analyze --fatal-infos --fatal-warnings` -- 0 issue.
- `dart run tool/check_imports.dart` -- exit 0.
- `flutter test` -- mọi test pass.

**Manual checks:**
- CI xanh: job ubuntu (build hook libsodium, test, APK 16 KB) và job macOS (build iOS).
