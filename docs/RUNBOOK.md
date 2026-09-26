# Runbook

## Machine

| Need | Version |
|---|---|
| Flutter / Dart | 3.47.2 / 3.13.2 |
| Android | SDK 36, JDK 17, licences accepted (`flutter doctor --android-licenses`) |
| Node | any recent — only for `tools/serve.js` |

`flutter doctor -v` should be green for Android and for Windows or Chrome. On the build machine
Flutter lives at `C:\flutter` and is not on `PATH`; the scripts find it there.

## Keys

The repository is public; no key is ever committed.

```bash
cp tools/keys.example.ps1 tools/keys.local.ps1
```

Fill in what you have. All of it is optional:

| Key | Without it |
|---|---|
| `GEMINI_API_KEY` | The "read the handwriting online" card never appears; everything else runs on the phone |
| `TWILIO_*` | Dose alerts do not send themselves; sharing and "send today's status" open WhatsApp for a person to press send |

The scripts write them to `build/dart_defines.json` (gitignored) and pass
`--dart-define-from-file`. A key built into an APK can be extracted from it: rotate it after the
event. The real fix — a proxy with App Check — is not hackathon work.

## Everyday

```bash
flutter pub get
```

```bash
flutter test
```

```bash
flutter analyze
```

Goldens are the UI spec. After an intended visual change:

```bash
flutter test --update-goldens
```

## Run

```powershell
.\tools\run.ps1 -Device windows
```

```powershell
.\tools\web.ps1
```

`web.ps1` builds a release with `--pwa-strategy=none` and serves it on `localhost:8080`;
`-NoBuild` serves the last build instantly.

## Build the APK

```powershell
.\tools\run.ps1 -Build apk
```

The APK lands in `build/app/outputs/flutter-apk/app-release.apk`, debug-signed so it installs
straight onto a demo phone.

## Before the demo

In `lib/core/dev_flags.dart`:

```dart
static const bool alwaysShowOnboarding = false;
static const bool voiceEnabled = true;
```

- [ ] **Warm the Kokoro cache**: online, with voice help on, walk every screen once. If the Space
      is asleep the first line takes ~30 s — do this early. After that the voice works offline
- [ ] Put the Gemini key in `tools/keys.local.ps1`
- [ ] Build the release APK and install it on **both** phones
- [ ] On a real phone, test the camera, the microphone, dictation, ML Kit reading a bill, and
      "find recent photos" — the browser exercises none of these
- [ ] **Watch a reminder fire**: set a medicine for the next slot, lock the phone, wait
- [ ] Run the whole flow end to end: onboarding → new prescription → approve → take a dose →
      caregiver home → send status
- [ ] Record a backup video
- [ ] Rotate the Gemini key after the event

## Known gaps — say them before anyone finds them

- **No cloud database.** Everything persists on the phone. The migration path is ADR-6.
- **The OTP is `1234`.** Phone auth needs Firebase's paid plan, and the screen says so.
- **Caretaker pairing has no server.** The patient scans the caretaker's QR code, and the
  caretaker types the 4-digit code the patient's phone shows (ADR-45). Nothing travels between
  the phones except what the two people carry; the screens say "Demo".
- **The voice agent is designed, not built** ([`VOICE_AGENT.md`](VOICE_AGENT.md)), and it is the
  one part that needs a backend.
- **Missed-dose alerts fire when the app opens**, not at the minute a dose is missed.
- **Reminders, camera, microphone and ML Kit are platform code.** Their decisions are tested on a
  laptop; the handoff to Android must be seen on a phone (the checklist above).

## If you are behind — cut in this order

Chemist audio → every-N-days and SOS → the voice.

**Never cut:** the prescription photo, the verification cards, the red-card lock, the daily tick
and **"सब ले ली"**, the caregiver message, the calendar.
