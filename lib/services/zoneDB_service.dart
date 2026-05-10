// ignore_for_file: file_names

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';
import 'package:heatshield/services/backend_api_service.dart';

enum ZoneType { shaded, unshaded }

/// A data model representing a geographic polygon zone (either shaded or unshaded).
/// Includes properties for map rendering, identifying central points, and active time windows.
class ZonePolygon {
  static int globalDayStartMinute = 360;
  static int globalDayEndMinute = 1080;

  final int? id;
  final String name;
  final ZoneType type;
  final double fillAlpha;
  final double borderAlpha;
  final List<LatLng> points;
  final int? startMinuteOfDay;
  final int? endMinuteOfDay;
  final double buildingHeight;

  ZonePolygon({
    this.id,
    required this.name,
    required this.type,
    required this.points,
    this.fillAlpha = 0.3,
    this.borderAlpha = 0.8,
    this.startMinuteOfDay,
    this.endMinuteOfDay,
    this.buildingHeight = 15.0,
  });

  Polygon toPolygon() {
    final baseColor = type == ZoneType.shaded ? Colors.teal : Colors.redAccent;
    return Polygon(
      points: points,
      borderStrokeWidth: 2,
      borderColor: baseColor.withValues(alpha: borderAlpha),
      color: baseColor.withValues(alpha: fillAlpha),
    );
  }

  LatLng get centroid {
    if (points.isEmpty) {
      return const LatLng(0, 0);
    }
    final latAvg =
        points.map((p) => p.latitude).reduce((a, b) => a + b) / points.length;
    final lngAvg =
        points.map((p) => p.longitude).reduce((a, b) => a + b) / points.length;
    return LatLng(latAvg, lngAvg);
  }

  /// Determines if this zone is currently active based on its defined time window.
  /// Handles scenarios where the zone is active all day, or spans across midnight.
  bool isActiveAt(DateTime now) {
    final nowUtc = now.toUtc();
    final nowMinute = nowUtc.hour * 60 + nowUtc.minute;
    if (!isMinuteInWindow(
      nowMinute,
      globalDayStartMinute,
      globalDayEndMinute,
    )) {
      return false;
    }

    final start = startMinuteOfDay;
    final end = endMinuteOfDay;
    if (start == null || end == null) {
      return true;
    }
    return isMinuteInWindow(nowMinute, start, end);
  }

  static bool isMinuteInWindow(int minute, int start, int end) {
    if (start == end) {
      return true;
    }

    if (start < end) {
      return minute >= start && minute < end;
    }

    // Overnight window. Example: 22:00 -> 05:00
    return minute >= start || minute < end;
  }

  static void updateGlobalDayWindow({
    required int startMinuteOfDay,
    required int endMinuteOfDay,
  }) {
    globalDayStartMinute = startMinuteOfDay;
    globalDayEndMinute = endMinuteOfDay;
  }

  String get activeWindowLabel {
    final start = startMinuteOfDay;
    final end = endMinuteOfDay;
    if (start == null || end == null) {
      return 'All day';
    }
    return '${_minuteToHHmm(start)}-${_minuteToHHmm(end)}';
  }

  static String _minuteToHHmm(int value) {
    final hour = (value ~/ 60).toString().padLeft(2, '0');
    final minute = (value % 60).toString().padLeft(2, '0');
    return '$hour:$minute';
  }
}

/// A local database service using SQLite to persist custom and default heat zones.
/// Allows adding, deleting, and retrieving geographic polygon data.
class ZoneDbService {
  static const String _dbName = 'heatshield.db';
  static const int _dbVersion = 3;
  static const String _zonesTable = 'zones';
  static const String _pointsTable = 'zone_points';
  static final StreamController<void> _updatesController =
      StreamController<void>.broadcast();

  static Stream<void> get updates => _updatesController.stream;

  Database? _database;

  Future<Database> get database async {
    if (_database != null) {
      return _database!;
    }

    final dbPath = await getDatabasesPath();
    final path = p.join(dbPath, _dbName);
    _database = await openDatabase(
      path,
      version: _dbVersion,
      onCreate: (db, version) async {
        await _createSchema(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute(
            'ALTER TABLE $_zonesTable ADD COLUMN start_minute_of_day INTEGER',
          );
          await db.execute(
            'ALTER TABLE $_zonesTable ADD COLUMN end_minute_of_day INTEGER',
          );
        }
        if (oldVersion < 3) {
          await db.execute(
            'ALTER TABLE $_zonesTable ADD COLUMN building_height REAL NOT NULL DEFAULT 15.0',
          );
        }
      },
    );

    return _database!;
  }

  Future<void> _createSchema(Database db) async {
    await db.execute('''
        CREATE TABLE $_zonesTable (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          name TEXT NOT NULL,
          type TEXT NOT NULL,
          fill_alpha REAL NOT NULL DEFAULT 0.3,
          border_alpha REAL NOT NULL DEFAULT 0.8,
          start_minute_of_day INTEGER,
          end_minute_of_day INTEGER,
          building_height REAL NOT NULL DEFAULT 15.0
        )
      ''');

    await db.execute('''
        CREATE TABLE $_pointsTable (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          zone_id INTEGER NOT NULL,
          point_order INTEGER NOT NULL,
          lat REAL NOT NULL,
          lng REAL NOT NULL,
          FOREIGN KEY (zone_id) REFERENCES $_zonesTable(id) ON DELETE CASCADE
        )
      ''');
  }

  /// Checks if the database is empty on app startup, and if so,
  /// populates it with a set of default shaded and unshaded zones around the Holy Mosque.
  Future<void> ensureSeedData() async {
    final db = await database;
    final count =
        Sqflite.firstIntValue(
          await db.rawQuery('SELECT COUNT(*) FROM $_zonesTable'),
        ) ??
        0;

    if (count > 0) {
      return;
    }

    await replaceAllZones(_defaultZones);
  }

  Future<void> syncFromBackend() async {
    try {
      final backendZones = await BackendApiService.fetchZones();
      final zones = backendZones
          .where((zone) => zone.points.length >= 3)
          .map(
            (zone) => ZonePolygon(
              id: zone.id,
              name: zone.name,
              type: zone.type.toLowerCase() == ZoneType.shaded.name
                  ? ZoneType.shaded
                  : ZoneType.unshaded,
              fillAlpha: zone.fillAlpha,
              borderAlpha: zone.borderAlpha,
              startMinuteOfDay: zone.startMinuteOfDay,
              endMinuteOfDay: zone.endMinuteOfDay,
              buildingHeight: zone.buildingHeight,
              points: zone.points,
            ),
          )
          .toList(growable: false);

      if (zones.isNotEmpty) {
        await replaceAllZones(zones, emitUpdate: false);
      }
    } catch (e) {
      debugPrint('Backend zone sync skipped: $e');
    }
  }

  Future<List<ZonePolygon>> getZones() async {
    final db = await database;
    final zoneRows = await db.query(_zonesTable, orderBy: 'id ASC');
    final zones = <ZonePolygon>[];

    for (final zoneRow in zoneRows) {
      final zoneId = zoneRow['id'] as int;
      final pointRows = await db.query(
        _pointsTable,
        where: 'zone_id = ?',
        whereArgs: [zoneId],
        orderBy: 'point_order ASC',
      );

      final points = pointRows
          .map(
            (row) => LatLng(
              (row['lat'] as num).toDouble(),
              (row['lng'] as num).toDouble(),
            ),
          )
          .toList();

      if (points.length < 3) {
        continue;
      }

      zones.add(
        ZonePolygon(
          id: zoneId,
          name: zoneRow['name'] as String,
          type: _zoneTypeFromString(zoneRow['type'] as String),
          fillAlpha: (zoneRow['fill_alpha'] as num).toDouble(),
          borderAlpha: (zoneRow['border_alpha'] as num).toDouble(),
          startMinuteOfDay: zoneRow['start_minute_of_day'] as int?,
          endMinuteOfDay: zoneRow['end_minute_of_day'] as int?,
          buildingHeight: (zoneRow['building_height'] as num).toDouble(),
          points: points,
        ),
      );
    }

    return zones;
  }

  Future<List<LatLng>> getZoneCenters({required ZoneType type}) async {
    final zones = await getZones();
    return zones.where((z) => z.type == type).map((z) => z.centroid).toList();
  }

  Future<void> replaceAllZones(
    List<ZonePolygon> zones, {
    bool emitUpdate = true,
  }) async {
    final db = await database;

    await db.transaction((txn) async {
      await txn.delete(_pointsTable);
      await txn.delete(_zonesTable);

      for (final zone in zones) {
        final zoneId = await txn.insert(_zonesTable, {
          'name': zone.name,
          'type': zone.type.name,
          'fill_alpha': zone.fillAlpha,
          'border_alpha': zone.borderAlpha,
          'start_minute_of_day': zone.startMinuteOfDay,
          'end_minute_of_day': zone.endMinuteOfDay,
          'building_height': zone.buildingHeight,
        });

        for (int i = 0; i < zone.points.length; i++) {
          final point = zone.points[i];
          await txn.insert(_pointsTable, {
            'zone_id': zoneId,
            'point_order': i,
            'lat': point.latitude,
            'lng': point.longitude,
          });
        }
      }
    });

    if (emitUpdate) {
      _updatesController.add(null);
    }
  }

  Future<int> addZone(ZonePolygon zone) async {
    final db = await database;
    final id = await db.transaction((txn) async {
      final zoneId = await txn.insert(_zonesTable, {
        'name': zone.name,
        'type': zone.type.name,
        'fill_alpha': zone.fillAlpha,
        'border_alpha': zone.borderAlpha,
        'start_minute_of_day': zone.startMinuteOfDay,
        'end_minute_of_day': zone.endMinuteOfDay,
        'building_height': zone.buildingHeight,
      });

      for (int i = 0; i < zone.points.length; i++) {
        final point = zone.points[i];
        await txn.insert(_pointsTable, {
          'zone_id': zoneId,
          'point_order': i,
          'lat': point.latitude,
          'lng': point.longitude,
        });
      }

      return zoneId;
    });

    _updatesController.add(null);

    try {
      await BackendApiService.createZone(
        name: zone.name,
        type: zone.type.name,
        points: zone.points,
        fillAlpha: zone.fillAlpha,
        borderAlpha: zone.borderAlpha,
        startMinuteOfDay: zone.startMinuteOfDay,
        endMinuteOfDay: zone.endMinuteOfDay,
        buildingHeight: zone.buildingHeight,
      );
    } catch (e) {
      debugPrint('Backend zone create skipped: $e');
    }

    return id;
  }

  Future<void> deleteZone(int zoneId) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete(_pointsTable, where: 'zone_id = ?', whereArgs: [zoneId]);
      await txn.delete(_zonesTable, where: 'id = ?', whereArgs: [zoneId]);
    });
    _updatesController.add(null);

    try {
      await BackendApiService.deleteZone(zoneId);
    } catch (e) {
      debugPrint('Backend zone delete skipped: $e');
    }
  }

  ZoneType _zoneTypeFromString(String value) {
    return value.toLowerCase() == ZoneType.shaded.name
        ? ZoneType.shaded
        : ZoneType.unshaded;
  }

  List<ZonePolygon> get _defaultZones => [
    ZonePolygon(
      name: 'Shaded Zone 1',
      type: ZoneType.shaded,
      points: const [
        LatLng(21.4227, 39.8258),
        LatLng(21.4227, 39.8265),
        LatLng(21.4222, 39.8265),
        LatLng(21.4222, 39.8258),
      ],
    ),
    ZonePolygon(
      name: 'Shaded Zone 2',
      type: ZoneType.shaded,
      points: const [
        LatLng(21.42223, 39.82397),
        LatLng(21.42175, 39.82387),
        LatLng(21.42087, 39.82449),
        LatLng(21.42078, 39.82499),
        LatLng(21.42115, 39.82559),
        LatLng(21.42191, 39.82580),
        LatLng(21.42248, 39.82542),
        LatLng(21.42259, 39.82455),
      ],
    ),
    ZonePolygon(
      name: 'Unshaded Zone 1',
      type: ZoneType.unshaded,
      points: const [
        LatLng(21.4230, 39.8266),
        LatLng(21.4230, 39.8275),
        LatLng(21.4220, 39.8275),
        LatLng(21.4220, 39.8266),
      ],
    ),
    ZonePolygon(
      name: 'Unshaded Zone 2',
      type: ZoneType.unshaded,
      points: const [
        LatLng(21.42294, 39.82456),
        LatLng(21.42409, 39.82163),
        LatLng(21.42350, 39.82128),
        LatLng(21.42141, 39.82274),
      ],
    ),
  ];
}
