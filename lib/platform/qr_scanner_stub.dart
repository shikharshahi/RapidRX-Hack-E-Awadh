import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import 'qr_scanner.dart';

/// Web has a camera. Windows and the test runner do not: [qr_scanner_io]
/// returns [UnsupportedQrScanner] there.
QrScanner createQrScanner() => CameraQrScanner();

/// Nothing to scan with. The screen offers the typed code.
class UnsupportedQrScanner implements QrScanner {
  final _torch = ValueNotifier(false);

  @override
  bool get supported => false;

  @override
  Widget view({
    required ValueChanged<String> onCode,
    required Widget Function(ScanProblem) problem,
  }) => problem(ScanProblem.unsupported);

  @override
  ValueListenable<bool> get torchOn => _torch;

  @override
  Future<void> toggleTorch() async {}

  @override
  Future<void> retry() async {}

  @override
  Future<void> dispose() async => _torch.dispose();
}

/// The phone and the browser. The controller lives with the camera widget,
/// so leaving the scan step and coming back starts a fresh session.
class CameraQrScanner implements QrScanner {
  final _torch = ValueNotifier(false);
  _CameraScanState? _state;

  @override
  bool get supported => true;

  @override
  Widget view({
    required ValueChanged<String> onCode,
    required Widget Function(ScanProblem) problem,
  }) => _CameraScan(
    onCode: onCode,
    problem: problem,
    torch: _torch,
    bind: (state) => _state = state,
    unbind: (state) {
      if (identical(_state, state)) _state = null;
    },
  );

  @override
  ValueListenable<bool> get torchOn => _torch;

  @override
  Future<void> toggleTorch() => _state?.toggleTorch() ?? Future.value();

  @override
  Future<void> retry() => _state?.retry() ?? Future.value();

  @override
  Future<void> dispose() async {
    _state = null;
    _torch.dispose();
  }
}

class _CameraScan extends StatefulWidget {
  const _CameraScan({
    required this.onCode,
    required this.problem,
    required this.torch,
    required this.bind,
    required this.unbind,
  });

  final ValueChanged<String> onCode;
  final Widget Function(ScanProblem) problem;
  final ValueNotifier<bool> torch;
  final ValueChanged<_CameraScanState> bind;
  final ValueChanged<_CameraScanState> unbind;

  @override
  State<_CameraScan> createState() => _CameraScanState();
}

class _CameraScanState extends State<_CameraScan> with WidgetsBindingObserver {
  // Close-range: the code is on another phone's screen, a few inches away.
  final _controller = MobileScannerController(
    formats: const [BarcodeFormat.qrCode],
    detectionSpeed: DetectionSpeed.noDuplicates,
    autoZoom: true,
  );

  @override
  void initState() {
    super.initState();
    widget.bind(this);
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didUpdateWidget(_CameraScan old) {
    super.didUpdateWidget(old);
    widget.bind(this);
  }

  /// A permission dialog and a browser prompt both pause the app. The
  /// scanner widget does not resume a controller it does not own, so the
  /// camera stayed off after the person allowed it.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!mounted) return;
    switch (state) {
      case AppLifecycleState.resumed:
        unawaited(_start());
      case AppLifecycleState.inactive:
      case AppLifecycleState.hidden:
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
        unawaited(_controller.stop());
    }
  }

  Future<void> _start() async {
    try {
      await _controller.start();
    } catch (_) {
      // Already starting, or the error builder is showing why.
    }
  }

  Future<void> toggleTorch() async {
    try {
      await _controller.toggleTorch();
      widget.torch.value = _controller.value.torchState == TorchState.on;
    } catch (_) {
      widget.torch.value = false;
    }
  }

  Future<void> retry() async {
    try {
      await _controller.stop();
    } catch (_) {}
    await _start();
  }

  @override
  void dispose() {
    widget.unbind(this);
    WidgetsBinding.instance.removeObserver(this);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MobileScanner(
      controller: _controller,
      // This state restarts the camera. The widget would not, because the
      // controller is owned here.
      useAppLifecycleState: false,
      onDetect: (capture) {
        for (final b in capture.barcodes) {
          final raw = b.rawValue;
          if (raw != null && raw.isNotEmpty) {
            widget.onCode(raw);
            return;
          }
        }
      },
      errorBuilder: (context, error) =>
          widget.problem(switch (error.errorCode) {
            MobileScannerErrorCode.permissionDenied =>
              ScanProblem.permissionDenied,
            MobileScannerErrorCode.unsupported => ScanProblem.unsupported,
            _ => ScanProblem.failed,
          }),
    );
  }
}
