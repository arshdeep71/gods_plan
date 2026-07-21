import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/haptic_service.dart';

class SmartReminderView extends StatefulWidget {
  const SmartReminderView({super.key});

  @override
  State<SmartReminderView> createState() => _SmartReminderViewState();
}

class _SmartReminderViewState extends State<SmartReminderView> {
  bool _enabled = true;
  List<int> _intervals = [10, 30];
  int _maxReminders = 3;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _enabled = prefs.getBool('smart_escalation_enabled') ?? true;
      final intervalStrings = prefs.getStringList('smart_escalation_intervals') ?? ['10', '30'];
      _intervals = intervalStrings.map((s) => int.tryParse(s) ?? 0).where((i) => i > 0).toList();
      _maxReminders = prefs.getInt('smart_escalation_max') ?? 3;
    });
  }

  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('smart_escalation_enabled', _enabled);
    
    // Ensure we only save up to maxReminders minus 1 (since the first is the actual reminder)
    final savedIntervals = _intervals.take(_maxReminders - 1).map((i) => i.toString()).toList();
    await prefs.setStringList('smart_escalation_intervals', savedIntervals);
    await prefs.setInt('smart_escalation_max', _maxReminders);
  }

  void _addInterval() {
    if (_intervals.length < _maxReminders - 1) {
      HapticService().lightImpact();
      setState(() {
        _intervals.add(60); // Default new interval
      });
      _saveSettings();
    }
  }

  void _removeInterval(int index) {
    HapticService().lightImpact();
    setState(() {
      _intervals.removeAt(index);
    });
    _saveSettings();
  }

  void _updateInterval(int index, int value) {
    setState(() {
      _intervals[index] = value;
    });
    _saveSettings();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F1A),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('Smart Reminder', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildToggle(),
          if (_enabled) ...[
            const SizedBox(height: 24),
            _buildMaxReminders(),
            const SizedBox(height: 24),
            _buildIntervalsList(),
          ],
        ],
      ),
    );
  }

  Widget _buildToggle() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF161622),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: SwitchListTile(
        title: const Text('Enabled', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        subtitle: const Text('Automatically follow up on missed tasks', style: TextStyle(color: Colors.white54, fontSize: 12)),
        value: _enabled,
        activeColor: Colors.blueAccent,
        onChanged: (val) {
          HapticService().selectionClick();
          setState(() {
            _enabled = val;
          });
          _saveSettings();
        },
      ),
    );
  }

  Widget _buildMaxReminders() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'MAXIMUM REMINDERS',
          style: TextStyle(color: Colors.white38, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.2),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFF161622),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withOpacity(0.05)),
          ),
          child: ListTile(
            title: const Text('Total Notifications per Task', style: TextStyle(color: Colors.white)),
            trailing: DropdownButton<int>(
              dropdownColor: const Color(0xFF161622),
              value: _maxReminders,
              underline: const SizedBox(),
              items: [2, 3, 4, 5, 6].map((int value) {
                return DropdownMenuItem<int>(
                  value: value,
                  child: Text(value.toString(), style: const TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.bold)),
                );
              }).toList(),
              onChanged: (val) {
                if (val != null) {
                  HapticService().selectionClick();
                  setState(() {
                    _maxReminders = val;
                    // Trim intervals if max is reduced
                    while (_intervals.length > _maxReminders - 1) {
                      _intervals.removeLast();
                    }
                  });
                  _saveSettings();
                }
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildIntervalsList() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'ESCALATION TIMERS',
          style: TextStyle(color: Colors.white38, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.2),
        ),
        const SizedBox(height: 8),
        ...List.generate(_intervals.length, (index) {
          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            decoration: BoxDecoration(
              color: const Color(0xFF161622),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withOpacity(0.05)),
            ),
            child: ListTile(
              title: Text('Reminder ${index + 2}', style: const TextStyle(color: Colors.white)),
              subtitle: Text('+${_intervals[index]} min after previous', style: const TextStyle(color: Colors.white54, fontSize: 12)),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButton<int>(
                    dropdownColor: const Color(0xFF161622),
                    value: [5, 10, 15, 30, 45, 60, 120].contains(_intervals[index]) ? _intervals[index] : null,
                    hint: _intervals[index] != null && ![5, 10, 15, 30, 45, 60, 120].contains(_intervals[index]) 
                        ? Text('${_intervals[index]} min', style: const TextStyle(color: Colors.blueAccent))
                        : null,
                    underline: const SizedBox(),
                    items: [5, 10, 15, 30, 45, 60, 120].map((int value) {
                      return DropdownMenuItem<int>(
                        value: value,
                        child: Text('$value min', style: const TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.bold)),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) {
                        HapticService().selectionClick();
                        _updateInterval(index, val);
                      }
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.remove_circle_outline, color: Colors.redAccent),
                    onPressed: () => _removeInterval(index),
                  ),
                ],
              ),
            ),
          );
        }),
        if (_intervals.length < _maxReminders - 1)
          GestureDetector(
            onTap: _addInterval,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 16),
              decoration: BoxDecoration(
                color: Colors.blueAccent.withOpacity(0.1),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.blueAccent.withOpacity(0.3)),
              ),
              child: const Center(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.add, color: Colors.blueAccent),
                    SizedBox(width: 8),
                    Text('Add Escalation', style: TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}
