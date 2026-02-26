import 'package:flutter/foundation.dart';

class TranslationStore extends ChangeNotifier {
  String enText = '';
  String zhText = '';
  bool enNeedsConfirm = false;
  bool zhNeedsConfirm = false;

  void apply({
    required String target,
    required String text,
    required bool needsConfirm,
  }) {
    final t = text.trim();
    if (t.isEmpty) return;

    if (target == 'en') {
      enText = t;
      enNeedsConfirm = needsConfirm;
    } else if (target == 'zh') {
      zhText = t;
      zhNeedsConfirm = needsConfirm;
    }
    notifyListeners();
  }

  void reset() {
    enText = '';
    zhText = '';
    enNeedsConfirm = false;
    zhNeedsConfirm = false;
    notifyListeners();
  }
}