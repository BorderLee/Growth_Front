// POST /department 응답
class DepartmentResponse {
  final String department;
  const DepartmentResponse({required this.department});
  factory DepartmentResponse.fromJson(Map<String, dynamic> json) =>
      DepartmentResponse(department: json['department'] as String);
}

// POST /question 요청
class QuestionRequest {
  final String question;
  final String context;

  const QuestionRequest({required this.question, required this.context});

  Map<String, dynamic> toJson() => {
        'question': question,
        'context': context,
      };
}

// POST /question 응답
class QuestionResponse {
  final bool canAnswer;
  final String? answer;
  final List<String> urgentSymptoms;

  const QuestionResponse({
    required this.canAnswer,
    this.answer,
    required this.urgentSymptoms,
  });

  factory QuestionResponse.fromJson(Map<String, dynamic> json) {
    return QuestionResponse(
      canAnswer: json['can_answer'] as bool,
      answer: json['answer'] as String?,
      urgentSymptoms: json['urgent_symptoms'] != null
          ? List<String>.from(json['urgent_symptoms'] as List)
          : [],
    );
  }
}

// /summary 응답
class SummaryResponse {
  final List<String> summary;

  const SummaryResponse({required this.summary});

  factory SummaryResponse.fromJson(Map<String, dynamic> json) {
    return SummaryResponse(
      summary: List<String>.from(json['summary'] as List),
    );
  }
}

// /explain 응답에서 개별 용어
class MedTerm {
  final String term;
  final String description;

  const MedTerm({required this.term, required this.description});

  factory MedTerm.fromJson(Map<String, dynamic> json) {
    return MedTerm(
      term: json['term'] as String,
      description: json['description'] as String,
    );
  }

  Map<String, dynamic> toJson() => {
        'term': term,
        'description': description,
      };
}

// /explain 응답
class ExplainResponse {
  final List<MedTerm> terms;

  const ExplainResponse({required this.terms});

  factory ExplainResponse.fromJson(Map<String, dynamic> json) {
    return ExplainResponse(
      terms: (json['terms'] as List)
          .map((e) => MedTerm.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

// POST /records 요청
class SaveRecordRequest {
  final String date;
  final String department;
  final String cleanText;
  final List<String> summary;
  final List<MedTerm> terms;

  const SaveRecordRequest({
    required this.date,
    required this.department,
    required this.cleanText,
    required this.summary,
    required this.terms,
  });

  Map<String, dynamic> toJson() => {
        'date': date,
        'department': department,
        'clean_text': cleanText,
        'summary': summary,
        'terms': terms.map((t) => t.toJson()).toList(),
      };
}

// POST /records 응답
class SaveRecordResponse {
  final String recordId;
  final String message;

  const SaveRecordResponse({required this.recordId, required this.message});

  factory SaveRecordResponse.fromJson(Map<String, dynamic> json) {
    return SaveRecordResponse(
      recordId: json['record_id'] as String,
      message: json['message'] as String,
    );
  }
}

// GET /records 응답의 개별 항목 (목록용)
class RecordSummary {
  final String recordId;
  final String date;
  final String department;
  final String summaryPreview;

  const RecordSummary({
    required this.recordId,
    required this.date,
    required this.department,
    required this.summaryPreview,
  });

  factory RecordSummary.fromJson(Map<String, dynamic> json) {
    return RecordSummary(
      recordId: json['record_id'] as String,
      date: json['date'] as String,
      department: json['department'] as String,
      summaryPreview: json['summary_preview'] as String,
    );
  }
}

// POST /questions 요청용 보조 모델
class GeneralInfoItem {
  final String question;
  final String answer;
  const GeneralInfoItem({required this.question, required this.answer});
  Map<String, dynamic> toJson() => {'question': question, 'answer': answer};
}

// POST /questions 요청
class SaveQuestionRequest {
  final String rawText;
  final List<GeneralInfoItem> generalInfo;
  final List<String> askDoctor;
  final List<String> caution;
  final String? recordId;

  const SaveQuestionRequest({
    required this.rawText,
    required this.generalInfo,
    required this.askDoctor,
    required this.caution,
    this.recordId,
  });

  Map<String, dynamic> toJson() => {
        'raw_text': rawText,
        'general_info': generalInfo.map((i) => i.toJson()).toList(),
        'ask_doctor': askDoctor,
        'caution': caution,
        if (recordId != null) 'record_id': recordId,
      };
}

// GET /records/{record_id} 응답 (상세)
class RecordDetail {
  final String recordId;
  final String date;
  final String department;
  final String cleanText;
  final List<String> summary;
  final List<MedTerm> terms;

  const RecordDetail({
    required this.recordId,
    required this.date,
    required this.department,
    required this.cleanText,
    required this.summary,
    required this.terms,
  });

  factory RecordDetail.fromJson(Map<String, dynamic> json) {
    return RecordDetail(
      recordId: json['record_id'] as String,
      date: json['date'] as String,
      department: json['department'] as String,
      cleanText: json['clean_text'] as String,
      summary: List<String>.from(json['summary'] as List),
      terms: (json['terms'] as List)
          .map((e) => MedTerm.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}
