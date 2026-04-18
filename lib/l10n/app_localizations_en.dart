// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'HeatShield';

  @override
  String get monitorTitle => 'HeatShield Monitor';

  @override
  String get dashboard => 'Dashboard';

  @override
  String get settings => 'Settings';

  @override
  String get history => 'History';

  @override
  String get statusDashboard => 'Status Dashboard';

  @override
  String get currentTemp => 'Current Temp';

  @override
  String get sunExposure => 'Sun Exposure';

  @override
  String get riskLevel => 'Risk Level';

  @override
  String get shaded => 'Shaded';

  @override
  String get unshaded => 'Unshaded';

  @override
  String get insideAlharam => 'Inside Alharam';

  @override
  String get outsideAlharam => 'Outside Alharam';

  @override
  String get low => 'LOW';

  @override
  String get moderate => 'MODERATE';

  @override
  String get critical => 'CRITICAL';

  @override
  String get notifications => 'Notifications';

  @override
  String get pushNotifications => 'Push Notifications';

  @override
  String get hapticFeedback => 'Haptic Feedback';

  @override
  String get receiveCriticalAlerts => 'Receive critical heat alerts';

  @override
  String get vibrateOnWrist => 'Vibrate on wrist for nearby smartwatches';

  @override
  String get application => 'Application';

  @override
  String get language => 'Language';

  @override
  String get privacyPolicy => 'Privacy Policy';

  @override
  String get about => 'About HeatShield';
}
