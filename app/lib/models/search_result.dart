class SearchResult {
  final String subjectCode;
  final int? syllabusId;
  final String section;
  final int? sessionNumber;
  final String title;
  final String content;
  final String? snippet;
  final String sourcePath;

  factory SearchResult.fromJson(Map<String, dynamic> json) {
    return SearchResult(
      subjectCode: json['subject_code'] as String? ?? '',
      syllabusId: json['syllabus_id'] as int?,
      section: json['section'] as String? ?? '',
      sessionNumber: json['session_number'] as int?,
      title: json['title'] as String? ?? '',
      content: json['content'] as String? ?? '',
      snippet: json['snippet'] as String?,
      sourcePath: json['source_path'] as String? ?? '',
    );
  }

  const SearchResult({
    required this.subjectCode,
    required this.syllabusId,
    required this.section,
    required this.sessionNumber,
    required this.title,
    required this.content,
    required this.sourcePath,
    this.snippet,
  });
}
