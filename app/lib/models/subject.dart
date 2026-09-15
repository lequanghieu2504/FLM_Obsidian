import 'syllabus.dart';

class Subject {
  const Subject({required this.code, required this.name});

  factory Subject.fromJson(Map<String, dynamic> json) {
    return Subject(
      code: json['code'] as String? ?? '',
      name: json['name'] as String? ?? '',
    );
  }

  final String code;
  final String name;
}

class SubjectList {
  const SubjectList({
    required this.items,
    required this.page,
    required this.pageSize,
    required this.total,
  });

  factory SubjectList.fromJson(Map<String, dynamic> json) {
    return SubjectList(
      items: [
        for (final item in json['items'] as List<dynamic>? ?? const [])
          Subject.fromJson(item as Map<String, dynamic>),
      ],
      page: json['page'] as int? ?? 1,
      pageSize: json['page_size'] as int? ?? 50,
      total: json['total'] as int? ?? 0,
    );
  }

  final List<Subject> items;
  final int page;
  final int pageSize;
  final int total;
}

class SubjectDetail {
  const SubjectDetail({
    required this.code,
    required this.name,
    required this.syllabi,
    required this.learningOutcomes,
    required this.assessment,
    required this.materials,
  });

  factory SubjectDetail.fromJson(Map<String, dynamic> json) {
    return SubjectDetail(
      code: json['code'] as String? ?? '',
      name: json['name'] as String? ?? '',
      syllabi: [
        for (final item in json['syllabi'] as List<dynamic>? ?? const [])
          Syllabus.fromJson(item as Map<String, dynamic>),
      ],
      learningOutcomes: _records(json['learning_outcomes']),
      assessment: _records(json['assessment']),
      materials: _records(json['materials']),
    );
  }

  final String code;
  final String name;
  final List<Syllabus> syllabi;
  final List<Map<String, String>> learningOutcomes;
  final List<Map<String, String>> assessment;
  final List<Map<String, String>> materials;
}

class ScheduleItem {
  const ScheduleItem({
    required this.subjectCode,
    required this.syllabusId,
    required this.sessionNumber,
    required this.title,
    required this.content,
  });

  factory ScheduleItem.fromJson(Map<String, dynamic> json) {
    return ScheduleItem(
      subjectCode: json['subject_code'] as String? ?? '',
      syllabusId: json['syllabus_id'] as int?,
      sessionNumber: json['session_number'] as int?,
      title: json['title'] as String? ?? '',
      content: json['content'] as String? ?? '',
    );
  }

  final String subjectCode;
  final int? syllabusId;
  final int? sessionNumber;
  final String title;
  final String content;
}

List<Map<String, String>> _records(Object? value) {
  return [
    for (final item in value as List<dynamic>? ?? const [])
      {
        for (final entry in (item as Map<String, dynamic>).entries)
          entry.key: entry.value.toString(),
      },
  ];
}
