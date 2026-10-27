---
title: Rubric review — ARCHITECTURE-SPINE.md (PAK Manager)
reviewed: _bmad-output/planning-artifacts/architecture/architecture-passwordmanager-2026-10-27/ARCHITECTURE-SPINE.md
against: prd.md (final 2026-10-27), addendum.md, EXPERIENCE.md surface table S1–S28, spine .memlog.md
date: 2026-10-27
verdict: revise before epics (no rewrite needed)
---

# Rubric review — PAK Manager architecture spine

## Verdict

This is a strong, well-targeted spine. It names the real single-owner seams (VaultSession, SessionController, LockoutGuard, ClipboardService, PasswordPolicy, AtomicFileWriter, a single Pigeon API, a single export codec) and most Rules are concrete enough to enforce. It is **not yet safe to hand to independent story agents**, for four reasons:

1. The lockout crash semantics (AD-8 and the login state diagram) leave a TC-3 bypass and an undefined startup state.
2. AD-7's "one file per operation" rule is contradicted by operations that need more than one file, and the spine never says what a missing vault data file means.
3. Nobody owns the vault lifecycle outside an unlocked session (create, wipe).
4. The operational envelope is only half decided. Testing of native and device behaviour, vault-format evolution, and app identity and versioning are all silent.

Everything below is fixable by amending existing ADs. The paradigm does not need to change.

## Scorecard

| Checklist item | Result | Notes |
| --- | --- | --- |
| Fixes the real divergence points for story-level agents | Mostly | Strong on ownership seams. Misses: wipe/create owner, multi-file op ordering, missing-file semantics, isolate/KDF threading, draft flush on lock, export temp-file lifecycle |
| Every AD Rule is enforceable and prevents its divergence | Mostly | AD-2 lint tool conflicts with AD-12 dependency rule. AD-7 "fsync thư mục" cannot be done in dart:io. AD-8 does not cover kill-during-check at attempts 5–9. AD-1 "no Material" has no mechanical check |
| Nothing under Deferred lets two units diverge | Mostly | iOS save-password suppression may need native code that AD-11's closed list forbids. Bloom-filter format is split across `tool/` and `core/policy` |
| Covers the spec's capabilities | Mostly | NFR-12 (tablet, adaptive layout) is missing and AD-1's portrait-only rule conflicts with it. FR-26 draft-on-lock is at risk. FR-7 header-corruption case is not handled |
| Every owned dimension is decided, deferred, or open | No | Testing strategy is partial. Vault-format versioning and migration are silent. Environments, bundle ID and versioning are silent. Operations (no telemetry) is implicit only |
| Mermaid diagrams valid and consistent with ADs | Partial | Syntax looks valid (one subgraph title should be quoted). Login state diagram is inconsistent with FR-5, FR-6 and FR-7. Layer diagram contradicts AD-2 and AD-14 |

## Findings

Severity: **critical** blocks correctness of a success criterion with no workaround. **high** means a likely defect or divergence that hits a TC. **medium** means a likely divergence between units, or a missing decision. **low** is polish or verification.

### F-01 [high] AD-8 and the login state diagram: crash during check skips the 30-minute wait, and startup with failCount=10 is undefined

- AD-8 writes the incremented counter *before* the KDF (correct per FR-5), but it writes only `failCount`. The wait start `(bootId, waitStartMonotonic)` is recorded only after a wrong result.
- Attack: at attempts 5–9, kill the app during the ~1–2 s KDF. On restart the guard holds `failCount=k≥5` with no wait start. The diagram goes `[*] --> Ready`, so the user retries immediately. FR-5 says a killed check counts as wrong, and FR-4 says a wrong attempt at 5–9 imposes a 30-minute wait. This breaks TC-3 ("kể cả khi tắt app").
- In the same way, attempt 10 killed mid-KDF leaves `failCount=10` with no `wiping` flag. Neither AD-8 nor the diagram says that startup must then wipe.
- The diagram also has no `[*] --> Waiting` transition, so after a restart during a legitimate wait an S3 implementer following the diagram shows Ready. AD-8's text implies Waiting, so the two disagree.
- **Fix:** make the pre-KDF write provisional and complete. It records the new `failCount` and, when the new count is ≥5, a provisional wait start (or `wiping=true` when it is 10). A correct password clears all of these in one atomic write. Add startup transitions `[*] --> Waiting` (wait active), `[*] --> Wiping` (failCount=10 or wiping flag), and state the guard precedence order (wiping > count 10 > waiting > header present > no header).

### F-02 [high] AD-7: "Mỗi thao tác nghiệp vụ ghi đúng một file" is false for several operations, and missing-file semantics are undefined

- **Account creation** writes `header` and at least an initial `cards` (and resets `guard`). If the app is killed between writes, `header` exists, so the state is Ready. The user logs in, `cards` is missing, and the result is either "Dữ liệu bị hỏng" or an empty vault, depending on the agent.
- **Saving a card** writes `cards` and must discard `draft` (FR-26). If the app is killed between the two, the draft is resumed via S6. For a *new* card this produces a duplicate card on the second save.
- **Wipe** deletes several files. It is ordered, but it is not "one file".
- **Fix:**
  - Define a missing `cards`, `recent` or `draft` file as empty, and a missing or unparseable `header` as described in F-04.
  - Fix the creation order: data files first, `header` last, so that header presence means the account is complete.
  - Fix the save order: `cards` then `draft` delete. The draft carries a pre-assigned card id, and save is an upsert by id, so resuming is idempotent.
  - Restate AD-7 as "each operation has one *commit* file; other writes are ordered and idempotent".

### F-03 [medium] AD-3, AD-7 and AD-8: no owner for vault lifecycle outside an unlocked session (create account, wipe, startup wipe resume)

- AD-3 says only `VaultSession` touches the vault directory. Wipe is triggered from three places: the 10th failure (LockoutGuard path), S4 / FR-9 (auth UI), and startup resume (FR-12). Wipe spans guard, vault dir, settings and clipboard.
- Account creation (S2) also happens before any session exists.
- No AD names the orchestrator, so the FR-4 story and the FR-9 story will each build a wipe sequence.
- **Fix:** name one owner, for example `VaultRepository` / `AccountService` in services, with `create()`, `unlock()` returning a `VaultSession`, and `wipe()` implementing the AD-7 sequence. LockoutGuard and the UI only call it.

### F-04 [medium] AD-4 and the state diagram: counter handling on Corrupt is inconsistent, and header corruption is indistinguishable from a wrong password

- The diagram says `Corrupt: … → hoàn bộ đếm` (restore to the previous value). FR-5 says a correct password resets the counter to 0. AD-4 says "không bao giờ tính vào bộ đếm". Two agents will pick different values.
- AD-4 uses both "mở bọc DEK thành công = mật khẩu đúng" and a separate "key check value", without saying which one decides. This is redundant and ambiguous.
- A bit flip inside the wrapped-DEK ciphertext in `header` fails AEAD exactly like a wrong password. It is counted, and could escalate to a wipe, which violates FR-7 ("không bao giờ kích hoạt việc xóa").
- **Fix:** state "password proven ⇒ failCount = 0 even if data is corrupt". Define the one verifier. Treat header structural failures (magic, version, length, param bounds) as Corrupt. Add a header integrity check, such as a keyed or unkeyed checksum over the header bytes, so that header damage is classed as Corrupt rather than as a wrong password. Alternatively, record this as an explicit accepted risk.

### F-05 [medium] Operational envelope: testing strategy is unit-only

- The conventions cover core unit tests, fake clock and ports, FR-named tests, and export fixtures. Silent areas:
  - How Pigeon native code is tested (clock, boot detection, clipboard expiry, backup exclusion), given there is no Mac and iOS native code is only compiled in CI.
  - Who verifies TC-1 (extract a backup or root image), TC-3 (real reboot and clock change), NFR-2 (timing on the reference devices), NFR-9 (keyboards), and TC-5 (iOS↔Android round trip). It is also unclear whether these checks are per-story acceptance or a release checklist.
  - Whether widget tests assert the AD-14 `SecretField` flags.
  - Whether CI verifies that Pigeon-generated code is up to date.
- **Fix:** add a testing AD that covers three levels (core unit; widget tests that include SecretField and SessionController lock teardown; a device acceptance checklist mapped to TC-1…TC-6 on TestFlight and closed testing) and says where each TC is verified.

### F-06 [medium] AD-6: vault format versioning and migration is silent

- AD-10 makes the *export* format a permanent contract with golden fixtures. The *vault* files persist across app updates, and mobile releases cannot be rolled back.
- A v2 vault format with no reader for v1 makes every vault Corrupt after an update. That is TC-6 data loss for every user at once.
- **Fix:** give the vault format the same treatment as export. Readers stay for every released version, migration rewrites through AtomicFileWriter with header written last, and golden vault fixtures for each released format version run in CI.

### F-07 [medium] NFR-12 and AD-1: tablet support and adaptive layout are undecided, and portrait-only conflicts with iPad

- NFR-12 requires phones and tablets with an adaptive layout. The spine never mentions tablets.
- AD-1 locks the app to portrait. On iPad a portrait-only app needs `UIRequiresFullScreen`, which Apple deprecated with iPadOS 26. Verify this against the SDK that CI will build with.
- **Fix:** decide whether to support tablets, set the orientation policy for each form factor, and pick one layout rule (for example a max content width and breakpoint in `features/shared/theme`). Alternatively, record a PRD change.

### F-08 [medium] AD-9: draft flush and background behaviour are unspecified

- The lock sequence says "hủy thao tác chưa bắt đầu ghi". A debounced `saveDraft` that has not started yet (the convention allows ≤500 ms) would be cancelled, so a lock on session expiry while the user is typing loses the last edits. FR-26 promises the draft survives a lock.
- **Fix:** add an explicit "flush pending draft save" step before `VaultSession.lock()`.
- The spine does not say whether autolock and session expiry are evaluated only on resume or also by a timer while backgrounded. Android keeps Dart timers running while the process lives; iOS suspends them. NFR-4 wants the DEK held for the shortest time the platform allows. Without a rule, agents will diverge.
- **Fix:** state the rule, for example "evaluate on resume and on a foreground timer; additionally lock on `paused` + timer where the platform allows".

### F-09 [medium] Concurrency: no rule on where KDF and crypto run

- Argon2id at ~1–2 s on the UI isolate freezes the activity indicator that EXPERIENCE requires (button-primary "hiện activity-indicator") and janks every login, unlock re-verify, export and import.
- The `sodium` package offers isolate execution, but moving a `SecureKey` across isolates has rules of its own.
- **Fix:** add a Rule that KDF and bulk AEAD run off the UI isolate via one helper in core/crypto, and state how SecureKey crosses the boundary (or that it does not).

### F-10 [medium] AD-2 enforcement conflicts with AD-12, and the layer diagram contradicts AD-2 and AD-14

- AD-2 says CI blocks layering violations by "lint quy tắc import", but no lint tool is in the Stack table. Dart has no built-in layering lint, so it needs `custom_lint`, an import-lint package, or a `tool/` script.
- AD-12 says every pubspec dependency must be in Stack, and it is unclear whether that includes dev_dependencies. Even the default `flutter_lints`, and any test helper such as `mocktail`, are absent from Stack. The first story either breaks AD-12 or skips the AD-2 gate.
- The layer diagram shows `F -. cấm .-x C` (features may not touch core at all). AD-2 forbids only `core/crypto`, `core/format`, `platform` and `dart:io`. AD-14 has `SecretField` in `features/shared` reporting errors "qua PasswordPolicy", which lives in core/policy. The convention also has UI mapping core sealed result types.
- **Fix:** pick one rule (for example "features may import core models, results and policy; not crypto, format, io or ports"), redraw the edge, name the lint mechanism, and say whether AD-12 covers dev deps.
- Optionally add "cấm import `package:flutter/material.dart` in lib/" to make AD-1 checkable.

### F-11 [medium] AD-7: "fsync thư mục" is not implementable in pure Dart

- `dart:io` has no API to fsync a directory. `RandomAccessFile.flush()` covers files only, and on iOS plain `fsync` does not guarantee durability; `F_FULLFSYNC` is needed.
- Agents will either silently skip the step or add FFI or native code outside the AD-11 Pigeon list.
- **Fix:** decide one of three options: (a) add `fsyncDir` and full-sync to the Pigeon or port list, (b) use an FFI helper in platform behind a port, or (c) accept file-level fsync plus rename as sufficient and record the residual risk. Also state whether `dart:io` is allowed in `lib/core/`. AtomicFileWriter needs it, but the paradigm says platform belongs behind ports.

### F-12 [medium] AD-13 and AD-10: export and import temp files fall outside the "only two files" rule

- `share_plus` needs the `.pakx` file on disk to share it. `file_selector` on iOS (and some Android providers) copies the picked file into the app's tmp or cache.
- AD-13 claims the app writes only `guard` and `settings` outside the vault. Location, backup exclusion and deletion timing for these encrypted files are unspecified.
- **Fix:** add a rule such as "export written to app temp dir via AtomicFileWriter, excluded from backup, deleted after share sheet closes and on next startup; picked import copies deleted after import completes or cancels". Also add a maximum import file size checked before reading. FR-63 bounds KDF params but not ciphertext length.

### F-13 [low] AD-17 and AD-11: clipboard details that will diverge

- It is unclear who clears the clipboard when the Clear Clipboard time elapses *while the app stays in the foreground*. AD-17 only specifies "khi trở lại tiền cảnh" for Android.
- Android 12+ shows a system "pasted from your clipboard" toast when the app reads a clip that another app set. Compare with `getPrimaryClipDescription()` (label or timestamp) first, and read content only if that matches.
- `clearPrimaryClip` is API 28+. On API 24–27, set an empty clip instead.

### F-14 [low] Deferred: iOS save-password suppression may require native code, which AD-11's closed group list forbids

If testing shows Flutter flags alone do not suppress the iCloud Keychain prompt, the fix belongs in the Pigeon API. Pre-authorize an "input" group in AD-11, or state that adding a group means amending AD-11.

### F-15 [low] AD-15: Bloom filter false-positive rate of ≤1% rejects about 1 in 100 legitimate master passwords as "phổ biến"

Consider ≤0.1%, or an exact sorted hash set. The size budget likely allows it after the 15–128 length filter. The Bloom format (hash functions, seed) is shared by `tool/` and `core/policy`. Pin it in the blocklist story's acceptance criteria, or commit a format note next to `assets/blocklist.bloom`.

### F-16 [low] AD-10: the export byte layout is named but not specified

Field widths and units are unspecified: m in KiB or bytes, u32 or u64; salt and nonce lengths; AEAD algorithm for export (implied XChaCha20-Poly1305 but not stated). There is one implementation, but this is a "permanent contract". Require a byte-level format note (for example `lib/core/format/export/FORMAT.md` or a doc comment) to be written with v1.

### F-17 [low] Deployment and identity: bundle ID, versioning, environments

- The app identifier (iOS bundle ID / Android applicationId) is permanent once published, and it is undecided.
- The version and build-number scheme is undecided, as is whether there are flavours (dev vs prod), which would let a debug build not clobber a real vault on the owner's phone.
- Fork-PR CI cannot access secrets, so state that PR iOS builds are `--no-codesign`.
- The Android upload path is a gap: the diagram shows `A --> Google Play Console`, but AD-19 only says "build AAB đã ký". Whether upload is manual or automated is fine to defer, but the diagram should match.
- The GitHub Pages privacy policy appears only in the diagram. It needs a one-line home (AD-19 or Deferred).

### F-18 [low] Operations dimension is implicit

There is no telemetry or crash reporting (AD-12), so the owner has no signal of field failures. State this explicitly as the operations posture: no runtime ops, issues are learned via the beta testers and store reviews, and diagnostics never leave the device. That marks the dimension as decided rather than silent.

## Mermaid diagram check

| Diagram | Syntax | Consistency |
| --- | --- | --- |
| Layer flowchart (Design Paradigm) | Valid. `-. cấm .-x` is a legal dotted link with an x head. | `F -x C` contradicts AD-2's partial ban and AD-14 (F-10). `ports` drawn as a sibling of core while the table says the port interfaces live *in* core. Minor; label it "core/ports". |
| Disk layout flowchart | Likely valid. Quote the subgraph title to be safe: `subgraph outside["Ngoài vault – không mã hóa"]`, since the bare ` - ` in an unquoted title can trip some renderers. | `guard` fields need the provisional-attempt state from F-01. The header has no magic, which differs from export's `PAKX`. Fine, but say whether the vault header has one. |
| Login state machine | Valid stateDiagram-v2. | 1. Missing `[*] --> Waiting` and a startup path to Wiping for `failCount=10` (F-01). 2. "hoàn bộ đếm" vs FR-5 "về 0" (F-04). 3. Startup guard precedence not stated: `wiping` and `có header` can both be true. 4. No self-loop for "same wrong string → báo sai, no count" (FR-5). Add `Ready --> Ready`. 5. `Checking --> Wiping` at 10 matches FR-4, and `Ready/Waiting/Corrupt --> Wiping` matches FR-9 and S4. 6. FR-12 "xóa nốt rồi mới hiện Login" matches `[*] --> Wiping --> NoAccount`. |
| Build and release flowchart | Valid. | Android path implies automatic upload to Play, which AD-19 does not state (F-17). Pages has no AD. |

## Capability coverage spot-check (PRD → spine)

- **Covered well:** FR-1–FR-8, FR-10–FR-11, FR-13–FR-16, FR-18–FR-19, FR-26 (modulo F-08), FR-29–FR-36, FR-38–FR-44, FR-46–FR-47, FR-50, FR-53–FR-65, NFR-1–NFR-9, NFR-11, NFR-13–NFR-14.
- **Weak or missing:**
  - NFR-12 (F-07).
  - FR-7 for header damage (F-04).
  - FR-12 / TC-6 under multi-file ops (F-02).
  - FR-62's sibling problem for the vault format (F-06).
- **UI-only FRs, correctly left to stories:** FR-9 hold-3s, FR-17, FR-20–FR-25, FR-27–FR-28, FR-37, FR-45, FR-49. These are not architectural.

## What is good and should be kept

- Single owners with crisp boundaries: AD-3, AD-8, AD-9, AD-14, AD-15, AD-17.
- AD-5 correctly catches the libsodium p=1 constraint against the addendum's p=4.
- AD-10's permanent-format rule with committed fixtures and a CI gate.
- AD-12's mechanical INTERNET-permission gate, and AD-18/AD-19 for a public repo with no Mac.
- Conventions that pre-empt classic drift: ids, time encoding, sort tie-break, search normalisation, sealed results, ARB key mapping.
