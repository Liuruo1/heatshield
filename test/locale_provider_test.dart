import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:heatshield/services/locale_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('LocaleProvider should update from English to Arabic', () async {
    // Mocking SharedPreferences for the provider
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final provider = LocaleProvider(prefs);

    // Initial state should be English
    expect(provider.locale.languageCode, 'en');

    // Change to Arabic
    provider.setLocale(const Locale('ar')); // [cite: 57, 93]

    expect(provider.locale.languageCode, 'ar');
  });
}
