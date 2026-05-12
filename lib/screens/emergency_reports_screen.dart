import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:heatshield/models/em_report.dart';
import 'package:heatshield/services/backend_api_service.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';

// ─────────────────────────────────────────────────────────────────────────────
// List screen
// ─────────────────────────────────────────────────────────────────────────────
class EmergencyReportsScreen extends StatefulWidget {
  const EmergencyReportsScreen({super.key});

  @override
  State<EmergencyReportsScreen> createState() => _EmergencyReportsScreenState();
}

class _EmergencyReportsScreenState extends State<EmergencyReportsScreen> {
  List<EMReport> _reports = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchReports();
  }

  Future<void> _fetchReports() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final reports = await BackendApiService.getAllEMReports();
      setState(() {
        _reports = reports;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _markAsResolved(EMReport report) async {
    try {
      await BackendApiService.completeEMReport(report.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Report #${report.id} marked as resolved'),
          backgroundColor: Colors.green.shade700,
        ),
      );
      _fetchReports();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to resolve report: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _openDetail(EMReport report) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _ReportDetailScreen(
          report: report,
          onMarkResolved: () => _markAsResolved(report),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 1,
        shadowColor: Colors.black12,
        title: const Row(
          children: [
            Icon(Icons.crisis_alert, color: Colors.redAccent, size: 22),
            SizedBox(width: 10),
            Text(
              'Emergency Escalation Reports',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh',
            onPressed: _fetchReports,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Colors.redAccent),
            )
          : _error != null
              ? _buildError()
              : _reports.isEmpty
                  ? _buildEmpty()
                  : _buildList(),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.wifi_off_rounded, color: Colors.redAccent, size: 56),
            const SizedBox(height: 16),
            Text(
              'Could not load reports',
              style: TextStyle(color: Colors.black54, fontSize: 16),
            ),
            const SizedBox(height: 8),
            Text(
              _error!,
              style: const TextStyle(color: Colors.red, fontSize: 12),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _fetchReports,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Retry'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmpty() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.check_circle_outline, color: Colors.green, size: 64),
          SizedBox(height: 16),
          Text(
            'No emergency reports',
            style: TextStyle(color: Colors.black87, fontSize: 18),
          ),
          SizedBox(height: 6),
          Text(
            'All clear — no escalations have been triggered.',
            style: TextStyle(color: Colors.black45, fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _buildList() {
    // Sort: unresolved first, then by time descending
    final sorted = [..._reports]
      ..sort((a, b) {
        if (a.takenCare != b.takenCare) return a.takenCare ? 1 : -1;
        return b.createdAt.compareTo(a.createdAt);
      });

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      itemCount: sorted.length,
      itemBuilder: (context, index) => _ReportCard(
        report: sorted[index],
        onTap: () => _openDetail(sorted[index]),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Compact list card
// ─────────────────────────────────────────────────────────────────────────────
class _ReportCard extends StatelessWidget {
  final EMReport report;
  final VoidCallback onTap;

  const _ReportCard({required this.report, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('MMM dd, yyyy  •  HH:mm');
    final isResolved = report.takenCare;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isResolved
                ? Colors.green.withValues(alpha: 0.4)
                : Colors.redAccent.withValues(alpha: 0.4),
            width: 1.4,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.07),
              blurRadius: 14,
              spreadRadius: 1,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── header bar ─────────────────────────────────────────────────
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: isResolved
                    ? Colors.green.withValues(alpha: 0.12)
                    : Colors.redAccent.withValues(alpha: 0.12),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(17)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      color: isResolved
                          ? Colors.green.withValues(alpha: 0.2)
                          : Colors.redAccent.withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      isResolved ? Icons.check_circle_rounded : Icons.crisis_alert,
                      color: isResolved ? Colors.greenAccent : Colors.redAccent,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Emergency #${report.id}',
                          style: const TextStyle(
                            color: Colors.black87,
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                        Text(
                          isResolved ? 'RESOLVED' : 'ACTIVE',
                          style: TextStyle(
                            color: isResolved ? Colors.green.shade700 : Colors.redAccent,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // "tap to view" hint
                  Column(
                    children: [
                      Icon(Icons.map_outlined, color: Colors.black38, size: 18),
                      const SizedBox(height: 2),
                      Text(
                        'View',
                        style: TextStyle(color: Colors.black38, fontSize: 10),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            // ── body ───────────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _InfoRow(
                          icon: Icons.person_outline_rounded,
                          label: 'User',
                          value: report.userId?.toString() ?? 'Unknown',
                        ),
                        const SizedBox(height: 6),
                        _InfoRow(
                          icon: Icons.access_time_rounded,
                          label: 'Time',
                          value: dateFormat.format(report.createdAt.toLocal()),
                        ),
                        const SizedBox(height: 6),
                        _InfoRow(
                          icon: Icons.location_on_rounded,
                          label: 'Location',
                          value:
                              '${report.locationLat.toStringAsFixed(5)}, ${report.locationLng.toStringAsFixed(5)}',
                          valueColor: Colors.lightBlueAccent,
                        ),
                      ],
                    ),
                  ),
                  // mini map thumbnail
                  _MiniMapThumbnail(
                    lat: report.locationLat,
                    lng: report.locationLng,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Tiny interactive-preview map on the card
// ─────────────────────────────────────────────────────────────────────────────
class _MiniMapThumbnail extends StatelessWidget {
  final double lat;
  final double lng;

  const _MiniMapThumbnail({required this.lat, required this.lng});

  @override
  Widget build(BuildContext context) {
    final point = LatLng(lat, lng);
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        width: 90,
        height: 90,
        child: Stack(
          children: [
            FlutterMap(
              options: MapOptions(
                initialCenter: point,
                initialZoom: 16,
                interactionOptions: const InteractionOptions(
                  flags: InteractiveFlag.none, // non-interactive in card
                ),
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.example.heatshield',
                ),
                MarkerLayer(
                  markers: [
                    Marker(
                      point: point,
                      width: 28,
                      height: 28,
                      child: const Icon(
                        Icons.location_pin,
                        color: Colors.redAccent,
                        size: 28,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            // subtle border overlay
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.black.withValues(alpha: 0.1), width: 1),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Detail screen (full map + info)
// ─────────────────────────────────────────────────────────────────────────────
class _ReportDetailScreen extends StatelessWidget {
  final EMReport report;
  final VoidCallback onMarkResolved;

  const _ReportDetailScreen({
    required this.report,
    required this.onMarkResolved,
  });

  @override
  Widget build(BuildContext context) {
    final point = LatLng(report.locationLat, report.locationLng);
    final dateFormat = DateFormat('EEEE, MMMM dd, yyyy');
    final timeFormat = DateFormat('HH:mm:ss');
    final localTime = report.createdAt.toLocal();
    final isResolved = report.takenCare;

    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FA),
      body: CustomScrollView(
        slivers: [
          // ── App bar with embedded map ────────────────────────────────────
          SliverAppBar(
            expandedHeight: 320,
            pinned: true,
            backgroundColor: Colors.white,
            foregroundColor: Colors.black87,
            title: Text(
              'Emergency #${report.id}',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.black87),
            ),
            flexibleSpace: FlexibleSpaceBar(
              background: _FullMap(point: point, isResolved: isResolved),
            ),
          ),

          // ── Status badge ─────────────────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 7,
                    ),
                    decoration: BoxDecoration(
                      color: isResolved
                          ? Colors.green.withValues(alpha: 0.12)
                          : Colors.red.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(30),
                      border: Border.all(
                        color: isResolved ? Colors.green.shade600 : Colors.redAccent,
                        width: 1.2,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          isResolved
                              ? Icons.check_circle_rounded
                              : Icons.crisis_alert,
                          color: isResolved ? Colors.green.shade700 : Colors.redAccent,
                          size: 16,
                        ),
                        const SizedBox(width: 7),
                        Text(
                          isResolved ? 'RESOLVED' : 'ACTIVE — NEEDS ATTENTION',
                          style: TextStyle(
                            color: isResolved ? Colors.green.shade700 : Colors.redAccent,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                            letterSpacing: 1.1,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── Report details card ──────────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.black.withValues(alpha: 0.06)),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 8, offset: Offset(0, 2)),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _SectionHeader(
                      icon: Icons.info_outline_rounded,
                      title: 'Report Information',
                    ),
                    _DetailRow(
                      icon: Icons.tag,
                      label: 'Report ID',
                      value: '#${report.id}',
                      valueColor: Colors.black87,
                      bold: true,
                    ),
                    _divider(),
                    _DetailRow(
                      icon: Icons.person_rounded,
                      label: 'User ID',
                      value: report.userId?.toString() ?? 'Unknown',
                    ),
                    _divider(),
                    _DetailRow(
                      icon: Icons.calendar_today_rounded,
                      label: 'Date',
                      value: dateFormat.format(localTime),
                    ),
                    _divider(),
                    _DetailRow(
                      icon: Icons.access_time_rounded,
                      label: 'Time',
                      value: timeFormat.format(localTime),
                    ),
                    _divider(),
                    _DetailRow(
                      icon: Icons.link_rounded,
                      label: 'Incident ID',
                      value: '#${report.incidentId}',
                      valueColor: Colors.orange.shade700,
                    ),
                  ],
                ),
              ),
            ),
          ),

          // ── Location card ────────────────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.black.withValues(alpha: 0.06)),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 8, offset: Offset(0, 2)),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _SectionHeader(
                      icon: Icons.location_on_rounded,
                      title: 'Incident Location',
                      iconColor: Colors.blue.shade700,
                    ),
                    _DetailRow(
                      icon: Icons.south_rounded,
                      label: 'Latitude',
                      value: report.locationLat.toStringAsFixed(6),
                      valueColor: Colors.blue.shade700,
                    ),
                    _divider(),
                    _DetailRow(
                      icon: Icons.east_rounded,
                      label: 'Longitude',
                      value: report.locationLng.toStringAsFixed(6),
                      valueColor: Colors.blue.shade700,
                    ),
                    _divider(),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 14),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.blue.withValues(alpha: 0.07),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Colors.blue.withValues(alpha: 0.25),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.open_in_new_rounded,
                              color: Colors.blue.shade600,
                              size: 16,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Coordinates: ${report.locationLat.toStringAsFixed(5)}, ${report.locationLng.toStringAsFixed(5)}',
                              style: TextStyle(
                                color: Colors.blue.shade700,
                                fontSize: 12,
                                fontFamily: 'monospace',
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // ── Action button ────────────────────────────────────────────────
          if (!isResolved)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                child: SizedBox(
                  height: 54,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.of(context).pop();
                      onMarkResolved();
                    },
                    icon: const Icon(Icons.check_circle_rounded, size: 22),
                    label: const Text(
                      'Mark as Resolved',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green.shade600,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 4,
                    ),
                  ),
                ),
              ),
            ),

          const SliverToBoxAdapter(child: SizedBox(height: 40)),
        ],
      ),
    );
  }

  Widget _divider() => const Divider(
        color: Color(0xFFEEEEEE),
        height: 1,
        indent: 16,
        endIndent: 16,
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// Full-screen interactive map used in detail header
// ─────────────────────────────────────────────────────────────────────────────
class _FullMap extends StatelessWidget {
  final LatLng point;
  final bool isResolved;

  const _FullMap({required this.point, required this.isResolved});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        FlutterMap(
          options: MapOptions(
            initialCenter: point,
            initialZoom: 17,
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.example.heatshield',
            ),
            // Pulsing circle around the incident point
            CircleLayer(
              circles: [
                CircleMarker(
                  point: point,
                  radius: 22,
                  color: (isResolved ? Colors.green : Colors.red)
                      .withValues(alpha: 0.25),
                  borderColor: isResolved ? Colors.greenAccent : Colors.redAccent,
                  borderStrokeWidth: 2.5,
                  useRadiusInMeter: false,
                ),
              ],
            ),
            MarkerLayer(
              markers: [
                Marker(
                  point: point,
                  width: 48,
                  height: 56,
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: isResolved ? Colors.green : Colors.redAccent,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: (isResolved ? Colors.green : Colors.red)
                                  .withValues(alpha: 0.6),
                              blurRadius: 12,
                              spreadRadius: 3,
                            ),
                          ],
                        ),
                        child: Icon(
                          isResolved
                              ? Icons.check_rounded
                              : Icons.person_pin_circle_rounded,
                          color: Colors.white,
                          size: 22,
                        ),
                      ),
                      // little triangle pointer
                      CustomPaint(
                        size: const Size(12, 6),
                        painter: _TrianglePainter(
                          color: isResolved ? Colors.green : Colors.redAccent,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
        // gradient at bottom so the app bar title is legible
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          height: 70,
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.transparent,
                  Colors.white.withValues(alpha: 0.7),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Helpers
// ─────────────────────────────────────────────────────────────────────────────
class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String title;
  final Color iconColor;

  const _SectionHeader({
    required this.icon,
    required this.title,
    this.iconColor = Colors.black54,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
      child: Row(
        children: [
          Icon(icon, color: iconColor, size: 18),
          const SizedBox(width: 8),
          Text(
            title,
            style: TextStyle(
              color: iconColor,
              fontWeight: FontWeight.w700,
              fontSize: 13,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color valueColor;
  final bool bold;

  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
    this.valueColor = Colors.black87,
    this.bold = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Icon(icon, color: Colors.black38, size: 18),
          const SizedBox(width: 12),
          SizedBox(
            width: 90,
            child: Text(
              label,
              style: const TextStyle(color: Colors.black45, fontSize: 13),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                color: valueColor,
                fontSize: 13,
                fontWeight: bold ? FontWeight.bold : FontWeight.normal,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color valueColor;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
    this.valueColor = Colors.black87,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: Colors.black38, size: 14),
        const SizedBox(width: 5),
        Text('$label: ', style: const TextStyle(color: Colors.black45, fontSize: 12)),
        Expanded(
          child: Text(
            value,
            style: TextStyle(color: valueColor, fontSize: 12),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

// Downward-pointing triangle for the marker
class _TrianglePainter extends CustomPainter {
  final Color color;
  const _TrianglePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    final path = ui.Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width / 2, size.height)
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_TrianglePainter old) => old.color != color;
}
