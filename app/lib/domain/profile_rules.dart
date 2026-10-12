/// Which profile options fit together (department -> level -> rank -> exams). The tables come from /v1/meta
/// (backend reference.py), which also rejects contradictions. Pure functions, unit-tested.
library;

import '../data/models.dart';

/// Levels the department has (all levels before a department is chosen, or if the server sent no table).
List<String> levelsFor(Meta m, String? department) {
  if (department == null || !m.departmentLevels.containsKey(department)) return m.levels.keys.toList();
  return m.departmentLevels[department]!;
}

/// The department's ranks that fit [level] (ranks without a level, such as "Other", fit any level).
List<String> ranksFor(Meta m, String? department, String? level) => [
      for (final r in m.ranks[department] ?? const <String>[])
        if (level == null || (m.rankLevel[r] ?? level) == level) r,
    ];

/// Exams the department can prepare for, without those the rank normally already holds.
List<String> examGradesFor(Meta m, String? department, String? rank) {
  final base = department != null && m.departmentExamGrades.containsKey(department)
      ? m.departmentExamGrades[department]!
      : m.examGrades.keys.toList();
  final held = m.rankHeldGrades[rank] ?? const <String>[];
  return [for (final g in base) if (!held.contains(g)) g];
}

/// The level a rank implies, if any.
String? levelOfRank(Meta m, String? rank) => rank == null ? null : m.rankLevel[rank];
