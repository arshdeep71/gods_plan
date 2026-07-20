import 'package:flutter/material.dart';
import '../../services/analytics_service.dart';
import 'heatmap_view.dart';
import '../../services/haptic_service.dart';

class StatisticsDashboard extends StatefulWidget {
  final String userId;

  const StatisticsDashboard({super.key, required this.userId});

  @override
  State<StatisticsDashboard> createState() => _StatisticsDashboardState();
}

class _StatisticsDashboardState extends State<StatisticsDashboard> {
  final AnalyticsService _analytics = AnalyticsService();
  
  bool _isLoading = true;
  int _totalXp = 0;
  Map<String, int> _streaks = {'current': 0, 'longest': 0};
  Map<String, dynamic> _insights = {};
  List<Map<String, dynamic>> _badges = [];

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
  }

  Future<void> _loadDashboardData() async {
    final xp = await _analytics.calculateTotalXp(widget.userId);
    final streaks = await _analytics.calculateStreaks(widget.userId);
    final insights = await _analytics.generateProductivityInsights(widget.userId);
    final badges = await _analytics.getBadgesStatus(widget.userId);

    if (mounted) {
      setState(() {
        _totalXp = xp;
        _streaks = streaks;
        _insights = insights;
        _badges = badges;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Color(0xFF0F0F1A),
        body: Center(child: CircularProgressIndicator(color: Colors.purpleAccent)),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFF0F0F1A), // AMOLED Dark
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('Analytics & Progress', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.share_rounded),
            onPressed: () {
              HapticService().selectionClick();
              // Trigger share intent to Instagram/Twitter
            },
          )
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadDashboardData,
        color: Colors.purpleAccent,
        backgroundColor: const Color(0xFF161622),
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          children: [
            // Hero: XP & Level
            _buildHeroXP(),
            const SizedBox(height: 24),

            // Metrics Row: Streaks & Insights
            Row(
              children: [
                Expanded(child: _buildMetricCard('Current Streak', '\${_streaks['current']} Days', Icons.local_fire_department, Colors.orangeAccent)),
                const SizedBox(width: 12),
                Expanded(child: _buildMetricCard('Focus Time', '\${_insights['total_focus_hours']} Hrs', Icons.timer, Colors.cyanAccent)),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: _buildMetricCard('Longest Streak', '\${_streaks['longest']} Days', Icons.workspace_premium, Colors.amberAccent)),
                const SizedBox(width: 12),
                Expanded(child: _buildMetricCard('Best Day', '\${_insights['best_day']}', Icons.star_border_rounded, Colors.pinkAccent)),
              ],
            ),
            const SizedBox(height: 24),

            // GitHub Heatmap
            HeatmapView(userId: widget.userId),
            const SizedBox(height: 32),

            // Achievements Grid
            const Text(
              'Unlockable Achievements',
              style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            _buildAchievementsGrid(),
            const SizedBox(height: 40), // Bottom Padding
          ],
        ),
      ),
    );
  }

  Widget _buildHeroXP() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF6A11CB), Color(0xFF2575FC)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.purpleAccent.withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          const Text('TOTAL XP', style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
          const SizedBox(height: 8),
          Text(
            _totalXp.toString(),
            style: const TextStyle(color: Colors.white, fontSize: 48, fontWeight: FontWeight.w900, letterSpacing: -1.0),
          ),
          const SizedBox(height: 16),
          // Progress Bar to next level (Mocked for 1000 XP per level)
          LinearProgressIndicator(
            value: (_totalXp % 1000) / 1000,
            backgroundColor: Colors.black26,
            valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
            minHeight: 8,
            borderRadius: BorderRadius.circular(4),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Level \${(_totalXp ~/ 1000) + 1}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              Text('\${1000 - (_totalXp % 1000)} XP to Next', style: const TextStyle(color: Colors.white70, fontSize: 12)),
            ],
          )
        ],
      ),
    );
  }

  Widget _buildMetricCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF161622),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 12),
          Text(value, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(title, style: const TextStyle(color: Colors.white54, fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildAchievementsGrid() {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 0.85,
      ),
      itemCount: _badges.length,
      itemBuilder: (context, index) {
        final badge = _badges[index];
        final bool unlocked = badge['unlocked'] as bool;
        
        // Map string icon names back to IconData for the UI
        IconData badgeIcon;
        switch(badge['icon']) {
          case 'wb_sunny_rounded': badgeIcon = Icons.wb_sunny_rounded; break;
          case 'water_drop_rounded': badgeIcon = Icons.water_drop_rounded; break;
          case 'shield_rounded': badgeIcon = Icons.shield_rounded; break;
          case 'menu_book_rounded': badgeIcon = Icons.menu_book_rounded; break;
          case 'savings_rounded': badgeIcon = Icons.savings_rounded; break;
          default: badgeIcon = Icons.star_rounded;
        }

        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: unlocked ? Colors.blueAccent.withOpacity(0.1) : const Color(0xFF161622),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: unlocked ? Colors.blueAccent.withOpacity(0.5) : Colors.white12,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: unlocked ? Colors.blueAccent.withOpacity(0.2) : Colors.white.withOpacity(0.05),
                  shape: BoxShape.circle,
                ),
                child: Icon(badgeIcon, color: unlocked ? Colors.blueAccent : Colors.white38, size: 32),
              ),
              const SizedBox(height: 16),
              Text(
                badge['name'] as String,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: unlocked ? Colors.white : Colors.white54,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                badge['desc'] as String,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: unlocked ? Colors.white70 : Colors.white38,
                  fontSize: 10,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
