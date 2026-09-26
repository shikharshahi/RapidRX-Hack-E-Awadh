<div align="center">

<img src="assets/images/logo_mark.png" width="112" alt="RapidRX">

# RapidRX

**Every dose, on time · हर दवाई, सही समय**

*A prescription understanding agent that never guesses a dose.*

Hack-e-Awadh · UP AI Labs, Lucknow · HealthTech · **PS-01 Prescription Understanding Agent**
<br>Team **AfterBurners**

![Flutter](https://img.shields.io/badge/Flutter-3.47-02569B?logo=flutter&logoColor=white)
![Tests](https://img.shields.io/badge/tests-271%20passing-1B7A3D)
![Offline first](https://img.shields.io/badge/offline-first-F6B20A)
![Vault](https://img.shields.io/badge/records-AES--256--GCM-111111)
![Languages](https://img.shields.io/badge/हिंदी%20%2B%20English-111111)

</div>

---

## The pitch

An older patient leaves the clinic with a handwritten slip, a printed bill, and a strip of tablets. The family is somewhere else. RapidRX turns those four pieces of evidence into a daily schedule the patient can follow in Hindi or English, on a phone that may have no signal, and tells the family on WhatsApp when a dose was missed.

The record stays on that phone, sealed. The understanding step is a fixed pipeline — **JeV** — that a person can watch. Where the sources disagree, both readings stay on the card and a person picks. The app never silently chooses, and never invents a dose.

## The problem

Even the best models read Indian handwritten prescriptions correctly only about half the time. A system that bets on one reading of handwriting is right half the time about something that goes into a person's body. A cloud record makes the same bet, and then the chart is gone the moment the hall has no Wi-Fi.

## What is different

### JeV — Judge, Extract, Verify

The understanding step is three stages on the phone, shown while they run, not a spinner and a claim.

| Stage | What it does |
|---|---|
| **Judge** | What arrived, and how clear it is. A holiday photo or a café receipt is turned away, with the reason, and a way to use it anyway. |
| **Extract** | Medicines, doses and timings. `1-0-1 p/c x 10 days` and *"subah ek, khane ke baad"* become structure through rules, not a model. |
| **Verify** | The four sources are lined up. Each medicine is 🟢 they agree, 🟡 needs a look, or 🔴 they disagree. |

Printed text is trusted for *what* the medicine is (ML Kit reads a bill at over 99% on the device). The doctor's own words are trusted for *when*. A red card cannot be confirmed until a person picks which source is right. A timing the doctor gave is never moved. A timing nobody gave is labelled a suggestion.

Gemini can read the handwriting, once, after a person presses Read on a card that says exactly what leaves the phone. Those rows land in the same merge, against the same printed bill. They get no extra trust. Offline, that card is absent and JeV still finishes.

### The record stays on the phone, encrypted

Medicines, the dose log and the visit draft are one document.

- **AES-256-GCM**, a new nonce on every write.
- The data key is random. On Android it sits in the **keystore**.
- The same key is wrapped from the **PIN** (PBKDF2-SHA256, 600,000 rounds) so a backup can open after a reinstall. Changing the PIN re-wraps the key. It does not re-encrypt the records.
- A wrong PIN loads nothing. A tampered box is rejected. A corrupt file is left where it is, and the app continues empty.
- The working copy is app-private. A copy that actually holds records is mirrored to `Documents/RapidRX` through MediaStore, with no broad storage permission. The plain manifest holds only a version, times, counts and a hash of the phone number. Medicine names are not in it.
- On a new launch the phone looks for that copy and asks before restoring. Nothing found can load one labeled demo profile.

Language, voice, role and the PIN hash stay beside the vault. They are not the medical record.

### It works with no signal

Parsing, merging, scheduling, placement and the dose log run with no key and no network. Photos are read by ML Kit on the device. Fonts ship in the app, so Hindi does not turn into empty boxes in a hall with no Wi-Fi.

Voice help is Kokoro, cached per sentence. After one warm walkthrough it speaks offline. If the voice cannot be fetched, the phone's own voice speaks, and if that cannot, the screen stays quiet. Silence beats a wrong accent reading the wrong screen.

A visit is saved after every capture. A call or a flat battery mid-visit loses nothing. The optional handwriting read, if the phone was offline when it was asked for, waits in a queue and drains when the connection returns. The schedule does not change until a person reviews that reading.

### Built for the person who takes the tablets

- **Hindi and English**, chosen first. The device check that follows speaks in that language. Medicine names stay in English letters everywhere, because the patient matches them against the strip in their hand.
- **Body text never below 20pt, tap targets never below 64px**, one decision per screen.
- **Voice help** reads every screen aloud, and repeats it, in the chosen language.
- **Pictograms with words**, never instead of them.
- **Two gates before a dose is logged** — a tick per medicine, then "सब ले ली".
- A reminder at the time, a nudge thirty minutes later, then silence. A miss tells the caregiver. It does not ring louder.

### The family does not install a second medical record

A caretaker pairs by QR. The patient scans it. Family sees misses and new prescriptions. A paid caretaker types the patient's PIN each time, then sees doses, the schedule and notes.

WhatsApp carries plain text: any phone, forwardable to a doctor, pasteable into SMS. "Sent" and "opened in WhatsApp" are different words. The caretaker site ([rapidrx-portal](https://rapidrx-portal.web.app)) shows dose status, medicine name, time and alerts. It does not hold transcripts, photos, the health profile or Ayushman data. Until a live copy exists, that page reads a labeled demo.

<div align="center">
<img src="test/goldens/wizard_7_medicine_cards_sources_en.png" width="300" alt="Medicine cards, each quoting its sources">
&nbsp;&nbsp;
<img src="test/goldens/wizard_3_takeaways_en.png" width="300" alt="Checking what the doctor said">
</div>

## How a prescription becomes a taken dose

```
 ONBOARDING
   language  →  check this phone for a saved medical record
   voice help  →  phone + OTP  →  name  →  PIN  →  role
   patient:    age, optional height / weight / Ayushman (labeled demo)
   caretaker:  family or paid  →  QR for the patient to scan
      │
      ▼
 NEW PRESCRIPTION
   1  what the doctor said
   2  who is verifying — doctor checklist, or me
   3  photos: prescription, bill, strips — read on the phone and labelled
   4  the pharmacy page
   5  is this what the chemist said?
        a disagreement asks before anything turns green
   6  JeV — Judge, Extract, Verify — on the phone
        optional, online, with consent: Gemini reads the handwriting
   7  one card per medicine, 🟢🟡🔴, every source quoted
   8  where each fits beside what you already take  →  APPROVE
      │
      ▼
 EVERY DAY
   reminder at the time, a nudge 30 min later, then silence
   tick each medicine  →  "सब ले ली"  →  the family is told on WhatsApp
   missed? the caregiver hears about it
```

## Screens

| Onboarding | Patient | Taking a dose | Caregiver |
|---|---|---|---|
| <img src="test/goldens/onboarding_10_role_en.png" width="190"> | <img src="test/goldens/patient_1_menu_hi.png" width="190"> | <img src="test/goldens/dose_1_take_hi.png" width="190"> | <img src="test/goldens/caregiver_home_full_en.png" width="190"> |

| Photos, labelled | JeV, on the phone | Where they fit | Schedule + month |
|---|---|---|---|
| <img src="test/goldens/wizard_8_photos_en.png" width="190"> | <img src="test/goldens/wizard_11_processing_en.png" width="190"> | <img src="test/goldens/wizard_6_placement_en.png" width="190"> | <img src="test/goldens/dose_2_schedule_en.png" width="190"> |

Every image is a **golden test**: the real app rendered at phone size with the real fonts, driven by the real controller. If the parser or the merge engine changes what a row says, these pictures change with it.

## Guardrails

- **Consent is a gate.** Nothing is captured before a plain-words yes.
- **A content gate on every input** turns away a holiday photo or a café receipt, with the reason shown, and always a "use it anyway".
- **The one cloud call** is the handwriting read. It happens only after a person presses Read.
- **A red card cannot be confirmed** until a person picks which source is right.
- **Nothing claims more than it did.**

## Run it

Requires Flutter 3.47 (Dart 3.13).

```bash
flutter pub get
flutter test
```

```powershell
.\tools\run.ps1 -Device windows     # the phone layout, on a laptop
.\tools\web.ps1                     # release web build on localhost:8080
.\tools\run.ps1 -Build apk          # the Android APK
```

Keys are optional and never committed — see [`docs/RUNBOOK.md`](docs/RUNBOOK.md).

## Project layout

```
lib/
  domain/     the deterministic core — pure Dart, no Flutter
              sig_parser · mention_extractor · name_matcher · merge_engine
              content_gate · schedule_engine · placement_advisor · reminder_planner
  features/   onboarding · wizard (JeV) · doses · caregiver · visit · patient · medicines
              records (the encrypted vault)
  platform/   native capabilities, each split so the stub says why it cannot, never fakes it
              text_recogniser · gallery_scanner · dictation · dose_reminders
  ai/         the Gemini client — the only cloud call
  core/       theme · strings (en + hi) · voice (Kokoro) · shared widgets
test/         271 tests, including golden screenshots of every screen in both languages
docs/         decisions · gotchas · runbook · voice-agent design · HANDOFF (done vs left)
```

## Honest about what it is

This is a hackathon build.

- The OTP is a demo code, and the screen says so.
- The Ayushman lookup is a labeled mock. Nothing is saved until the patient says "Yes, this is me".
- Pairing has no server. Two phones agree through the QR and a short code.
- The caretaker website shows a labeled demo fixture. It is not a live copy of the vault.
- The missed-dose phone call is written and not deployed. There is no live call.
- A restore after uninstall has not been watched on a handset yet. The vault and the mirror are built; that last check is still open.

**What is built vs still open** is in [`docs/HANDOFF.md`](docs/HANDOFF.md). The runbook lists [gaps to say out loud](docs/RUNBOOK.md#known-gaps--say-them-before-anyone-finds-them), and why each choice was made is in [`docs/DECISIONS.md`](docs/DECISIONS.md).

**RapidRX is not medical advice.** Every row that reaches a schedule was checked by a person.

---

<div align="center">
<sub>Built by Team AfterBurners for Hack-e-Awadh 2026 · Fonts: Noto Sans (SIL Open Font License)</sub>
</div>
