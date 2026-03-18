import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:lpinyin/lpinyin.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';

class SpeechService extends ChangeNotifier {
  final SpeechToText _speechToText = SpeechToText();
  bool _isListening = false;
  String _lastRecognizedWords = '';
  Set<String> _knownStations = {};
  Map<String, String> _stationPinyinMap = {};
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
    
    // Precompute pinyins
    _stationPinyinMap = {};
    for (var s in _knownStations) {
      _stationPinyinMap[s] = PinyinHelper.getPinyin(s, separator: '', format: PinyinFormat.WITHOUT_TONE);
    }

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

    // 1. Text Exact Match
    final pattern = _stationPattern;
    if (pattern != null) {
      final matches = pattern.allMatches(normalizedText);
      for (final m in matches) {
        if (m.group(0) == normalizedTarget) {
          return true;
        }
      }
    } else {
       if (normalizedText.contains(normalizedTarget)) {
         return true;
       }
    }

    // 2. Pinyin Fuzzy Match
    // If text match failed, try pinyin match to handle homophones (e.g. 彭埠 vs 篷布)
    final textPinyin = PinyinHelper.getPinyin(normalizedText, separator: '', format: PinyinFormat.WITHOUT_TONE);
    // Use cached pinyin if available
    final targetPinyin = _stationPinyinMap[normalizedTarget] ?? 
        PinyinHelper.getPinyin(normalizedTarget, separator: '', format: PinyinFormat.WITHOUT_TONE);
    
    if (_fuzzyContains(textPinyin, targetPinyin, 1)) {
      // Conflict check: ensure we didn't match a longer station name's pinyin
      // e.g. target="上海" (shanghai), text="上海南站" (shanghainan...)
      // textPinyin contains "shanghai", but it also contains "shanghainan..."
      
      for (var otherStation in _knownStations) {
        if (otherStation == normalizedTarget) continue;
        
        final otherPinyin = _stationPinyinMap[otherStation] ?? 
            PinyinHelper.getPinyin(otherStation, separator: '', format: PinyinFormat.WITHOUT_TONE);
            
        // If otherStation starts with target (phonetically) AND text contains otherStation
        // Then we likely matched the longer station, so this is a false positive for the shorter one.
        if (otherPinyin.startsWith(targetPinyin) && _fuzzyContains(textPinyin, otherPinyin, 1)) {
          return false; 
        }
      }
      return true;
    }

    return false;
  }

  String _normalize(String value) {
    return value.replaceAll(RegExp(r'[\s，。、“”‘’；：！？,.!?]'), '');
  }

  bool _fuzzyContains(String text, String pattern, int tolerance) {
    if (pattern.isEmpty) return true;
    if (text.length < pattern.length - tolerance) return false;

    // Sliding window with tolerance length adjustment
    // We check substrings of text with length: pattern.length, pattern.length + 1, pattern.length - 1
    int pLen = pattern.length;
    for (int len = pLen - tolerance; len <= pLen + tolerance; len++) {
      if (len <= 0) continue;
      for (int i = 0; i <= text.length - len; i++) {
        String sub = text.substring(i, i + len);
        if (_levenshtein(sub, pattern) <= tolerance) {
          return true;
        }
      }
    }
    return false;
  }

  int _levenshtein(String s, String t) {
    if (s == t) return 0;
    if (s.isEmpty) return t.length;
    if (t.isEmpty) return s.length;

    List<int> v0 = List<int>.generate(t.length + 1, (i) => i);
    List<int> v1 = List<int>.filled(t.length + 1, 0);

    for (int i = 0; i < s.length; i++) {
      v1[0] = i + 1;
      for (int j = 0; j < t.length; j++) {
        int cost = (s.codeUnitAt(i) == t.codeUnitAt(j)) ? 0 : 1;
        v1[j + 1] = min(v1[j] + 1, min(v0[j + 1] + 1, v0[j] + cost));
      }
      for (int j = 0; j < v0.length; j++) {
        v0[j] = v1[j];
      }
    }
    return v1[t.length];
  }
}
