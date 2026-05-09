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
  String get goDownstairs =>
      'You are on the roof of a shaded structure. Please go downstairs to reach the shaded area below.';

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

  @override
  String get privacyPolicyTitle => 'HeatShield Privacy Policy';

  @override
  String get lastUpdated => 'Last Updated: May 2026';

  @override
  String get ppIntroTitle => '1. Introduction';

  @override
  String get ppIntroText =>
      'Welcome to HeatShield. This privacy policy explains how our app handles your personal information, specifically focusing on your location and health-related data used for calculating heat exposure.';

  @override
  String get ppDataTitle => '2. Data We Collect';

  @override
  String get ppDataText =>
      '• Location Data: We track your real-time location to determine whether you are in shaded or unshaded zones and to provide accurate local weather data.\n• Health & Environmental Metrics: We log your estimated sun exposure duration, safe exposure thresholds, and local temperatures.';

  @override
  String get ppUsageTitle => '3. How We Use Your Data';

  @override
  String get ppUsageText =>
      'Your data is primarily used locally on your device to calculate your risk of heat stress. If an emergency exposure incident occurs, we securely transmit an Emergency Report (including your location, time, and exposure duration) to our backend server so that safety personnel can assist you.';

  @override
  String get ppSharingTitle => '4. Data Sharing and Security';

  @override
  String get ppSharingText =>
      'We do not sell your personal data. The information sent to our servers is strictly used for emergency escalation and improving our predictive safety models. We use standard encryption to protect your data during transmission.';

  @override
  String get ppRightsTitle => '5. Your Rights';

  @override
  String get ppRightsText =>
      'You may disable location tracking at any time via your device settings, though this will limit HeatShield\'s ability to monitor your heat exposure accurately.';
}
