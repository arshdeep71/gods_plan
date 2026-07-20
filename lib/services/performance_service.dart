import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

class PerformanceService with WidgetsBindingObserver {
  static final PerformanceService _instance = PerformanceService._internal();
  factory PerformanceService() => _instance;
  PerformanceService._internal();

  bool _isLowMemoryMode = false;

  void init() {
    WidgetsBinding.instance.addObserver(this);
    
    // Optional: Log frame rendering times in debug mode to spot UI jank
    assert(() {
      SchedulerBinding.instance.addTimingsCallback((List<FrameTiming> timings) {
        for (final timing in timings) {
          if (timing.totalSpan.inMilliseconds > 16.6) { // 60 FPS threshold
            print('⚠️ [PERFORMANCE] Frame Drop Detected: \${timing.totalSpan.inMilliseconds}ms');
          }
        }
      });
      return true;
    }());
  }

  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
  }

  /// Listens to native OS memory warnings (e.g. from iOS Jetsam)
  @override
  void didHaveMemoryPressure() {
    super.didHaveMemoryPressure();
    print('🚨 [PERFORMANCE] OS MEMORY PRESSURE DETECTED! Purging caches...');
    _isLowMemoryMode = true;
    
    // 1. Instantly clear Flutter's image cache
    PaintingBinding.instance.imageCache.clear();
    PaintingBinding.instance.imageCache.clearLiveImages();
    
    // 2. Here we could trigger a cleanup of our own memory-heavy singletons (like AudioPlayer pool)
  }

  /// Called when the app is backgrounded or foregrounded
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      // App is moving to the background. 
      // Aggressively clean up memory to prevent the OS from killing us.
      if (_isLowMemoryMode) {
         PaintingBinding.instance.imageCache.clearLiveImages();
      }
    } else if (state == AppLifecycleState.resumed) {
      // Reset memory flag if we survived the background trip
      _isLowMemoryMode = false;
    }
  }

  /// Helper to aggressively precache critical UI assets to prevent scrolling jank
  Future<void> preloadCriticalAssets(BuildContext context) async {
    // Example: precacheImage(const AssetImage('assets/hero_bg.png'), context);
    // Setting cache dimensions reduces RAM usage significantly
    PaintingBinding.instance.imageCache.maximumSize = 1000; // items
    PaintingBinding.instance.imageCache.maximumSizeBytes = 50 << 20; // 50 MB Max
  }
}
