import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';

class SpeechService extends ChangeNotifier {
  final SpeechToText _speechToText = SpeechToText();
  bool _isListening = false;
  String _lastRecognizedWords = '';
  Set<String> _knownStations = {};
  RegExp? _stationPattern;

  bool get isListening => _isListening;
  String get lastRecognizedWords => _lastRecognizedWords;
  String? _targetStation;
  Function(String)? onTargetMatched;

  Future<void> init() async {
    await _speechToText.initialize(
      onStatus: (status) {
        if (status == 'done' && _isListening) {
          // Restart listening to keep it continuous
          _startListening();
        }
      },
      onError: (errorNotification) {
        if (_isListening) {
          // Restart on error as well (e.g. timeout)
          Future.delayed(const Duration(milliseconds: 500), () {
            if (_isListening) _startListening();
          });
        }
      },
    );
  }

  void startListeningFor(String station, Function(String) onMatched) {
    _speechToText.stop();
    _targetStation = station;
    onTargetMatched = onMatched;
    _isListening = true;
    _lastRecognizedWords = '';
    notifyListeners();
    _startListening();
  }

  void stopListening() {
    _isListening = false;
    _targetStation = null;
    _speechToText.stop();
    notifyListeners();
  }

  void _startListening() async {
    if (!_isListening) return;

    await _speechToText.listen(
      onResult: _onSpeechResult,
      localeId: 'zh_CN',
      listenOptions: SpeechListenOptions(
        cancelOnError: false,
        partialResults: true,
      ),
    );
  }

  void _onSpeechResult(SpeechRecognitionResult result) {
    _lastRecognizedWords = result.recognizedWords;
    notifyListeners();

    if (_targetStation != null && result.recognizedWords.isNotEmpty) {
      if (result.hasConfidenceRating &&
          result.confidence > 0.0 &&
          result.confidence < 0.5) {
        return;
      }

      if (matchesTargetText(result.recognizedWords, _targetStation!)) {
        var matchedStation = _targetStation!;
        _targetStation = null;
        if (onTargetMatched != null) {
          onTargetMatched!(matchedStation);
        }
      }
    }
  }

  void setKnownStations(Iterable<String> stations) {
    _knownStations = stations
        .map(_normalize)
        .where((e) => e.isNotEmpty)
        .toSet();
    if (_knownStations.isEmpty) {
      _stationPattern = null;
      return;
    }
    final sorted = _knownStations.toList()
      ..sort((a, b) => b.length.compareTo(a.length));
    final pattern = sorted.map(RegExp.escape).join('|');
    _stationPattern = RegExp(pattern);
  }

  bool matchesTargetText(String text, String target) {
    final normalizedText = _normalize(text);
    final normalizedTarget = _normalize(target);
    if (normalizedText.isEmpty || normalizedTarget.isEmpty) {
      return false;
    }

    final pattern = _stationPattern;
    if (pattern == null) {
      return RegExp(
            '(^|\\W)${RegExp.escape(normalizedTarget)}(\\W|\$)',
          ).hasMatch(normalizedText) ||
          normalizedText == normalizedTarget;
    }

    final matches = pattern.allMatches(normalizedText);
    for (final m in matches) {
      if (m.group(0) == normalizedTarget) {
        return true;
      }
    }
    return false;
  }

  String _normalize(String value) {
    return value.replaceAll(RegExp(r'[\s，。、“”‘’；：！？,.!?]'), '');
  }
}
