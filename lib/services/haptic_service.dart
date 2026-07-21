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
    HapticFeedback.heavyImpact();
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_hapticsEnabled) HapticFeedback.heavyImpact();
    });
    Future.delayed(const Duration(milliseconds: 200), () {
      if (_hapticsEnabled) HapticFeedback.mediumImpact();
    });
  }

  void streak() {
    if (!_hapticsEnabled) return;
    // 3 taps, increasing intensity
    HapticFeedback.lightImpact();
    Future.delayed(const Duration(milliseconds: 120), () {
      if (_hapticsEnabled) HapticFeedback.mediumImpact();
    });
    Future.delayed(const Duration(milliseconds: 260), () {
      if (_hapticsEnabled) HapticFeedback.heavyImpact();
    });
  }

  void xpCoin() {
    if (!_hapticsEnabled) return;
    // Quick double-tap
    HapticFeedback.lightImpact();
    Future.delayed(const Duration(milliseconds: 80), () {
      if (_hapticsEnabled) HapticFeedback.mediumImpact();
    });
  }

  void achievement() {
    if (!_hapticsEnabled) return;
    // 4 ascending taps
    HapticFeedback.lightImpact();
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_hapticsEnabled) HapticFeedback.lightImpact();
    });
    Future.delayed(const Duration(milliseconds: 200), () {
      if (_hapticsEnabled) HapticFeedback.mediumImpact();
    });
    Future.delayed(const Duration(milliseconds: 320), () {
      if (_hapticsEnabled) HapticFeedback.heavyImpact();
    });
  }

  // UI Interaction Haptics
  void navigation() => lightImpact();
  void bottomNav() => lightImpact();
  void buttonPress() => mediumImpact();
  void calendar() => selectionClick();
  void bottomSheet() => lightImpact();
  void search() => selectionClick();
  
  void pullToRefresh() {
    if (!_hapticsEnabled) return;
    HapticFeedback.lightImpact();
    Future.delayed(const Duration(milliseconds: 200), () {
      if (_hapticsEnabled) HapticFeedback.mediumImpact();
    });
    Future.delayed(const Duration(milliseconds: 400), () {
      if (_hapticsEnabled) HapticFeedback.lightImpact();
    });
  }

  void delete() {
    if (!_hapticsEnabled) return;
    HapticFeedback.mediumImpact();
    Future.delayed(const Duration(milliseconds: 150), () {
      if (_hapticsEnabled) HapticFeedback.mediumImpact();
    });
    Future.delayed(const Duration(milliseconds: 350), () {
      if (_hapticsEnabled) HapticFeedback.heavyImpact();
    });
  }

  void longPress() {
    if (!_hapticsEnabled) return;
    HapticFeedback.mediumImpact();
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_hapticsEnabled) HapticFeedback.heavyImpact();
    });
  }
}
