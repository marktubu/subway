import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/metro_data.dart';
import 'route_service.dart';
import 'speech_service.dart';

class AppState extends ChangeNotifier {
  final MetroCatalog metroCatalog;
  final SpeechService speechService;
  final SharedPreferences prefs;

  late String _selectedCity;
  late RouteService _routeService;

  AppState({
    required this.metroCatalog,
    required this.speechService,
    required this.prefs,
  }) {
    _selectedCity = prefs.getString('selectedCity') ?? metroCatalog.cities.first.city;
    // Fallback if saved city is invalid
    if (!metroCatalog.cities.any((e) => e.city == _selectedCity)) {
      _selectedCity = metroCatalog.cities.first.city;
    }
    _routeService = RouteService(currentMetroData);
    speechService.setKnownStations(
      currentMetroData.lines.expand((line) => line.stations),
    );
  }

  List<String> get cityNames => metroCatalog.cities.map((e) => e.city).toList();

  String get selectedCity => _selectedCity;

  MetroData get currentMetroData =>
      metroCatalog.cities.firstWhere((e) => e.city == _selectedCity);

  RouteService get routeService => _routeService;

  void selectCity(String city) {
    if (city == _selectedCity) {
      return;
    }
    _selectedCity = city;
    prefs.setString('selectedCity', city);
    _routeService = RouteService(currentMetroData);
    speechService.setKnownStations(
      currentMetroData.lines.expand((line) => line.stations),
    );
    notifyListeners();
  }
}
