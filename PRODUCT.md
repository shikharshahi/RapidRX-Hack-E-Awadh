# Product

<!-- impeccable:product-schema 1 -->

## Platform

web

## Stack

Static HTML, CSS, and one script in `portal/`. Hosted as Firebase Hosting site `rapidrx-portal`. The Android app is Flutter and is not this surface.

## Users

A family member, or a paid caretaker, checking whether doses were taken. The patient uses the phone app. The portal is the caretaker's copy, not a second medical record.

## Product Purpose

Show dose status, medicine name, time, caretaker notes, and alert events for a linked patient, and offer the Android APK. Success is a caretaker who can see today's doses without the phone's records leaving the device.

## Positioning

The phone stays the record. This site holds a caretaker copy only: dose status, medicine name, time, and alert events. It does not hold transcripts, photos, the health profile, or Ayushman data. Family can read the copy. A commercial caretaker reads it only after the patient's PIN.

## Operating Context

Four pages: family overview, alerts, APK install, and a demo load. Until a live cloud copy exists, the overview reads a labeled fixture in `portal/demo-family.json` after the visitor loads it. Calls and dose confirmation happen on the phone, not here.

## Capabilities and Constraints

- Demo PIN is the four digits compared in `portal/app.js`. A real build checks the SHA-256 on the server. The hash hint lives in the fixture; the digits do not.
- Notification permission is requested only from the Turn on alerts control.
- The APK download link is `rapidrx.apk`. Version on the page is 1.0.0 (build 1). The file is not in this folder.
- Do not invent customers, clinical claims, or live patient data.

## Brand Commitments

Name: RapidRX. Team AfterBurners. Hack-e-Awadh, Lucknow. Track: HealthTech, PS-01 Prescription Understanding Agent. Mark: `portal/logo_mark.png`.

The user pinned https://getrapidrx.web.app as the visual reference for this portal: warm paper, ink, amber, the same mark, and that site's craft. Inferred from the repository plus that request; not a second interview.

## Evidence on Hand

`portal/demo-family.json` is a labeled demo, dated as of 2026-09-26: Metformin and Amlodipine, taken / missed / upcoming doses, two notes, three alert kinds. No testimonials, no clinical results.

## Product Principles

- The phone keeps the records.
- Family and commercial views are different gates, not different products.
- Say what the page does. Do not mark a dose or place a call from the site.
- Demo data stays labeled as demo data.
