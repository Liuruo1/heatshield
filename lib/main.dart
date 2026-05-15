import 'package:flutter/material.dart';
import 'package:responsive_framework/responsive_framework.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'main_dashboard.dart';
import 'package:heatshield/services/history_service.dart';
import 'package:heatshield/l10n/app_localizations.dart';
import 'package:heatshield/services/locale_provider.dart';
import 'package:heatshield/services/server_connection_notifier.dart';
import 'package:heatshield/services/time_provider.dart';

/// App entry point — bootstraps services and launches the widget tree.
void main() async {
  // Required before any async work is done before runApp()
  WidgetsFlutterBinding.ensureInitialized();

  // Load persistent local storage once; passed into services that need it
  final prefs = await SharedPreferences.getInstance();

  runApp(
    // MultiProvider makes all global services available anywhere in the widget tree
    MultiProvider(
      providers: [
        // Manages the user's heat exposure history log (reads/writes to SharedPreferences)
        ChangeNotifierProvider(create: (_) => HistoryService(prefs)),

        // Manages the active app language (EN / AR), persisted across restarts
        ChangeNotifierProvider(create: (_) => LocaleProvider(prefs)),

        // Provides the current time — can be overridden with a mock time for testing
        ChangeNotifierProvider(create: (_) => TimeProvider()),
      ],

      child: const HeatShieldApp(),
    ),
  );
}

/// The root widget of the app.
/// Configures the MaterialApp with theme, localization, responsive layout,
/// and sets [MainDashboard] as the first screen.
class HeatShieldApp extends StatelessWidget {
  const HeatShieldApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'HeatShield',
      debugShowCheckedModeBanner: false, // Hide the debug ribbon in the top corner

      // Read the active locale from LocaleProvider (EN or AR)
      // Rebuilds whenever the user changes the language in Settings
      locale: Provider.of<LocaleProvider>(context).locale,

      // Enables Flutter's built-in localization system
      localizationsDelegates: AppLocalizations.localizationsDelegates,

      // Declares which languages the app supports
      supportedLocales: AppLocalizations.supportedLocales,

      // A global key that lets ServerConnectionNotifier show snackbars
      // from anywhere in the app without needing a BuildContext
      scaffoldMessengerKey: ServerConnectionNotifier.scaffoldMessengerKey,

      // App-wide theme: teal color palette + Roboto font
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
        fontFamily: 'Roboto',
      ),

      // Wraps the entire app in responsive layout logic
      builder: (context, child) => ResponsiveBreakpoints.builder(
        child: Builder(
          builder: (context) {
            return MaxWidthBox(
              // Cap the maximum layout width at 1200px (useful on large screens/web)
              maxWidth: 1200,
              child: ResponsiveScaledBox(
                // Scale the UI to a fixed design width per breakpoint,
                // so the layout looks consistent across all device sizes
                width: ResponsiveValue<double?>(
                  context,
                  defaultValue: null, // No scaling by default
                  conditionalValues: [
                    Condition.equals(name: MOBILE, value: 390.0),           // Phone: scale to 390px
                    Condition.between(start: 800, end: 1100, value: 800.0), // Small desktop
                    Condition.between(start: 1000, end: 1200, value: 1000.0), // Large desktop
                  ],
                ).value,
                child: child!,
              ),
            );
          },
        ),
        // Define the screen size breakpoints used throughout the app
        breakpoints: [
          const Breakpoint(start: 0, end: 450, name: MOBILE),       // Phone
          const Breakpoint(start: 451, end: 800, name: TABLET),     // Tablet
          const Breakpoint(start: 801, end: 1920, name: DESKTOP),   // Desktop / Web
          const Breakpoint(start: 1921, end: double.infinity, name: '4K'), // 4K screens
        ],
      ),

      // The first screen shown when the app launches
      home: const MainDashboard(),
    );
  }
}
