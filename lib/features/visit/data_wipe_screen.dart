import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/feedback/haptics.dart';
import '../../core/l10n/l10n.dart';
import '../../core/l10n/strings_wipe.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';

/// A short full-screen pause after the verified prescription is saved.
///
/// The transcript fades out. [duration] and [skipAfter] are injected: a real
/// timer under fake test time never fires (see GOTCHAS).
class DataWipeScreen extends StatefulWidget {
  const DataWipeScreen({
    super.key,
    required this.onDone,
    this.transcript = '',
    this.duration = const Duration(milliseconds: 2500),
    this.skipAfter = const Duration(seconds: 1),
  });

  final VoidCallback onDone;
  final String transcript;
  final Duration duration;
  final Duration skipAfter;

  @override
  State<DataWipeScreen> createState() => _DataWipeScreenState();
}

class _DataWipeScreenState extends State<DataWipeScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _fade;
  Timer? _done;
  Timer? _skipTimer;
  bool _canSkip = false;
  bool _finished = false;

  @override
  void initState() {
    super.initState();
    Haptics.tap();
    _fade = AnimationController(vsync: this, duration: widget.duration);
    _fade.forward();
    _done = Timer(widget.duration, _finish);
    if (widget.skipAfter <= Duration.zero) {
      _canSkip = true;
    } else {
      _skipTimer = Timer(widget.skipAfter, () {
        if (mounted) setState(() => _canSkip = true);
      });
    }
  }

  void _finish() {
    if (_finished) return;
    _finished = true;
    _done?.cancel();
    widget.onDone();
  }

  @override
  void dispose() {
    _done?.cancel();
    _skipTimer?.cancel();
    _fade.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = L10n.of(context);
    final text = Theme.of(context).textTheme;
    final fading = widget.transcript.trim();
    return Scaffold(
      backgroundColor: AppColors.paper,
      body: SafeArea(
        child: Padding(
          padding: AppTheme.pagePadding,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(),
              if (fading.isNotEmpty)
                FadeTransition(
                  opacity: ReverseAnimation(_fade),
                  child: Text(
                    fading,
                    maxLines: 6,
                    overflow: TextOverflow.fade,
                    style: text.titleMedium?.copyWith(color: AppColors.muted),
                  ),
                ),
              const SizedBox(height: 28),
              FadeTransition(
                opacity: _fade,
                child: Text(s.wipeLine, style: text.titleLarge),
              ),
              const Spacer(),
              if (_canSkip)
                Align(
                  alignment: Alignment.center,
                  child: TextButton(
                    onPressed: Haptics.on(_finish),
                    child: Text(s.skip),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
