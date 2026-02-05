import 'package:flutter/foundation.dart';
import 'models.dart';

class TranscriptStore extends ChangeNotifier {
  final List<String> _finalSegments = [];
  String _interim = '';

  List<String> get finalSegments => List.unmodifiable(_finalSegments);
  String get interim => _interim;

  String get combinedText {
    final base = _finalSegments.join(' ');
    if (_interim.isEmpty) return base;
    if (base.isEmpty) return _interim;
    return '$base $_interim';
  }

  void apply(SttEvent e) {
    final t = e.text.trim();
    if (t.isEmpty) return;

    if (e.isFinal) {
      _finalSegments.add(t);
      _interim = '';
    } else {
      _interim = t;
    }
    notifyListeners();
  }

  void reset() {
    _finalSegments.clear();
    _interim = '';
    notifyListeners();
  }
}