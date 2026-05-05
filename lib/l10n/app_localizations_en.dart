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
  String get monitorTitle => 'HeatShield';

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

  @override
  String get nearestSafeZone => 'Nearest SafeZone';

  @override
  String get criticalHeatRisk => 'CRITICAL HEAT RISK';

  @override
  String get seekShadeImmediately =>
      'You have been in direct sunlight for too long. Seek shade immediately.';

  @override
  String get routingToShade => 'Routing to nearest shaded zone...';

  @override
  String get alreadyInShade => 'You are already in a safe shaded zone.';

  @override
  String get riskLevelLabel => 'Risk Level';

  @override
  String get emergencySos => 'Emergency SOS';

  @override
  String get callEmergency => 'CALL EMERGENCY SERVICES';

  @override
  String get navigateToShade => 'Navigate to Nearest Shade';

  @override
  String get emergencyEscalation => '⚠️ EMERGENCY ESCALATION';

  @override
  String get emergencyWorkerDispatched => 'Emergency worker dispatched in';

  @override
  String get ifNoActionTaken => 'if no action is taken';

  @override
  String get criticalRiskMessage =>
      'You have been in CRITICAL heat risk for over';

  @override
  String get totalExposureLabel => 'Total exposure:';

  @override
  String get iUnderstandDismiss => 'I understand — dismiss';

  @override
  String get heatStressZoneWarning =>
      'WARNING: You are entering a Heat Stress Zone!!';

  @override
  String get callingEmergency => '🚨 Calling Emergency Services...';

  @override
  String get emergencyWorkerOnWay =>
      '🚑 A nearby emergency worker has been notified and is on the way to your location.';

  @override
  String get areYouSureEmergency =>
      'Are you sure you want to call Emergency Services?';

  @override
  String get callNow => 'Call Now';

  @override
  String get criticalRiskForMinutes =>
      'minutes past your safe exposure limit without moving to a safer location.';

  @override
  String get lowRisk => 'Low Risk';

  @override
  String get moderateRisk => 'Moderate Risk';

  @override
  String get highRisk => 'High Risk';

  @override
  String get exposureHistory => 'Exposure History';

  @override
  String get clearHistoryTooltip => 'Clear History';

  @override
  String get clearHistoryTitle => 'Clear History?';

  @override
  String get clearHistoryContent =>
      'This will permanently delete all your exposure records.';

  @override
  String get cancel => 'Cancel';

  @override
  String get clear => 'Clear';

  @override
  String get noHistoryYet => 'No History Yet';

  @override
  String get noHistoryDesc =>
      'Your past heat exposure events will appear here once recorded.';

  @override
  String get overallSummary => 'Overall Summary';

  @override
  String get totalExposures => 'Total\nExposures';

  @override
  String get totalDuration => 'Total\nDuration';

  @override
  String get averageRisk => 'Average\nRisk';

  @override
  String get recentIncidents => 'Recent Incidents';

  @override
  String get nighttime => 'Nighttime';

  @override
  String get nearestWaterPoint => 'Nearest Water';

  @override
  String get routingToWater => 'Routing to nearest water point...';

  @override
  String get noWaterPointFound => 'No water point found nearby.';
}
