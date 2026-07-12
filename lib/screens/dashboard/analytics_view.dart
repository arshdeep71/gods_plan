import 'package:flutter/material.dart';
import '../../services/analytics_service.dart';
import '../../utils/colors.dart';

class AnalyticsView extends StatefulWidget {
  final String userId;

  const AnalyticsView({super.key, required this.userId});

  @override
  State<AnalyticsView> createState() => _AnalyticsViewState();
}

class _AnalyticsViewState extends State<AnalyticsView> {
  final AnalyticsService _analyticsService = AnalyticsService();
  Map<String, double> _compliance = {};
  List<double> _sleepQuality = [];
  List<double> _waterLogged = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final comp = await _analyticsService.getWeeklyHabitCompliance(widget.userId);
      final sleep = await _analyticsService.getWeeklySleepQuality(widget.userId);
      final water = await _analyticsService.getWeeklyWaterLogged(widget.userId);
      setState(() {
        _compliance = comp;
        _sleepQuality = sleep;
        _waterLogged = water;
        _isLoading = false;
      });
    } catch (_) {
      setState(() => _isLoading = false);
    }
  }

  Widget _buildBarChart(String title, Map<String, double> data, Color barColor) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 15),
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 150,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: data.entries.map((e) {
                final heightFactor = e.value.clamp(0.0, 1.0);
                return Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Expanded(
                      child: Container(
                        width: 14,
                        decoration: BoxDecoration(
                          color: AppColors.border,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        alignment: Alignment.bottomCenter,
                        child: FractionallySizedBox(
                          heightFactor: heightFactor,
                          child: Container(
                            decoration: BoxDecoration(
                              color: barColor,
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      e.key,
                      style: const TextStyle(color: AppColors.textSecondary, fontSize: 10),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "${(heightFactor * 100).toStringAsFixed(0)}%",
                      style: const TextStyle(color: AppColors.textMuted, fontSize: 8),
                    ),
                  ],
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTrendChart(String title, List<double> data, double maxVal, String suffix, Color barColor) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 15),
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 150,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: List.generate(data.length, (idx) {
                final val = data[idx];
                final heightFactor = maxVal > 0 ? (val / maxVal).clamp(0.0, 1.0) : 0.0;
                return Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Expanded(
                      child: Container(
                        width: 14,
                        decoration: BoxDecoration(
                          color: AppColors.border,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        alignment: Alignment.bottomCenter,
                        child: FractionallySizedBox(
                          heightFactor: heightFactor,
                          child: Container(
                            decoration: BoxDecoration(
                              color: barColor,
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      "Day ${idx + 1}",
                      style: const TextStyle(color: AppColors.textSecondary, fontSize: 10),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "${val.toStringAsFixed(0)}$suffix",
                      style: const TextStyle(color: AppColors.textMuted, fontSize: 8),
                    ),
                  ],
                );
              }),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
        title: const Text(
          "Performance Insights",
          style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.accent))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Weekly Compliance Reports",
                    style: TextStyle(color: AppColors.textPrimary, fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),

                  // Habit Compliance Bar Chart
                  _buildBarChart("Habit Completion Compliance", _compliance, AppColors.accent),
                  const SizedBox(height: 24),

                  // Sleep quality trend
                  _buildTrendChart("Sleep Quality History", _sleepQuality, 10.0, "/10", AppColors.primary),
                  const SizedBox(height: 24),

                  // Water logged trend
                  _buildTrendChart("Daily Water Logged", _waterLogged, 12.0, " gl", AppColors.success),
                ],
              ),
            ),
    );
  }
}
