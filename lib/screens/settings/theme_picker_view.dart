import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/haptic_service.dart';

class ThemePickerView extends StatefulWidget {
  const ThemePickerView({super.key});

  @override
  State<ThemePickerView> createState() => _ThemePickerViewState();
}

class _ThemePickerViewState extends State<ThemePickerView> {
  final List<Map<String, dynamic>> _accentColors = [
    {'name': "God's Blue", 'color': Colors.blueAccent},
    {'name': 'Neon Purple', 'color': Colors.purpleAccent},
    {'name': 'Cyber Green', 'color': Colors.greenAccent},
    {'name': 'Sunset Orange', 'color': Colors.orangeAccent},
    {'name': 'Minimalist White', 'color': Colors.white},
    {'name': 'Cherry Red', 'color': Colors.redAccent},
  ];

  String _currentTheme = "God's Blue";

  @override
  void initState() {
    super.initState();
    _loadTheme();
  }

  Future<void> _loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _currentTheme = prefs.getString('accent_theme') ?? "God's Blue";
    });
  }

  Future<void> _setTheme(String themeName) async {
    HapticService().selectionClick();
    setState(() => _currentTheme = themeName);
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('accent_theme', themeName);
    
    // In a full implementation, this would trigger a Provider/Riverpod state update
    // to instantly redraw the AppTheme.
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F1A),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('Theme & Accents', style: TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'CHOOSE ACCENT COLOR',
            style: TextStyle(color: Colors.white54, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.2),
          ),
          const SizedBox(height: 16),
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFF161622),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white12),
            ),
            child: ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _accentColors.length,
              separatorBuilder: (context, index) => const Divider(color: Colors.white12, height: 1),
              itemBuilder: (context, index) {
                final colorItem = _accentColors[index];
                final isSelected = _currentTheme == colorItem['name'];
                
                return ListTile(
                  leading: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: colorItem['color'] as Color,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white24, width: 2),
                    ),
                  ),
                  title: Text(colorItem['name'] as String, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  trailing: isSelected 
                      ? const Icon(Icons.check_circle_rounded, color: Colors.white)
                      : null,
                  onTap: () => _setTheme(colorItem['name'] as String),
                );
              },
            ),
          ),
          const SizedBox(height: 32),
          const Text(
            'BACKGROUND MODE',
            style: TextStyle(color: Colors.white54, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.2),
          ),
          const SizedBox(height: 16),
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFF161622),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white12),
            ),
            child: RadioListTile<String>(
              title: const Text('AMOLED True-Black', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              subtitle: const Text('Saves battery on OLED screens.', style: TextStyle(color: Colors.white54, fontSize: 12)),
              value: 'AMOLED',
              groupValue: 'AMOLED', // Hardcoded for this phase
              activeColor: Colors.blueAccent,
              onChanged: (val) {},
            ),
          )
        ],
      ),
    );
  }
}
