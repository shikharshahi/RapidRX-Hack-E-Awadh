import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../core/l10n/app_language.dart';
import '../../domain/sig.dart';

/// What the phone asks the function to ring about. Medicine names only.
class CallRequest {
  const CallRequest({
    required this.to,
    required this.language,
    required this.medicineNames,
    required this.slot,
    required this.day,
  });

  final String to;
  final AppLanguage language;
  final List<String> medicineNames;
  final DoseSlot slot;
  final DateTime day;

  Map<String, Object?> toJson() => {
    'to': to,
    'language': language.code,
    'medicines': medicineNames,
    'slot': slot.name,
    'day':
        '${day.year.toString().padLeft(4, '0')}-'
        '${day.month.toString().padLeft(2, '0')}-'
        '${day.day.toString().padLeft(2, '0')}',
  };
}

enum CallRequestStatus { notConfigured, accepted, failed }

class CallRequestResult {
  const CallRequestResult(this.status);
  const CallRequestResult.notConfigured()
    : status = CallRequestStatus.notConfigured;
  const CallRequestResult.accepted() : status = CallRequestStatus.accepted;
  const CallRequestResult.failed() : status = CallRequestStatus.failed;

  final CallRequestStatus status;

  bool get accepted => status == CallRequestStatus.accepted;

  /// A result may say the function was reached. It must not say a call
  /// happened when the URL was empty.
  bool get claimsSuccess => accepted;
}

/// Asks a function to place the call. The phone never talks to Twilio.
abstract class CallGateway {
  /// False when no function URL was compiled in. The demo says so.
  bool get configured;

  Future<CallRequestResult> requestCall(CallRequest request);
}

/// Posts JSON to `CALL_FUNCTION_URL` with `X-RapidRX-Secret`.
///
/// Both come from `--dart-define` and default to empty. An empty URL does
/// not throw and does not claim the call went out. The Twilio token is not
/// a define here: it stays in Functions config.
class HttpCallGateway implements CallGateway {
  HttpCallGateway({String? url, String? secret, http.Client? client})
    : url = url ?? const String.fromEnvironment('CALL_FUNCTION_URL'),
      secret = secret ?? const String.fromEnvironment('CALL_FUNCTION_SECRET'),
      _injected = client;

  static const header = 'X-RapidRX-Secret';

  final String url;
  final String secret;
  final http.Client? _injected;

  @override
  bool get configured => url.trim().isNotEmpty;

  @override
  Future<CallRequestResult> requestCall(CallRequest request) async {
    if (!configured) return const CallRequestResult.notConfigured();
    final client = _injected ?? http.Client();
    try {
      final response = await client
          .post(
            Uri.parse(url),
            headers: {'Content-Type': 'application/json', header: secret},
            body: jsonEncode(request.toJson()),
          )
          .timeout(const Duration(seconds: 20));
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return const CallRequestResult.accepted();
      }
      return const CallRequestResult.failed();
    } catch (_) {
      return const CallRequestResult.failed();
    } finally {
      if (_injected == null) client.close();
    }
  }
}
