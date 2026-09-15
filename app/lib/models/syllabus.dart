class Syllabus {
  const Syllabus({
    required this.syllabusId,
    required this.subjectCode,
    required this.subjectName,
    required this.syllabusName,
    required this.credits,
    required this.degreeLevel,
    required this.timeAllocation,
    required this.prerequisite,
    required this.decision,
    required this.description,
    required this.sourcePath,
  });

  factory Syllabus.fromJson(Map<String, dynamic> json) {
    return Syllabus(
      syllabusId: json['syllabus_id'] as int? ?? 0,
      subjectCode: json['subject_code'] as String? ?? '',
      subjectName: json['subject_name'] as String? ?? '',
      syllabusName: json['syllabus_name'] as String? ?? '',
      credits: json['credits']?.toString() ?? '',
      degreeLevel: json['degree_level']?.toString() ?? '',
      timeAllocation: json['time_allocation']?.toString() ?? '',
      prerequisite: json['prerequisite']?.toString() ?? '',
      decision: json['decision'] as String? ?? '',
      description: json['description'] as String? ?? '',
      sourcePath: json['source_path'] as String? ?? '',
    );
  }

  final int syllabusId;
  final String subjectCode;
  final String subjectName;
  final String syllabusName;
  final String credits;
  final String degreeLevel;
  final String timeAllocation;
  final String prerequisite;
  final String decision;
  final String description;
  final String sourcePath;
}
