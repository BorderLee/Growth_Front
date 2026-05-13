import 'dart:convert';
import 'package:http/http.dart' as http;
import 'api_models.dart';
import 'app_config.dart';

class ApiException implements Exception {
  final int statusCode;
  final String message;

  const ApiException({required this.statusCode, required this.message});

  @override
  String toString() => 'ApiException($statusCode): $message';
}

class ApiService {
  static final ApiService instance = ApiService._();
  ApiService._();

  final _client = http.Client();

  static const Map<String, String> _headers = {
    'Content-Type': 'application/json; charset=utf-8',
    'Accept': 'application/json',
  };

  // POST /summary
  Future<SummaryResponse> getSummary(String text) async {
    final response = await _client.post(
      Uri.parse('${await getApiBaseUrl()}/summary'),
      headers: _headers,
      body: jsonEncode({'text': text}),
    );
    _checkStatus(response);
    return SummaryResponse.fromJson(_decodeBody(response));
  }

  // POST /department
  Future<DepartmentResponse> getDepartment(String text) async {
    final response = await _client.post(
      Uri.parse('${await getApiBaseUrl()}/department'),
      headers: _headers,
      body: jsonEncode({'text': text}),
    );
    _checkStatus(response);
    return DepartmentResponse.fromJson(_decodeBody(response));
  }

  // POST /question
  Future<QuestionResponse> askQuestion(String question, String context) async {
    final response = await _client.post(
      Uri.parse('${await getApiBaseUrl()}/question'),
      headers: _headers,
      body: jsonEncode({'question': question, 'context': context}),
    );
    _checkStatus(response);
    return QuestionResponse.fromJson(_decodeBody(response));
  }

  // POST /explain
  Future<ExplainResponse> getExplain(String text) async {
    final response = await _client.post(
      Uri.parse('${await getApiBaseUrl()}/explain'),
      headers: _headers,
      body: jsonEncode({'text': text}),
    );
    _checkStatus(response);
    return ExplainResponse.fromJson(_decodeBody(response));
  }

  // POST /records
  Future<SaveRecordResponse> saveRecord(SaveRecordRequest req) async {
    final response = await _client.post(
      Uri.parse('${await getApiBaseUrl()}/records'),
      headers: _headers,
      body: jsonEncode(req.toJson()),
    );
    _checkStatus(response);
    return SaveRecordResponse.fromJson(_decodeBody(response));
  }

  // GET /records
  Future<List<RecordSummary>> getRecords() async {
    final response = await _client.get(
      Uri.parse('${await getApiBaseUrl()}/records'),
      headers: _headers,
    );
    _checkStatus(response);
    final json = _decodeBody(response);
    return (json['records'] as List)
        .map((e) => RecordSummary.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  // GET /records/{record_id}
  Future<RecordDetail> getRecordDetail(String recordId) async {
    final response = await _client.get(
      Uri.parse('${await getApiBaseUrl()}/records/$recordId'),
      headers: _headers,
    );
    _checkStatus(response);
    return RecordDetail.fromJson(_decodeBody(response));
  }

  // POST /questions
  Future<void> saveQuestion(SaveQuestionRequest req) async {
    final response = await _client.post(
      Uri.parse('${await getApiBaseUrl()}/questions'),
      headers: _headers,
      body: jsonEncode(req.toJson()),
    );
    _checkStatus(response);
  }

  // DELETE /records/{record_id}
  Future<void> deleteRecord(String recordId) async {
    final response = await _client.delete(
      Uri.parse('${await getApiBaseUrl()}/records/$recordId'),
      headers: _headers,
    );
    _checkStatus(response);
  }

  Map<String, dynamic> _decodeBody(http.Response response) =>
      jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;

  void _checkStatus(http.Response response) {
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(
        statusCode: response.statusCode,
        message: utf8.decode(response.bodyBytes),
      );
    }
  }
}
