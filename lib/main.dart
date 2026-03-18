import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'models/metro_data.dart';
import 'services/app_state.dart';
import 'services/speech_service.dart';
import 'screens/home_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final prefs = await SharedPreferences.getInstance();

  final String response = await rootBundle.loadString('assets/metro_data.json');
  final data = await json.decode(response);
  final metroCatalog = MetroCatalog.fromJson(data);

  final speechService = SpeechService();
  final appState = AppState(
    metroCatalog: metroCatalog,
    speechService: speechService,
    prefs: prefs,
  );
  await speechService.init();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<SpeechService>.value(value: speechService),
        ChangeNotifierProvider<AppState>.value(value: appState),
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
