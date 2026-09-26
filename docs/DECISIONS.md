# Decisions

Why RapidRX is the way it is. Read the relevant entry before changing any of these —
each one is here because the obvious alternative was tried, or thought through, and lost.

---

## The product

### ADR-1 · One Flutter codebase — Android is the product
Flutter 3.47 / Dart 3.13, targeting Android, Windows and web. The APK is what a patient uses;
the Windows and web builds exist so a laptop demo shows exactly what the phone shows.

### ADR-3 · Portrait everywhere
`PhoneShell` frames the app as a 412 × 892 phone on anything wider. A second, wide layout would
be designed once and never used.

### ADR-19 · The patient lands on a menu, not on today's doses
The first thing a new user needs is to add a prescription; what a returning user needs depends on
the time of day. So the app asks. All three tiles fit without scrolling.

### ADR-23 · The merge engine is plain Dart, and never picks a side
This is the step that decides what reaches a patient's schedule. It is deterministic, inspectable
and identical every run, so no model sits between the evidence and the plan. Where sources
disagree, both are kept and a person decides.

### ADR-29 · Four inputs that cross-question each other
Doctor's words, the prescription photo, the printed bill, the chemist. **Identity** is decided
bill > strip > doctor > prescription, because printed text reads at over 99% on the device and
handwriting at about half. **Timing** is decided doctor > prescription > chemist, because the
bill carries none.

### ADR-31 · The medicine card shows the evidence, not a claim
Every source that mentioned a medicine is quoted in its own words. A red card shows each
conflicting reading side by side and cannot be confirmed until a person picks one.

### ADR-36 · The caregiver gets plain text on WhatsApp, not an app to install
Text arrives on any phone, forwards to a doctor, and pastes into SMS for someone with no
smartphone. Medicine names stay in English letters in the Hindi message: the reader may be
holding the strip.

---

## Accessibility

### ADR-2 · Fonts are bundled, never downloaded
Noto Sans and Noto Sans Devanagari ship in `assets/fonts/`. Runtime Google Fonts would render the
Hindi UI as tofu boxes in a hall with no Wi-Fi.

### ADR-4 · The elderly-first scale lives in `ThemeData`
Body text never below 20pt on a patient screen; every tap target at least 64px. In the theme, so
no screen can quietly break it.

### ADR-12 · Localisation is a typed Dart table
`AppStrings` has a getter per string with English and Hindi side by side. A missing translation
is a compile error, not a blank label on a demo phone.

### ADR-15 · The newest screen owns the voice
`VoiceGuide` holds an owner token. A screen stops the voice on its way out only if it still owns
it; a sentence that finishes loading after its screen has gone is dropped. Without this, a user
who moves quickly hears the previous screen talking over the new one.

### ADR-32 · Kokoro TTS, cached per sentence
Device TTS was robotic and often had no Hindi voice. Kokoro (a public Hugging Face Space) sounds
like a person in both languages. Every sentence is cached on the device, so after one warm
walkthrough the voice works offline. Kokoro → device → silence: silence beats a wrong accent
reading the wrong screen. One failure marks the Space unreachable for the session.

---

## Data and privacy

### ADR-6 · `shared_preferences` now, Firestore for medical data later
This build keeps everything on the phone as JSON. The shapes in `MedicineStore`, `DoseLogStore`
and `VisitRepository` are the documents a Firestore migration would write.

### ADR-14 · Phone, OTP, PIN — all local in this build
The OTP is `1234`, and the screen says so: phone auth needs Firebase's paid plan. The PIN is
stored as a SHA-256 hash, never as itself.

### ADR-20 · A visit is saved after every capture
Not at the end. A phone call or a flat battery mid-visit loses nothing.

### ADR-21 · Consent is a gate, not a checkbox
It is asked before the first capture, in plain words, and nothing is captured on a no.

### ADR-35 · Gemini reads handwriting, and nothing else
The only thing that ever leaves the phone, only after a person presses Read on a card that says
exactly what goes where, and only when online with a key. `gemini-3.8-flash`, temperature 0,
JSON out, four calls per visit, 45 s timeout. Its rows are re-parsed by the same `SigParser` and
land in the same merge: a better reader, not a higher authority.

---

## Extraction

### ADR-25 · The "understanding" step is rules, and says so
Takeaways are produced by `MentionExtractor` + `SigParser`: auditable, instant, no quota, and
nothing invented. The screen says it was read on the phone.

### ADR-27 · Speaking must produce text
Dictation goes through `speech_to_text`. A recording nobody can read cross-checks against
nothing; saving the audio is a separate, optional choice for the family.

### ADR-28 · Photos are read on the device, or the screen says why not
ML Kit on the phone. Everywhere else, `TextRecogniser` returns `unsupported` — never an empty
string, which would be indistinguishable from "your bill was blank".

### ADR-30 · Parser fixes that cross-checking forced out
1. `TELMA 40 TAB` is a strength, not forty tablets: only a single digit or a half can be a count.
2. Bill quantities (`30 NOS`, `1x15`) and prices never land in a name.
3. Double-space columns are cut.
4. `aur` and number words no longer flag clean rows.
5. On a **printed** line, a single digit before `TAB` is a strength (`AMLONG 5 TAB`). Read as a
   count, the line had no strength and no form, and the medicine was dropped from the bill.
6. A sentence that opens with advice ("come back after ten days") is a note, and never attaches
   a duration to the medicine above it.

### ADR-33 · A content gate on every input — that can always be overruled
Strong signals (dosage forms, shorthand, strengths) carry a verdict; weak ones (a word and a
number, a store header) only support one. The words behind a verdict are shown, and every
rejection offers "use it anyway". The bar for speech is lower than for photos.

### ADR-34 · One photo step that reads and labels
Prescription, bill and strips together: find recent, camera, or gallery. Only ticked photos
enter the visit, and only when the step is left. OCR runs once; the text is reused.

---

## Doses and reminders

### ADR-26 · Two notifications on approval
"Prescription saved" and "Schedule updated" are two different facts.

### ADR-37 · Two reminders per dose, then silence
At the time, and thirty minutes later. By +60 the slot is missed and the **caregiver** is told:
escalation moves to a different person rather than getting louder. Ids come from the slot, so a
re-sync replaces instead of duplicating; every sync is a full replace; confirming a dose cancels
its slot at once. Never for SOS, a finished course, a stopped medicine, or a slot taken.

### Missed is derived, never written
Nothing runs at 09:01 to record a miss. Status is computed day to day whenever it is asked for.

---

## The voice agent

### ADR-38 · A keypad, not a conversation — and the last rung, not the first
Designed in [`VOICE_AGENT.md`](VOICE_AGENT.md), not built. A misheard "nahi" logged as *taken*
is the worst failure this product could produce; a keypress cannot be misheard.
