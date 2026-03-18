import 'package:flutter_test/flutter_test.dart';
import 'package:subway/services/speech_service.dart';

void main() {
  test('站名匹配不会将短站名误判为长站名', () {
    final speechService = SpeechService();
    speechService.setKnownStations(['上海', '上海南站', '人民广场', '陆家嘴']);

    expect(speechService.matchesTargetText('下一站是上海南站', '上海'), isFalse);
    expect(speechService.matchesTargetText('下一站人民广场，请下车', '人民广场'), isTrue);
    expect(speechService.matchesTargetText('即将到达陆家嘴', '人民广场'), isFalse);
  });

  test('同音字模糊匹配应能正确触发', () {
    final speechService = SpeechService();
    speechService.setKnownStations(['彭埠', '水澄桥', '人民广场']);

    // 彭埠 -> 篷布
    expect(speechService.matchesTargetText('下一站篷布', '彭埠'), isTrue);
    // 水澄桥 -> 水城桥
    expect(speechService.matchesTargetText('即将到达水城桥', '水澄桥'), isTrue);
    // 普通匹配
    expect(speechService.matchesTargetText('下一站人民广场', '人民广场'), isTrue);
  });

  test('拼音匹配也应遵守长站名优先原则', () {
    final speechService = SpeechService();
    // 假设有 "上海" 和 "上海南站"
    // 语音识别为 "上海南站" (shanghainan...)
    // 目标是 "上海" (shanghai)
    // 拼音包含，但应该被拒绝，因为匹配了更长的 "上海南站"
    speechService.setKnownStations(['上海', '上海南站']);

    expect(speechService.matchesTargetText('上海南站', '上海'), isFalse);
    expect(speechService.matchesTargetText('下一站上海', '上海'), isTrue);
  });
}
