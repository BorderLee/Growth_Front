import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'models.dart';
import 'ws_transport.dart';
import 'audio_source.dart';

enum SessionState { idle, starting, streaming, ending }

class StreamSessionController {
  final WsTransport ws;
  final AudioSource audio;
  final String sessionId;

  SessionState _state = SessionState.idle;
  SessionState get state => _state;

  int _seq = 0;
  StreamSubscription<Uint8List>? _audioSub;

  StreamSessionController({
    required this.ws,
    required this.audio,
    required this.sessionId,
  });

  Future<void> start() async {
    if (_state != SessionState.idle) return;
    _state = SessionState.starting;

    // 1) WS connect (초기 연결)
    await ws.connect(reconnecting: false);

    // 2) session.start
    ws.sendJson({
      'type': 'session.start',
      'sessionId': sessionId,
      'audio': audio.config.toJson(),
      'lang': {
        'stt': 'ko-KR',
        // M1에서는 번역 UI까지 꼭 안 붙여도 되지만,
        // 서버가 무시해도 되게 스키마만 유지 가능.
        'translateTargets': ['en', 'zh'],
      },
    });

    // 3) audio start + stream subscribe
    await audio.start();
    _audioSub = audio.pcmStream.listen((frame) {
      _sendAudioFrame(frame);
    });

    _state = SessionState.streaming;

    // 4) WS 끊김 감지 → 자동 재연결
    ws.stateStream.listen((s) {
      if (_state != SessionState.streaming) return;
      if (s == WsConnState.disconnected) {
        _reconnectLoop();
      }
    });
  }

  void _sendAudioFrame(Uint8List bytes) {
    if (ws.state != WsConnState.connected) return;
    // base64 JSON
    final b64 = base64.encode(bytes);
    ws.sendJson({
      'type': 'audio',
      'sessionId': sessionId,
      'seq': _seq++,
      'audioB64': b64,
      'bytes': bytes.length,
    });
  }

  Future<void> _reconnectLoop() async {
    // M1: "재연결 중..." 표시만 요구 → transport state로 UI에 전달됨
    // 실무적으로 backoff
    final delays = [500, 1000, 2000, 3000];
    for (final ms in delays) {
      if (_state != SessionState.streaming) return;
      try {
        await Future<void>.delayed(Duration(milliseconds: ms));
        await ws.connect(reconnecting: true);

        // M1에서는 resume 메시지 필수 요구사항 아님.
        // 서버가 세션 유지한다는 전제라, 동일 sessionId로 이어서 audio 보내면 됨.
        // (서버가 resume 필요하면 여기에서 type: session.resume 추가)
        ws.sendJson({
          'type': 'session.resume',
          'sessionId': sessionId,
          'lastAckSeq': _seq - 1,
        });
        return;
      } catch (_) {
        // 계속 시도
      }
    }
  }

  Future<void> end() async {
    if (_state != SessionState.streaming) return;
    _state = SessionState.ending;

    await _audioSub?.cancel();
    _audioSub = null;
    await audio.stop();

    if (ws.state == WsConnState.connected) {
      ws.sendJson({'type': 'session.end', 'sessionId': sessionId});
    }
    // close는 앱 정책에 따라 (세션 끝나면 닫는게 보통)
    // await ws.close();

    _state = SessionState.idle;
  }
}
