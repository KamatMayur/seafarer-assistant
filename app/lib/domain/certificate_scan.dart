/// Turns the OCR text of a certificate into suggested form fields, with rules only (decisions.md R1, R12).
/// Everything returned is copied from the text; nothing is made up. The user checks each field before saving.
library;

class ScanGuess {
  String? type, subtype, number, authority;
  DateTime? issue, expiry;

  bool get isEmpty =>
      type == null && subtype == null && number == null && authority == null && issue == null && expiry == null;
}

const _months = {
  'jan': 1, 'feb': 2, 'mar': 3, 'apr': 4, 'may': 5, 'jun': 6, //
  'jul': 7, 'aug': 8, 'sep': 9, 'oct': 10, 'nov': 11, 'dec': 12,
};
const _mon = r'(jan|feb|mar|apr|may|jun|jul|aug|sep|oct|nov|dec)[a-z]*\.?';

class FoundDate {
  FoundDate(this.start, this.date);
  final int start;
  final DateTime date;
}

DateTime? _make(int y, int m, int d) {
  if (y < 100) y += 2000;
  if (y < 1950 || y > 2100 || m < 1 || m > 12 || d < 1 || d > 31) return null;
  final dt = DateTime(y, m, d);
  return dt.month == m && dt.day == d ? dt : null; // rejects 31/02
}

/// All dates in [s] (lower case), in order. Numeric dates are day first (Indian style) unless that is impossible.
List<FoundDate> findDates(String s) {
  final out = <FoundDate>[];
  final taken = <int>{};
  void add(int start, int end, DateTime? d) {
    if (d == null || Iterable<int>.generate(end - start, (i) => start + i).any(taken.contains)) return;
    taken.addAll(Iterable<int>.generate(end - start, (i) => start + i));
    out.add(FoundDate(start, d));
  }

  for (final m in RegExp(r'\b(\d{4})-(\d{1,2})-(\d{1,2})\b').allMatches(s)) {
    add(m.start, m.end, _make(int.parse(m[1]!), int.parse(m[2]!), int.parse(m[3]!)));
  }
  for (final m in RegExp(r'\b(\d{1,2})\s?[./-]\s?(\d{1,2})\s?[./-]\s?(\d{4}|\d{2})\b').allMatches(s)) {
    var d = int.parse(m[1]!), mo = int.parse(m[2]!);
    if (mo > 12 && d <= 12) (d, mo) = (mo, d);
    add(m.start, m.end, _make(int.parse(m[3]!), mo, d));
  }
  for (final m in RegExp('\\b(\\d{1,2})(?:st|nd|rd|th)?[\\s./,-]*$_mon[\\s./,-]*(\\d{4})\\b').allMatches(s)) {
    add(m.start, m.end, _make(int.parse(m[3]!), _months[m[2]!]!, int.parse(m[1]!)));
  }
  for (final m in RegExp('\\b$_mon\\s+(\\d{1,2})(?:st|nd|rd|th)?,?\\s+(\\d{4})\\b').allMatches(s)) {
    add(m.start, m.end, _make(int.parse(m[3]!), _months[m[1]!]!, int.parse(m[2]!)));
  }
  out.sort((a, b) => a.start.compareTo(b.start));
  return out;
}

final _expiryLabel = RegExp(
  r'date\s*of\s*expir\w*|expir\w*\s*(date|on)?|valid\s*(until|till|upto|up\s*to|to|thru|through)|validity',
);
final _issueLabel = RegExp(r'date\s*of\s*(issu\w*|grant)|issu\w*\s*(date|on)\b');
final _birth = RegExp(r'birth|\bdob\b|d\.o\.b');

/// Dates next to their labels: on the same line after the label, or (labels without dates, e.g. a two-column
/// table) on the next line that has dates, matched in order.
void _labelledDates(List<String> lines, ScanGuess g) {
  for (var i = 0; i < lines.length; i++) {
    final line = lines[i];
    final labels = <(int, String)>[
      for (final m in _expiryLabel.allMatches(line)) (m.end, 'expiry'),
      for (final m in _issueLabel.allMatches(line)) (m.end, 'issue'),
    ]..sort((a, b) => a.$1.compareTo(b.$1));
    if (labels.isEmpty) continue;
    final dates = findDates(line);
    var assigned = <String, DateTime>{};
    for (var k = 0; k < labels.length; k++) {
      final from = labels[k].$1, to = k + 1 < labels.length ? labels[k + 1].$1 : line.length + 1;
      final d = dates.where((f) => f.start >= from && f.start < to).firstOrNull;
      if (d != null) assigned[labels[k].$2] = d.date;
    }
    if (assigned.isEmpty) {
      for (var j = i + 1; j < lines.length && j <= i + 2; j++) {
        if (_birth.hasMatch(lines[j])) continue;
        final next = findDates(lines[j]);
        if (next.isEmpty) continue;
        assigned = {for (var k = 0; k < labels.length && k < next.length; k++) labels[k].$2: next[k].date};
        break;
      }
    }
    g.issue ??= assigned['issue'];
    g.expiry ??= assigned['expiry'];
  }
}

final _numberLabel = RegExp(
  r'\b(certificate|cert\.?|c\.?d\.?c\.?|passport|licen[cs]e|document|registration|regn?\.?)\s*'
  r'(no\b\.?|number\b|num\b\.?|#)\s*[:.\-]?\s*',
);
final _stopWords = RegExp(r'\s(date|issued|valid|place|name|indos|dated|of\s)|\s{2,}');
final _idLike = RegExp(r'^[A-Z0-9][A-Z0-9/\-. ]{2,39}$');

String? _number(List<String> original, ScanGuess g) {
  for (var i = 0; i < original.length; i++) {
    final m = _numberLabel.firstMatch(original[i].toLowerCase());
    if (m == null) continue;
    var value = original[i].substring(m.end);
    final stop = _stopWords.firstMatch(value.toLowerCase());
    if (stop != null) value = value.substring(0, stop.start);
    value = value.trim().replaceAll(RegExp(r'^[:.\-\s]+|[.,;:\s]+$'), '');
    if (value.isEmpty && i + 1 < original.length && _idLike.hasMatch(original[i + 1].trim())) {
      value = original[i + 1].trim();
    }
    if (value.length >= 3 && value.length <= 40 && RegExp(r'\d').hasMatch(value)) return value;
  }
  if (g.type == 'passport') return RegExp(r'\b[A-Z][0-9]{7}\b').firstMatch(original.join('\n'))?.group(0);
  return null;
}

const _basicCourses = {
  'personal survival techniques': 'PST',
  'fire prevention and fire fighting': 'FPFF',
  'elementary first aid': 'EFA',
  'personal safety and social responsibilit': 'PSSR',
  'designated security duties': 'STSDSD',
};
const _advancedCourses = {
  'advanced fire fighting': 'AFF',
  'proficiency in survival craft': 'PSCRB',
  'medical first aid': 'MFA',
  'fast rescue boat': 'FRB',
  'ship security officer': 'SSO',
};
const _acronyms = {'PST', 'FPFF', 'EFA', 'PSSR', 'STSDSD', 'AFF', 'PSCRB', 'MFA', 'FRB', 'SSO'};
const _basicAcronyms = {'PST', 'FPFF', 'EFA', 'PSSR', 'STSDSD'};

const _mmdCities = [
  'mumbai', 'kolkata', 'chennai', 'kochi', 'kandla', 'goa', 'visakhapatnam', 'jamnagar', 'port blair', //
  'noida', 'haldia', 'tuticorin', 'mangalore', 'paradip',
];

String _title(String s) => s.split(' ').map((w) => w.isEmpty ? w : w[0].toUpperCase() + w.substring(1)).join(' ');

void _typeAndGrade(String t, String original, ScanGuess g) {
  final roman = RegExp(r'marine engineer officer\s*,?\s*class\s*[-:]?\s*(iv|i{1,3}|[1-4])\b').firstMatch(t);
  String? course;
  bool basic = false;
  for (final e in {..._basicCourses, ..._advancedCourses}.entries) {
    if (t.contains(e.key)) {
      course = e.value;
      basic = _basicCourses.containsKey(e.key);
      break;
    }
  }
  if (course == null) {
    final m = RegExp(r'\b(PSCRB|STSDSD|FPFF|PSSR|AFF|MFA|PST|EFA|FRB|SSO)\b').firstMatch(original);
    if (m != null && _acronyms.contains(m[1])) {
      course = m[1];
      basic = _basicAcronyms.contains(course);
    }
  }

  if (t.contains('continuous discharge certificate')) {
    g.type = 'cdc';
  } else if (t.contains("general operator") || t.contains('gmdss')) {
    g.type = 'coc';
    g.subtype = 'GMDSS GOC';
  } else if (t.contains('certificate of competency') || roman != null) {
    g.type = 'coc';
    if (roman != null) {
      const r = {'i': 'I', 'ii': 'II', 'iii': 'III', 'iv': 'IV', '1': 'I', '2': 'II', '3': 'III', '4': 'IV'};
      g.subtype = 'MEO Class ${r[roman[1]!]}';
    } else if (t.contains('electro-technical officer') || t.contains('electro technical officer')) {
      g.subtype = 'ETO';
    } else {
      for (final grade in ['chief mate', 'second mate', 'master']) {
        if (RegExp('\\b$grade\\b\\s*\\((foreign[- ]going|f\\.?g\\.?|nce|near[- ]coastal)').hasMatch(t) ||
            (grade != 'master' && t.contains(grade))) {
          g.subtype = _title(grade);
          break;
        }
      }
    }
  } else if (t.contains('passport') && (t.contains('republic of india') || t.contains('nationality'))) {
    g.type = 'passport';
  } else if (t.contains('seafarer identity document') ||
      t.contains('seafarers identity document') ||
      t.contains('bsid')) {
    g.type = 'bsid';
  } else if (RegExp(r'medical (fitness|examination|certificate)|fit for sea service').hasMatch(t)) {
    g.type = 'medical';
  } else if (course != null) {
    g.type = basic ? 'stcw_basic' : 'stcw_advanced';
    g.subtype = course;
  } else if (t.contains('certificate of proficiency')) {
    g.type = 'cop';
  } else if (RegExp(r'\bvisa\b').hasMatch(t)) {
    g.type = 'visa';
  }
}

void _authority(String t, List<String> original, ScanGuess g) {
  final mmd = RegExp('mercantile marine department[\\s,.:-]*(${_mmdCities.join('|')})?').firstMatch(t);
  final institute = original
      .map((l) => l.trim())
      .where(
        (l) =>
            l.length <= 80 &&
            RegExp(r'institute|academy|college|training (centre|center)|university', caseSensitive: false).hasMatch(l),
      )
      .firstOrNull;
  final course = g.type == 'stcw_basic' || g.type == 'stcw_advanced' || g.type == 'cop';
  if (course && institute != null) {
    g.authority = institute;
  } else if (mmd != null) {
    g.authority = mmd[1] == null ? 'MMD' : 'MMD ${_title(mmd[1]!)}';
  } else if (t.contains('directorate general of shipping')) {
    g.authority = 'DG Shipping';
  } else if (t.contains('ministry of external affairs')) {
    g.authority = 'Ministry of External Affairs';
  } else if (institute != null) {
    g.authority = institute;
  }
}

ScanGuess readCertificateText(String text) {
  final original = text
      .replaceAll('\r', '')
      .split('\n')
      .map((l) => l.replaceAll(RegExp(r'[ \t]+'), ' ').trim())
      .where((l) => l.isNotEmpty)
      .toList();
  final lower = [for (final l in original) l.toLowerCase()];
  final all = lower.join('\n');
  final g = ScanGuess();

  _typeAndGrade(all, original.join('\n'), g);
  _labelledDates(lower, g);
  // No labels at all: two or more dates (not a birth date) are read as issue = earliest, expiry = latest.
  if (g.issue == null && g.expiry == null) {
    final dates = [
      for (final l in lower)
        if (!_birth.hasMatch(l)) ...findDates(l).map((f) => f.date),
    ]..sort();
    if (dates.length >= 2 && dates.first != dates.last) {
      g.issue = dates.first;
      g.expiry = dates.last;
    }
  }
  if (g.issue != null && g.expiry != null && g.expiry!.isBefore(g.issue!)) g.expiry = null;
  g.number = _number(original, g);
  _authority(all, original, g);
  return g;
}
