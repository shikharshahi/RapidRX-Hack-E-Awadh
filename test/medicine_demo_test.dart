import 'package:flutter_test/flutter_test.dart';
import 'package:rapidrx/domain/scheduled_medicine.dart';
import 'package:rapidrx/domain/sig.dart';
import 'package:rapidrx/features/calls/medicine_demo.dart';

ScheduledMedicine med(String name, double units) => ScheduledMedicine(
  id: name,
  name: name,
  sig: Sig(unitsPerDose: units),
  startDate: DateTime(2026),
);

void main() {
  test('one tablet is one picture, two tablets are two', () {
    expect(visualPills(1), 1);
    expect(visualPills(2), 2);
    expect(visualPills(0.5), 1);
  });

  test('one alert lists every medicine', () {
    final body = demoAlertBody(
      to: '+919876543210',
      medicines: [med('TELMA 40', 1), med('Metformin', 2)],
    );
    expect(body['to'], '+919876543210');
    expect(body['medicines'], [
      {'name': 'TELMA 40', 'pills': 1},
      {'name': 'Metformin', 'pills': 2},
    ]);
  });
}
