# Firestore rules cases

`firestore.rules` is the enforcement. These cases were not executed: firebase-tools is not installed here, and it was not installed for this change. Deploy was not run.

Tokens are custom claims. The static page does not set them. A commercial `pinOk: true` claim is issued by a server after a PIN-hash check, not by this site.

Paths under test: `/patients/{patientId}/doses/{id}` and `/patients/{patientId}/alerts/{id}`. Every other path is denied.

## Stranger denied

No auth, or auth whose `patientId` does not match, or `role` is not `caretaker` with `linked == true`. Read and write are denied on both paths.

## Family read ok

`role == caretaker`, `linked == true`, `caretakerType == family`, `patientId` matches. Read is allowed on doses and alerts. Write is denied.

## Commercial without PIN denied

Same linked caretaker token, but `caretakerType == commercial` and `pinOk` is missing or not `true`. Read is denied. Read is allowed only when `pinOk == true`.

## Medical-content field write denied

A patient device (`device == patient`, matching `patientId`) may create or update a dose with only `status`, `medicine`, and `time` (`status` is `taken`, `missed`, or `upcoming`). It may create an alert with `kind` (`missed_dose`, `unanswered_call`, or `new_prescription`), optional `medicine`, and `time`.

A write that includes `transcript`, `photo`, `photos`, `healthProfile`, `health_profile`, `ayushman`, `ayushmanId`, or `prescriptionPhoto` is denied. Any field outside the allowlist, including note text, is denied. A caretaker cannot write. Delete is denied.

Caretaker notes in `portal/demo-family.json` are for the static demo page. They are not an allowed Firestore field.
