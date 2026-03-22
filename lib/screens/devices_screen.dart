import 'package:flutter/material.dart';

class DevicesScreen extends StatefulWidget {
  const DevicesScreen({super.key});

  @override
  State<DevicesScreen> createState() => _DevicesScreenState();
}

class _DevicesScreenState extends State<DevicesScreen> {
  // --- State Variables ---
  /// Tracks if the Bluetooth search animation and delay are active
  bool _isScanning = false;

  /// Simulated list of paired/available Bluetooth devices for the UI demo
  final List<Map<String, dynamic>> _devices = [
    {
      'name': 'Samsung Galaxy Watch',
      'id': 'AA:BB:CC:11:22:33',
      'isConnected': true,
      'battery': 85,
    },
    {
      'name': 'Garmin Fenix 7',
      'id': '11:22:33:AA:BB:CC',
      'isConnected': false,
      'battery': null,
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Smart Device Management'),
        backgroundColor: Colors.teal.shade700,
        foregroundColor: Colors.white,
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildRationaleCard(),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text(
              'My Devices',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            child: ListView.separated(
              itemCount: _devices.length,
              separatorBuilder: (context, index) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final device = _devices[index];
                return _buildDeviceTile(device);
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          setState(() {
            _isScanning = true;
          });
          Future.delayed(const Duration(seconds: 2), () {
            if (mounted) {
              setState(() {
                _isScanning = false;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('No new devices found.')),
                );
              });
            }
          });
        },
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
        icon: _isScanning
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2,
                ),
              )
            : const Icon(Icons.bluetooth_searching),
        label: Text(_isScanning ? 'Scanning...' : 'Scan for Devices'),
      ),
    );
  }

  /// Builds an informational UI card explaining the benefits of connecting a wearable
  /// device for heat stroke prevention (e.g. haptic feedback in noisy environments).
  Widget _buildRationaleCard() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? Colors.blueGrey.shade900 : Colors.blue.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? Colors.blueGrey.shade800 : Colors.blue.shade100,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.watch,
            color: isDark ? Colors.blue.shade300 : Colors.blue.shade700,
            size: 32,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Why connect a wearable?',
                  style: TextStyle(
                    color: isDark ? Colors.blue.shade100 : Colors.blue.shade900,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Connecting a smartwatch ensures you receive prompt, haptic (vibration) alerts even in noisy and crowded environments like the Holy Mosque area. This is critical for real-time heat stroke prevention.',
                  style: TextStyle(
                    color: isDark ? Colors.blue.shade200 : Colors.blue.shade800,
                    fontSize: 14,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Builds a list tile representing a single Bluetooth device.
  /// Displays connection status, battery level, and a button to toggle connection.
  Widget _buildDeviceTile(Map<String, dynamic> device) {
    final bool isConnected = device['isConnected'];
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      leading: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isConnected
              ? (isDark
                    ? Colors.teal.withValues(alpha: 0.2)
                    : Colors.teal.shade50)
              : (isDark ? Colors.grey.shade800 : Colors.grey.shade100),
          shape: BoxShape.circle,
        ),
        child: Icon(
          Icons.watch_outlined,
          color: isConnected
              ? (isDark ? Colors.tealAccent : Colors.teal)
              : (isDark ? Colors.grey.shade400 : Colors.grey.shade500),
        ),
      ),
      title: Text(
        device['name'],
        style: TextStyle(
          fontWeight: FontWeight.bold,
          color: isConnected
              ? Theme.of(context).textTheme.bodyLarge?.color
              : (isDark ? Colors.grey.shade500 : Colors.black54),
        ),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 4),
          Text(
            device['id'],
            style: TextStyle(
              fontSize: 12,
              color: isDark ? Colors.grey.shade400 : Colors.grey.shade700,
            ),
          ),
          if (isConnected && device['battery'] != null) ...[
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(
                  Icons.battery_4_bar,
                  size: 14,
                  color: isDark ? Colors.green.shade400 : Colors.green.shade600,
                ),
                const SizedBox(width: 4),
                Text(
                  '${device['battery']}%',
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? Colors.grey.shade400 : Colors.grey.shade700,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
      trailing: ElevatedButton(
        onPressed: () {
          setState(() {
            device['isConnected'] = !isConnected;
          });
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: isConnected
              ? (isDark ? Colors.grey.shade800 : Colors.grey.shade200)
              : (isDark ? Colors.teal.shade900 : Colors.teal.shade50),
          foregroundColor: isConnected
              ? Theme.of(context).textTheme.bodyLarge?.color
              : (isDark ? Colors.tealAccent : Colors.teal.shade700),
          elevation: 0,
        ),
        child: Text(isConnected ? 'Disconnect' : 'Connect'),
      ),
    );
  }
}
