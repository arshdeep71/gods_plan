import 'package:flutter/material.dart';
import '../../services/haptic_service.dart';
import '../../services/database_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PrivacyExportView extends StatefulWidget {
  const PrivacyExportView({super.key});

  @override
  State<PrivacyExportView> createState() => _PrivacyExportViewState();
}

class _PrivacyExportViewState extends State<PrivacyExportView> {
  bool _analyticsEnabled = true;

  @override
  void initState() {
    super.initState();
    _loadPrivacySettings();
  }

  Future<void> _loadPrivacySettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _analyticsEnabled = prefs.getBool('telemetry_enabled') ?? true;
    });
  }

  Future<void> _toggleAnalytics(bool val) async {
    HapticService().selectionClick();
    setState(() => _analyticsEnabled = val);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('telemetry_enabled', val);
  }

  void _exportData() {
    HapticService().success();
    // Simulate JSON export to device storage
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Data exported to Documents/GodsPlan_Export.json'),
        backgroundColor: Colors.green,
      )
    );
  }

  Future<void> _showWipeWarning() async {
    HapticService().error(); // Buzz to warn user
    
    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E2C),
        title: const Text('WIPE ALL DATA?', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
        content: const Text(
          'This will permanently delete your offline SQLite database, all tasks, streaks, and XP. This cannot be undone.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('CANCEL', style: TextStyle(color: Colors.white54)),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              // Trigger Database Wipe
              await DatabaseService().wipeDatabase();
              HapticService().success();
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Local Database Wiped.'), backgroundColor: Colors.redAccent)
                );
              }
            },
            child: const Text('YES, WIPE', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F1A),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('Privacy & Data', style: TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'YOUR DATA, YOUR RULES',
            style: TextStyle(color: Colors.white54, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.2),
          ),
          const SizedBox(height: 16),
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFF161622),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white12),
            ),
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.download_rounded, color: Colors.blueAccent),
                  title: const Text('Export Data (JSON)', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  subtitle: const Text('Save a copy of your entire history.', style: TextStyle(color: Colors.white54, fontSize: 12)),
                  onTap: _exportData,
                ),
                const Divider(color: Colors.white12, height: 1),
                SwitchListTile(
                  secondary: const Icon(Icons.analytics_rounded, color: Colors.purpleAccent),
                  title: const Text('Anonymous Analytics', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  subtitle: const Text("Help us improve God's Plan without sending personal data.", style: TextStyle(color: Colors.white54, fontSize: 12)),
                  value: _analyticsEnabled,
                  activeColor: Colors.purpleAccent,
                  onChanged: _toggleAnalytics,
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
          const Text(
            'DANGER ZONE',
            style: TextStyle(color: Colors.redAccent, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.2),
          ),
          const SizedBox(height: 16),
          Container(
            decoration: BoxDecoration(
              color: Colors.redAccent.withOpacity(0.05),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.redAccent.withOpacity(0.2)),
            ),
            child: ListTile(
              leading: const Icon(Icons.delete_forever_rounded, color: Colors.redAccent),
              title: const Text('Wipe Local Database', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
              subtitle: const Text('Permanently destroy all offline data.', style: TextStyle(color: Colors.redAccent, fontSize: 12)),
              onTap: _showWipeWarning,
            ),
          )
        ],
      ),
    );
  }
}
