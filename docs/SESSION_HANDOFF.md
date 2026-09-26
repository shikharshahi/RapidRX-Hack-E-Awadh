# Session handoff — 26 Sep 2026 (afternoon)

Continue from here. This session ran out of context after parallel agents
were stopped and their branches were merged.

## What this session finished

- Patient scan UI is wired: menu tile **Scan caretaker QR**, camera/stub
  scanner, typed-code fallback, commercial PIN on the patient phone, unlink
  from the account sheet, alerts go to `AppPrefs.alertPhone`.
- Pairing goldens for the patient scan / found / linked screens (EN + HI).
- Accidental `test/failures/*.png` dumps from a WIP merge were removed from
  git and ignored.
- This file plus [`HANDOFF.md`](HANDOFF.md) (project status).

## What was already on `main` before this wrap-up

Merged from agent worktrees (feature commits, not the “WIP snapshot”
messages):

| Area | On `main` |
|---|---|
| Health profile + PM-JAY mock | yes |
| Doctor verification + caretaker notes | yes |
| Offline `SyncQueue` | yes |
| Caretaker type + QR | yes |
| Haptics / pressable | yes |
| Dose alarm screen + demo tools | yes |
| Voice fallback chain | yes |
| Recording pulse / green chip | yes |
| Pharmacy conflict questions | yes |
| Patient pairing logic | yes (`4f64df36`) |

## Do not merge these worktrees

| Worktree branch | Why |
|---|---|
| `worktree-agent-ab7586f11e57b2657` (`f0a0548a`) | Firebase Functions **plus `functions/node_modules`**. Snapshot only. Do not merge. |
| `worktree-agent-a9ed929b1643f7d10` (`28c771e3`) | `pubspec.yaml` only: `cryptography`, `flutter_secure_storage`, `file_picker`, `web`. No vault code. Leave until encrypted-store work starts. |

The other `worktree-agent-*` branches were already merged; leftover “WIP”
commits are merge parents on `main`. Do not rebase them off history unless
you rewrite with the team’s agreement.

## 26 Sep 2026, later — PIN gate

Paid caretaker home asks for the patient’s PIN on every launch, locks for
five minutes after five wrong tries, and then shows doses, schedule and
notes only. Family home leads with misses and prescriptions from this week.
Hash copy: process map plus an `RXPIN` line in the WhatsApp message (ADR-63).
Tests: `test/caretaker_gate_test.dart` and the pairing confirm cases. 40
targeted tests passed on Flutter 3.47.5. Older screen goldens differ by
glyph antialiasing on this Linux host; they were not regenerated.

Four other branches are being built in separate worktrees (encrypted
records, data wipe, missed-dose calls, family portal). They are not merged
yet. Do not deploy Firebase. Do not install Stitch.

## Stopped work — not in the earlier wrap-up

See [`HANDOFF.md`](HANDOFF.md) for the full leftover list. The PIN gate
above is no longer in that list.

## 26 Sep 2026, evening — vault merged, portal hosted

Merged onto `feat/paid-caretaker-pin`: family portal, data wipe (ADR-65),
missed-dose call policy (ADR-66), encrypted vault (ADR-67). Vault tests:
14 passed (`test/secure_records_test.dart`, `test/record_check_golden_test.dart`).
A full `flutter test` on this Linux host still fails older goldens by
glyph antialiasing; those goldens were not regenerated.

Hosting only is live at https://rapidrx-portal.web.app on
`rscortgameryca@gmail.com`, project `rapidrx-portal`. Functions, Firestore
rules, Blaze and secrets were not deployed. `myrapidrx` is reserved.

Still open:
- Stitch plugin (not installed; do not install from an unverified source).
- Live Kokoro measurement on a cold Space (opt-in test exists, skipped).
- Release APK on a real phone, locked-screen alarm, two-phone QR, airplane-mode sync.
- Restore after uninstall on a device. IndexedDB is not built.
- Deploy Functions only if a Blaze plan and a Twilio token are approved.

## How to keep going

```powershell
.\tools\run.ps1 -Device windows
C:\flutter\bin\flutter.bat test
```

`main` is ahead of `origin/main`. Push only when asked.
