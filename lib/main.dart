import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'package:medexplain/api/app_config.dart';
import 'package:medexplain/stt/models.dart';
import 'package:medexplain/stt/transcript_store.dart';
import 'package:medexplain/stt/ws_transport.dart';
import 'screens/result_screen.dart';
import 'screens/records_screen.dart';

void main() {
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
      home: const MyHomePage(title: 'MedExplain'),
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
  String _statusText = "버튼을 누르고 녹음을 시작해보세요.";
  String? _completedTranscript;

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

          if (mounted) {
            setState(() {
              if (transcript.isNotEmpty) {
                _completedTranscript = transcript;
                _statusText = transcript;
              }
            });
          }
          return;
        }

        final warning = WarningEvent.fromWs(e);
        if (warning != null) {
          debugPrint('WARNING: ${warning.message}');
          transcriptStore.applyWarning(warning);
          if (mounted) {
            setState(() {
              _statusText = warning.message;
            });
          }
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
        setState(() {
          _statusText = "마이크 권한이 필요합니다. 설정에서 권한을 허용해주세요.";
        });
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
      setState(() {
        _isListening = true;
        _completedTranscript = null;
        _statusText = "녹음 중...";
      });
    } else {
      final path = await _recorder.stop();

      if (path == null) {
        setState(() {
          _isListening = false;
          _statusText = "녹음 저장 경로를 찾을 수 없습니다.";
        });
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

      // STT 결과가 transcriptStore에 있으면 사용, 없으면 빈 문자열
      setState(() {
        _isListening = false;
        _statusText = "녹음이 완료되었습니다. STT 결과를 기다리는 중...";
        });
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
      appBar: AppBar(
        title: Text(widget.title),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            tooltip: '서버 설정',
            onPressed: _showServerSettingDialog,  // ← 아래에서 만들 함수
          ),
          IconButton(
            icon: const Icon(Icons.folder_outlined),
            tooltip: '진료 기록',
            onPressed: _goToRecords,
          ),
        ],
      ),
      floatingActionButton: _buildFab(),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      body: _buildBody(),
    );
  }

  Widget _buildFab() {
    return FloatingActionButton.extended(
      onPressed: _toggleListening,
      icon: Icon(_isListening ? Icons.stop : Icons.mic),
      label: Text(_isListening ? "녹음 종료" : "녹음 시작"),
      backgroundColor: _isListening ? Colors.red : Colors.green,
    );
  }

  Widget _buildBody() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildHeader(),
          const SizedBox(height: 8),
          Expanded(child: _buildTextPanel()),
          if (!_isListening &&
              (transcriptStore.combinedText.trim().isNotEmpty ||
               transcriptStore.hasWarning)) ...[
            const SizedBox(height: 12),
            _buildResultButton(),
          ],
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return const Text(
      "의사 설명 텍스트",
      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
    );
  }

  Widget _buildTextPanel() {
    final displayText = _isListening
        ? ("녹음 중...\n\n${transcriptStore.combinedText}")
        : _statusText;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey),
        borderRadius: BorderRadius.circular(8),
      ),
      child: SingleChildScrollView(
        child: Text(
          displayText.isEmpty ? "대기 중..." : displayText,
          style: const TextStyle(fontSize: 16),
        ),
      ),
    );
  }

  Widget _buildResultButton() {
    return ElevatedButton.icon(
      onPressed: _goToResult,
      icon: const Icon(Icons.analytics_outlined),
      label: const Text("결과 보기 (요약 / 용어 / 저장)"),
      style: ElevatedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}
