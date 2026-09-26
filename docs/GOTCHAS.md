# Gotchas

Every trap already hit, with the fix. When something looks impossible, look here first.

## Build and tooling

| Symptom | Cause | Fix |
|---|---|---|
| No APK builds at all; `kernel_snapshot` fails | `record ^5.x` resolves a `record_linux` that does not implement the newer platform interface. The web/desktop loop never runs that step, so you find out late | `record: ^6.1.1`. Build an APK early, before anything depends on it |
| `requires core library desugaring` | `flutter_local_notifications` uses `java.time` | `isCoreLibraryDesugaringEnabled = true` + `desugar_jdk_libs` in `android/app/build.gradle.kts` |
| Release build fails in R8: `Missing class …DevanagariTextRecognizerOptions` | The ML Kit plugin only *compiles* against non-Latin scripts. Without the artifact, reading Hindi crashes on the phone — and a debug build never tells you | `implementation("com.google.mlkit:text-recognition-devanagari:16.0.1")` in `android/app/build.gradle.kts`. Build a **release** APK early |
| Release build fails in R8: missing Chinese/Japanese/Korean classes | The ML Kit plugin references all five scripts; the app bundles two | `-dontwarn` lines in `android/app/proguard-rules.pro` |
| A key passed with `--dart-define=KEY=VALUE` from PowerShell arrives broken, or flutter says `Target file "-" not found` | `cmd` splits `flutter.bat` arguments on `=` | `tools/common.ps1` writes `build/dart_defines.json` and passes `--dart-define-from-file` |
| `tools/run.ps1` stops on `WARNING: Your app uses … Kotlin Gradle Plugin` | In Windows PowerShell 5.1, with `$ErrorActionPreference = 'Stop'`, any stderr line from a native tool is a terminating error | The scripts use `Continue` and judge native commands by `$LASTEXITCODE` |
| A web fix "did nothing" | A release web build installs a service worker that serves the stale app | Always `--pwa-strategy=none` (in `tools/web.ps1`). Suspect this first |
| `flutter run -d web-server` shows a blank page | A DWDS websocket problem | Build a release and serve it statically: `tools/web.ps1` |
| `flutter format` not found | Removed from the Flutter CLI | `dart format lib test` |

## Tests

| Symptom | Cause | Fix |
|---|---|---|
| Every golden shows boxes instead of letters and icons | The test runner has no fonts, and icons ship with the SDK, not the app | `test/flutter_test_config.dart` loads the Noto faces and `materialicons-regular.otf` from the SDK cache |
| The logo is a blank square in a golden | Asset images decode on a real thread | `precacheImage` inside `tester.runAsync` (`precacheLogo`) |
| A test hangs forever | A real `Future.delayed` under fake time | Injectable delays (`stageDelay`) |
| A golden hangs for ten minutes, even with a zero delay | `Future.delayed(Duration.zero)` is still a timer, and fake time never fires it | Run the call inside `tester.runAsync` |
| `find.text('Set a 4-digit PIN')` finds two widgets | The onboarding title and the field hint say the same thing | Find by the "why" line, or `findsWidgets` |
| `There is no current invoker` at load | An external resource (`AudioPlayer`, `http.Client`, an ML Kit recogniser) built in a constructor | Build lazily: `_injected ?? (_lazy ??= Thing())` |
| `Looking up a deactivated widget's ancestor is unsafe` | `dispose()` reading an inherited widget | Cache it in `didChangeDependencies` (`VoicePrompt`) |
| A pushed route cannot find `L10n` or the voice | Scopes placed around `home` | Put them in `MaterialApp.builder` — and mirror that in the harness |
| `pumpAndSettle` never settles on a screen with a loading bar | The bar animates forever | `pump()` with a duration instead |
| A string getter in a `strings_<feature>.dart` extension shows the wrong text, with no error | A member of `AppStrings` with the same name wins over the extension, silently | Grep `app_strings.dart` for each new getter name before adding it |
| An arrow (`→`) in on-screen text is a box in the golden, in English and Hindi | The bundled Noto faces have no arrow glyph | Say it in words ("open RapidRX and tap …"); arrows are fine in test names |

## Layout

| Symptom | Cause | Fix |
|---|---|---|
| The wizard's bottom bar fills the whole screen | A `Scaffold` gives `bottomNavigationBar` the full height as a loose limit, and a plain `Align` takes all of it | `Align(heightFactor: 1)` |
| `RenderFlex overflowed by 72 pixels` on a short phone | `Expanded` tiles with a minimum content height | The menu measures itself and falls back to a scrolling list |

## Product logic

| Symptom | Cause | Fix |
|---|---|---|
| Missed doses never appear on the schedule | `statusOf` compared a timestamped date against midnight, so a same-day slot was always pending | Compare day to day, always through `dayOf()` |
| A café receipt, a cricket chat and "beach 2024" pass the content gate | `TOTAL` and `night` counted as medical, and word-plus-number matched on its own | The strong/weak split; English times of day are weak in speech |
| A strip is labelled as a bill | "batch", "exp" and "store" are on both | Bill words are only the ones a bill alone has |
| A counter substitution (TELMA → TELMISARTAN) folds into one quiet row | Jaro-Winkler scores the pair at 0.89 | A length-ratio guard in `NameMatcher` |
| "…after food BP ke liye" loses "after food" | The purpose pattern captured two words before "ke liye" and deleted both | A purpose takes only its own words, never a timing word |
| "Come back after ten days" turns a medicine into a ten-day course | The advice line had no name, so its duration attached to the row above | Sentences that open with an advice word are notes |
| A medicine on the bill disappears | `AMLONG 5 TAB` read as five tablets, leaving no strength and no form | On printed lines, a single digit before `TAB` is a strength |
| Green is unreachable with the best evidence present | A rule demanding timing from two sources; a bill never has timing | Rule dropped; bill + one timed source can be green |
| An SOS medicine gets an alarm | `fillFrom` borrowed slots from a lower-priority source | An as-needed Sig never borrows slots |
| Kokoro says "no voice" on the web | `getLanguages()` is empty on the first call | Consult `getVoices` too, and try optimistically |
| The first voice line takes 30 seconds | The Hugging Face Space is asleep | Warm the cache early: walk the app once, online |
