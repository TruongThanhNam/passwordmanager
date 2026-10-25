# Research digest: offline mobile password managers (2026-10-23)

Web research subagent, used as PRD input. Items marked "unverified" have not been checked.

## 1. Comparable apps: backup, export and import
- **KeePassDX (Android):** local, GPL3 app. Uses KDBX 1–4 with AES, Twofish, ChaCha20 and Argon2. No third-party audit.
- **KeePassium (iOS):**
  - The vault file (KDBX) is itself the export.
  - Keeps hidden automatic backups: a "latest" copy plus timestamped copies made before edits, deleted after 2 months.
  - Its KB says merge is "not supported yet". That page may be out of date.
- **Strongbox:** uses the KeePass and Password Safe formats. Advertises "automatic compare & merge".
- **Enpass:** the backup is encrypted with the master password. Restoring several vaults requires "Erase everything and start over", so it works as an overwrite.
- **Bitwarden:** the export is either "account restricted" or "password protected". The second uses a separate password and can be imported anywhere.
- **KeePass 2 merge:** matches entries and keeps the newest by last-modified time, with older versions kept in history.

## 2. Brute-force protection and timers that survive clock changes
- **iOS passcode:**
  - Erases the device after 10 consecutive wrong attempts. Repeating the same wrong passcode does not count.
  - From the 5th attempt, delays escalate: 1, 5, 15, 15, 60 minutes.
  - The Secure Enclave enforces the delays, and a reboot restarts the current delay period.
- **Android:** `elapsedRealtime()` is monotonic but resets on reboot.
- **iOS:** `systemUptime` does not advance while the device sleeps. Firefox iOS had a lockout bug because of this.
- **Suggested pattern:**
  - Store the counter and remaining wait in Keychain / Keystore. Update them before checking the password.
  - Measure the wait with a monotonic clock. After a reboot, restart the current wait.
  - Never shorten a wait when the wall clock changes.
- **iOS pitfall:** Keychain items may survive uninstalling the app (undocumented behavior). The PRD must say whether reinstalling keeps or resets the counter.
- **Limit:** an app does not get Secure-Enclave-grade enforcement. Once the file is copied out, the KDF is the real defense.

## 3. KDF and master password
- **OWASP Argon2id minimums:** m=19 MiB/t=2/p=1, or m=46 MiB/t=1.
- **RFC 9106 second recommended profile:** m=64 MiB, t=3, p=4. This is also Bitwarden's default.
- **Suggestion:** calibrate unlock time to about 0.5–1 s on the weakest target phone.
- **NIST SP 800-63B-4:**
  - A single-factor password should be at least 15 characters.
  - Allow at least 64 characters.
  - No composition rules; use a blocklist instead.
  - The SHALL/SHOULD wording is unverified.

## 4. Mobile security hygiene
- **iOS clipboard:**
  - Set `UIPasteboard` with `.localOnly` and `.expirationDate`.
  - There is no way to keep copies out of clipboard-history apps.
- **Android clipboard:**
  - Set `EXTRA_IS_SENSITIVE` (API 33+).
  - Android 13+ clears the clipboard automatically after about 1 hour.
  - The app runs its own timer and clears only if the clipboard still holds the value it copied.
- **Screenshots and app switcher:**
  - On Android, `FLAG_SECURE` blocks screenshots and blanks the recents thumbnail.
  - On iOS, cover the screen when the app resigns active.
- **Going to the background:** wipe the in-memory key, either at once or after the autolock grace period.
- **OS backups:**
  - Android: `allowBackup=false` / `dataExtractionRules`, excluding both cloud-backup and device-transfer.
  - iOS: `isExcludedFromBackupKey` plus Keychain `…ThisDeviceOnly`.
  - The PRD must decide this. Excluding the vault from OS backups makes the export the only backup.

## 5. Password strength and length
- **Generated passwords:** entropy = length × log2(charset size).
- **Master password:** zxcvbn, which detects patterns.
- **Length range:**
  - Bitwarden allows 5–128.
  - Suggested: 8–128 with a default of 16–20, and at least about 80 bits for generated passwords.
