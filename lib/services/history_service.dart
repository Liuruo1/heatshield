import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ExposureIncident {
  final String id;
  final DateTime date;
  final int durationSeconds;
  final int? maxTemp;
  final double maxRiskRatio;

  ExposureIncident({
    required this.id,
    required this.date,
    required this.durationSeconds,
    this.maxTemp,
    required this.maxRiskRatio,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'date': date.toIso8601String(),
      'durationSeconds': durationSeconds,
      'maxTemp': maxTemp,
      'maxRiskRatio': maxRiskRatio,
    };
  }

  factory ExposureIncident.fromJson(Map<String, dynamic> json) {
    return ExposureIncident(
      id: json['id'],
      date: DateTime.parse(json['date']),
      durationSeconds: json['durationSeconds'],
      maxTemp: json['maxTemp'],
      maxRiskRatio: json['maxRiskRatio']?.toDouble() ?? 0.0,
    );
  }
}

class HistoryService extends ChangeNotifier {
  static const String _storageKey = 'heatshield_history';
  final SharedPreferences _prefs;
  List<ExposureIncident> _incidents = [];

  HistoryService(this._prefs) {
    _loadHistory();
  }

  List<ExposureIncident> get incidents => List.unmodifiable(_incidents);

  int get totalExposures => _incidents.length;

  int get totalDurationSeconds {
    return _incidents.fold(0, (sum, incident) => sum + incident.durationSeconds);
  }

  double get averageRiskRatio {
    if (_incidents.isEmpty) return 0.0;
    final totalRisk = _incidents.fold(0.0, (sum, incident) => sum + incident.maxRiskRatio);
    return totalRisk / _incidents.length;
  }

  void _loadHistory() {
    final String? data = _prefs.getString(_storageKey);
    if (data != null) {
      try {
        final List<dynamic> decoded = json.decode(data);
        _incidents = decoded.map((item) => ExposureIncident.fromJson(item)).toList();
        // Sort newest first
        _incidents.sort((a, b) => b.date.compareTo(a.date));
        notifyListeners();
      } catch (e) {
        debugPrint('Error loading history: $e');
      }
    }
  }

  Future<void> _saveHistory() async {
    try {
      final String encoded = json.encode(_incidents.map((e) => e.toJson()).toList());
      await _prefs.setString(_storageKey, encoded);
    } catch (e) {
      debugPrint('Error saving history: $e');
    }
  }

  Future<void> logIncident({
    required int durationSeconds,
    required int? maxTemp,
    required double maxRiskRatio,
  }) async {
    final newIncident = ExposureIncident(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      date: DateTime.now(),
      durationSeconds: durationSeconds,
      maxTemp: maxTemp,
      maxRiskRatio: maxRiskRatio,
    );

    _incidents.insert(0, newIncident); // add to top
    notifyListeners();
    await _saveHistory();
  }

  Future<void> clearHistory() async {
    _incidents.clear();
    notifyListeners();
    await _prefs.remove(_storageKey);
  }
}
