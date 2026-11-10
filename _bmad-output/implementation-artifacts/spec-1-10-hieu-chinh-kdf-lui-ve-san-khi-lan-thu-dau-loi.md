---
title: 'Story 1.10 — Hiệu chỉnh KDF lùi về sàn khi lần thử đầu lỗi'
type: 'feature'
created: '2026-11-10'
status: 'done'
route: 'oneshot'
review_loop_iteration: 0
context:
  - '{project-root}/_bmad-output/implementation-artifacts/epic-1-context.md'
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** `calibrateVaultKdf` (`pak_manager/lib/core/crypto/kdf_calibration.dart`) trả `null` ngay khi probe m=64 MiB, t=3 lỗi (vd. không cấp được bộ nhớ), nên máy ít RAM không tạo được tài khoản (AD-5, NFR-2; `epics.md:749`).

**Approach:** Khi lần chạy đầu (probe) lỗi — `derive` trả `null` hoặc ném — thử lại đúng một lần ở `KdfParams.floor` (m=19 MiB, t=2) và trả `(params, kek)` của lần đó nếu thành công; chỉ trả `null` khi cả lần ở sàn lỗi. Không bao giờ trả tham số dưới sàn; mọi KEK không trả về đều bị `dispose`. Probe thành công thì thuật toán giữ nguyên story 1.4 (lỗi ở lần 2/3 vẫn trả `null`). Unit test với `derive` giả: probe lỗi rồi sàn thành công, cả hai lỗi, probe ném.

</frozen-after-approval>

## Implementation Notes

- Tách `_tryDerive` (ném → `null`) dùng chung cho probe và lần ở sàn; lần ở sàn được nhận bất kể thời gian vì không còn gì thấp hơn.
- Files: `pak_manager/lib/core/crypto/kdf_calibration.dart`, `pak_manager/test/core/crypto/kdf_calibration_test.dart` (đổi 2 test cũ coi probe lỗi = `null`; thêm `ad05_probe_failure_retries_once_at_floor_and_accepts`, `ad05_probe_and_floor_both_failing_returns_null`).
- `flutter analyze` 0 issue, `check_imports` OK; `flutter test` chỉ còn 7 lỗi cần libsodium, giống baseline.

## Review Triage Log

Review 2026-11-10 (Blind Hunter, cây làm việc).

- `false` — Probe đã ở sàn thì chạy sàn hai lần: `KdfParams.start` là hằng (3, 64 MiB) ≠ sàn; không thể xảy ra.
- `low` (reject) — `on Object` nuốt lỗi lập trình, không log: giữ đúng hành vi story 1.4 (`derive` ném → `null`); log/diagnostic cần API mới.
- `low` (reject) — Caller không biết đã lùi về sàn: không AC nào yêu cầu; thêm field là API mới.
- `low` (patch) — Doc comment chưa nói lần ở sàn nhận bất kể thời gian và đường 2 lần chạy: đã thêm bước 0.
- `low` (patch) — Test lỗi `null` sau probe thành công không kiểm không lùi về sàn: thêm `h.calls hasLength(durations.length)` (test ném đã có sẵn).
- `false` — KEK rò khi probe ném sau khi tạo key: `derive` ném thì không trả key nào cho hàm nắm giữ.
- `low` (reject) — Thiếu test cấp `account_service`: service chỉ chuyển tiếp kết quả `calibrateVaultKdf`, đã test ở unit.
- `false` — Status/bookkeeping spec cũ: được cập nhật ở bước Finalize này.
