/// Plain models for API JSON. Field names follow backend/sa_backend/api/schemas.py.
library;

DateTime? _date(Object? v) => v == null ? null : DateTime.tryParse('$v');

class DocumentCard {
  DocumentCard({
    required this.id,
    required this.title,
    this.circularNumber,
    this.issuingBranch,
    this.publishedDate,
    required this.docType,
    required this.priority,
    required this.status,
    this.summaryShort,
    this.actionRequired = false,
    this.actionDeadline,
  });

  factory DocumentCard.fromJson(Map<String, dynamic> j) => DocumentCard(
        id: j['id'] as String,
        title: j['title'] as String,
        circularNumber: j['circular_number'] as String?,
        issuingBranch: j['issuing_branch'] as String?,
        publishedDate: _date(j['published_date']),
        docType: j['doc_type'] as String? ?? 'unknown',
        priority: j['priority'] as String? ?? 'normal',
        status: j['status'] as String? ?? 'processed',
        summaryShort: j['summary_short'] as String?,
        actionRequired: j['action_required'] as bool? ?? false,
        actionDeadline: _date(j['action_deadline']),
      );

  final String id;
  final String title;
  final String? circularNumber;
  final String? issuingBranch;
  final DateTime? publishedDate;
  final String docType;
  final String priority;
  final String status;
  final String? summaryShort;
  final bool actionRequired;
  final DateTime? actionDeadline;

  bool get isCritical => priority == 'critical';
}

class Summary {
  Summary.fromJson(Map<String, dynamic> j)
      : language = j['language'] as String,
        languageFallback = j['language_fallback'] as bool? ?? false,
        summaryShort = j['summary_short'] as String,
        summaryDetailed = j['summary_detailed'] as String?,
        actionRequired = j['action_required'] as bool? ?? false,
        actionDeadline = _date(j['action_deadline']),
        affectedGroups = (j['affected_groups'] as Map<String, dynamic>? ?? {})
            .map((k, v) => MapEntry(k, (v as List).cast<String>())),
        keyPoints = (j['key_points'] as List? ?? []).cast<String>(),
        uncertainFields = (j['uncertain_fields'] as List? ?? []).cast<String>(),
        method = j['method'] as String? ?? 'extractive',
        modelVersion = j['model_version'] as String? ?? '',
        verifiedByHuman = j['verified_by_human'] as bool? ?? false,
        disclaimer = j['disclaimer'] as String? ?? '';

  final String language;
  final bool languageFallback;
  final String summaryShort;
  final String? summaryDetailed;
  final bool actionRequired;
  final DateTime? actionDeadline;
  final Map<String, List<String>> affectedGroups;
  final List<String> keyPoints;
  final List<String> uncertainFields;
  final String method;
  final String modelVersion;
  final bool verifiedByHuman;
  final String disclaimer;
}

class RelatedDoc {
  RelatedDoc.fromJson(Map<String, dynamic> j)
      : documentId = j['document_id'] as String,
        relation = j['relation'] as String,
        title = j['title'] as String,
        circularNumber = j['circular_number'] as String?;
  final String documentId;
  final String relation;
  final String title;
  final String? circularNumber;
}

class DocumentDetail {
  DocumentDetail.fromJson(Map<String, dynamic> j)
      : card = DocumentCard.fromJson(j),
        pdfUrl = j['pdf_url'] as String,
        sourceUrl = j['source_url'] as String,
        summary = j['summary'] == null ? null : Summary.fromJson(j['summary'] as Map<String, dynamic>),
        tags = _groups(j['tags']),
        mentions = _groups(j['mentions']),
        related = (j['related'] as List? ?? []).map((e) => RelatedDoc.fromJson(e as Map<String, dynamic>)).toList(),
        impacts = (j['your_impact'] as List? ?? [])
            .map((e) => (certificateId: e['certificate_id'] as String, reason: e['reason'] as String))
            .toList(),
        textAvailable = j['text_available'] as bool? ?? false;

  static Map<String, List<String>> _groups(Object? v) =>
      (v as Map<String, dynamic>? ?? {}).map((k, v) => MapEntry(k, (v as List).cast<String>()));

  final DocumentCard card;
  final String pdfUrl;
  final String sourceUrl;
  final Summary? summary;
  final Map<String, List<String>> tags;
  final Map<String, List<String>> mentions;
  final List<RelatedDoc> related;
  final List<({String certificateId, String reason})> impacts;
  final bool textAvailable;
}

class Profile {
  Profile({
    this.name,
    this.email,
    this.preferredLanguage = 'en',
    this.rank,
    this.department,
    this.level,
    this.shipTypes = const [],
    this.homeMmd,
    this.examGrades = const [],
    this.alertChannels = const ['in_app'],
    this.quietStart,
    this.quietEnd,
  });

  factory Profile.fromJson(Map<String, dynamic> j) => Profile(
        name: j['name'] as String?,
        email: j['email'] as String?,
        preferredLanguage: j['preferred_language'] as String? ?? 'en',
        rank: j['rank'] as String?,
        department: j['department'] as String?,
        level: j['level'] as String?,
        shipTypes: (j['ship_types'] as List? ?? []).cast<String>(),
        homeMmd: j['home_mmd'] as String?,
        examGrades: (j['exam_grades'] as List? ?? []).cast<String>(),
        alertChannels: (j['alert_channels'] as List? ?? ['in_app']).cast<String>(),
        quietStart: (j['quiet_hours'] as Map?)?['start'] as String?,
        quietEnd: (j['quiet_hours'] as Map?)?['end'] as String?,
      );

  final String? name;
  final String? email;
  final String preferredLanguage;
  final String? rank;
  final String? department;
  final String? level;
  final List<String> shipTypes;
  final String? homeMmd;
  final List<String> examGrades;
  final List<String> alertChannels;
  final String? quietStart;
  final String? quietEnd;

  bool get isComplete => department != null && level != null;

  /// Body for PATCH /v1/me (only fields the user can edit).
  Map<String, dynamic> toPatch() => {
        'name': name,
        'preferred_language': preferredLanguage,
        'rank': rank,
        'department': department,
        'level': level,
        'ship_types': shipTypes,
        'home_mmd': homeMmd,
        'exam_grades': examGrades,
        'quiet_hours': quietStart != null && quietEnd != null ? {'start': quietStart, 'end': quietEnd} : null,
      };

  Profile copyWith({
    String? name,
    String? preferredLanguage,
    String? rank,
    String? department,
    String? level,
    List<String>? shipTypes,
    String? homeMmd,
    List<String>? examGrades,
    String? quietStart,
    String? quietEnd,
    bool clearQuiet = false,
  }) =>
      Profile(
        name: name ?? this.name,
        email: email,
        preferredLanguage: preferredLanguage ?? this.preferredLanguage,
        rank: rank ?? this.rank,
        department: department ?? this.department,
        level: level ?? this.level,
        shipTypes: shipTypes ?? this.shipTypes,
        homeMmd: homeMmd ?? this.homeMmd,
        examGrades: examGrades ?? this.examGrades,
        alertChannels: alertChannels,
        quietStart: clearQuiet ? null : quietStart ?? this.quietStart,
        quietEnd: clearQuiet ? null : quietEnd ?? this.quietEnd,
      );
}

/// Reference lists from GET /v1/meta (code -> label). Cached offline.
class Meta {
  Meta.fromJson(Map<String, dynamic> j)
      : departments = _m(j['departments']),
        levels = _m(j['levels']),
        ranks = _lists(j['ranks']),
        rankLevel = _m(j['rank_level']),
        departmentLevels = _lists(j['department_levels']),
        departmentExamGrades = _lists(j['department_exam_grades']),
        rankHeldGrades = _lists(j['rank_held_grades']),
        shipTypes = _m(j['ship_types']),
        mmds = _m(j['mmds']),
        examGrades = _m(j['exam_grades']),
        topics = _m(j['topics']),
        certTypes = _m(j['cert_types']),
        languages = _m(j['languages']);

  static Map<String, String> _m(Object? v) => (v as Map<String, dynamic>? ?? {}).cast<String, String>();
  static Map<String, List<String>> _lists(Object? v) =>
      (v as Map<String, dynamic>? ?? {}).map((k, v) => MapEntry(k, (v as List).cast<String>()));

  final Map<String, String> departments;
  final Map<String, String> levels;
  final Map<String, List<String>> ranks;
  /// Rank -> level ('officer' / 'rating' / 'cadet'). Ranks not listed (e.g. "Other") fit any level.
  final Map<String, String> rankLevel;
  final Map<String, List<String>> departmentLevels;
  final Map<String, List<String>> departmentExamGrades;
  /// Exams a rank has normally already passed, so they are not offered.
  final Map<String, List<String>> rankHeldGrades;
  final Map<String, String> shipTypes;
  final Map<String, String> mmds;
  final Map<String, String> examGrades;
  final Map<String, String> topics;
  final Map<String, String> certTypes;
  final Map<String, String> languages;

  String label(Map<String, String> m, String code) => m[code] ?? code.replaceAll('_', ' ');
}
