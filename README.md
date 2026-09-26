<div align="center">

<img src="assets/images/logo_mark.png" width="112" alt="RapidRX">

# RapidRX

**Every dose, on time · हर दवाई, सही समय**

*A prescription understanding agent that never guesses a dose.*

Hack-e-Awadh · UP AI Labs, Lucknow · HealthTech · **PS-01 Prescription Understanding Agent**
<br>Team **AfterBurners**

</div>

---

## The problem

Even the best models read Indian handwritten prescriptions correctly only about half the time.
A system that bets everything on reading handwriting is right half the time about something that
goes into a person's body.

## The idea

RapidRX does not bet on handwriting. It collects **four sources that cross-question each other**:

| Source | What it is good at |
|---|---|
| 🗣️ **The doctor's own words** | *When* to take it — the doctor is the authority on timing |
| 📄 **The prescription photo** | Everything, if it can be read |
| 🧾 **The printed pharmacy bill** | *What* the medicine is — printed text reads at over 99% on-device |
| 💊 **The chemist's note** | Catches a substitution at the counter |

A deterministic merge engine lines them up and marks every medicine 🟢 agreed, 🟡 needs a look, or
🔴 the sources disagree. **Where they disagree, both readings are shown and a person decides.**
Once approved, the plan becomes a daily schedule that reminds the patient, logs what was taken,
and tells the family on WhatsApp what was missed.

> **The rule behind every decision:** the app never silently picks between conflicting sources,
> and never invents a dose.

## Built for the person who actually takes the tablets

- **Hindi and English**, chosen once, everywhere — medicine names stay in English letters, because
  the patient has to match them against the strip in their hand
- **Body text never below 20pt, tap targets never below 64px**, one decision per screen
- **Voice help** reads every screen aloud, in the chosen language
- **Offline-first** — reading, parsing, merging, scheduling and reminders all run on the phone

## Status

🚧 Being built during the hackathon — this README grows as each part lands.

## Run it

Requires Flutter 3.47 (Dart 3.13).

```bash
flutter pub get
flutter test
flutter run
```

The Windows and web builds render the same portrait phone layout as Android, so a laptop demo
shows exactly what the phone shows.

---

<div align="center">
<sub>Built by Team AfterBurners for Hack-e-Awadh 2026</sub>
</div>
