import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'main_dashboard.dart';
import 'package:heatshield/services/history_service.dart';
import 'package:heatshield/services/server_connection_notifier.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();

  runApp(
    MultiProvider(
      providers: [ChangeNotifierProvider(create: (_) => HistoryService(prefs))],
      child: const HeatShieldApp(),
    ),
  );
}

class HeatShieldApp extends StatelessWidget {
  const HeatShieldApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'HeatShield',
      debugShowCheckedModeBanner: false,
      scaffoldMessengerKey: ServerConnectionNotifier.scaffoldMessengerKey,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
        fontFamily: 'Roboto', // Modern standard font
      ),
      home: const MainDashboard(),
    );
  }
}
