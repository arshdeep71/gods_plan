import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

class HapticService {
  static final HapticService _instance = HapticService._internal();
  factory HapticService() => _instance;
  HapticService._internal();

  bool _hapticsEnabled = true;

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _hapticsEnabled = prefs.getBool('haptics_enabled') ?? true;
  }

  Future<void> toggleHaptics(bool isEnabled) async {
    _hapticsEnabled = isEnabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('haptics_enabled', isEnabled);
    if (isEnabled) lightImpact();
  }

  bool get isEnabled => _hapticsEnabled;

  void lightImpact() {
    if (!_hapticsEnabled) return;
    HapticFeedback.lightImpact();
  }

  void mediumImpact() {
    if (!_hapticsEnabled) return;
    HapticFeedback.mediumImpact();
  }

  void heavyImpact() {
    if (!_hapticsEnabled) return;
    HapticFeedback.heavyImpact();
  }

  void selectionClick() {
    if (!_hapticsEnabled) return;
    HapticFeedback.selectionClick();
  }

  void success() {
    if (!_hapticsEnabled) return;
    // Simulate a double tap for success
    HapticFeedback.mediumImpact();
    Future.delayed(const Duration(milliseconds: 150), () {
      if (_hapticsEnabled) HapticFeedback.heavyImpact();
    });
  }

  void error() {
    if (!_hapticsEnabled) return;
    // Simulate a rapid triple buzz for errors or failures
    HapticFeedback.heavyImpact();
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_hapticsEnabled) HapticFeedback.heavyImpact();
    });
    Future.delayed(const Duration(milliseconds: 200), () {
      if (_hapticsEnabled) HapticFeedback.mediumImpact();
    });
  }
}
