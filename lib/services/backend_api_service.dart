import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

class EffectiveWeather {
  final double baseTempC;
  final double effectiveTempC;
  final double tempDeltaC;
  final String? zoneName;
  final String? zoneType;

  const EffectiveWeather({
    required this.baseTempC,
    required this.effectiveTempC,
    required this.tempDeltaC,
    this.zoneName,
    this.zoneType,
  });

  factory EffectiveWeather.fromJson(Map<String, dynamic> json) {
    return EffectiveWeather(
      baseTempC: (json['base_temp_c'] as num).toDouble(),
      effectiveTempC: (json['effective_temp_c'] as num).toDouble(),
      tempDeltaC: (json['temp_delta_c'] as num).toDouble(),
      zoneName: json['zone_name'] as String?,
      zoneType: json['zone_type'] as String?,
    );
  }
}

class ExposureThreshold {
  final int safeExposureSeconds;
  final double blendAlpha;
  final int sampleCount;

  const ExposureThreshold({
    required this.safeExposureSeconds,
    required this.blendAlpha,
    required this.sampleCount,
  });

  factory ExposureThreshold.fromJson(Map<String, dynamic> json) {
    return ExposureThreshold(
      safeExposureSeconds: json['safe_exposure_seconds'] as int,
      blendAlpha: (json['blend_alpha'] as num).toDouble(),
      sampleCount: json['sample_count'] as int,
    );
  }
}

class BackendZone {
  final int id;
  final String name;
  final String type;
  final double fillAlpha;
  final double borderAlpha;
  final int? startMinuteOfDay;
  final int? endMinuteOfDay;
  final double tempDeltaC;
  final List<LatLng> points;

  const BackendZone({
    required this.id,
    required this.name,
    required this.type,
    required this.fillAlpha,
    required this.borderAlpha,
    required this.startMinuteOfDay,
    required this.endMinuteOfDay,
    required this.tempDeltaC,
    required this.points,
  });

  factory BackendZone.fromJson(Map<String, dynamic> json) {
    final pointsJson = json['points'] as List<dynamic>;
    return BackendZone(
      id: json['id'] as int,
      name: json['name'] as String,
      type: json['type'] as String,
      fillAlpha: (json['fill_alpha'] as num).toDouble(),
      borderAlpha: (json['border_alpha'] as num).toDouble(),
      startMinuteOfDay: json['start_minute_of_day'] as int?,
      endMinuteOfDay: json['end_minute_of_day'] as int?,
      tempDeltaC: (json['temp_delta_c'] as num).toDouble(),
      points: pointsJson
          .map(
            (item) => LatLng(
              (item['lat'] as num).toDouble(),
              (item['lng'] as num).toDouble(),
            ),
          )
          .toList(),
    );
  }
}

class BackendApiService {
  BackendApiService._();

  static const String _baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://10.0.2.2:8000',
  );
  static const String _apiKey = String.fromEnvironment(
    'API_KEY',
    defaultValue: '',
  );

  static Map<String, String> get _headers {
    final headers = <String, String>{'Content-Type': 'application/json'};
    if (_apiKey.isNotEmpty) {
      headers['x-api-key'] = _apiKey;
    }
    return headers;
  }

  static Future<EffectiveWeather> fetchEffectiveWeather({
    required LatLng location,
  }) async {
    final uri = Uri.parse(
      '$_baseUrl/v1/weather/effective?lat=${location.latitude}&lng=${location.longitude}',
    );

    final response = await http
        .get(uri, headers: _headers)
        .timeout(const Duration(seconds: 10));
    if (response.statusCode != 200) {
      throw Exception('Failed to fetch effective weather: ${response.statusCode}');
    }

    final decoded = json.decode(response.body) as Map<String, dynamic>;
    return EffectiveWeather.fromJson(decoded);
  }

  static Future<ExposureThreshold> fetchExposureThreshold({
    required String userId,
    required double temp,
    required bool shaded,
  }) async {
    final uri = Uri.parse(
      '$_baseUrl/v1/exposure-threshold?user_id=$userId&temp=$temp&shaded=$shaded',
    );

    final response = await http
        .get(uri, headers: _headers)
        .timeout(const Duration(seconds: 10));
    if (response.statusCode != 200) {
      throw Exception('Failed to fetch threshold: ${response.statusCode}');
    }

    final decoded = json.decode(response.body) as Map<String, dynamic>;
    return ExposureThreshold.fromJson(decoded);
  }

  static Future<List<BackendZone>> fetchZones() async {
    final uri = Uri.parse('$_baseUrl/v1/zones');
    final response = await http
        .get(uri, headers: _headers)
        .timeout(const Duration(seconds: 10));

    if (response.statusCode != 200) {
      throw Exception('Failed to fetch zones: ${response.statusCode}');
    }

    final decoded = json.decode(response.body) as List<dynamic>;
    return decoded
        .map((item) => BackendZone.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  static Future<void> createZone({
    required String name,
    required String type,
    required List<LatLng> points,
    double fillAlpha = 0.3,
    double borderAlpha = 0.8,
    int? startMinuteOfDay,
    int? endMinuteOfDay,
    double tempDeltaC = 0.0,
  }) async {
    final uri = Uri.parse('$_baseUrl/v1/zones');
    final body = json.encode({
      'name': name,
      'type': type,
      'fill_alpha': fillAlpha,
      'border_alpha': borderAlpha,
      'start_minute_of_day': startMinuteOfDay,
      'end_minute_of_day': endMinuteOfDay,
      'temp_delta_c': tempDeltaC,
      'points': points
          .map((point) => {'lat': point.latitude, 'lng': point.longitude})
          .toList(),
    });

    final response = await http
        .post(uri, headers: _headers, body: body)
        .timeout(const Duration(seconds: 10));

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Failed to create zone: ${response.statusCode}');
    }
  }

  static Future<void> deleteZone(int zoneId) async {
    final uri = Uri.parse('$_baseUrl/v1/zones/$zoneId');
    final response = await http
        .delete(uri, headers: _headers)
        .timeout(const Duration(seconds: 10));

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Failed to delete zone: ${response.statusCode}');
    }
  }

  static Future<void> postIncident({
    required String userId,
    required int durationSeconds,
    required int? maxTemp,
    required double maxRiskRatio,
    required bool shaded,
  }) async {
    final uri = Uri.parse('$_baseUrl/v1/incidents');
    final body = json.encode({
      'user_id': userId,
      'duration_seconds': durationSeconds,
      'max_temp': maxTemp,
      'max_risk_ratio': maxRiskRatio,
      'shaded': shaded,
    });

    final response = await http
        .post(uri, headers: _headers, body: body)
        .timeout(const Duration(seconds: 10));

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Failed to post incident: ${response.statusCode}');
    }
  }
}
