import 'dart:async';
import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'models.dart';

enum WsConnState { disconnected, connecting, connected, reconnecting }

class WsTransport {
  final Uri uri;
  WebSocketChannel? _ch;
  StreamSubscription? _sub;

  final _stateCtrl = StreamController<WsConnState>.broadcast();
  final _eventCtrl = StreamController<WsEvent>.broadcast();

  WsConnState _state = WsConnState.disconnected;
  WsConnState get state => _state;

  Stream<WsConnState> get stateStream => _stateCtrl.stream;
  Stream<WsEvent> get eventStream => _eventCtrl.stream;

  WsTransport({required this.uri});

  Future<void> connect({bool reconnecting = false}) async {
    _setState(reconnecting ? WsConnState.reconnecting : WsConnState.connecting);

    try {
      _ch = WebSocketChannel.connect(uri);
      _setState(WsConnState.connected);

      _sub = _ch!.stream.listen(
            (data) {
          final s = data is String ? data : utf8.decode(data as List<int>);
          final ev = WsEvent.tryParse(s);
          if (ev != null) _eventCtrl.add(ev);
        },
        onError: (_) => _handleClosed(),
        onDone: () => _handleClosed(),
        cancelOnError: true,
      );
    } catch (_) {
      _handleClosed();
      rethrow;
    }
  }

  void sendJson(Map<String, dynamic> msg) {
    final ch = _ch;
    if (ch == null) return;
    if (_state != WsConnState.connected) return;
    ch.sink.add(json.encode(msg));
  }

  void _handleClosed() {
    _setState(WsConnState.disconnected);
    _sub?.cancel();
    _sub = null;
    _ch = null;
  }

  Future<void> close() async {
    _handleClosed();
    await _stateCtrl.close();
    await _eventCtrl.close();
  }

  void _setState(WsConnState s) {
    _state = s;
    _stateCtrl.add(s);
  }
}
