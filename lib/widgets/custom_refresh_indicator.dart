import 'package:flutter/material.dart';
import '../../services/haptic_service.dart';

class CustomRefreshIndicator extends StatelessWidget {
  final Widget child;
  final Future<void> Function() onRefresh;

  const CustomRefreshIndicator({
    super.key,
    required this.child,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      color: Colors.blueAccent,
      backgroundColor: const Color(0xFF1E1E2C), // Matches AMOLED dark panels
      strokeWidth: 3.0,
      displacement: 60.0,
      edgeOffset: 0.0,
      onRefresh: () async {
        HapticService().lightImpact(); // Haptic tick when refresh triggers
        await onRefresh();
        HapticService().success(); // Double tick when refresh completes
      },
      child: child,
    );
  }
}
