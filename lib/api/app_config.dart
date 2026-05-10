import 'package:shared_preferences/shared_preferences.dart';

const String kDefaultServerIp = '10.240.66.72';
const int kServerPort = 8000;

String? _cachedIp;

Future<String> getServerIp() async {
  if (_cachedIp != null) return _cachedIp!;
  final prefs = await SharedPreferences.getInstance();
  return _cachedIp = prefs.getString('server_ip') ?? kDefaultServerIp;
}

Future<void> saveServerIp(String ip) async {
  _cachedIp = ip;
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString('server_ip', ip);
}

Future<String> getApiBaseUrl() async =>
    'http://${await getServerIp()}:$kServerPort';

Future<Uri> getWsUri() async =>
    Uri.parse('ws://${await getServerIp()}:$kServerPort/ws/stt');
