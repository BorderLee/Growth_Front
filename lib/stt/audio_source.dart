import 'dart:async';
import 'dart:typed_data';
import 'models.dart';


/// "PCM 프레임 스트림"만 여기로 연결하면 됨.
/// - sampleRateHz/encoding/channels는 서버/Google STT와 정확히 일치해야 함.
abstract class AudioSource {
  AudioConfig get config;

  ///PCM 프레임 스트림
  Stream<Uint8List> get pcmStream;

  Future<void> start();
  Future<void> stop();
}

///임시 stub class
class StubAudioSource implements AudioSource {
  @override
  AudioConfig get config =>
      const AudioConfig(encoding: 'LINEAR16', sampleRateHz: 16000, channels: 1);

  final _ctrl = StreamController<Uint8List>.broadcast();

  @override
  Stream<Uint8List> get pcmStream => _ctrl.stream;

  Timer? _t;

  @override
  Future<void> start() async {
    //더미 프레임
    _t = Timer.periodic(const Duration(milliseconds: 100), (_) {
      _ctrl.add(Uint8List(0)); //빈 프레임(테스트용)
    });
  }

  @override
  Future<void> stop() async {
    _t?.cancel();
    _t = null;
  }
}
