//포트 연결을 관장하는 코드입니다
import 'package:shared_preferences/shared_preferences.dart';

const String kDefaultServerIp = '10.240.66.72';
const int kServerPort = 8000;

Future<String> getServerIp() async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getString('server_ip') ?? kDefaultServerIp;
}

Future<void> saveServerIp(String ip) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString('server_ip', ip);
}

Future<String> getApiBaseUrl() async {
  final ip = await getServerIp();
  return 'http://$ip:$kServerPort';
}

Future<Uri> getWsUri() async {
  final ip = await getServerIp();
  return Uri.parse('ws://$ip:$kServerPort/ws/stt');
}
