import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:medexplain/api/app_config.dart';
import 'package:medexplain/stt/models.dart';
import 'package:medexplain/stt/transcript_store.dart';
import 'package:medexplain/stt/ws_transport.dart';
import 'screens/result_screen.dart';
import 'screens/records_screen.dart';
import 'screens/auth_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(
    ChangeNotifierProvider(
      create: (_) => TranscriptStore(),
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MedExplain',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.green),
      ),
      debugShowCheckedModeBanner: false,
      home: const AuthGate(),
    );
  }
}

/// 로그인 상태에 따라 AuthScreen 또는 홈 화면을 보여주는 게이트
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      // 스트림 대기 전에 현재 로그인 상태를 즉시 확인
      initialData: FirebaseAuth.instance.currentUser,
      builder: (context, snapshot) {
        if (snapshot.hasData) {
          return const MyHomePage(title: 'MedExplain');
        }
        return const AuthScreen();
      },
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});
  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  final AudioRecorder _recorder = AudioRecorder();
  late WsTransport ws;
  late final TranscriptStore transcriptStore;
  StreamSubscription<WsConnState>? _wsStateSub;
  StreamSubscription<WsEvent>? _wsEventSub;

  WsConnState connState = WsConnState.disconnected;

  bool _isListening = false;

  @override
  void initState() {
    super.initState();
    transcriptStore = TranscriptStore();
    ws = WsTransport(uri: Uri.parse("ws://placeholder"));

    getWsUri().then((uri) {
      debugPrint('WS URI: $uri');
      ws = WsTransport(uri: uri);

      _wsStateSub = ws.stateStream.listen((s) {
        if (!mounted) return;
        setState(() => connState = s);
      });

      _wsEventSub = ws.eventStream.listen((e) {
        final stt = SttEvent.fromWs(e);
        if (stt != null) {
          debugPrint('PARSED STT TEXT: ${stt.text}');
          debugPrint('PARSED STT FINAL: ${stt.isFinal}');
          transcriptStore.apply(stt);

          final transcript = transcriptStore.combinedText.trim();
          debugPrint('COMBINED TEXT: $transcript');

          if (mounted && transcript.isNotEmpty) setState(() {});
          return;
        }

        final warning = WarningEvent.fromWs(e);
        if (warning != null) {
          debugPrint('WARNING: ${warning.message}');
          transcriptStore.applyWarning(warning);
          if (mounted) setState(() {});
          return;
        }

        debugPrint('UNHANDLED WS EVENT: ${e.type}');
      });

      ws.connect().then((_) {
        ws.sendJson({
          "type": "session.start",
          "sessionId": "test-session",
          "audio": {
            "encoding": "LINEAR16",
            "sampleRateHz": 16000,
            "channels": 1,
          }
        });
      });
    }).catchError((e) {
      debugPrint('getWsUri 에러: $e');
    });
  }

  @override
  void dispose() {
    _wsStateSub?.cancel();
    _wsEventSub?.cancel();
    ws.close();
    _recorder.dispose();
    super.dispose();
  }

  Future<String> _buildOutputPath() async {
    final dir = await getApplicationDocumentsDirectory();
    final fileName =
        "medex_${DateTime.now().millisecondsSinceEpoch}.wav";
    return "${dir.path}/$fileName";
  }

  Future<void> _toggleListening() async {
    if (!_isListening) {
      final hasPermission = await _recorder.hasPermission();
      if (!hasPermission) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('마이크 권한이 필요합니다. 설정에서 권한을 허용해주세요.')),
          );
        }
        return;
      }

      final outPath = await _buildOutputPath();

      await _recorder.start(
        const RecordConfig(
          encoder: AudioEncoder.wav,
          sampleRate: 16000,
          numChannels: 1,
        ),
        path: outPath,
      );

      transcriptStore.reset();
      setState(() => _isListening = true);
    } else {
      final path = await _recorder.stop();

      if (path == null) {
        setState(() => _isListening = false);
        return;
      }

      final file = File(path);
      final exists = await file.exists();
      final sizeBytes = exists ? await file.length() : 0;

      if (exists && sizeBytes > 0) {
        final bytes = await file.readAsBytes();
        final b64 = base64Encode(bytes);
        ws.sendJson({
          "type": "audio",
          "sessionId": "test-session",
          "seq": DateTime.now().millisecondsSinceEpoch,
          "bytes": bytes.length,
          "audioB64": b64,
        });
        debugPrint("AUDIO SENT bytes=${bytes.length}");
      }

      setState(() => _isListening = false);
    }
  }

  void _goToResult() {
    final text = transcriptStore.combinedText.trim();
    final warning = transcriptStore.warningMessage;

    if (text.isEmpty && warning == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('아직 STT 결과가 도착하지 않았습니다. 잠시 후 다시 눌러주세요.'),
        ),
      );
      return;
    }

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ResultScreen(
          transcript: text,
          warningMessage: warning,
        ),
      ),
    );
  }

  void _goToRecords() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const RecordsScreen()),
    );
  }

  void _resetRecording() {
    transcriptStore.reset();
    setState(() {});
  }

  void _showServerSettingDialog() async {
    final currentIp = await getServerIp();
    final controller = TextEditingController(text: currentIp);

    if (!mounted) return;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('서버 IP 설정'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'IP 주소',
            hintText: '예: 192.168.0.10',
          ),
          keyboardType: TextInputType.number,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('취소'),
          ),
          ElevatedButton(
            onPressed: () async {
              await saveServerIp(controller.text.trim());
              if (!mounted) return;
              Navigator.pop(ctx);
              // 새 IP로 재연결
              ws.close();
              final uri = await getWsUri();
              setState(() {
                ws = WsTransport(uri: uri);
              });
              ws.connect().then((_) {
                ws.sendJson({
                  "type": "session.start",
                  "sessionId": "test-session",
                  "audio": {
                    "encoding": "LINEAR16",
                    "sampleRateHz": 16000,
                    "channels": 1,
                  }
                });
              });
            },
            child: const Text('저장'),
          ),
        ],
      ),
    );
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        titleSpacing: 16,
        title: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.asset('assets/MedExplain.png', width: 32, height: 32),
            ),
            const SizedBox(width: 10),
            Text(
              widget.title,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.folder, color: Colors.amber),
            tooltip: '진료 기록',
            onPressed: _goToRecords,
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (value) {
              if (value == 'settings') _showServerSettingDialog();
              if (value == 'logout') FirebaseAuth.instance.signOut();
            },
            itemBuilder: (ctx) => [
              const PopupMenuItem(
                value: 'settings',
                child: Row(children: [
                  Icon(Icons.settings_outlined, size: 18),
                  SizedBox(width: 8),
                  Text('서버 설정'),
                ]),
              ),
              const PopupMenuItem(
                value: 'logout',
                child: Row(children: [
                  Icon(Icons.logout, size: 18),
                  SizedBox(width: 8),
                  Text('로그아웃'),
                ]),
              ),
            ],
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    final hasResult = !_isListening &&
        (transcriptStore.combinedText.trim().isNotEmpty ||
            transcriptStore.hasWarning);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
          child: _buildConnectionStatus(),
        ),
        Expanded(
          child: (_isListening || hasResult)
              ? Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                  child: _buildTextCard(),
                )
              : _buildEmptyState(),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
          child: _buildBottomButtons(),
        ),
      ],
    );
  }

  Widget _buildConnectionStatus() {
    final (color, label) = switch (connState) {
      WsConnState.connected => (Colors.green, '서버 연결됨'),
      WsConnState.connecting || WsConnState.reconnecting =>
        (Colors.orange, '연결 중...'),
      _ => (Colors.red, '서버 연결 안됨'),
    };

    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(
              fontSize: 13, color: color, fontWeight: FontWeight.w500),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.medical_services_outlined,
                size: 56,
                color: Colors.blue.shade400,
              ),
            ),
            const SizedBox(height: 28),
            const Text(
              '진료실에서 의사 설명을\n녹음해 보세요',
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 20, fontWeight: FontWeight.bold, height: 1.4),
            ),
            const SizedBox(height: 12),
            Text(
              'AI가 핵심 내용을 요약하고\n어려운 용어를 쉽게 설명해 드려요',
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 14, color: Colors.grey.shade500, height: 1.5),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextCard() {
    final text = transcriptStore.combinedText.trim();
    final warning = transcriptStore.warningMessage;
    final displayText = text.isNotEmpty ? text : (warning ?? '');

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                const Icon(Icons.mic_outlined, size: 16),
                const SizedBox(width: 6),
                Text(
                  _isListening ? '녹음 중...' : '인식된 텍스트',
                  style: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w600),
                ),
                if (_isListening) ...[
                  const SizedBox(width: 6),
                  Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                        color: Colors.red, shape: BoxShape.circle),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 12),
            ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.35,
              ),
              child: SingleChildScrollView(
                child: Text(
                  displayText.isEmpty ? '음성 인식 대기 중...' : displayText,
                  style: const TextStyle(fontSize: 15, height: 1.6),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomButtons() {
    final hasResult = !_isListening &&
        (transcriptStore.combinedText.trim().isNotEmpty ||
            transcriptStore.hasWarning);

    if (_isListening) {
      return OutlinedButton.icon(
        onPressed: _toggleListening,
        icon: const Icon(Icons.stop, color: Colors.red),
        label: const Text('녹음 종료',
            style: TextStyle(color: Colors.red, fontSize: 16)),
        style: OutlinedButton.styleFrom(
          side: const BorderSide(color: Colors.red),
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      );
    }

    if (hasResult) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          FilledButton.icon(
            onPressed: _goToResult,
            icon: const Icon(Icons.auto_awesome),
            label: const Text('AI 분석 결과 보기',
                style: TextStyle(fontSize: 16)),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
            ),
          ),
          const SizedBox(height: 10),
          ElevatedButton.icon(
            onPressed: _resetRecording,
            icon: const Icon(Icons.mic),
            label: const Text('다시 녹음', style: TextStyle(fontSize: 16)),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
            ),
          ),
        ],
      );
    }

    return ElevatedButton.icon(
      onPressed: _toggleListening,
      icon: const Icon(Icons.mic),
      label: const Text('녹음 시작', style: TextStyle(fontSize: 16)),
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }
}
