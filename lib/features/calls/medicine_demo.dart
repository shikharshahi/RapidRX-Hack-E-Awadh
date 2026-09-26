import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../../core/l10n/app_strings.dart';
import '../../core/l10n/l10n.dart';
import '../../core/l10n/strings_alarm.dart';
import '../../core/l10n/strings_calls.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/voice/voice_prompt.dart';
import '../../core/widgets/pictograms.dart';
import '../../domain/medicine_form.dart';
import '../../domain/scheduled_medicine.dart';
import '../../platform/photo_thumb.dart';

/// How many pill pictures to draw. One tablet draws one; two draws two.
/// Half a tablet still draws one.
///
/// ponytail: capped at 4. A sig that says 12 would fill the screen; raise
/// the cap if a real dose needs more pictures.
int visualPills(double units) {
  final n = units.round();
  if (n < 1) return 1;
  return n > 4 ? 4 : n;
}

/// One website notification, listing every medicine and its pill count.
Map<String, Object?> demoAlertBody({
  required String? to,
  required List<ScheduledMedicine> medicines,
}) => {
  'to': ?to,
  'medicines': [
    for (final m in medicines)
      {'name': m.name, 'pills': visualPills(m.sig.unitsPerDose)},
  ],
};

/// What the laptop bay said back. [whatsapp] is `sent`, `missing-from`,
/// `no-number`, `failed`, or `skipped`.
class DemoAlertResult {
  const DemoAlertResult({required this.bay, required this.whatsapp});

  final bool bay;
  final String whatsapp;
}

Future<DemoAlertResult> postDemoAlert({
  required String bayUrl,
  required Map<String, Object?> body,
  http.Client? client,
}) async {
  final url = bayUrl.trim();
  if (url.isEmpty) return const DemoAlertResult(bay: false, whatsapp: 'skipped');
  final httpClient = client ?? http.Client();
  try {
    final response = await httpClient
        .post(
          Uri.parse(url),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(body),
        )
        .timeout(const Duration(seconds: 20));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      return const DemoAlertResult(bay: false, whatsapp: 'failed');
    }
    final decoded = jsonDecode(response.body);
    if (decoded is! Map) {
      return const DemoAlertResult(bay: true, whatsapp: 'failed');
    }
    return DemoAlertResult(
      bay: decoded['bay'] == true,
      whatsapp: decoded['whatsapp'] is String
          ? decoded['whatsapp'] as String
          : 'failed',
    );
  } catch (_) {
    return const DemoAlertResult(bay: false, whatsapp: 'failed');
  } finally {
    if (client == null) httpClient.close();
  }
}

String spokenMedicineDemo(AppStrings s, List<ScheduledMedicine> medicines) => [
  s.callDemo,
  for (final m in medicines)
    '${m.name}, ${_pillWords(s, visualPills(m.sig.unitsPerDose))}.',
].join(' ');

String _pillWords(AppStrings s, int pills) =>
    pills == 1 ? s.alarmOneTablet : s.tablets(pills);

/// Big picture, readable name, and one pill picture per tablet.
class MedicineDemoPage extends StatefulWidget {
  const MedicineDemoPage({
    super.key,
    required this.medicines,
    required this.bayUrl,
    this.to,
    this.client,
  });

  final List<ScheduledMedicine> medicines;
  final String bayUrl;
  final String? to;
  final http.Client? client;

  @override
  State<MedicineDemoPage> createState() => _MedicineDemoPageState();
}

class _MedicineDemoPageState extends State<MedicineDemoPage> {
  String? _status;

  @override
  void initState() {
    super.initState();
    unawaited(_send());
  }

  Future<void> _send() async {
    final result = await postDemoAlert(
      bayUrl: widget.bayUrl,
      body: demoAlertBody(to: widget.to, medicines: widget.medicines),
      client: widget.client,
    );
    if (!mounted) return;
    final s = L10n.of(context);
    setState(() => _status = _statusLine(s, result, widget.to));
  }

  @override
  Widget build(BuildContext context) {
    final s = L10n.of(context);
    return VoicePrompt(
      text: spokenMedicineDemo(s, widget.medicines),
      child: Scaffold(
        backgroundColor: AppColors.paper,
        appBar: AppBar(title: Text(s.callDemo)),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          children: [
            for (final m in widget.medicines) ...[
              _MedicineCard(medicine: m, strings: s),
              const SizedBox(height: 16),
            ],
            if (_status != null)
              Text(
                _status!,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

String _statusLine(AppStrings s, DemoAlertResult result, String? to) {
  final bay = result.bay ? s.bayUpdated : s.bayMissed;
  final whatsApp = switch (result.whatsapp) {
    'sent' => s.whatsAppSent,
    'missing-from' => s.whatsAppNeedsSender,
    'no-number' || 'skipped' when to == null => s.callNoPhone,
    _ => s.whatsAppFailed,
  };
  return '$bay $whatsApp';
}

class _MedicineCard extends StatelessWidget {
  const _MedicineCard({required this.medicine, required this.strings});

  final ScheduledMedicine medicine;
  final AppStrings strings;

  @override
  Widget build(BuildContext context) {
    final pills = visualPills(medicine.sig.unitsPerDose);
    return Semantics(
      label: '${medicine.name}. ${_pillWords(strings, pills)}',
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppTheme.radius),
          border: Border.all(color: AppColors.hairline, width: 2),
        ),
        child: Column(
          children: [
            medicine.imagePath == null
                ? FormPictogram(
                    form: formOf(medicine.name),
                    strings: strings,
                    size: 200,
                  )
                : photoThumb(medicine.imagePath!, size: 200),
            const SizedBox(height: 12),
            Text(
              medicine.name,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 36,
                fontWeight: FontWeight.w800,
                height: 1.1,
              ),
            ),
            if (medicine.strength != null &&
                !medicine.name.contains(medicine.strength!))
              Text(
                medicine.strength!,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w600,
                  color: AppColors.muted,
                ),
              ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var i = 0; i < pills; i++) ...[
                  if (i > 0) const SizedBox(width: 16),
                  const Icon(
                    Icons.medication_rounded,
                    size: 72,
                    color: AppColors.ink,
                  ),
                ],
              ],
            ),
            const SizedBox(height: 6),
            Text(
              _pillWords(strings, pills),
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
    );
  }
}
