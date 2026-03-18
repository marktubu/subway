import 'package:flutter/foundation.dart';
import '../models/metro_data.dart';
import 'route_service.dart';
import 'speech_service.dart';

class AppState extends ChangeNotifier {
  final MetroCatalog metroCatalog;
  final SpeechService speechService;

  late String _selectedCity;
  late RouteService _routeService;

  AppState({required this.metroCatalog, required this.speechService}) {
    _selectedCity = metroCatalog.cities.first.city;
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
    _routeService = RouteService(currentMetroData);
    speechService.setKnownStations(
      currentMetroData.lines.expand((line) => line.stations),
    );
    notifyListeners();
  }
}
