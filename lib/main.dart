import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'models/metro_data.dart';
import 'services/route_service.dart';
import 'services/speech_service.dart';
import 'screens/home_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final String response = await rootBundle.loadString('assets/metro_data.json');
  final data = await json.decode(response);
  final metroData = MetroData.fromJson(data);
  final routeService = RouteService(metroData);

  final speechService = SpeechService();
  speechService.setKnownStations(
    metroData.lines.expand((line) => line.stations),
  );
  await speechService.init();

  runApp(
    MultiProvider(
      providers: [
        Provider<MetroData>.value(value: metroData),
        Provider<RouteService>.value(value: routeService),
        ChangeNotifierProvider<SpeechService>.value(value: speechService),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '防过站',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: const HomePage(),
    );
  }
}
