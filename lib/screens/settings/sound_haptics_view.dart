import 'package:flutter/material.dart';
import '../../services/haptic_service.dart';
import '../../services/audio_service.dart';

class SoundHapticsView extends StatefulWidget {
  const SoundHapticsView({super.key});

  @override
  State<SoundHapticsView> createState() => _SoundHapticsViewState();
}

class _SoundHapticsViewState extends State<SoundHapticsView> {
  final HapticService _hapticService = HapticService();
  final AudioService _audioService = AudioService();

  bool _hapticsEnabled = true;
  bool _soundsEnabled = true;
  double _uiVolume = 0.8;
  String _hapticIntensity = 'Medium';

  @override
  void initState() {
    super.initState();
    _loadPreferences();
  }

  void _loadPreferences() {
    setState(() {
      _hapticsEnabled = _hapticService.isEnabled;
      _soundsEnabled = _audioService.isEnabled;
      _uiVolume = _audioService.volume;
      // Mock loading intensity for UI display
      _hapticIntensity = 'Medium'; 
    });
  }

  void _testHaptic(String intensity) {
    if (!_hapticsEnabled) return;
    if (intensity == 'Light') _hapticService.lightImpact();
    else if (intensity == 'Medium') _hapticService.mediumImpact();
    else if (intensity == 'Strong') _hapticService.heavyImpact();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F1A),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('Sounds & Haptics', style: TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildSectionHeader('Haptics (Vibration)'),
          _buildToggleTile(
            title: 'System Haptics',
            subtitle: 'Vibrate on button taps, task completions, and errors.',
            value: _hapticsEnabled,
            onChanged: (val) {
              setState(() => _hapticsEnabled = val);
              _hapticService.toggleHaptics(val);
            },
          ),
          if (_hapticsEnabled) ...[
            const SizedBox(height: 16),
            const Text('VIBRATION INTENSITY', style: TextStyle(color: Colors.white54, fontSize: 12, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: ['Light', 'Medium', 'Strong'].map((intensity) {
                  return RadioListTile<String>(
                    title: Text(intensity, style: const TextStyle(color: Colors.white)),
                    value: intensity,
                    groupValue: _hapticIntensity,
                    activeColor: Colors.blueAccent,
                    onChanged: (val) {
                      if (val != null) {
                        setState(() => _hapticIntensity = val);
                        _testHaptic(val);
                      }
                    },
                  );
                }).toList(),
              ),
            ),
          ],

          const SizedBox(height: 32),
          _buildSectionHeader('In-App Sounds'),
          _buildToggleTile(
            title: 'UI Sound Effects',
            subtitle: 'Play sounds for achievements, completions, and leveling up.',
            value: _soundsEnabled,
            onChanged: (val) {
              setState(() => _soundsEnabled = val);
              _audioService.toggleSounds(val);
            },
          ),
          if (_soundsEnabled) ...[
            const SizedBox(height: 16),
            const Text('UI VOLUME', style: TextStyle(color: Colors.white54, fontSize: 12, fontWeight: FontWeight.bold)),
            Slider(
              value: _uiVolume,
              min: 0.0,
              max: 1.0,
              activeColor: Colors.blueAccent,
              inactiveColor: Colors.white24,
              onChanged: (val) {
                setState(() => _uiVolume = val);
                _audioService.setVolume(val);
              },
              onChangeEnd: (val) {
                _audioService.playSuccess(); // Test sound
              },
            ),
          ],

          const SizedBox(height: 32),
          _buildSectionHeader('Notification Overrides'),
          _buildCategoryOverrideTile('Fitness & Workouts', 'gym_bell.mp3'),
          _buildCategoryOverrideTile('Study & Focus', 'lofi_chime.mp3'),
          _buildCategoryOverrideTile('Addiction Recovery', 'healing_tone.mp3'),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Text(
        title,
        style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildToggleTile({required String title, required String subtitle, required bool value, required ValueChanged<bool> onChanged}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
      ),
      child: SwitchListTile(
        title: Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        subtitle: Text(subtitle, style: const TextStyle(color: Colors.white54, fontSize: 13)),
        value: value,
        activeColor: Colors.blueAccent,
        onChanged: onChanged,
      ),
    );
  }

  Widget _buildCategoryOverrideTile(String category, String currentSound) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        title: Text(category, style: const TextStyle(color: Colors.white)),
        subtitle: Text('Sound: \$currentSound', style: const TextStyle(color: Colors.blueAccent, fontSize: 12)),
        trailing: const Icon(Icons.arrow_forward_ios, color: Colors.white38, size: 16),
        onTap: () {
          // Open sound picker modal
          _audioService.playSuccess(); // demo buzz
        },
      ),
    );
  }
}
