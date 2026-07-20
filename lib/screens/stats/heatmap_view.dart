import 'package:flutter/material.dart';
import '../../services/analytics_service.dart';

class HeatmapView extends StatefulWidget {
  final String userId;

  const HeatmapView({super.key, required this.userId});

  @override
  State<HeatmapView> createState() => _HeatmapViewState();
}

class _HeatmapViewState extends State<HeatmapView> {
  final AnalyticsService _analytics = AnalyticsService();
  Map<String, int> _heatmapData = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final data = await _analytics.generateHeatmapData(widget.userId);
    if (mounted) {
      setState(() {
        _heatmapData = data;
        _isLoading = false;
      });
    }
  }

  Color _getColorForIntensity(int intensity) {
    switch (intensity) {
      case 1: return Colors.greenAccent.withOpacity(0.25);
      case 2: return Colors.greenAccent.withOpacity(0.50);
      case 3: return Colors.greenAccent.withOpacity(0.75);
      case 4: return Colors.greenAccent;
      case 0:
      default:
        return Colors.white.withOpacity(0.05); // Empty block
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const SizedBox(
        height: 150,
        child: Center(child: CircularProgressIndicator(color: Colors.greenAccent)),
      );
    }

    // Build the grid representing the last 70 days (10 weeks)
    final now = DateTime.now();
    List<Widget> columns = [];

    for (int week = 9; week >= 0; week--) {
      List<Widget> days = [];
      for (int day = 6; day >= 0; day--) {
        // Calculate date for this specific block
        final targetDate = now.subtract(Duration(days: (week * 7) + day));
        final dateStr = "\${targetDate.year}-\${targetDate.month.toString().padLeft(2, '0')}-\${targetDate.day.toString().padLeft(2, '0')}";
        
        final intensity = _heatmapData[dateStr] ?? 0;
        
        days.add(
          Container(
            width: 14,
            height: 14,
            margin: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              color: _getColorForIntensity(intensity),
              borderRadius: BorderRadius.circular(3),
            ),
          )
        );
      }
      columns.add(
        Column(
          mainAxisSize: MainAxisSize.min,
          children: days,
        )
      );
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF101016),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Consistency Heatmap',
            style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            reverse: true, // Scroll to most recent automatically
            child: Row(
              children: columns,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              const Text('Less', style: TextStyle(color: Colors.white54, fontSize: 10)),
              const SizedBox(width: 4),
              _buildLegendBlock(0),
              _buildLegendBlock(1),
              _buildLegendBlock(2),
              _buildLegendBlock(3),
              _buildLegendBlock(4),
              const SizedBox(width: 4),
              const Text('More', style: TextStyle(color: Colors.white54, fontSize: 10)),
            ],
          )
        ],
      ),
    );
  }

  Widget _buildLegendBlock(int intensity) {
    return Container(
      width: 10,
      height: 10,
      margin: const EdgeInsets.symmetric(horizontal: 2),
      decoration: BoxDecoration(
        color: _getColorForIntensity(intensity),
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }
}
