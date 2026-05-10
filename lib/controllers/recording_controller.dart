import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:record/record.dart';

import 'package:medexplain/api/app_config.dart';
import 'package:medexplain/stt/models.dart';
import 'package:medexplain/stt/transcript_store.dart';
import 'package:medexplain/stt/ws_transport.dart';

class RecordingController extends ChangeNotifier {
  final AudioRecorder _recorder = AudioRecorder();
  WsTransport? _ws;
  final TranscriptStore transcriptStore = TranscriptStore();

  StreamSubscription<WsConnState>? _wsStateSub;
  StreamSubscription<WsEvent>? _wsEventSub;
  StreamSubscription<Uint8List>? _audioSub;
  final List<Uint8List> _audioChunks = [];

  WsConnState connState = WsConnState.disconnected;
  bool isListening = false;
  bool analyzing = false;

  bool get hasResult =>
      !isListening &&
      (transcriptStore.combinedText.trim().isNotEmpty ||
          transcriptStore.hasWarning);

  RecordingController() {
    transcriptStore.addListener(notifyListeners);
  }

  Future<void> init() => _initWs();

  Future<bool> checkPermission() => _recorder.hasPermission();

  Future<void> toggleListening() async {
    if (isListening) {
      await _stopListening();
    } else {
      await _startListening();
    }
  }

  void reset() {
    transcriptStore.reset();
    analyzing = false;
    notifyListeners();
  }

  Future<void> reinitWs() => _initWs();

  // ── private ────────────────────────────────────────────────────────────────

  Future<void> _initWs() async {
    await _wsStateSub?.cancel();
    await _wsEventSub?.cancel();
    await _ws?.close();

    try {
      final uri = await getWsUri();
      debugPrint('[WS] URI: $uri');
      _ws = WsTransport(uri: uri);

      _wsStateSub = _ws!.stateStream.listen((s) {
        connState = s;
        notifyListeners();
        if (s == WsConnState.connected) _sendSessionStart();
      });

      _wsEventSub = _ws!.eventStream.listen((e) {
        final stt = SttEvent.fromWs(e);
        if (stt != null) {
          transcriptStore.apply(stt);
          if (transcriptStore.combinedText.trim().isNotEmpty) {
            analyzing = false;
            notifyListeners();
          }
          return;
        }

        final warning = WarningEvent.fromWs(e);
        if (warning != null) {
          transcriptStore.applyWarning(warning);
          analyzing = false;
          notifyListeners();
          return;
        }

        debugPrint('[WS] unhandled event: ${e.type}');
      });

      await _ws!.connect();
    } catch (e) {
      debugPrint('[WS] init error: $e');
    }
  }

  void _sendSessionStart() {
    _ws?.sendJson({
      'type': 'session.start',
      'sessionId': 'test-session',
      'audio': {
        'encoding': 'LINEAR16',
        'sampleRateHz': 16000,
        'channels': 1,
      },
    });
  }

  Future<void> _startListening() async {
    final stream = await _recorder.startStream(
      const RecordConfig(
        encoder: AudioEncoder.pcm16bits,
        sampleRate: 16000,
        numChannels: 1,
      ),
    );

    _audioChunks.clear();
    _audioSub = stream.listen((chunk) => _audioChunks.add(chunk));
    transcriptStore.reset();
    isListening = true;
    notifyListeners();
  }

  Future<void> _stopListening() async {
    await _recorder.stop();
    await _audioSub?.cancel();
    _audioSub = null;

    final bytes = Uint8List.fromList(_audioChunks.expand((x) => x).toList());
    _audioChunks.clear();

    if (bytes.isNotEmpty) {
      _ws?.sendJson({
        'type': 'audio',
        'sessionId': 'test-session',
        'seq': DateTime.now().millisecondsSinceEpoch,
        'bytes': bytes.length,
        'audioB64': base64Encode(bytes),
      });
      debugPrint('AUDIO SENT bytes=${bytes.length}');
    }

    isListening = false;
    analyzing = bytes.isNotEmpty;
    notifyListeners();
  }

  @override
  void dispose() {
    transcriptStore.removeListener(notifyListeners);
    transcriptStore.dispose();
    _wsStateSub?.cancel();
    _wsEventSub?.cancel();
    _audioSub?.cancel();
    _ws?.close();
    _recorder.dispose();
    super.dispose();
  }
}
