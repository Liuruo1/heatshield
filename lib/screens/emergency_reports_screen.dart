import 'package:flutter/material.dart';
import 'package:heatshield/models/em_report.dart';
import 'package:heatshield/services/backend_api_service.dart';
import 'package:intl/intl.dart';

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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Report #${report.id} marked as resolved')),
      );
      _fetchReports();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to resolve report: $e'), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Emergency Escalation Reports'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchReports,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('Error: $_error', style: const TextStyle(color: Colors.red)),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _fetchReports,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : _reports.isEmpty
                  ? const Center(child: Text('No emergency reports found.'))
                  : ListView.builder(
                      itemCount: _reports.length,
                      itemBuilder: (context, index) {
                        final report = _reports[index];
                        final dateFormat = DateFormat('MMM dd, yyyy - HH:mm:ss');
                        
                        return Card(
                          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          child: ListTile(
                            leading: Icon(
                              report.takenCare ? Icons.check_circle : Icons.warning_rounded,
                              color: report.takenCare ? Colors.green : Colors.red,
                              size: 32,
                            ),
                            title: Text('Emergency #${report.id}'),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const SizedBox(height: 4),
                                Text('User: ${report.userId ?? 'Unknown'}'),
                                Text('Time: ${dateFormat.format(report.createdAt.toLocal())}'),
                                Text('Location: ${report.locationLat.toStringAsFixed(5)}, ${report.locationLng.toStringAsFixed(5)}'),
                                if (report.incidentId != null)
                                  Text('Incident ID: ${report.incidentId}'),
                              ],
                            ),
                            isThreeLine: true,
                            trailing: !report.takenCare
                                ? IconButton(
                                    icon: const Icon(Icons.check_circle_outline),
                                    tooltip: 'Mark as Resolved',
                                    onPressed: () => _markAsResolved(report),
                                  )
                                : const Text(
                                    'Resolved',
                                    style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold),
                                  ),
                          ),
                        );
                      },
                    ),
    );
  }
}
