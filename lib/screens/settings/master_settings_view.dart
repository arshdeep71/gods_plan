import 'package:flutter/material.dart';
import '../../services/haptic_service.dart';
import 'sound_haptics_view.dart';
import 'sync_status_view.dart';
import 'app_icon_view.dart';
import 'theme_picker_view.dart';
import 'privacy_export_view.dart';

class MasterSettingsView extends StatelessWidget {
  const MasterSettingsView({super.key});

  void _navigateTo(BuildContext context, Widget screen) {
    HapticService().selectionClick();
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => screen),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F1A), // AMOLED Dark
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('Settings', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        children: [
          _buildCategoryHeader('Customization'),
          _buildSettingsTile(
            context: context,
            title: 'Theme & Accent Colors',
            icon: Icons.palette_rounded,
            color: Colors.pinkAccent,
            destination: const ThemePickerView(),
          ),
          _buildSettingsTile(
            context: context,
            title: 'Alternate App Icons',
            icon: Icons.app_shortcut_rounded,
            color: Colors.orangeAccent,
            destination: const AppIconView(), // From Phase 8
          ),
          _buildSettingsTile(
            context: context,
            title: 'Sounds & Haptics',
            icon: Icons.vibration_rounded,
            color: Colors.purpleAccent,
            destination: const SoundHapticsView(), // From Phase 3
          ),
          
          const SizedBox(height: 24),
          _buildCategoryHeader('Data & Privacy'),
          _buildSettingsTile(
            context: context,
            title: 'Sync & Backup Status',
            icon: Icons.cloud_sync_rounded,
            color: Colors.blueAccent,
            destination: const SyncStatusView(), // From Phase 1
          ),
          _buildSettingsTile(
            context: context,
            title: 'Privacy & Data Export',
            icon: Icons.security_rounded,
            color: Colors.greenAccent,
            destination: const PrivacyExportView(),
          ),

          const SizedBox(height: 24),
          _buildCategoryHeader('About'),
          ListTile(
            leading: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: Colors.white12, borderRadius: BorderRadius.circular(8)),
              child: const Icon(Icons.info_outline_rounded, color: Colors.white70),
            ),
            title: const Text('God\\'s Plan Version', style: TextStyle(color: Colors.white)),
            trailing: const Text('v1.0.0 (Build 42)', style: TextStyle(color: Colors.white54)),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, left: 4),
      child: Text(
        title.toUpperCase(),
        style: const TextStyle(
          color: Colors.white38,
          fontSize: 12,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _buildSettingsTile({
    required BuildContext context,
    required String title,
    required IconData icon,
    required Color color,
    required Widget destination,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF161622),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.15),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: color),
        ),
        title: Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        trailing: const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white38, size: 16),
        onTap: () => _navigateTo(context, destination),
      ),
    );
  }
}
