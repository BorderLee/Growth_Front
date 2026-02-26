import 'package:flutter/material.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'package:medexplain/stt/audio_source.dart';
import 'package:medexplain/stt/models.dart';
import 'package:medexplain/stt/stream_session_controller.dart';
import 'package:medexplain/stt/transcript_store.dart';
import 'package:medexplain/stt/translation_store.dart';
import 'package:medexplain/stt/ws_transport.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        colorScheme: .fromSeed(seedColor: Colors.green),
      ),
      debugShowCheckedModeBanner: false,
      home: const MyHomePage(title:'MedExplain'),
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
  bool running = false;

  bool _isListening = false;

  // 기존 "입력된 텍스트" UI를 그대로 쓰되, A 단계에서는 상태/결과 표시로 사용
  String _recognizedText = "버튼을 누르고 녹음을 시작해보세요. ";
  String _pathText = "";

  DateTime? _recordingStartedAt;
  String? _lastSavedPath;

  @override
  void initState() {
    super.initState();

    transcriptStore = TranscriptStore();
    ws = WsTransport(uri: Uri.parse('ws://YOUR_SERVER/ws'));

    // 연결 상태 → "재연결 중…" 표시용
    ws.stateStream.listen((s) {
      if (!mounted) return;
      setState(() => connState = s);
    });

    // 서버 이벤트 → STT(Interim/Final) 누적 반영
    ws.eventStream.listen((e) {
      final stt = SttEvent.fromWs(e);
      if (stt != null) {
        transcriptStore.apply(stt);
        if (mounted) setState(() {});
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
        "medex_${DateTime
        .now()
        .millisecondsSinceEpoch}.wav";
    return "${dir.path}/$fileName";
  }

  Future<void> _toggleListening() async {
    if (!_isListening) {
      // 1) 권한 체크
      final hasPermission = await _recorder.hasPermission();
      if (!hasPermission) {
        setState(() {
          _recognizedText = "마이크 권한이 필요합니다. 설정에서 권한을 허용해주세요.";
        });
        return;
      }
      //======START======
      final outPath = await _buildOutputPath();

      await _recorder.start(
        const RecordConfig(
          encoder: AudioEncoder.wav,
          sampleRate: 16000,
          numChannels: 1,
        ),
        path: outPath,
      );

      setState(() {
        _isListening = true;
        _recordingStartedAt = DateTime.now();
        _lastSavedPath = outPath;
        _recognizedText = "녹음 중...\n$outPath";
        _pathText;
      });
    }
    else {
      // ===== STOP =====
      final path = await _recorder.stop();
      final startedAt = _recordingStartedAt;

      final durationMs = startedAt == null
          ? null
          : DateTime
          .now()
          .difference(startedAt)
          .inMilliseconds;

      if (path == null) {
        setState(() {
          _isListening = false;
          _recognizedText = "녹음 저장 경로를 찾을 수 없습니다 (path == null)";
        });
        return;
      }
      final file = File(path);
      final exists = await file.exists();
      final sizeBytes = exists ? await file.length() : 0;

      setState(() {
        _isListening = false;
        //here===========================
        _recognizedText = "여기에 녹음한 stt 넣으세요";
        //===============================
        _pathText = [
          "녹음 완료",
          "경로: $path",
          if (durationMs != null) "길이(ms): $durationMs",
          "파일 존재: $exists",
          "파일 크기(bytes): $sizeBytes",
          "샘플레이트: 16000Hz",
        ].join("\n");
      });
      debugPrint(
          "RECORD DONE path=$path durationMs=$durationMs size=$sizeBytes");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(),
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
    final text = _recognizedText.isEmpty ? "대기 중..." : _recognizedText;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey),
        borderRadius: BorderRadius.circular(8),
      ),
      child: SingleChildScrollView(
        child: Text(
          text,
          style: const TextStyle(fontSize: 16),
        ),
      ),
    );
  }

  Widget _translationPanel(BuildContext context) {
    final tr = context.watch<TranslationStore>();

    Widget block(String title, String text, bool needsConfirm) {
      return Expanded(
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            border: Border.all(),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Expanded(
                child: SingleChildScrollView(
                  child: Text(text.isEmpty ? '—' : text),
                ),
              ),
              if (needsConfirm) ...[
                const SizedBox(height: 8),
                const Text(
                  '확인 필요',
                  style: TextStyle(
                      color: Colors.red, fontWeight: FontWeight.bold),
                ),
              ],
            ],
          ),
        ),
      );
    }

    return Row(
      children: [
        block('EN', tr.enText, tr.enNeedsConfirm),
        const SizedBox(width: 12),
        block('中文', tr.zhText, tr.zhNeedsConfirm),
      ],
    );
  }
}
