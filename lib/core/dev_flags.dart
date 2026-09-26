/// Two build-time switches, and nothing else.
///
/// They exist because the two things that are slowest to reach during
/// development are the far end of onboarding and a warm voice cache. Both are
/// flipped back before the demo — the checklist in `docs/REBUILD.md` says so.
abstract final class DevFlags {
  /// Show onboarding on every launch, instead of resuming where the user got to.
  ///
  /// Set to `false` for the demo, so a judge who reopens the app lands where
  /// they left off.
  static const bool alwaysShowOnboarding = true;

  /// Let the voice guide speak.
  ///
  /// Off by default during development: a screen that talks every ten seconds
  /// while you are reading a stack trace is its own kind of punishment.
  static const bool voiceEnabled = false;
}
