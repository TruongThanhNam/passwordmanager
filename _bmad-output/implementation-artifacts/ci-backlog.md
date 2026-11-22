# Backlog CI

Nơi duy nhất chứa việc làm cứng hoặc mở rộng CI chưa làm. Lập theo action item `epic-1-retro-item-11` (retro Epic 1, D1: "làm cứng CI tự sinh thêm việc làm cứng CI"; sáu trong 16 story của Epic 1 chỉ làm CI).

## Điểm dừng

1. **Danh sách cổng an toàn đã đóng.** Mục tiêu "mọi cổng tự chứng minh bằng kiểm âm" chỉ áp cho các cổng sau; các cổng này đã xong ở story 1.11–1.16 và action item `epic-1-retro-item-1`/`-2`, và đó là lần làm cứng cuối:
   - cổng chuỗi cung ứng: ghim action theo SHA, ghim revision Flutter (`.metadata`), `check_stack`, `distributionSha256Sum`, `--enforce-lockfile`;
   - cổng APK: không quyền `INTERNET`, ELF 16 KB, `applicationId` prod/dev;
   - cổng secret trong `ci.yml` (AD-18), Pigeon sinh ra đã cập nhật, l10n/fixture đã cập nhật, `check_imports`;
   - bundle id iOS và hai job `integration-*`.
2. **Mục CI mới không thành story chen trước story sản phẩm.** Mọi mục phát sinh (từ review, retro, hay lỗi CI) ghi vào bảng dưới, kèm id `DW-…` hoặc nguồn.
3. **Chỉ được nâng một mục lên story CI riêng khi** (a) CI đỏ hoặc chập chờn chặn merge vì lý do không do code, hoặc (b) mục đó bảo vệ một thuộc tính an toàn mà story sản phẩm sắp chạm tới (ghi rõ story). Còn lại, mục chờ ở bảng này tới ranh giới epic, hoặc tới story đã được ghi ở cột "Làm khi".
4. **Quyết định nâng mục là của PM (John)**; ghi ngày và lý do vào cột "Trạng thái".

## Bảng

| Mục | Nguồn | Làm khi | Trạng thái |
|---|---|---|---|
| Quét mọi workflow có trigger `pull_request` tìm `secrets`, cấm `pull_request_target` ở mọi file (hiện `check_workflow_secrets` chỉ quét `ci.yml`). | `deferred-work.md`, mục review 1.1 (2026-11-02) | Story 7.2 (workflow release dùng secret) | planned |
| Integration test cho bản release (R8/minify có thể làm hỏng đăng ký Pigeon). | `deferred-work.md`, mục `spec-1-13` | Story 7.2 | planned |
| Kiểm âm cho các nhánh guard có sẵn của `check_android_apk.sh` (thiếu APK, thiếu `ANDROID_HOME`, thiếu `aapt2`/`zipalign`/`readelf`/`unzip`/`dart`). | `deferred-work.md`, mục review `spec-1-15` | Khi sửa `check_android_apk.sh` lần sau | planned |
| Bước kiểm APK dev chạy cả khi bước prod fail (`if: ${{ !cancelled() }}`) để artifact `apk-raw-output` đủ. Phải thêm `allowedIf` cho `_apkDevGate` trong `tool/ci/ci_structure.dart` và sửa test tương ứng. | `deferred-work.md`, mục review `spec-1-15` | Khi cần chẩn đoán lỗi APK trên CI | planned |
| Kiểm tự động bất biến: `port_fakes.dart` không import Flutter; fake `implements` port/`Timer`/`SecureKey` chỉ nằm trong `test/support/` (trừ fake cục bộ có lý do). `check_imports` chỉ quét `lib/`. | `DW-retro1.9-2` | Khi `test/support/` có thêm vi phạm, hoặc ở ranh giới epic | planned |
| Run CI fail do Gradle không phân giải được `kotlin-gradle-plugin-api`/`kotlin-stdlib` 2.2.21 từ `plugins.gradle.org` (một lần, run `45023284886`); chưa rõ nguyên nhân gốc. Chỉ đóng thành việc khi tái diễn (điều kiện 3a). | `epic-2-retro-2026-11-22.md`, D4 | Theo dõi; nâng nếu lặp lại | watch |

## Cách dùng

- Thêm mục: một dòng vào bảng, ghi nguồn. Không sửa `ci.yml`, `tool/ci/` hay `test/tool/` cho mục chưa được nâng.
- Đóng mục: đổi cột "Trạng thái" thành `done — <ngày> — CI run <id từ gh run list>` hoặc SHA commit, đúng chính sách đóng mục hoãn trong `AGENTS.md`; đồng thời đóng mục gốc ở `deferred-work.md`.
