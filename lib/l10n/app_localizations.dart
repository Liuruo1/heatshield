import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_ar.dart';
import 'app_localizations_en.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('ar'),
    Locale('en'),
  ];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'HeatShield'**
  String get appTitle;

  /// No description provided for @monitorTitle.
  ///
  /// In en, this message translates to:
  /// **'HeatShield'**
  String get monitorTitle;

  /// No description provided for @dashboard.
  ///
  /// In en, this message translates to:
  /// **'Dashboard'**
  String get dashboard;

  /// No description provided for @settings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

  /// No description provided for @history.
  ///
  /// In en, this message translates to:
  /// **'History'**
  String get history;

  /// No description provided for @statusDashboard.
  ///
  /// In en, this message translates to:
  /// **'Status Dashboard'**
  String get statusDashboard;

  /// No description provided for @currentTemp.
  ///
  /// In en, this message translates to:
  /// **'Current Temp'**
  String get currentTemp;

  /// No description provided for @sunExposure.
  ///
  /// In en, this message translates to:
  /// **'Sun Exposure'**
  String get sunExposure;

  /// No description provided for @riskLevel.
  ///
  /// In en, this message translates to:
  /// **'Risk Level'**
  String get riskLevel;

  /// No description provided for @shaded.
  ///
  /// In en, this message translates to:
  /// **'Shaded'**
  String get shaded;

  /// No description provided for @unshaded.
  ///
  /// In en, this message translates to:
  /// **'Unshaded'**
  String get unshaded;

  /// No description provided for @insideAlharam.
  ///
  /// In en, this message translates to:
  /// **'Inside Alharam'**
  String get insideAlharam;

  /// No description provided for @outsideAlharam.
  ///
  /// In en, this message translates to:
  /// **'Outside Alharam'**
  String get outsideAlharam;

  /// No description provided for @low.
  ///
  /// In en, this message translates to:
  /// **'LOW'**
  String get low;

  /// No description provided for @moderate.
  ///
  /// In en, this message translates to:
  /// **'MODERATE'**
  String get moderate;

  /// No description provided for @critical.
  ///
  /// In en, this message translates to:
  /// **'CRITICAL'**
  String get critical;

  /// No description provided for @notifications.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get notifications;

  /// No description provided for @pushNotifications.
  ///
  /// In en, this message translates to:
  /// **'Push Notifications'**
  String get pushNotifications;

  /// No description provided for @hapticFeedback.
  ///
  /// In en, this message translates to:
  /// **'Haptic Feedback'**
  String get hapticFeedback;

  /// No description provided for @receiveCriticalAlerts.
  ///
  /// In en, this message translates to:
  /// **'Receive critical heat alerts'**
  String get receiveCriticalAlerts;

  /// No description provided for @vibrateOnWrist.
  ///
  /// In en, this message translates to:
  /// **'Vibrate on wrist for nearby smartwatches'**
  String get vibrateOnWrist;

  /// No description provided for @application.
  ///
  /// In en, this message translates to:
  /// **'Application'**
  String get application;

  /// No description provided for @language.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// No description provided for @privacyPolicy.
  ///
  /// In en, this message translates to:
  /// **'Privacy Policy'**
  String get privacyPolicy;

  /// No description provided for @about.
  ///
  /// In en, this message translates to:
  /// **'About HeatShield'**
  String get about;

  /// No description provided for @nearestSafeZone.
  ///
  /// In en, this message translates to:
  /// **'Nearest SafeZone'**
  String get nearestSafeZone;

  /// No description provided for @criticalHeatRisk.
  ///
  /// In en, this message translates to:
  /// **'CRITICAL HEAT RISK'**
  String get criticalHeatRisk;

  /// No description provided for @seekShadeImmediately.
  ///
  /// In en, this message translates to:
  /// **'You have been in direct sunlight for too long. Seek shade immediately.'**
  String get seekShadeImmediately;

  /// No description provided for @routingToShade.
  ///
  /// In en, this message translates to:
  /// **'Routing to nearest shaded zone...'**
  String get routingToShade;

  /// No description provided for @alreadyInShade.
  ///
  /// In en, this message translates to:
  /// **'You are already in a safe shaded zone.'**
  String get alreadyInShade;

  /// No description provided for @riskLevelLabel.
  ///
  /// In en, this message translates to:
  /// **'Risk Level'**
  String get riskLevelLabel;

  /// No description provided for @emergencySos.
  ///
  /// In en, this message translates to:
  /// **'Emergency SOS'**
  String get emergencySos;

  /// No description provided for @callEmergency.
  ///
  /// In en, this message translates to:
  /// **'CALL EMERGENCY SERVICES'**
  String get callEmergency;

  /// No description provided for @navigateToShade.
  ///
  /// In en, this message translates to:
  /// **'Navigate to Nearest Shade'**
  String get navigateToShade;

  /// No description provided for @emergencyEscalation.
  ///
  /// In en, this message translates to:
  /// **'⚠️ EMERGENCY ESCALATION'**
  String get emergencyEscalation;

  /// No description provided for @emergencyWorkerDispatched.
  ///
  /// In en, this message translates to:
  /// **'Emergency worker dispatched in'**
  String get emergencyWorkerDispatched;

  /// No description provided for @ifNoActionTaken.
  ///
  /// In en, this message translates to:
  /// **'if no action is taken'**
  String get ifNoActionTaken;

  /// No description provided for @criticalRiskMessage.
  ///
  /// In en, this message translates to:
  /// **'You have been in CRITICAL heat risk for over'**
  String get criticalRiskMessage;

  /// No description provided for @totalExposureLabel.
  ///
  /// In en, this message translates to:
  /// **'Total exposure:'**
  String get totalExposureLabel;

  /// No description provided for @iUnderstandDismiss.
  ///
  /// In en, this message translates to:
  /// **'I understand — dismiss'**
  String get iUnderstandDismiss;

  /// No description provided for @heatStressZoneWarning.
  ///
  /// In en, this message translates to:
  /// **'WARNING: You are entering a Heat Stress Zone!!'**
  String get heatStressZoneWarning;

  /// No description provided for @callingEmergency.
  ///
  /// In en, this message translates to:
  /// **'🚨 Calling Emergency Services...'**
  String get callingEmergency;

  /// No description provided for @emergencyWorkerOnWay.
  ///
  /// In en, this message translates to:
  /// **'🚑 A nearby emergency worker has been notified and is on the way to your location.'**
  String get emergencyWorkerOnWay;

  /// No description provided for @areYouSureEmergency.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to call Emergency Services?'**
  String get areYouSureEmergency;

  /// No description provided for @callNow.
  ///
  /// In en, this message translates to:
  /// **'Call Now'**
  String get callNow;

  /// No description provided for @criticalRiskForMinutes.
  ///
  /// In en, this message translates to:
  /// **'minutes past your safe exposure limit without moving to a safer location.'**
  String get criticalRiskForMinutes;

  /// No description provided for @lowRisk.
  ///
  /// In en, this message translates to:
  /// **'Low Risk'**
  String get lowRisk;

  /// No description provided for @moderateRisk.
  ///
  /// In en, this message translates to:
  /// **'Moderate Risk'**
  String get moderateRisk;

  /// No description provided for @highRisk.
  ///
  /// In en, this message translates to:
  /// **'High Risk'**
  String get highRisk;

  /// No description provided for @exposureHistory.
  ///
  /// In en, this message translates to:
  /// **'Exposure History'**
  String get exposureHistory;

  /// No description provided for @clearHistoryTooltip.
  ///
  /// In en, this message translates to:
  /// **'Clear History'**
  String get clearHistoryTooltip;

  /// No description provided for @clearHistoryTitle.
  ///
  /// In en, this message translates to:
  /// **'Clear History?'**
  String get clearHistoryTitle;

  /// No description provided for @clearHistoryContent.
  ///
  /// In en, this message translates to:
  /// **'This will permanently delete all your exposure records.'**
  String get clearHistoryContent;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @clear.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get clear;

  /// No description provided for @noHistoryYet.
  ///
  /// In en, this message translates to:
  /// **'No History Yet'**
  String get noHistoryYet;

  /// No description provided for @noHistoryDesc.
  ///
  /// In en, this message translates to:
  /// **'Your past heat exposure events will appear here once recorded.'**
  String get noHistoryDesc;

  /// No description provided for @overallSummary.
  ///
  /// In en, this message translates to:
  /// **'Overall Summary'**
  String get overallSummary;

  /// No description provided for @totalExposures.
  ///
  /// In en, this message translates to:
  /// **'Total\nExposures'**
  String get totalExposures;

  /// No description provided for @totalDuration.
  ///
  /// In en, this message translates to:
  /// **'Total\nDuration'**
  String get totalDuration;

  /// No description provided for @averageRisk.
  ///
  /// In en, this message translates to:
  /// **'Average\nRisk'**
  String get averageRisk;

  /// No description provided for @recentIncidents.
  ///
  /// In en, this message translates to:
  /// **'Recent Incidents'**
  String get recentIncidents;

  /// No description provided for @nighttime.
  ///
  /// In en, this message translates to:
  /// **'Nighttime'**
  String get nighttime;

  /// No description provided for @nearestWaterPoint.
  ///
  /// In en, this message translates to:
  /// **'Nearest Water'**
  String get nearestWaterPoint;

  /// No description provided for @routingToWater.
  ///
  /// In en, this message translates to:
  /// **'Routing to nearest water point...'**
  String get routingToWater;

  /// No description provided for @noWaterPointFound.
  ///
  /// In en, this message translates to:
  /// **'No water point found nearby.'**
  String get noWaterPointFound;

  /// No description provided for @privacyPolicyTitle.
  ///
  /// In en, this message translates to:
  /// **'HeatShield Privacy Policy'**
  String get privacyPolicyTitle;

  /// No description provided for @lastUpdated.
  ///
  /// In en, this message translates to:
  /// **'Last Updated: May 2026'**
  String get lastUpdated;

  /// No description provided for @ppIntroTitle.
  ///
  /// In en, this message translates to:
  /// **'1. Introduction'**
  String get ppIntroTitle;

  /// No description provided for @ppIntroText.
  ///
  /// In en, this message translates to:
  /// **'Welcome to HeatShield. This privacy policy explains how our app handles your personal information, specifically focusing on your location and health-related data used for calculating heat exposure.'**
  String get ppIntroText;

  /// No description provided for @ppDataTitle.
  ///
  /// In en, this message translates to:
  /// **'2. Data We Collect'**
  String get ppDataTitle;

  /// No description provided for @ppDataText.
  ///
  /// In en, this message translates to:
  /// **'• Location Data: We track your real-time location to determine whether you are in shaded or unshaded zones and to provide accurate local weather data.\n• Health & Environmental Metrics: We log your estimated sun exposure duration, safe exposure thresholds, and local temperatures.'**
  String get ppDataText;

  /// No description provided for @ppUsageTitle.
  ///
  /// In en, this message translates to:
  /// **'3. How We Use Your Data'**
  String get ppUsageTitle;

  /// No description provided for @ppUsageText.
  ///
  /// In en, this message translates to:
  /// **'Your data is primarily used locally on your device to calculate your risk of heat stress. If an emergency exposure incident occurs, we securely transmit an Emergency Report (including your location, time, and exposure duration) to our backend server so that safety personnel can assist you.'**
  String get ppUsageText;

  /// No description provided for @ppSharingTitle.
  ///
  /// In en, this message translates to:
  /// **'4. Data Sharing and Security'**
  String get ppSharingTitle;

  /// No description provided for @ppSharingText.
  ///
  /// In en, this message translates to:
  /// **'We do not sell your personal data. The information sent to our servers is strictly used for emergency escalation and improving our predictive safety models. We use standard encryption to protect your data during transmission.'**
  String get ppSharingText;

  /// No description provided for @ppRightsTitle.
  ///
  /// In en, this message translates to:
  /// **'5. Your Rights'**
  String get ppRightsTitle;

  /// No description provided for @ppRightsText.
  ///
  /// In en, this message translates to:
  /// **'You may disable location tracking at any time via your device settings, though this will limit HeatShield\'s ability to monitor your heat exposure accurately.'**
  String get ppRightsText;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['ar', 'en'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'ar':
      return AppLocalizationsAr();
    case 'en':
      return AppLocalizationsEn();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
