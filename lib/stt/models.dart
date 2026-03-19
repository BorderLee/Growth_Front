import 'dart:convert';

class AudioConfig {
  final String encoding; // e.g., LINEAR16
  final int sampleRateHz; // e.g., 16000
  final int channels; // e.g., 1
  const AudioConfig({
    required this.encoding,
    required this.sampleRateHz,
    required this.channels,
  });

  Map<String, dynamic> toJson() => {
    'encoding': encoding,
    'sampleRateHz': sampleRateHz,
    'channels': channels,
  };
}

class WsEvent {
  final String type;
  final Map<String, dynamic> raw;
  WsEvent(this.type, this.raw);

  static WsEvent? tryParse(String jsonStr) {
    try {
      final m = json.decode(jsonStr);
      if (m is! Map<String, dynamic>) return null;
      final type = (m['type'] ?? '').toString();
      if (type.isEmpty) return null;
      return WsEvent(type, m);
    } catch (_) {
      return null;
    }
  }
}

class SttEvent {
  final bool isFinal;
  final String text;
  SttEvent({required this.isFinal, required this.text});

  static SttEvent? fromWs(WsEvent e) {
    if (e.type != 'stt') return null;
    final isFinal = e.raw['isFinal'] == true;
    final text = (e.raw['text'] ?? '').toString();
    return SttEvent(isFinal: isFinal, text: text);
  }
}

class TranslateEvent {
  final String target; // en | zh
  final String text;
  final bool needsConfirm;

  TranslateEvent({
    required this.target,
    required this.text,
    required this.needsConfirm,
  });

  static SttEvent? fromWs(WsEvent e) {
    if (e.type != 'stt') return null;
    
    final dynamic rawFinal = e.raw['isFinal'] ?? e.raw['final'];
    final bool isFinal =
      rawFinal == true || rawFinal?.toString().toLowerCase() == 'true';
      
    final text = (e.raw['text'] ?? '').toString().trim();

    if (text.isEmpty) return null;

    return SttEvent(isFinal: isFinal, text: text);
  }
}