import 'dart:convert';
import 'package:http/http.dart' as http;

class GoogleSttService {
  // API 키
  final String _apiKey = "AIzaSyDzv_5Lb6VoJByJ33Eql9B3NAL1Jom8HCc";

  Future<String> convertAudioToText(String base64Audio) async {
    final url = Uri.parse('https://speech.googleapis.com/v1/speech:recognize?key=$_apiKey');

    final body = jsonEncode({
      "config": {
        "encoding": "LINEAR16", // 녹음 방식에 따라 추후 수정 가능
        "sampleRateHertz": 44100,
        "languageCode": "ko-KR"
      },
      "audio": {
        "content": base64Audio // 여기에 목소리 데이터가 들어감
      }
    });

    final response = await http.post(
      url, 
      headers: {"Content-Type": "application/json"}, 
      body: body
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      // 터미널에서 확인한 결과 경로
      if (data['results'] != null) {
        return data['results'][0]['alternatives'][0]['transcript'];
      }
      return "인식된 결과가 없습니다.";
    } else {
      return "에러 발생: ${response.body}";
    }
  }
}
