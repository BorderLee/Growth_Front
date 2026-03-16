import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'dart:convert';
import 'package:medexplain/stt/models.dart';
import 'package:medexplain/stt/stream_session_controller.dart';
import 'package:medexplain/stt/transcript_store.dart';
import 'package:medexplain/stt/translation_store.dart';
import 'package:medexplain/stt/ws_transport.dart';
import 'screens/result_screen.dart';
import 'screens/records_screen.dart';

void main() {
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => TranscriptStore()),
        ChangeNotifierProvider(create: (_) => TranslationStore()),
      ],
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
  late final WsTransport ws;
  late final TranscriptStore transcriptStore;
  StreamSessionController? session;

  WsConnState connState = WsConnState.disconnected;

  bool _isListening = false;
  String _statusText = "버튼을 누르고 녹음을 시작해보세요.";
  String? _completedTranscript;

  @override
  void initState() {
    super.initState();

    transcriptStore = TranscriptStore();
    ws = WsTransport(uri: Uri.parse("ws://10.0.2.2:8000/ws/stt"));

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

    ws.stateStream.listen((s) {
      if (!mounted) return;
      setState(() => connState = s);
    });

    ws.eventStream.listen((e) {
      final stt = SttEvent.fromWs(e);
      if (stt != null) {
        transcriptStore.apply(stt);
        if (mounted) setState(() {});
      }
    });
  }

  ws.stateStream.listen((s) {
    if (!mounted) return;
    setState(() => connState = s);
  });
  
  ws.eventStream.listen((e) {
    final stt = SttEvent.fromWs(e);
    if (stt != null) {
      transcriptStore.apply(stt);
      if (mounted) setState(() {});
      return;
      }
      
      if (e.type == "translation") {
        final payload = e.raw["payload"] ?? {};
        final lang = payload["target_lang"];
        final text = payload["translated_text"];
        
        print("TRANSLATION [$lang] $text");
        }
        });
}

  @override
  void dispose() {
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
      final transcript = transcriptStore.combinedText.trim();

      setState(() {
        _isListening = false;
        _completedTranscript = transcript;
        _statusText = transcript.isNotEmpty
            ? transcript
            : "녹음이 완료되었습니다. (STT 결과 없음)";
      });
    }
  }

  void _goToResult() {
    final text = _completedTranscript ?? '';
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ResultScreen(transcript: text),
      ),
    );
  }

  void _goToRecords() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const RecordsScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        actions: [
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
          if (_completedTranscript != null && !_isListening) ...[
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
