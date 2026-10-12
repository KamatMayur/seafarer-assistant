import 'package:flutter_test/flutter_test.dart';
import 'package:seafarer_assistant/data/models.dart';
import 'package:seafarer_assistant/domain/profile_rules.dart';

// A cut-down copy of GET /v1/meta (backend reference.py) with the tables the rules use.
final meta = Meta.fromJson({
  'departments': {'deck': 'Deck', 'engine': 'Engine', 'catering': 'Catering', 'other': 'Other'},
  'levels': {'officer': 'Officer', 'rating': 'Rating', 'cadet': 'Cadet / Trainee'},
  'ranks': {
    'deck': ['Master', 'Chief Officer', 'Third Officer', 'Deck Cadet', 'AB'],
    'engine': ['Chief Engineer', 'Fourth Engineer', 'Junior Engineer', 'Engine Cadet', 'Oiler'],
    'catering': ['Cook'],
    'other': ['Other'],
  },
  'rank_level': {
    'Master': 'officer', 'Chief Officer': 'officer', 'Third Officer': 'officer', 'Deck Cadet': 'cadet', //
    'AB': 'rating', 'Chief Engineer': 'officer', 'Fourth Engineer': 'officer', 'Junior Engineer': 'cadet',
    'Engine Cadet': 'cadet', 'Oiler': 'rating', 'Cook': 'rating',
  },
  'department_levels': {
    'deck': ['officer', 'rating', 'cadet'],
    'engine': ['officer', 'rating', 'cadet'],
    'catering': ['rating'],
    'other': ['officer', 'rating', 'cadet'],
  },
  'department_exam_grades': {
    'deck': ['second_mate', 'chief_mate', 'master', 'gmdss'],
    'engine': ['meo_class_4', 'meo_class_2', 'meo_class_1'],
    'catering': <String>[],
    'other': ['second_mate', 'chief_mate', 'master', 'gmdss', 'meo_class_4', 'meo_class_2', 'meo_class_1'],
  },
  'rank_held_grades': {
    'Master': ['second_mate', 'chief_mate', 'master', 'gmdss'],
    'Chief Officer': ['second_mate', 'chief_mate', 'gmdss'],
    'Fourth Engineer': ['meo_class_4'],
    'Chief Engineer': ['meo_class_4', 'meo_class_2', 'meo_class_1'],
  },
  'exam_grades': {
    'second_mate': '2nd Mate', 'chief_mate': 'Chief Mate', 'master': 'Master', 'gmdss': 'GMDSS', //
    'meo_class_4': 'MEO IV', 'meo_class_2': 'MEO II', 'meo_class_1': 'MEO I',
  },
});

void main() {
  test('an engine cadet cannot pick Chief Engineer', () {
    expect(ranksFor(meta, 'engine', 'cadet'), ['Junior Engineer', 'Engine Cadet']);
    expect(ranksFor(meta, 'engine', 'officer'), ['Chief Engineer', 'Fourth Engineer']);
    expect(ranksFor(meta, 'engine', null), hasLength(5));
    expect(ranksFor(meta, 'other', 'cadet'), ['Other']); // no level of its own: fits any
  });

  test('levels follow the department; a rank sets its level', () {
    expect(levelsFor(meta, 'catering'), ['rating']);
    expect(levelsFor(meta, null), ['officer', 'rating', 'cadet']);
    expect(levelOfRank(meta, 'Deck Cadet'), 'cadet');
    expect(levelOfRank(meta, 'Other'), isNull);
  });

  test('exams follow the department and skip what the rank already holds', () {
    expect(examGradesFor(meta, 'engine', 'Engine Cadet'), ['meo_class_4', 'meo_class_2', 'meo_class_1']);
    expect(examGradesFor(meta, 'engine', 'Fourth Engineer'), ['meo_class_2', 'meo_class_1']);
    expect(examGradesFor(meta, 'deck', 'Chief Officer'), ['master']);
    expect(examGradesFor(meta, 'deck', 'Master'), isEmpty);
    expect(examGradesFor(meta, 'catering', 'Cook'), isEmpty);
    expect(examGradesFor(meta, null, null), hasLength(7));
  });

  test('an old cached meta without the tables still works (no filtering)', () {
    final old = Meta.fromJson({
      'levels': {'officer': 'Officer', 'cadet': 'Cadet'},
      'ranks': {'engine': ['Chief Engineer', 'Engine Cadet']},
      'exam_grades': {'meo_class_1': 'MEO I'},
    });
    expect(levelsFor(old, 'engine'), ['officer', 'cadet']);
    expect(ranksFor(old, 'engine', 'cadet'), ['Chief Engineer', 'Engine Cadet']);
    expect(examGradesFor(old, 'engine', 'Chief Engineer'), ['meo_class_1']);
  });
}
