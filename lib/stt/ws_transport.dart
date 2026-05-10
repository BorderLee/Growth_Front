import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'models.dart';

enum WsConnState { disconnected, connecting, connected, reconnecting }

class WsTransport {
  final Uri uri;
  WebSocketChannel? _ch;
  StreamSubscription? _sub;
  Timer? _retryTimer;
  int _retryCount = 0;
  bool _closed = false;

  final _stateCtrl = StreamController<WsConnState>.broadcast();
  final _eventCtrl = StreamController<WsEvent>.broadcast();

  WsConnState _state = WsConnState.disconnected;
  WsConnState get state => _state;

  Stream<WsConnState> get stateStream => _stateCtrl.stream;
  Stream<WsEvent> get eventStream => _eventCtrl.stream;

  WsTransport({required this.uri});

  Future<void> connect({bool reconnecting = false}) async {
    if (_closed) return;
    debugPrint('[WS] connecting to: $uri');
    _setState(reconnecting ? WsConnState.reconnecting : WsConnState.connecting);

    try {
      _ch = WebSocketChannel.connect(uri);
      _retryCount = 0;
      _setState(WsConnState.connected);

      _sub = _ch!.stream.listen(
        (data) {
          final s = data is String ? data : utf8.decode(data as List<int>);
          final ev = WsEvent.tryParse(s);
          if (ev != null) _eventCtrl.add(ev);
        },
        onError: (_) => _onDisconnected(),
        onDone: () => _onDisconnected(),
        cancelOnError: true,
      );
    } catch (ex) {
      debugPrint('[WS] connect failed: $ex');
      _onDisconnected();
    }
  }

  void sendJson(Map<String, dynamic> msg) {
    if (_state != WsConnState.connected) return;
    _ch?.sink.add(json.encode(msg));
  }

  void _onDisconnected() {
    _sub?.cancel();
    _sub = null;
    _ch = null;
    _setState(WsConnState.disconnected);
    if (!_closed) _scheduleReconnect();
  }

  void _scheduleReconnect() {
    final delaySecs = math.min(2 << _retryCount, 30); // 2→4→8→16→30s
    _retryCount++;
    _retryTimer?.cancel();
    _retryTimer = Timer(
      Duration(seconds: delaySecs),
      () => connect(reconnecting: true),
    );
    debugPrint('[WS] retry in ${delaySecs}s (attempt $_retryCount)');
  }

  Future<void> close() async {
    _closed = true;
    _retryTimer?.cancel();
    _retryTimer = null;
    _sub?.cancel();
    _sub = null;
    _ch = null;
    await _stateCtrl.close();
    await _eventCtrl.close();
  }

  void _setState(WsConnState s) {
    _state = s;
    if (!_stateCtrl.isClosed) _stateCtrl.add(s);
  }
}
