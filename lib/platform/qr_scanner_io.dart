import 'dart:io';

import 'qr_scanner.dart';
import 'qr_scanner_stub.dart';

QrScanner createQrScanner() => Platform.isAndroid || Platform.isIOS
    ? CameraQrScanner()
    // Windows and the test runner: mobile_scanner has no scanner there.
    : UnsupportedQrScanner();
