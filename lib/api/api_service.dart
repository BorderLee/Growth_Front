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

  Map<String, String> get _headers => {
        'Content-Type': 'application/json; charset=utf-8',
        'Accept': 'application/json',
      };

  // POST /summary
  Future<SummaryResponse> getSummary(String text) async {
    final response = await _client.post(
      Uri.parse('$kApiBaseUrl/summary'),
      headers: _headers,
      body: jsonEncode({'text': text}),
    );
    _checkStatus(response);
    return SummaryResponse.fromJson(
        jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>);
  }

  // POST /explain
  Future<ExplainResponse> getExplain(String text) async {
    final response = await _client.post(
      Uri.parse('$kApiBaseUrl/explain'),
      headers: _headers,
      body: jsonEncode({'text': text}),
    );
    _checkStatus(response);
    return ExplainResponse.fromJson(
        jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>);
  }

  // POST /records
  Future<SaveRecordResponse> saveRecord(SaveRecordRequest req) async {
    final response = await _client.post(
      Uri.parse('$kApiBaseUrl/records'),
      headers: _headers,
      body: jsonEncode(req.toJson()),
    );
    _checkStatus(response);
    return SaveRecordResponse.fromJson(
        jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>);
  }

  // GET /records
  Future<List<RecordSummary>> getRecords() async {
    final response = await _client.get(
      Uri.parse('$kApiBaseUrl/records'),
      headers: _headers,
    );
    _checkStatus(response);
    final json =
        jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
    return (json['records'] as List)
        .map((e) => RecordSummary.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  // GET /records/{record_id}
  Future<RecordDetail> getRecordDetail(String recordId) async {
    final response = await _client.get(
      Uri.parse('$kApiBaseUrl/records/$recordId'),
      headers: _headers,
    );
    _checkStatus(response);
    return RecordDetail.fromJson(
        jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>);
  }

  void _checkStatus(http.Response response) {
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(
        statusCode: response.statusCode,
        message: utf8.decode(response.bodyBytes),
      );
    }
  }
}
