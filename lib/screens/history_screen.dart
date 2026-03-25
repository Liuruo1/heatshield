import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:heatshield/services/history_service.dart';

/// Screen that displays the user's past heat exposure incidents.
/// It reads from [HistoryService] and shows overall summaries and a scrollable list of events.
class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  /// Formats an integer amount of seconds into a readable string (e.g., "15m 30s").
  String _formatDuration(int seconds) {
    if (seconds == 0) return '0s';
    final m = seconds ~/ 60;
    final s = seconds % 60;
    if (m > 0) return '${m}m ${s}s';
    return '${s}s';
  }

  /// Formats a [DateTime] object into a readable date and time string.
  String _formatDate(DateTime date) {
    // Simple formatting: MM/DD/YYYY HH:MM
    return '${date.month.toString().padLeft(2, '0')}/${date.day.toString().padLeft(2, '0')}/${date.year} '
        '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  Color _getRiskColor(double ratio) {
    if (ratio < 0.33) return Colors.green;
    if (ratio < 0.66) return Colors.amber.shade700;
    return Colors.red;
  }

  String _getRiskText(double ratio) {
    if (ratio < 0.33) return 'Low Risk';
    if (ratio < 0.66) return 'Moderate Risk';
    return 'High Risk';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Exposure History'),
        backgroundColor: Colors.teal.shade700,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_sweep),
            tooltip: 'Clear History',
            onPressed: () {
              showDialog(
                context: context,
                builder: (BuildContext context) {
                  return AlertDialog(
                    title: const Text('Clear History?'),
                    content: const Text('This will permanently delete all your exposure records.'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Cancel'),
                      ),
                      ElevatedButton(
                        onPressed: () {
                          Provider.of<HistoryService>(context, listen: false).clearHistory();
                          Navigator.pop(context);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          foregroundColor: Colors.white,
                        ),
                        child: const Text('Clear'),
                      ),
                    ],
                  );
                },
              );
            },
          )
        ],
      ),
      body: Consumer<HistoryService>(
        builder: (context, historyService, child) {
          final incidents = historyService.incidents;

          if (incidents.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.history_outlined,
                    size: 100,
                    color: Colors.grey.shade400,
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'No History Yet',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).textTheme.bodyLarge?.color,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Your past heat exposure events will appear here once recorded.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 16,
                      color: Theme.of(context).textTheme.bodyMedium?.color?.withValues(alpha: 0.7) ??
                          Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            );
          }

          return CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Overall Summary',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: _buildSummaryCard(
                              context,
                              title: 'Total\nExposures',
                              value: historyService.totalExposures.toString(),
                              icon: Icons.timer_outlined,
                              color: Colors.blue,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildSummaryCard(
                              context,
                              title: 'Total\nDuration',
                              value: _formatDuration(historyService.totalDurationSeconds),
                              icon: Icons.hourglass_bottom,
                              color: Colors.orange,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildSummaryCard(
                              context,
                              title: 'Average\nRisk',
                              value: _getRiskText(historyService.averageRiskRatio).replaceAll(' Risk', ''),
                              icon: Icons.monitor_heart,
                              color: _getRiskColor(historyService.averageRiskRatio),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      const Text(
                        'Recent Incidents',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              ),
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final incident = incidents[index];
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 6.0),
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black12,
                              blurRadius: 8,
                              offset: const Offset(0, 4),
                            ),
                          ],
                          border: Border.all(
                            color: _getRiskColor(incident.maxRiskRatio).withValues(alpha: 0.3),
                            width: 1,
                          ),
                        ),
                        child: ListTile(
                          contentPadding: const EdgeInsets.all(16),
                          leading: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: _getRiskColor(incident.maxRiskRatio).withValues(alpha: 0.1),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.wb_sunny_rounded,
                              color: _getRiskColor(incident.maxRiskRatio),
                            ),
                          ),
                          title: Text(
                            _formatDate(incident.date),
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                          subtitle: Padding(
                            padding: const EdgeInsets.only(top: 8.0),
                            child: Row(
                              children: [
                                _buildBadge(
                                  icon: Icons.timer,
                                  text: _formatDuration(incident.durationSeconds),
                                  color: Colors.blueGrey,
                                ),
                                const SizedBox(width: 12),
                                if (incident.maxTemp != null)
                                  _buildBadge(
                                    icon: Icons.thermostat,
                                    text: '${incident.maxTemp}°C',
                                    color: Colors.orange.shade700,
                                  ),
                              ],
                            ),
                          ),
                          trailing: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                _getRiskText(incident.maxRiskRatio),
                                style: TextStyle(
                                  color: _getRiskColor(incident.maxRiskRatio),
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                  childCount: incidents.length,
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 32)),
            ],
          );
        },
      ),
    );
  }

  /// Builds a small rectangular card used in the top summary row
  /// (shows total exposures, duration, or average risk).
  Widget _buildSummaryCard(
    BuildContext context, {
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 12),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).textTheme.bodyLarge?.color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              color: Theme.of(context).textTheme.bodyMedium?.color?.withValues(alpha: 0.8),
            ),
          ),
        ],
      ),
    );
  }

  /// Builds a pill-shaped badge with an icon and text, used to display quick
  /// stats (like duration or max temp) inside an incident list tile.
  Widget _buildBadge({required IconData icon, required String text, required Color color}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 4),
        Text(text, style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.w500)),
      ],
    );
  }
}
