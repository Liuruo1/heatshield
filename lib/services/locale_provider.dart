import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LocaleProvider extends ChangeNotifier {
  Locale? _locale;

  Locale? get locale => _locale;

  LocaleProvider(SharedPreferences prefs) {
    String? languageCode = prefs.getString('languageCode');
    if (languageCode != null) {
      _locale = Locale(languageCode);
    }
  }

  Future<void> setLocale(Locale loc) async {
    if (!['en', 'ar'].contains(loc.languageCode)) return;

    _locale = loc;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('languageCode', loc.languageCode);
    notifyListeners();
  }

  void clearLocale() {
    _locale = null;
    notifyListeners();
  }
}
