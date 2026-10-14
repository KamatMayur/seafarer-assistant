import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:seafarer_assistant/domain/sea_time.dart';
import 'package:seafarer_assistant/features/sea_time/sea_time_screen.dart';

DateTime d(int y, int m, int day) => DateTime.utc(y, m, day);

void main() {
  final rules = NriRules.fromJson(jsonDecode(File('assets/nri_rules.json').readAsStringSync()) as Map<String, dynamic>);

  test('both sign-on and sign-off days count; still on board counts to today', () {
    expect(rangeDays(spellRange(SeaSpell(signOn: d(2026, 1, 1), signOff: d(2026, 1, 1)), d(2026, 10, 14))!), 1);
    expect(rangeDays(spellRange(SeaSpell(signOn: d(2026, 1, 1), signOff: d(2026, 1, 31)), d(2026, 10, 14))!), 31);
    expect(rangeDays(spellRange(SeaSpell(signOn: d(2026, 10, 1)), d(2026, 10, 14))!), 14);
    expect(spellRange(SeaSpell(signOn: d(2026, 11, 1)), d(2026, 10, 14)), isNull); // future sign-on
  });

  test('totals merge overlapping entries but per-rank totals do not', () {
    final t = seaTotals([
      SeaSpell(signOn: d(2025, 1, 1), signOff: d(2025, 1, 10), rank: 'Third Officer', shipType: 'tanker'),
      SeaSpell(signOn: d(2025, 1, 6), signOff: d(2025, 1, 15), rank: 'Second Officer', shipType: 'tanker'),
      SeaSpell(signOn: d(2025, 3, 1), signOff: d(2025, 3, 2)),
    ], d(2026, 10, 14));
    expect(t.totalDays, 15 + 2); // 1–15 Jan merged, plus 2 days
    expect(t.byRank, {'Third Officer': 10, 'Second Officer': 10, '': 2});
    expect(t.byShipType, {'tanker': 20, '': 2});
  });

  test('describeDays', () {
    expect(describeDays(0), '0 days');
    expect(describeDays(1), '1 day');
    expect(describeDays(30), '1 month');
    expect(describeDays(400), '1 year 1 month 5 days');
  });

  test('financial years', () {
    expect(fyStartYear(d(2026, 3, 31)), 2025);
    expect(fyStartYear(d(2026, 4, 1)), 2026);
    expect(fyLabel(2025), '2025-26');
    expect(fyLabel(2099), '2099-00');
    expect(rangeDays(financialYear(2023)), 366); // includes 29 Feb 2024
  });

  test('NRI days split a spell across financial years and compare with the threshold', () {
    final spells = [
      // 1 Oct 2024 – 30 Jun 2025: 182 days in FY 2024-25 (Oct–Mar) and 91 days in FY 2025-26 (Apr–Jun)
      SeaSpell(signOn: d(2024, 10, 1), signOff: d(2025, 6, 30)),
      // 1 Aug 2025 – 31 Mar 2026: 243 days in FY 2025-26
      SeaSpell(signOn: d(2025, 8, 1), signOff: d(2026, 3, 31)),
    ];
    final rows = nriByFinancialYear(spells, rules, d(2026, 10, 14));
    expect(rows.map((r) => r.fy), [2026, 2025, 2024]);

    final fy25 = rows[1];
    expect((fy25.daysCounted, fy25.daysOnBoard, fy25.complete), (365, 91 + 243, true));
    expect(fy25.daysPossiblyInIndia, 31);
    expect(fy25.status, NriStatus.below);

    final fy24 = rows[2];
    expect((fy24.daysOnBoard, fy24.daysPossiblyInIndia), (182, 183));
    expect(fy24.status, NriStatus.atOrAbove); // 183 >= 182

    final now = rows[0]; // 1 Apr – 14 Oct 2026, nothing on board
    expect((now.complete, now.daysCounted, now.daysOnBoard), (false, 197, 0));
    expect(now.status, NriStatus.atOrAbove);
    expect(now.regime!.law, 'Income-tax Act, 2025');
  });

  test('current year below the threshold says how many India days are left', () {
    final rows = nriByFinancialYear([SeaSpell(signOn: d(2026, 4, 10))], rules, d(2026, 10, 14));
    final now = rows.single;
    expect((now.daysCounted, now.daysOnBoard, now.daysPossiblyInIndia), (197, 188, 9));
    expect(now.status, NriStatus.belowSoFar);
    expect(now.daysLeftBelowThreshold, 181 - 9);
  });

  test('years before the configured rules show days but no verdict', () {
    final rows = nriByFinancialYear([SeaSpell(signOn: d(2010, 5, 1), signOff: d(2010, 5, 31))], rules, d(2026, 10, 14));
    final old = rows.firstWhere((r) => r.fy == 2010);
    expect((old.daysOnBoard, old.status), (31, NriStatus.noRule));
  });

  test('the rules file cites a source for every year and claims no owner check yet', () {
    expect(rules.regimes, isNotEmpty);
    for (final r in rules.regimes) {
      expect(r.sources, isNotEmpty);
      expect(r.thresholdDays, 182);
      expect(r.verifiedByOwner, isFalse);
    }
    for (var fy = 2015; fy <= 2040; fy++) {
      expect(rules.forFy(fy), isNotNull, reason: 'FY $fy has no rule');
    }
  });

  testWidgets('NRI card shows days, verdicts and the not-checked warning', (tester) async {
    final rows = nriByFinancialYear([
      SeaSpell(signOn: d(2024, 10, 1), signOff: d(2025, 6, 30)),
      SeaSpell(signOn: d(2025, 8, 1), signOff: d(2026, 3, 31)),
    ], rules, d(2026, 10, 14));
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: SingleChildScrollView(child: NriCard(rows: rows, notes: rules.notes))),
    ));
    expect(find.textContaining('not been checked by the app owner'), findsOneWidget);
    expect(find.text('FY 2025-26'), findsOneWidget);
    expect(find.text('FY 2026-27 (so far)'), findsOneWidget);
    expect(find.text('On board 334 days · possibly in India 31 of 365 days'), findsOneWidget);
    expect(find.text('Fewer than 182 days possibly in India'), findsOneWidget);
    expect(find.text('182 days or more possibly in India: likely resident'), findsNWidgets(2)); // 2024-25 and 2026-27
    await tester.tap(find.text('How this is counted and its limits'));
    await tester.pumpAndSettle();
    expect(find.textContaining('rule 126'), findsOneWidget);
    expect(find.textContaining('not tax advice'), findsOneWidget);
  });
}
