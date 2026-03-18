import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:subway/models/metro_data.dart';
import 'package:subway/screens/home_page.dart';
import 'package:subway/services/route_service.dart';
import 'package:subway/services/speech_service.dart';

void main() {
  testWidgets('首页可正常渲染模式标签', (WidgetTester tester) async {
    final metroData = MetroData(
      city: '上海',
      lines: [
        MetroLine(id: 'line_1', name: '1号线', stations: ['莘庄', '人民广场', '徐家汇']),
        MetroLine(id: 'line_2', name: '2号线', stations: ['人民广场', '陆家嘴']),
      ],
      transfers: [
        MetroTransfer(station: '人民广场', lines: ['line_1', 'line_2']),
      ],
    );
    final routeService = RouteService(metroData);
    final speechService = SpeechService();

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<MetroData>.value(value: metroData),
          Provider<RouteService>.value(value: routeService),
          ChangeNotifierProvider<SpeechService>.value(value: speechService),
        ],
        child: const MaterialApp(home: HomePage()),
      ),
    );

    expect(find.text('自动规划'), findsOneWidget);
    expect(find.text('手动多站点'), findsOneWidget);
    expect(find.text('开始乘车'), findsOneWidget);
  });
}
