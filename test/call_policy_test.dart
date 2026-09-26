import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:rapidrx/core/l10n/app_language.dart';
import 'package:rapidrx/core/l10n/app_strings.dart';
import 'package:rapidrx/domain/scheduled_medicine.dart';
import 'package:rapidrx/domain/sig.dart';
import 'package:rapidrx/features/calls/call_gateway.dart';
import 'package:rapidrx/features/calls/call_policy.dart';
import 'package:rapidrx/features/calls/dose_twiml.dart';
import 'package:rapidrx/features/calls/missed_dose_calls.dart';
import 'package:rapidrx/features/caregiver/caregiver_notifier.dart';
import 'package:rapidrx/features/caregiver/whatsapp_alerts.dart';
import 'package:rapidrx/features/doses/dose_log_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

const en = AppStrings(AppLanguage.en);
const slot = DoseSlot.morning;
final day = DateTime(2026, 9, 26);
final missed = DateTime(2026, 9, 26, 9);

final telma = ScheduledMedicine(
  id: 'telma-40',
  name: 'TELMA 40',
  sig: const Sig(slots: [slot], food: FoodTiming.after),
  startDate: day,
  purpose: 'BP',
);

class _FakeGateway implements CallGateway {
  final requests = <CallRequest>[];

  @override
  bool get configured => true;

  int get posts => requests.length;

  @override
  Future<CallRequestResult> requestCall(CallRequest request) async {
    requests.add(request);
    return const CallRequestResult.accepted();
  }
}

class _Harness {
  _Harness({
    required this.gateway,
    required this.ledger,
    required this.logs,
    required this.caller,
    required this.sent,
    required this.alerts,
  });

  final _FakeGateway gateway;
  final CallLedger ledger;
  final DoseLogStore logs;
  final MissedDoseCaller caller;
  final List<http.Request> sent;
  final CaregiverNotifier alerts;

  Future<void> check(DateTime now) => caller.check(
    medicines: [telma],
    logs: logs,
    now: now,
    phone: '9876543210',
    language: AppLanguage.en,
  );
}

Future<_Harness> _harness() async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final sent = <http.Request>[];
  final alerts = CaregiverNotifier(
    alerts: WhatsAppAlerts(
      accountSid: 'AC123',
      authToken: 'tok',
      fromNumber: '+14155238886',
      client: MockClient((req) async {
        sent.add(req);
        return http.Response('{}', 201);
      }),
    ),
    prefs: prefs,
    patientName: 'Ramesh',
    caregiverPhone: '9812345678',
    strings: en,
  );
  final gateway = _FakeGateway();
  final ledger = CallLedger(prefs);
  return _Harness(
    gateway: gateway,
    ledger: ledger,
    logs: DoseLogStore(prefs),
    sent: sent,
    alerts: alerts,
    caller: MissedDoseCaller(
      gateway: gateway,
      ledger: ledger,
      alerts: alerts,
      patientName: 'Ramesh',
      strings: en,
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('first miss schedules one call', () async {
    final h = await _harness();
    await h.check(DateTime(2026, 9, 26, 8, 40));
    expect(h.gateway.posts, 0, reason: 'still inside the missed window');
    await h.check(missed);
    expect(h.gateway.posts, 1);
    expect(h.gateway.requests.single.medicineNames, ['TELMA 40']);
    expect(h.gateway.requests.single.to, '+919876543210');
    expect(h.ledger.read(day, slot).firstAt, missed);
    expect(h.sent, isEmpty);
  });

  test('no answer schedules exactly one retry at +60 min', () async {
    final h = await _harness();
    await h.check(missed);
    await h.check(missed.add(const Duration(minutes: 59)));
    expect(h.gateway.posts, 1);
    final due = missed.add(const Duration(minutes: 60));
    await h.check(due);
    expect(h.gateway.posts, 2);
    expect(h.ledger.read(day, slot).retryAt, due);
    await h.check(due);
    expect(h.gateway.posts, 2, reason: 'the retry is not a third call');
    expect(h.sent, isEmpty);
  });

  test('second miss alerts caretaker and does not call a third time', () async {
    final h = await _harness();
    await h.check(missed);
    await h.check(missed.add(const Duration(minutes: 60)));
    await h.check(missed.add(const Duration(minutes: 61)));
    expect(h.gateway.posts, 2);
    expect(h.sent, hasLength(1));
    expect(
      h.sent.single.bodyFields['Body'],
      'Ramesh: nobody answered the call about the Morning medicines.',
    );
    await h.check(missed.add(const Duration(hours: 3)));
    expect(h.gateway.posts, 2);
    expect(h.sent, hasLength(1));
  });

  test(
    'digit 1 writes taken; digit 2 does not; unknown digit does not',
    () async {
      Future<DoseLogStore> fresh() async {
        SharedPreferences.setMockInitialValues({});
        return DoseLogStore(await SharedPreferences.getInstance());
      }

      final taken = await fresh();
      await applyCallDigit(
        digit: '1',
        logs: taken,
        date: day,
        slot: slot,
        medicineIds: const ['telma-40'],
        at: missed,
      );
      expect(taken.logFor(day, slot)?.taken, ['telma-40']);

      final later = await fresh();
      await applyCallDigit(
        digit: '2',
        logs: later,
        date: day,
        slot: slot,
        medicineIds: const ['telma-40'],
        at: missed,
      );
      await applyCallDigit(
        digit: '5',
        logs: later,
        date: day,
        slot: slot,
        medicineIds: const ['telma-40'],
        at: missed,
      );
      await applyCallDigit(
        digit: null,
        logs: later,
        date: day,
        slot: slot,
        medicineIds: const ['telma-40'],
        at: missed,
      );
      expect(later.logFor(day, slot), isNull);

      final h = await _harness();
      await applyReportedDigit(
        digit: '9',
        logs: h.logs,
        alerts: h.alerts,
        patientName: 'Ramesh',
        strings: en,
        date: day,
        slot: slot,
        medicineIds: const ['telma-40'],
        at: missed,
      );
      expect(h.logs.logFor(day, slot), isNull);
      expect(h.sent, hasLength(1));
      expect(
        h.sent.single.bodyFields['Body'],
        contains('asked us to tell you'),
      );
    },
  );

  test('dedupe: same slot does not double-call', () async {
    expect(
      callDedupeKey(DateTime(2026, 9, 26, 9), slot),
      callDedupeKey(DateTime(2026, 9, 26, 22), slot),
    );
    expect(callDedupeKey(day, slot), isNot(callDedupeKey(day, DoseSlot.night)));
    final h = await _harness();
    await h.check(missed);
    await h.check(missed);
    expect(h.gateway.posts, 1);
  });

  test(
    'gateway with empty URL does not throw and does not claim success',
    () async {
      var called = false;
      final gateway = HttpCallGateway(
        url: '',
        secret: '',
        client: MockClient((_) async {
          called = true;
          throw StateError('must not post');
        }),
      );
      final result = await gateway.requestCall(
        CallRequest(
          to: '+919876543210',
          language: AppLanguage.en,
          medicineNames: const ['TELMA 40'],
          slot: slot,
          day: day,
        ),
      );
      expect(called, isFalse);
      expect(gateway.configured, isFalse);
      expect(result.claimsSuccess, isFalse);
      expect(result.status, CallRequestStatus.notConfigured);
    },
  );

  test('TwiML says the medicine name and gathers 1, 2, 9', () {
    final xml = buildDoseTwiml(
      language: AppLanguage.hi,
      medicineNames: const ['TELMA 40', 'A<B&C'],
      gatherUrl: 'https://example.test/gather',
    );
    expect(xml, contains('language="hi-IN"'));
    expect(xml, contains('TELMA 40'));
    expect(xml, contains('A&lt;B&amp;C'));
    expect(xml, contains('<Gather numDigits="1"'));
    expect(xml, contains('1 दबाइए'));
    expect(xml, contains('9।'));
    expect(xml, isNot(contains('BP')));
    expect(xml, isNot(contains('<B')));
    expect(
      buildDoseTwiml(
        language: AppLanguage.en,
        medicineNames: const ['TELMA 40'],
        gatherUrl: '/gather',
      ),
      contains('language="en-IN"'),
    );
  });

  test('a taken slot is not called', () {
    final decision = CallPolicy.onUnanswered(
      record: SlotCallRecord.empty,
      now: missed,
      taken: true,
    );
    expect(decision.placeCall, isFalse);
    expect(decision.alertCaretaker, isFalse);
  });
}
