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
}
