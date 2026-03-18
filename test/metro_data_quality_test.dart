import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('地铁数据包含指定城市且站点规模充足', () {
    final file = File('assets/metro_data.json');
    final data = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
    final cities = (data['cities'] as List).cast<Map<String, dynamic>>();

    const requiredCities = [
      '上海',
      '杭州',
      '北京',
      '重庆',
      '广州',
      '深圳',
      '成都',
      '武汉',
      '西安',
      '南京',
      '苏州',
      '天津',
      '长沙',
      '福州',
      '厦门',
      '哈尔滨',
    ];

    final cityNames = cities.map((c) => c['city'] as String).toSet();
    expect(cityNames.containsAll(requiredCities), isTrue);
    expect(cityNames.length, requiredCities.length);

    for (final city in cities) {
      final lines = (city['lines'] as List).cast<Map<String, dynamic>>();
      final transfers = (city['transfers'] as List)
          .cast<Map<String, dynamic>>();
      final stations = <String>{};
      for (final line in lines) {
        for (final station in (line['stations'] as List).cast<String>()) {
          stations.add(station);
        }
      }
      expect(lines.length >= 2, isTrue);
      expect(stations.length >= 20, isTrue);
      expect(transfers.isNotEmpty, isTrue);
    }
  });
}
