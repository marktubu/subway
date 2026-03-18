import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';

class WeatherService {
  Future<WeatherData?> fetchWeather(double lat, double lon) async {
    try {
      final url = Uri.parse(
        'https://api.open-meteo.com/v1/forecast?latitude=$lat&longitude=$lon&current_weather=true',
      );
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final current = data['current_weather'];
        return WeatherData(
          temperature: (current['temperature'] as num).toDouble(),
          weatherCode: current['weathercode'] as int,
        );
      }
    } catch (e) {
      debugPrint('Error fetching weather: $e');
    }
    return null;
  }

  IconData getWeatherIcon(int code) {
    if (code == 0) return Icons.wb_sunny;
    if (code <= 3) return Icons.wb_cloudy;
    if (code <= 48) return Icons.cloud;
    if (code <= 67) return Icons.grain; // Drizzle/Rain
    if (code <= 77) return Icons.ac_unit; // Snow
    if (code <= 82) return Icons.umbrella; // Showers
    if (code <= 86) return Icons.ac_unit; // Snow showers
    if (code <= 99) return Icons.flash_on; // Thunderstorm
    return Icons.question_mark;
  }

  String getWeatherDescription(int code) {
    switch (code) {
      case 0:
        return '晴';
      case 1:
        return '大部晴朗';
      case 2:
        return '多云';
      case 3:
        return '阴';
      case 45:
      case 48:
        return '雾';
      case 51:
      case 53:
      case 55:
        return '毛毛雨';
      case 56:
      case 57:
        return '冻毛毛雨';
      case 61:
        return '小雨';
      case 63:
        return '中雨';
      case 65:
        return '大雨';
      case 66:
      case 67:
        return '冻雨';
      case 71:
        return '小雪';
      case 73:
        return '中雪';
      case 75:
        return '大雪';
      case 77:
        return '米雪';
      case 80:
        return '阵雨';
      case 81:
        return '强阵雨';
      case 82:
        return '暴阵雨';
      case 85:
        return '阵雪';
      case 86:
        return '强阵雪';
      case 95:
        return '雷阵雨';
      case 96:
      case 99:
        return '雷阵雨伴有冰雹';
      default:
        return '未知';
    }
  }
}

class WeatherData {
  final double temperature;
  final int weatherCode;

  WeatherData({required this.temperature, required this.weatherCode});
}
