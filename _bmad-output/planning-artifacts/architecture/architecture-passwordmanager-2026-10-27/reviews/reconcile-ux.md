---
review: reconcile-ux
spine: ../ARCHITECTURE-SPINE.md (draft, 2026-10-27)
sources:
  - _bmad-output/planning-artifacts/ux-designs/ux-passwordmanager-2026-10-26/EXPERIENCE.md (final)
  - _bmad-output/planning-artifacts/ux-designs/ux-passwordmanager-2026-10-26/DESIGN.md (final)
  - _bmad-output/planning-artifacts/ux-designs/ux-passwordmanager-2026-10-26/.memlog.md
date: 2026-10-27
---

# Reconcile: Architecture Spine vs UX (EXPERIENCE + DESIGN)

## Verdict

**Mostly aligned on the big calls, with gaps in the shell layer.** The spine covers the main UX-driven decisions: Cupertino on both platforms (AD-1), one owner for decrypted state and lock (AD-3, AD-9), clipboard behavior per platform (AD-11, AD-17), shared secret widgets (AD-14), settings fields (AD-13), date and l10n conventions, and the icon and font question the UX memlog passed on (AD-1 picks CupertinoIcons plus the system font).

What it does not yet cover is the **imperative shell around navigation and lifecycle**:

- the navigator topology and how lock tears modals down
- flushing the draft on lock
- the Android Back policy
- lock and result handling while OS share and picker UI is open
- tablet presentation
- live theme and language wiring
- scoping of non-vault UI state

One rule **contradicts** the UX: AD-9's "cancel operations that have not started writing" combined with the 500 ms draft debounce. Two rules **conflict with what the platform allows**:

- AD-13's "only `guard` + `settings` outside the vault" does not survive the OS share sheet and file picker.
- AD-1's "portrait only" cannot be enforced on Android 16+ large screens.

None of these needs a new paradigm. Most are a new AD, or a clause added to AD-1, AD-9, AD-13 or AD-17.

Severity: **High** means an agent following the spine as written will likely ship a UX-contract violation or a data bug. **Medium** means agents will each improvise, so the result will be inconsistent or crash on some devices. **Low** means a convention or clarification is needed.

---

## Findings

### F1: Draft must be flushed on lock and on background; AD-9 currently cancels it [High]

- **UX:**
  - EXPERIENCE › State Patterns, "Bị khóa": "Form card đang mở → đã có bản nháp (FR-26)".
  - Key Flows UJ-2 Failure: a lock while S9 is being filled restores everything she had typed.
  - Interaction Primitives, "Bản nháp": it saves after every change.
  - S6 reopens "S9 hoặc S10 đúng loại".
- **Spine:**
  - The Bản nháp convention: `saveDraft` is debounced ≤ 500 ms.
  - AD-9's lock sequence: "chờ thao tác ghi đang chạy xong … → **hủy thao tác chưa bắt đầu ghi** → `VaultSession.lock()`".
  - Together, any debounced draft write still pending at lock time gets cancelled, so the last ≤ 500 ms of typing is lost. Session-limit locks happen "kể cả đang thao tác", which makes this realistic.
- **Gaps:**
  1. **Flush before lock.** No rule makes the open form flush its pending draft synchronously before `VaultSession.lock()`. The same flush is needed on `AppLifecycleState.paused`/`hidden`, because the OS can kill the process in the background (2 GB Android reference device). After a kill, the draft is the only thing that survives.
  2. **Draft schema.** The spine does not define it. S6 needs at least: `kind` (new | edit), `cardId` for an edit, the field values, and a pre-assigned id for a new card.
  3. **Save is two file operations.** Save writes `cards`, then deletes `draft`. AD-7 says "mỗi thao tác nghiệp vụ ghi đúng một file". A crash between the two leaves a draft for a card that is already saved. S6 would then offer it and could **duplicate** a new card. Proposal: give the new card's id to the draft up front, and on restore discard any draft whose id already exists in `cards` with identical content. Or state the ordering and its accepted risk explicitly.
  4. **Restored edit drafts and S12.** For a restored edit draft, the form compares against the card's stored values as its baseline. Opening S10 from a draft should count as dirty, so swipe-down or Cancel triggers S12. The spine should state this so S12 behaves the same in every case.
- **Proposal:** extend AD-9 with "flush draft (synchronous write, not cancellable) before `lock()`". Add a lifecycle rule that flushes the draft on `paused`/`hidden`. Define the draft payload and the Save/discard ordering under AD-3/AD-6.

### F2: Navigator topology and modal teardown on lock are unspecified [High]

- **UX:**
  - EXPERIENCE › IA "Ngăn xếp modal": at most two sheet tiers (page-sheet, then bottom-sheet). Alerts can sit on any tier. There is no third sheet.
  - Lock removes the whole stack and returns to S3.
  - tab-bar: "Ẩn khi sheet che toàn màn". Sheets cover the tab bar, while S20 is a push *inside* the Settings tab with the tab bar visible.
  - Each tab keeps its own state.
- **Spine:** AD-1 lists the building blocks (`CupertinoTabScaffold`, `Navigator`/`CupertinoPageRoute`, Cupertino sheets and dialogs). AD-9 says "gỡ toàn bộ navigation về S3". The spine does not say:
  - which navigator hosts what: page-sheets, bottom-sheets, the wheel panel, popup-menus and alerts on the **root** navigator; push screens (S2, S20) on the tab navigator or the root;
  - where the auth gate lives. If the gate sits *below* the root `Navigator` (as `home:`), swapping Login and Home does **not** dispose dialogs and sheets already pushed on the root navigator. Decrypted data would stay in their widget state after `lock()`. The gate has to sit above the navigator (for example in `CupertinoApp.builder`, or a navigator keyed by session epoch), or lock has to call `popUntil` on the root navigator **and** every tab navigator;
  - that the two-tier limit is enforced in one place, a shared presenter, rather than by convention.
- **Proposal:** a new AD "Navigation shell":
  - One root navigator hosts every modal.
  - Each tab has its own navigator for pushes.
  - The session gate is keyed by session epoch above all navigators, so lock rebuilds everything.
  - A single `ModalPresenter` in `features/shared` exposes `showPageSheet`, `showBottomSheet`, `showAlert` and `showPanel`, enforces the max-two-sheets rule, and centralizes swipe-dismiss guards (F4).

### F3: OS share sheet and file picker (S23/S24): lock, late results, temp files, iPad anchor, file type [High]

- **UX:**
  - EXPERIENCE S23, S24 and Responsive "Import / Export": the real OS UI, not a redrawn version.
  - State Patterns: "Khóa khi chưa ghi | S21, S24, S25: Thao tác bị hủy".
  - "Export xong": when the share sheet closes (sent or not), close the Export sheet and return to S18.
  - UJ-3 Failure: "App khóa khi chị đang ở trình chọn file → import bị hủy".
  - The tablet form factor applies here too.
- **Gaps in the spine:**
  1. **System UI cannot be dismissed from Flutter.** If the session limit fires while the picker or share sheet is up, `lock()` runs underneath it. The picker later returns a file, or the share future completes, into a locked app. AD-9 needs a rule: every `await` on a platform port is followed by a session-epoch check, and the result is discarded if the epoch changed. That rule makes "import bị hủy" true.
  2. **"Background" is not defined.** The Android picker is a separate activity, so the app goes to `paused` and the autolock timer starts. On iOS the picker and share sheet are in-process. AD-9 says "lúc vào nền" and AD-17 says "tiền cảnh" without mapping them to `AppLifecycleState`. `inactive` also fires for Control Center, the app switcher, and Android multi-window focus loss. Proposal: background = `hidden`/`paused`; `inactive` does not start the autolock timer.
  3. **AD-13 contradiction.**
     - Sharing requires writing the `.pakx` file to disk: `share_plus` takes a file or `XFile`, and even `XFile.fromData` is spooled to a temp file.
     - On iOS, the document picker copies the chosen file into the app's `tmp`/`Inbox`.
     - AD-13 says nothing outside the vault except `guard` and `settings`. The export file is encrypted, so this is not a confidentiality breach, but the rule as written is false.
     - Proposal: allow one ephemeral `transfer/` cache directory, excluded from backup, deleted after the share completes or on next startup, and deleted on wipe.
  4. **iPad share anchor.** `share_plus` on iPad requires `sharePositionOrigin`; without it the call throws or crashes. UX targets tablets. The share port must take an anchor rect, from the "Tạo file" button.
  5. **Picker filter.** `.pakx` has no registered MIME type or UTI, and chat apps such as Zalo can rename files or drop the extension. The picker should accept any file (`*/*` / `public.data`), with validation done only by the `PAKX` magic (AD-10). This keeps "File không hợp lệ" (S27) as the single rejection path. Optionally declare an exported UTType on iOS. Either way, state it.
  6. **Share completion.** "Close Export sheet when the share menu closes" depends on the share future completing on both platforms. The port contract should say what happens when the result is unavailable (older Android): treat it as closed.

### F4: Android system Back has no architectural rule [Medium]

- **UX:** EXPERIENCE › Responsive & Platform, "Android — nút Back hệ thống":
  - Back closes the top layer (dialog → sheet → push).
  - On a dirty form card, Back shows S12, the same as swipe-down.
  - At a tab root, the OS default applies (the app goes to background).
  - On S4 while holding, Back cancels.
- **Spine:** nothing. AD-1 does not mention `PopScope` or predictive back.
- **Gaps:**
  - Cupertino dialogs are popped by Back even when `barrierDismissible: false`, so each alert needs an explicit Back meaning:
    - S6 (Back = "Tiếp tục"? keep the draft and dismiss? The UX does not say, so the spine or UX must pick one)
    - S26: Back = Hủy
    - S27: Back = OK
    - S13 and S17: Back = Hủy
  - S5 (wiping) must swallow Back.
  - While an activity-indicator is showing (KDF or write: S2, S3, S20–S22, S25, S26), Back must be blocked, so it cannot bypass FR-16's "finish the write first".
  - Android 14+ predictive back (`enableOnBackInvokedCallback`, on by default for newer target SDKs) requires `PopScope(canPopHandler)` rather than `WillPopScope`.
  - Cupertino routes on Android need a decision on predictive-back animation: none, or the Cupertino pop animation. Flutter's built-in predictive-back page transition is Material-styled, which AD-1 forbids.
- **Proposal:** fold this into the Navigation shell AD (F2). The `ModalPresenter` declares a Back and swipe policy per presentation (dismissible / guarded-by-dirty / blocked-while-busy / blocked). Add a table that gives the Back result for each dialog.

### F5: Tablet layout and portrait-only are not backed by a mechanism, and portrait-only is not enforceable on Android 16+ [Medium]

- **UX:**
  - EXPERIENCE › Foundation: phones **and tablets** (NFR-12).
  - Responsive, "Máy tính bảng": a single centered column, max `content-max-tablet` 672; page-sheet and bottom-sheet appear as centered form sheets, iPad-style.
  - DESIGN › Layout: no master-detail, portrait only.
  - UX memlog: Q16a, and the line "Hướng màn hình: chỉ dọc trên cả điện thoại và tablet".
- **Spine:** AD-1 says only "Chỉ hỗ trợ hướng dọc". It does not specify:
  - A shared width-constraining wrapper. Without one, every screen will improvise, or stretch full width, which DESIGN's Do's & Don'ts forbid.
  - Sheet presentation by size class. Flutter's Cupertino sheet routes do not produce an iPad-style centered form sheet out of the box, so this needs a custom presenter (F2).
  - How portrait is enforced:
    - iOS: Info.plist orientation keys for iPhone and iPad. Portrait-only on iPad needs `UIRequiresFullScreen`, otherwise App Store validation requires all orientations. That key is deprecated as of iPadOS 26 and must be verified.
    - Android: `screenOrientation="portrait"` is **ignored on large screens (sw ≥ 600 dp) for apps targeting API 36+** (Android 16 adaptive-app change).
- **Consequence:** on Android tablets and foldables, and potentially future iPad windowing, the app *will* be shown in landscape or in resizable windows. Layouts must stay correct at any width and height. The 672 centered column largely achieves that. The spine should state that portrait is a preference, not a guarantee, and that screens must not assume a fixed aspect ratio. This is especially important for the S14 vertical rhythm in DESIGN › Layout, which is given in absolute positions measured from the top.
- **Proposal:** add to AD-1: a `ContentColumn` wrapper in `features/shared` (max 672, centered, background full-bleed); sheet size-class presentation inside the `ModalPresenter`; the orientation config per platform with the large-screen caveat recorded as an accepted platform limit; and layouts that are scrollable and safe at any width and height.

### F6: UI state scoping beyond "decrypted data" (app switching vs tab switching vs lock) [Medium]

- **UX:**
  - search-bar: the keyword survives tab switches and app switches and is **cleared on lock**. UJ-1 Failure confirms the cleared keyword after re-login.
  - credential-card: revealed passwords and expanded notes are **not** kept. They reset when leaving the tab or on lock.
  - Interaction Primitives, "Chuyển app": coming back within autolock shows the same screen in the same state.
  - IA: each tab keeps its own state.
  - S14 holds a freshly generated password; S11 holds one too.
- **Spine:** AD-9 scopes only "provider chứa dữ liệu giải mã" to the session. Not covered:
  - **The search query.** It is not decrypted data but it reveals which sites the user has accounts with, and it must be cleared on lock. It needs session scope.
  - **The S14 generated password and the S11 password.** These are secrets in RAM outside `VaultSession`. NFR-4 ("bỏ dữ liệu giải mã khỏi bộ nhớ") reads naturally to include them. AD-3 does not list them, and AD-9 does not scope them.
  - **Reveal and expanded state reset on tab leave.** `CupertinoTabScaffold` keeps inactive tabs mounted, so this state persists unless explicitly reset on tab-index change. It needs a stated scope: tab-visit scope, distinct from session scope.
  - **Process death (Android; also iOS memory jettison).** "Quay lại đúng màn, đúng trạng thái" is impossible after the OS kills the process, because the DEK lives only in RAM by design. The spine should record this as an accepted limitation: process death equals lock, and the form is recovered via the draft (F1). Otherwise an agent may try Flutter state restoration, which would persist UI state, possibly including secrets, to OS-managed storage. That would contradict AD-6 and AD-13.
- **Proposal:** add a scoping table to the conventions. Each kind of state is assigned one scope: app, session, tab-visit, or route. Secret-bearing state means anything shown as a password, the search query, and form text. All of it is session-scoped at minimum. Add "no `RestorationScope`/state restoration" to AD-13.

### F7: Live theme and language switching: root wiring, "System" modes, system bars [Medium]

- **UX:**
  - EXPERIENCE › popup-menu: "Đổi Ngôn ngữ / Giao diện có hiệu lực ngay, không cần khởi động lại".
  - Foundation: the language defaults to the device language; theme is System / Light / Dark with System as the default.
  - The Login screens (S1/S3) are themed and localized **before** unlock.
  - "Không màn chờ khởi động riêng".
- **Spine:** gen-l10n and the token conventions exist, and AD-13 stores the language and theme. Missing:
  - **One rule** for how the root is driven: `SettingsStore` is a Riverpod provider read **above** `CupertinoApp`, which sets `locale` and `CupertinoThemeData.brightness`. `null` means System; `CupertinoApp` has no `themeMode`, so System = `brightness: null`.
  - **Token colors must resolve against the effective brightness**, not `MediaQuery.platformBrightness`. Otherwise Light/Dark overrides break wherever a widget reads the platform value. Proposal: tokens as `CupertinoDynamicColor`, or a single `AppColors.of(context)` that reads `CupertinoTheme.brightnessOf`.
  - **Language default and fallback.** If the device language is neither `vi` nor `en`, the app falls back to `en`. The spine must also say whether the stored language is "unset = follow device" or is fixed on first launch. AD-13 lists only "ngôn ngữ"; it should allow an unset value.
  - **Settings load before the first frame** (synchronous read before `runApp`, or a native splash held), so Login never flashes the wrong language or theme.
  - **System bars.** Status-bar icon brightness (`SystemUiOverlayStyle`) must follow the *app* theme when it differs from the system's. Android 15+ edge-to-edge is enforced for API 35+ targets, and Android 3-button navigation gives a different bottom inset than the iOS home indicator assumed in DESIGN measurements, so the tab bar and toast offsets must use safe-area insets.

### F8: Android clipboard check-on-resume would show a system "pasted" toast [Low–Medium]

- **UX:** EXPERIENCE › Responsive "Clipboard": "UI giống nhau trên hai nền tảng … **không có thông báo nào khi xóa**".
- **Spine:** AD-17 says "Android so khớp nội dung khi trở lại tiền cảnh".
- **Problem:** on Android 12+, reading clip *content* (`getPrimaryClip`) set by another app shows the system toast "PAK Manager pasted from your clipboard". If the user copied something else in another app, the resume check triggers a visible OS notification. That breaks the UX contract and looks alarming in a password manager.
- **Proposal:** compare without reading content:
  - `getPrimaryClipDescription()`: the label is set to a per-copy nonce, and the timestamp is available on API 26+.
  - Read content only if the description matches.
  - Put this in the Pigeon clipboard group (AD-11).

### F9: Icons: AD-1 overrides DESIGN for iOS too, and some specified glyphs may not exist [Low]

- **UX:**
  - DESIGN › Components: "Icon: SF Symbols trên iOS … Android … chọn bộ icon chuyển sang bước architecture".
  - Specific glyphs:
    - the history icon (clock with a counter-clockwise arrow, left half of the ring dotted)
    - tab icons: key / magic wand with sparkles / dial with a geared rim
    - copy, refresh, eye / eye-slash, ⋯, trash, ⌃⌄, ✓, search, clear (x)
  - UX memlog line 43.
- **Spine:** AD-1 uses `CupertinoIcons` on **both** platforms. This is reasonable, keeps one codebase, and stays licence-safe. But it also replaces real SF Symbols on iOS, which DESIGN did not hand over. The spine should say so explicitly as a deliberate override.
- **Missing:** a glyph mapping table. The dotted-half history glyph is unlikely to exist in `cupertino_icons` 1.0.9. Plausible stand-ins: `arrow_counterclockwise` / `clock`. Others: `wand_stars`, `gear_alt`, `doc_on_doc`, `arrow_2_circlepath`, `chevron_up_chevron_down`. Each needs verification against the 1.0.9 glyph set. If a custom glyph is needed, decide now between an SVG or `CustomPainter` in `assets/` and a new font dependency, since AD-12 requires a spine update for any new dependency.

### F10: Custom Cupertino-look components need a shared home; the toast must render above sheets [Low]

- **UX and DESIGN:**
  - popup-menu: UIMenu-style but flat, with a 1 px border, no shadow and no scrim.
  - bottom-sheet: a grabber, content height, stacked over a page-sheet, scrim-tap dismiss.
  - wheel-picker: a bottom panel with "Xong" that applies on close.
  - hold-confirm-button: a 3 s progress ring, reversing on release.
  - toast: "Hiện được trên cả sheet"; one at a time; it survives a sheet closing, since Import closes the sheet and then shows the toast.
- **Spine:** the Structural Seed's `features/shared` lists SecretField, SecretText, toast and theme only. Flutter's Cupertino set does not provide most of these as specified. Without a rule, each feature folder will build its own.
- **Proposal:**
  - List these components in `features/shared/` alongside the `ModalPresenter` (F2).
  - The toast host lives in the root `Overlay`, above the root navigator, so it sits above every modal route.
  - The toast is cleared on lock.
  - Optionally add a lint that bans `package:flutter/material.dart` in `lib/features/`, which enforces AD-1 mechanically.

### F11: Recent expiry "biến mất ngay" while the sheet is open needs a timer [Low]

- **UX:** EXPERIENCE › recent-row: an entry older than 72 h disappears **immediately** if S16 is open, otherwise on next open.
- **Spine:** the Recent convention filters only on read, on open, and on write.
- **Proposal:** while S16 is mounted, the Recent provider schedules a single timer for the next expiry. One sentence in the convention covers it.

### F12: Text scaling policy [Low]

- **UX:** EXPERIENCE › Accessibility Floor: "không cam kết Dynamic Type".
- **Platform behavior:** Flutter honors the system text scale by default. DESIGN uses fixed heights:
  - row 44
  - button 48
  - chip 50
  - toolbar 49
  - recent-row 72
- **Gap:** large system font sizes will clip text, so the spine should pick one option:
  - (a) clamp `textScaler` at the root, for example ≤ 1.3, or
  - (b) make those heights minimums.

  It is a one-line convention, but without it agents will choose differently per screen.

---

## Checked and consistent (no action)

| UX decision | Spine coverage |
|---|---|
| iOS look on Android, no Material (memlog Q2a; DESIGN Do's) | AD-1 |
| Font: SF on iOS, Roboto on Android (memlog assumption) | AD-1 |
| Portrait only (memlog) | AD-1 (enforcement gap: F5) |
| Lock removes all surfaces, clears decrypted data, clears clipboard if foreground (EXPERIENCE › Bảo mật hiển thị & phiên) | AD-3, AD-9, AD-17 (teardown mechanics: F2) |
| Timer setting changes apply from next count | AD-9 last sentence |
| Lock while writing finishes the write; lock before writing cancels (S20/S22/S26 vs S21/S24/S25) | AD-9 (draft exception: F1; system UI: F3) |
| Interrupted wipe resumes at S5 before S1 | AD-7, state machine |
| Countdown survives reboot by restarting at 30:00 | AD-8 |
| Repeating the same wrong string does not count, button busy blocks repeats | AD-8 |
| Non-ASCII kept in field, error order, button disabled | AD-14, AD-15 (order matches EXPERIENCE inline-message priority) |
| No autofill, suggestions or learning; paste allowed, copy/cut blocked; no selection on secrets | AD-14 |
| iOS clipboard local-only with expiry; Android 13 sensitive flag | AD-11, AD-17 |
| Screenshot and app-switcher not blocked (NFR-10) | Capability map: accepted risk |
| Export date stored even if share dismissed; settings fields (language, theme, 3 timers, generator criteria, export date) | AD-13 |
| Generator criteria persisted (FR-35); first run all on, length 16 | AD-13 |
| Search: title only, accent and đ-insensitive, in-RAM | Conventions › Tìm kiếm, AD-6 |
| Fixed date formats in both languages, 24 h | Conventions › Id và thời gian |
| Microcopy keys map to ARB keys | Conventions › Chuỗi giao diện |
| Light/dark token pairs from DESIGN | Conventions › Màu và token (resolution rule: F7) |
| File compatibility iOS ↔ Android (FR-61) | AD-10 |
| No accessibility floor | Deferred table |

## Suggested spine edits (summary)

1. **New AD "Navigation & presentation shell"** (F2, F4, F5 part, F10):
   - root navigator for modals, tab navigators for pushes
   - a session-epoch-keyed gate above all navigators
   - a `ModalPresenter` with the two-tier limit, the dirty-guard, the Back and swipe policy table, and tablet form-sheet sizing
   - the toast host in the root overlay
   - a `ContentColumn` max 672
2. **AD-9 amendments** (F1, F3, F6):
   - flush the draft before `lock()` and on `paused`/`hidden`
   - define background as `hidden`/`paused`, with `inactive` excluded
   - a post-`await` session-epoch check for platform ports
   - session scope for the search query and the generator password
   - process death equals lock, as an accepted limitation
3. **AD-3/AD-6 additions** (F1): the draft payload schema, and the Save → delete-draft ordering with dedup on restore.
4. **AD-13 amendments** (F3, F6, F7):
   - an ephemeral `transfer/` cache directory, backup-excluded and swept on start and on wipe
   - no state restoration
   - the language may be "unset = follow device"
5. **AD-1 amendments** (F5, F7, F9):
   - per-platform orientation configuration plus the Android 16 large-screen caveat
   - the theme and locale root wiring and the brightness resolution rule
   - system bar style and safe-area rules
   - the explicit CupertinoIcons-on-iOS override and a glyph mapping table
6. **AD-11/AD-17 amendment** (F8): compare the Android clipboard by description (label nonce, timestamp) before reading content.
7. **Conventions** (F6, F11, F12):
   - a state-scope table
   - a Recent expiry timer while S16 is open
   - the text-scale policy
8. **Share port contract** (F3): an anchor rect for iPad, the completion semantics, and the accept-any-file picker with magic-only validation.
