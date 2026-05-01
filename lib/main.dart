import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'main_dashboard.dart';
import 'package:heatshield/services/history_service.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:heatshield/l10n/app_localizations.dart';
import 'package:heatshield/services/locale_provider.dart';
import 'package:heatshield/services/server_connection_notifier.dart';
import 'package:heatshield/services/time_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => HistoryService(prefs)),
        ChangeNotifierProvider(create: (_) => LocaleProvider(prefs)),
        ChangeNotifierProvider(create: (_) => TimeProvider()),
      ],

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
      locale: Provider.of<LocaleProvider>(context).locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      scaffoldMessengerKey: ServerConnectionNotifier.scaffoldMessengerKey,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
        fontFamily: 'Roboto', // Modern standard font
      ),
      home: const MainDashboard(),
    );
  }
}
