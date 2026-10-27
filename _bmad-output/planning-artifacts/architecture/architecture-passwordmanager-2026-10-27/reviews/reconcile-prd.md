---
title: Reconcile — ARCHITECTURE-SPINE vs PRD + addendum
spine: ../ARCHITECTURE-SPINE.md
sources:
  - ../../../prds/prd-passwordmanager-2026-10-23/prd.md
  - ../../../prds/prd-passwordmanager-2026-10-23/addendum.md
date: 2026-10-27
---

# Reconcile: ARCHITECTURE-SPINE vs PRD + addendum

## Verdict

**Mostly aligned, needs a revision pass before stories.** Every feature area (F1–F7) and every NFR has a governing AD, and the big security decisions (two-tier key, write-before-check counter, monotonic wait, single export format, no Keychain, no network) faithfully carry the PRD and addendum. The gaps are in **edge cases inside the decisions**, not missing decisions: two of them (crash during the login check, and header corruption being read as a wrong password) can lead to the outcomes the PRD most explicitly forbids — data wiped by a non-password cause, or the 30-minute wait bypassed. Most of the rest are platform details from the addendum/PRD that interact badly with another AD (atomic rename vs iOS backup flag, AD-13 vs temp files from share/pick, API 24 floor vs the accepted clipboard risk).

Out of scope by instruction: libsodium Argon2id p=1 instead of addendum p=4 (intended deviation).

## Findings

### F-1 [HIGH] Crash during the login check is not handled at startup (FR-5, FR-4, TC-3; PRD §1 accepted risk 2)

AD-8 writes the incremented counter **before** the KDF, which is right. But the spine never says what startup does with the state that write leaves behind when the app dies mid-check:

- **10th attempt killed mid-KDF.** The guard holds `failCount = 10` with no `wiping` flag. The state machine in Structural Seed only enters `Wiping` from "cờ wiping còn" or from `Checking`; `[*] --> Ready: có header` would show Login with 0 attempts left. PRD §1 explicitly accepts that this case "bị tính là sai và có thể dẫn đến xóa dữ liệu" — so the intended behavior is to wipe, but no rule says so.
- **Attempts 5–9 killed mid-KDF.** The counter is incremented, but nothing records that a 30-minute wait should start (`waitStartMonotonic` is only meaningful after a confirmed failure). Next launch: `Ready` with no wait. A script can therefore submit → kill during KDF → relaunch, and skip every 30-minute wait (still capped at 10 total, but TC-3 says the wait must hold "kể cả khi tắt app").

**Needed rule (AD-8 + state machine):** the pre-KDF write records a pending-check marker (or provisional `waitStart` for attempts ≥ 5). On startup, a pending check is resolved as a failure: `failCount ≥ 10` → `Wiping`; `5 ≤ failCount ≤ 9` → `Waiting` from a fresh `(bootId, monotonic)`. A successful check clears the marker in the same write that resets the counter.

### F-2 [HIGH] Header corruption / missing header is indistinguishable from wrong password or "no account" (FR-7, TC-6; addendum "header được xác thực riêng")

AD-4: "mở bọc DEK thành công = mật khẩu đúng", so any unwrap failure is a wrong password. That separates *data-file* corruption from wrong password, but not **header** corruption: a truncated/bit-rotted `header` fails the unwrap on every attempt and walks the user to the 10th-attempt wipe — exactly what FR-7 says must never happen. Related holes:

- AD-5 rejects out-of-range KDF params "trước khi chạy KDF" for vault headers too, but does not say the result is `corrupt` (not `wrongPassword`, not counted).
- State machine `[*] --> NoAccount: không có header`: if `header` is missing but `cards`/`recent`/`draft` exist, the user is offered "Tạo tài khoản", which would overwrite data (TC-6). Account creation itself writes several files (header + initial data files), contradicting AD-7's "one operation = one file" without saying which file is the commit point.

**Needed rule (AD-4/AD-6):** header carries a structural integrity check independent of the password (magic + version + checksum over the header bytes); parse/checksum/param-range failure → `corrupt`, never counted. Define startup classification for every file-presence combination (header only, data without header, etc.), and make `header` the last file written at account creation (absent data files = empty).

### F-3 [MEDIUM] No compatibility rule for the vault format across app updates (TC-6; FR-62 by analogy)

AD-10 makes the **export** format a permanent contract with fixtures in CI, but the **vault** format (header + AEAD files, AD-6) has a version field and no rule. An update that changes the vault layout without a reader/migration would surface as "Dữ liệu bị hỏng" (and with F-2, possibly as wrong password), and the user's documented recovery is "Xóa & Tạo tài khoản mới" — data loss caused by the app (TC-6). Also unspecified: what an older app does on a newer vault version (should be "update the app", never counted, never wipe).

**Needed rule:** extend AD-10's discipline to the vault: released vault versions are never altered; new app versions read/migrate every older version (migration = one atomic write per file, header last); vault fixtures per version in `test/fixtures/vault/`; unknown-newer version → a distinct non-counting result.

### F-4 [MEDIUM] ASCII/length validation at Login and Import fields is not tied to the counter (FR-2 rationale, FR-3; addendum "Ô nhập mật khẩu — Kiểm tra ký tự ... Login, tạo tài khoản, đổi mật khẩu, export và import")

The addendum requires ASCII-only checking on **all** password fields including Login and Import. AD-14/AD-15 apply `PasswordPolicy` to create/change/export only. The PRD's stated reason for the ASCII rule is that a keyboard/OS re-encoding "sẽ tính là nhập sai, và có thể xóa dữ liệu". If Login submits a non-ASCII (or >128-char) string, AD-8 counts it — the very failure mode the rule exists to prevent.

**Needed rule:** `LockoutGuard` (not the widget) rejects input that cannot be a valid master password (non-printable-ASCII, <15, >128) **before** incrementing, returning a non-counting result; same pre-check for the import password and for FR-13/FR-51 re-verification.

### F-5 [MEDIUM] Export/import temp files are outside AD-13's two-file allowlist and outside the wipe (FR-55, FR-56, FR-12, FR-11, NFR-8)

AD-13 says the app writes only `guard` and `settings` outside the vault, but:
- `share_plus` (FR-55) needs the `.pakx` written to a file (app cache/temp) before the share sheet opens; it lingers after sharing.
- iOS document picker / Android `file_selector` copy the picked file into the app's tmp/Inbox/cache (FR-56).

These are encrypted, so TC-1 is not broken, but they contradict AD-13, are not covered by the AD-7 wipe sequence ("xóa mọi thứ", FR-12), and their backup exclusion depends on which directory they land in (Caches/tmp vs Application Support).

**Needed rule:** name one transfer temp directory, write/read export/import files only there, delete after share/import completes, and include it in the wipe sequence and the backup-exclusion rule. Amend AD-13 accordingly.

### F-6 [MEDIUM] iOS backup-exclusion flag is lost on every atomic write (NFR-8; AD-7 × AD-11)

AD-11: "iOS: mọi file của app đặt cờ `isExcludedFromBackup`". AD-7: every write is temp → rename over. `isExcludedFromBackup` is a per-item resource value; the renamed temp file is a new item and does not inherit the old file's flag, so after the first save the vault files become eligible for iCloud backup. (Same for `guard`/`settings`.)

**Needed rule:** set the flag on the containing directory (the app's data root under Application Support) once at startup and verify it, or have `AtomicFileWriter` set it on the temp file before rename. Add a test/assert path through the port.

### F-7 [MEDIUM] Android floor API 24 silently widens the accepted clipboard risk (PRD §1 accepted risk 5, FR-65)

The PRD accepts that on Android copied content "có thể còn trong clipboard tối đa khoảng 1 giờ" — that bound is the Android 13+ system auto-clear. The spine picks API 24 as minimum; on Android 7–12 there is neither `EXTRA_IS_SENSITIVE` nor system auto-clear, so a password copied and never returned to stays in the clipboard **indefinitely** (and is visible in keyboard clipboard history, e.g. Gboard). This is not recorded as an accepted risk anywhere in the spine.

**Needed:** either record the widened risk explicitly (owner sign-off, store-description note), or raise minSdk to 33 for this guarantee. One line in AD-11/AD-17.

### F-8 [MEDIUM] Tablet support vs portrait-only, no layout rule (NFR-12)

NFR-12 requires phone **and tablet** with adaptive layout. AD-1 fixes "Chỉ hỗ trợ hướng dọc" and no AD/convention governs adaptive layout. Platform detail: an iPad build that does not support all orientations must set `UIRequiresFullScreen = YES` (opting out of Split View/Slide Over), otherwise App Store validation rejects it.

**Needed:** state the tablet decision (portrait-only + `UIRequiresFullScreen`, or full rotation on tablets) and a layout breakpoint/max-content-width convention so each feature agent doesn't improvise.

### F-9 [MEDIUM-LOW] FR-63 bounds only KDF params, and the ceiling may itself exhaust memory (FR-63; addendum "Khi import")

FR-63's purpose is to stop a malicious file from hanging the app or exhausting memory. AD-5 bounds `m ≤ 256 MiB, t ≤ 10`, but:
- m = 256 MiB is 4× the fixed export value and may OOM/kill the app on the spine's own reference device (Android 7, 2 GB RAM); t = 10 at 256 MiB can run far beyond the 2 s budget.
- No file-size cap: AD-10 reads the whole file and decrypts a JSON payload into RAM; a multi-GB file passes the param check.

**Needed:** tighten the import ceiling to what the weakest device can run (or exactly the released export param sets), add a max file size (vault ≈ 100 cards → a few hundred KB suffices) checked before reading, and a max JSON payload/card count.

### F-10 [LOW] Import picker must not filter by type (FR-56, UJ-3, FR-61)

FR-56 says non-PAK files are rejected with "File không hợp lệ" — i.e. the user can pick them and the app decides by content. Files arriving via Zalo/Drive/email often lose or change their extension, and on iOS a custom `.pakx` filter requires a declared UTI or the picker greys files out. Rule: picker accepts any file; validity is decided only by the `PAKX` magic + version in core.

### F-11 [LOW] Pending debounced draft is not flushed before lock (FR-26 × AD-9)

FR-26: after a lock, the next login reopens the draft. The convention debounces `saveDraft` ≤ 500 ms; AD-9's lock sequence destroys the DEK without mentioning a pending debounce, so the last edit before an absolute-session lock (FR-14 fires "kể cả khi người dùng đang thao tác") is dropped. Add "flush pending draft save" as step 0 of the lock sequence.

### F-12 [LOW] iOS `bootId` source unspecified (FR-6; addendum iOS clock)

AD-11 names Android `BOOT_COUNT` but not the iOS boot identifier. iOS has no boot counter; the usual source (`kern.boottime`) is derived from wall time and shifts when the user changes the clock. That errs in the safe direction under AD-8 (restart full 30 min), but the agent needs to know which source to use and that a clock change may restart the wait. Specify it in AD-11.

### F-13 [LOW] Search normalization must handle decomposed (NFD) Vietnamese (FR-19)

Titles can be typed/pasted in NFD form (base letter + combining marks), depending on keyboard/source. "bỏ dấu tiếng Việt" implemented as a precomposed-character table misses them. Convention should say: Unicode-decompose, strip combining marks, then map `đ/Đ → d`.

### F-14 [LOW] "Background" for autolock not defined in lifecycle terms (FR-15, FR-16)

Autolock counts from "app chuyển sang chạy nền". Flutter exposes `inactive`/`hidden`/`paused`; iOS goes `inactive` for Control Center, share sheet and document picker, Android `paused` for the system file picker (which FR-16 expects to be cancellable). Pin which state starts the autolock clock so all agents (session, clipboard-on-resume) use the same definition.

### F-15 [LOW] Android autofill suppression has no verification path (NFR-9; addendum Android `importantForAutofill="no"`)

The Deferred row covers only the iOS save-password prompt. The addendum's Android requirements (`importantForAutofill=no`, `IME_FLAG_NO_PERSONALIZED_LEARNING`) map only partially to Flutter flags; Google Autofill save prompts are not addressed. Extend the Deferred row (or AD-14) to Android Autofill, tested with Gboard/Laban Key.

## Checked and landed (no action)

- Two-tier key + key check value, change password rewraps header only (FR-7, FR-13; addendum key check value) — AD-4.
- Write-before-check, one check at a time, previous wrong string in RAM only (FR-5) — AD-8 (RAM-only consequence recorded in memlog).
- Monotonic wait incl. sleep, reboot restarts wait, clock change can't shorten (FR-6; addendum Android/iOS clocks) — AD-8, AD-11.
- No Keychain/Keystore, uninstall wipes all (FR-11; addendum Keychain) — AD-11.
- Resumable wipe with `wiping` flag, clipboard clear on wipe (FR-12; addendum) — AD-7.
- Fixed export params, params + version in header, range check before KDF, no Unicode normalization needed (FR-54, FR-62, FR-63; addendum KDF) — AD-5, AD-10.
- Import atomic, appends, keeps `createdAt`, unlimited export-password attempts, no Recent/settings/draft (FR-56–FR-60) — AD-7, AD-10.
- Clipboard: iOS expiry + localOnly + changeCount, Android sensitive flag + clear on foreground (FR-65; addendum clipboard) — AD-11, AD-17.
- Lock during write waits/rolls back, un-started import/export cancelled (FR-16) — AD-9.
- No network, CI manifest check, iOS packet capture (NFR-7) — AD-12, AD-19.
- CSPRNG for generator, at-least-one-per-class (NFR-6, FR-32) — AD-16.
- Settings outside vault contain no user data (TC-1) — AD-13.
- Accepted risks NFR-10 (screenshots/thumbnails) — mapped as "no code".
- PRD §8 store items — Deferred.
