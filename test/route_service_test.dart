import 'package:flutter_test/flutter_test.dart';
import 'package:subway/models/metro_data.dart';
import 'package:subway/models/stop_task.dart';
import 'package:subway/services/route_service.dart';

void main() {
  final metroData = MetroData(
    city: '上海',
    lines: [
      MetroLine(id: 'line_1', name: '1号线', stations: ['莘庄', '人民广场', '徐家汇']),
      MetroLine(id: 'line_2', name: '2号线', stations: ['人民广场', '陆家嘴', '张江高科']),
    ],
    transfers: [
      MetroTransfer(station: '人民广场', lines: ['line_1', 'line_2']),
    ],
  );

  test('自动规划可生成换乘与终点任务', () {
    final service = RouteService(metroData);
    final tasks = service.planRoute('莘庄', '张江高科');
    expect(tasks, isNotNull);
    expect(tasks!.length, 2);
    expect(tasks.first.action, ActionType.transfer);
    expect(tasks.first.name, '人民广场');
    expect(tasks.last.action, ActionType.exit);
    expect(tasks.last.name, '张江高科');
  });

  test('手动多站点可拼接分段路径', () {
    final service = RouteService(metroData);
    final tasks = service.planMultiRoute(['莘庄', '陆家嘴', '张江高科']);
    expect(tasks, isNotNull);
    expect(tasks!.last.action, ActionType.exit);
    expect(tasks.last.name, '张江高科');
  });
}
