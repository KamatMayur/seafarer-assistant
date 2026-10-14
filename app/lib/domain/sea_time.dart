/// Sea time totals and NRI days per Indian financial year (screen S15). Pure logic: dates are UTC-midnight days
/// (see expiry.dart parseDay), and both the sign-on and the sign-off day count as days on board, as rule 126 counts
/// the period from the CDC sign-on date to the CDC sign-off date. Informational only (decisions.md R15).
library;

class SeaSpell {
  const SeaSpell({required this.signOn, this.signOff, this.rank, this.shipType});
  final DateTime signOn;
  final DateTime? signOff; // null = still on board (counted up to today)
  final String? rank;
  final String? shipType;
}

typedef DayRange = ({DateTime start, DateTime end}); // both ends included

DateTime _day(DateTime d) => DateTime.utc(d.year, d.month, d.day);

int rangeDays(DayRange r) => r.end.isBefore(r.start) ? 0 : r.end.difference(r.start).inDays + 1;

/// The spell as a day range ending today when still on board; null if it starts after today.
DayRange? spellRange(SeaSpell s, DateTime today) {
  final start = _day(s.signOn), end = _day(s.signOff ?? today);
  final capped = end.isAfter(today) ? today : end;
  return capped.isBefore(start) ? null : (start: start, end: capped);
}

/// Merges overlapping or touching ranges, so a day is never counted twice (e.g. a mistyped overlap).
List<DayRange> mergeRanges(Iterable<DayRange> ranges) {
  final sorted = [...ranges]..sort((a, b) => a.start.compareTo(b.start));
  final out = <DayRange>[];
  for (final r in sorted) {
    if (out.isNotEmpty && !r.start.isAfter(out.last.end.add(const Duration(days: 1)))) {
      final last = out.removeLast();
      out.add((start: last.start, end: r.end.isAfter(last.end) ? r.end : last.end));
    } else {
      out.add(r);
    }
  }
  return out;
}

int daysWithin(List<DayRange> merged, DayRange window) {
  var n = 0;
  for (final r in merged) {
    final s = r.start.isAfter(window.start) ? r.start : window.start;
    final e = r.end.isBefore(window.end) ? r.end : window.end;
    n += rangeDays((start: s, end: e));
  }
  return n;
}

class SeaTotals {
  SeaTotals(this.totalDays, this.byRank, this.byShipType);
  final int totalDays; // overlaps merged
  final Map<String, int> byRank; // per entry; '' = not given
  final Map<String, int> byShipType;
}

SeaTotals seaTotals(Iterable<SeaSpell> spells, DateTime today) {
  final byRank = <String, int>{}, byShip = <String, int>{};
  final ranges = <DayRange>[];
  for (final s in spells) {
    final r = spellRange(s, today);
    if (r == null) continue;
    ranges.add(r);
    final d = rangeDays(r);
    byRank.update(s.rank?.trim() ?? '', (v) => v + d, ifAbsent: () => d);
    byShip.update(s.shipType ?? '', (v) => v + d, ifAbsent: () => d);
  }
  final total = mergeRanges(ranges).fold(0, (n, r) => n + rangeDays(r));
  return SeaTotals(total, byRank, byShip);
}

/// "2 years 3 months 4 days" style, using 30-day months and 365-day years (an approximation; DG counts by dates).
String describeDays(int days) {
  if (days <= 0) return '0 days';
  final y = days ~/ 365, m = (days % 365) ~/ 30, d = days % 365 % 30;
  String p(int n, String w) => '$n $w${n == 1 ? '' : 's'}';
  return [if (y > 0) p(y, 'year'), if (m > 0) p(m, 'month'), if (d > 0 || (y == 0 && m == 0)) p(d, 'day')].join(' ');
}

// ------------------------------------------------------------------------------------------- NRI days

/// Indian financial year starting 1 April of [startYear] ("2025-26" for 2025).
DayRange financialYear(int startYear) =>
    (start: DateTime.utc(startYear, 4, 1), end: DateTime.utc(startYear + 1, 3, 31));

int fyStartYear(DateTime d) => d.month >= 4 ? d.year : d.year - 1;

String fyLabel(int startYear) => '$startYear-${((startYear + 1) % 100).toString().padLeft(2, '0')}';

class NriRegime {
  NriRegime.fromJson(Map<String, dynamic> j)
      : fromFy = j['from_fy'] as int,
        toFy = j['to_fy'] as int?,
        law = j['law'] as String,
        thresholdDays = j['threshold_days'] as int,
        verifiedByOwner = j['verified_by_owner'] as bool? ?? false,
        sources = (j['sources'] as List).cast<String>();

  final int fromFy;
  final int? toFy;
  final String law;
  final int thresholdDays;
  final bool verifiedByOwner;
  final List<String> sources;

  bool covers(int fy) => fy >= fromFy && (toFy == null || fy <= toFy!);
}

class NriRules {
  NriRules.fromJson(Map<String, dynamic> j)
      : regimes = [for (final r in j['regimes'] as List) NriRegime.fromJson(r as Map<String, dynamic>)],
        notes = (j['notes'] as List).cast<String>();

  final List<NriRegime> regimes;
  final List<String> notes;

  NriRegime? forFy(int fy) => regimes.where((r) => r.covers(fy)).firstOrNull;
}

enum NriStatus { atOrAbove, below, belowSoFar, noRule }

class FyNri {
  FyNri({
    required this.fy,
    required this.daysCounted,
    required this.daysOnBoard,
    required this.complete,
    required this.regime,
  });
  final int fy;
  final int daysCounted; // days of the year so far (the whole year once it has ended)
  final int daysOnBoard;
  final bool complete;
  final NriRegime? regime;

  /// Upper bound: every day not on board is counted as possibly in India.
  int get daysPossiblyInIndia => daysCounted - daysOnBoard;

  NriStatus get status {
    if (regime == null) return NriStatus.noRule;
    if (daysPossiblyInIndia >= regime!.thresholdDays) return NriStatus.atOrAbove;
    return complete ? NriStatus.below : NriStatus.belowSoFar;
  }

  /// Days still available in India this year before reaching the threshold (current year only).
  int? get daysLeftBelowThreshold =>
      complete || regime == null ? null : (regime!.thresholdDays - 1 - daysPossiblyInIndia).clamp(0, 366);
}

/// One row per financial year that has sea service, newest first, plus the current year.
List<FyNri> nriByFinancialYear(Iterable<SeaSpell> spells, NriRules rules, DateTime today) {
  final ranges = [for (final s in spells) ?spellRange(s, today)];
  final merged = mergeRanges(ranges);
  final years = <int>{fyStartYear(today)};
  for (final r in merged) {
    for (var y = fyStartYear(r.start); y <= fyStartYear(r.end); y++) {
      years.add(y);
    }
  }
  final out = <FyNri>[];
  for (final y in years.toList()..sort((a, b) => b.compareTo(a))) {
    final fy = financialYear(y);
    if (fy.start.isAfter(today)) continue;
    final complete = fy.end.isBefore(today);
    final window = (start: fy.start, end: complete ? fy.end : today);
    out.add(FyNri(
      fy: y,
      daysCounted: rangeDays(window),
      daysOnBoard: daysWithin(merged, window),
      complete: complete,
      regime: rules.forFy(y),
    ));
  }
  return out;
}
