import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/task_provider.dart';
import '../../utils/colors.dart';

class StreakView extends StatefulWidget {
  const StreakView({super.key});

  @override
  State<StreakView> createState() => _StreakViewState();
}

class _StreakViewState extends State<StreakView> {
  DateTime _currentMonth = DateTime.now();

  @override
  Widget build(BuildContext context) {
    final taskProvider = context.watch<TaskProvider>();
    final authProvider = context.watch<AuthProvider>();
    final userId = authProvider.user?.id ?? '';
    
    // Calculate global streak using the centralized provider logic
    final currentStreak = userId.isNotEmpty ? taskProvider.calculateCurrentStreak(userId) : 0;
    final restoresLeft = userId.isNotEmpty ? taskProvider.getStreakRestoresLeft(userId) : 3;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded, color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          "Streak",
          style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.only(left: 20, right: 20, top: 16, bottom: 60),
        child: Column(
          children: [
            // Gold Banner Insight
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFFFB75E), Color(0xFFED8F03)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFED8F03).withOpacity(0.4),
                    blurRadius: 15,
                    offset: const Offset(0, 8),
                  )
                ],
              ),
              child: Column(
                children: [
                  const Icon(Icons.local_fire_department_rounded, color: Colors.white, size: 64),
                  const SizedBox(height: 12),
                  Text(
                    "$currentStreak",
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 48,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const Text(
                    "Day Streak",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      currentStreak > 0 ? "You're on fire! Keep it up!" : "Reach 80%+ task completion today to start your streak!",
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                    ),
                  )
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Streak Restores Widget
            if (userId.isNotEmpty)
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.purple.withOpacity(0.15),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.restore_rounded, color: Colors.purpleAccent, size: 28),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            "Streak Restores",
                            style: TextStyle(color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            "$restoresLeft left this month",
                            style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: restoresLeft > 0 ? Colors.purple : AppColors.border,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      ),
                      onPressed: restoresLeft > 0
                          ? () async {
                              final success = await taskProvider.restoreStreak(userId);
                              if (success) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text("Streak restored successfully! 🔥"),
                                    backgroundColor: Colors.purple,
                                    behavior: SnackBarBehavior.floating,
                                  ),
                                );
                              } else {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text("No broken days found to restore in the last 30 days."),
                                    backgroundColor: AppColors.error,
                                    behavior: SnackBarBehavior.floating,
                                  ),
                                );
                              }
                            }
                          : null,
                      child: const Text("Restore", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 24),

            // Calendar Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _getMonthName(_currentMonth.month) + " ${_currentMonth.year}",
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.chevron_left_rounded, color: AppColors.textSecondary),
                      onPressed: () {
                        setState(() {
                          _currentMonth = DateTime(_currentMonth.year, _currentMonth.month - 1);
                        });
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.chevron_right_rounded, color: AppColors.textSecondary),
                      onPressed: () {
                        setState(() {
                          _currentMonth = DateTime(_currentMonth.year, _currentMonth.month + 1);
                        });
                      },
                    ),
                  ],
                )
              ],
            ),
            const SizedBox(height: 12),
            
            // Month Calendar (Duolingo Style Pill Highlights)
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                children: [
                  _buildMonthCalendar(taskProvider, userId),
                  const SizedBox(height: 24),
                  const Divider(color: AppColors.border),
                  const SizedBox(height: 12),
                  _buildLegend(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLegend() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Calendar Legends",
          style: TextStyle(color: AppColors.textSecondary, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 0.5),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 16,
          runSpacing: 10,
          children: [
            _buildLegendItem(Colors.orange, "● Perfect (100%)"),
            _buildLegendItem(Colors.amber, "🌟 Successful (80%+)"),
            _buildLegendItem(AppColors.error, "○ Missed"),
            _buildLegendItem(Colors.blue, "⏸ Paused"),
            _buildLegendItem(Colors.purpleAccent, "↺ Restored"),
            _buildLegendItem(AppColors.textSecondary.withOpacity(0.5), "⚪ Partial (<80%)"),
          ],
        ),
      ],
    );
  }

  Widget _buildLegendItem(Color color, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(text, style: const TextStyle(color: AppColors.textPrimary, fontSize: 12)),
      ],
    );
  }

  Widget _buildMonthCalendar(TaskProvider taskProvider, String userId) {
    final now = DateTime.now();
    final firstDayOfMonth = DateTime(_currentMonth.year, _currentMonth.month, 1);
    final daysInMonth = DateTime(_currentMonth.year, _currentMonth.month + 1, 0).day;
    final firstWeekday = firstDayOfMonth.weekday; // 1 = Mon, 7 = Sun
    
    // Day Names
    final dayNames = ["M", "T", "W", "T", "F", "S", "S"];
    
    List<Widget> dayLabels = dayNames.map((d) => Expanded(
      child: Center(
        child: Text(
          d,
          style: const TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.bold),
        ),
      ),
    )).toList();

    List<Widget> weeks = [];
    weeks.add(Row(children: dayLabels));
    weeks.add(const SizedBox(height: 16));
    
    List<Widget> currentWeek = [];
    
    // Empty slots before 1st of month
    for (int i = 1; i < firstWeekday; i++) {
      currentWeek.add(Expanded(child: Container()));
    }
    
    for (int day = 1; day <= daysInMonth; day++) {
      final date = DateTime(_currentMonth.year, _currentMonth.month, day);
      final isToday = date.year == now.year && date.month == now.month && date.day == now.day;
      
      final status = taskProvider.getDayStreakStatus(date, userId: userId);
      
      bool isStreakDay = status == DayStreakStatus.perfect || status == DayStreakStatus.successful || status == DayStreakStatus.restored;
      
      // Connecting background strips for active streak days
      bool prevIsStreak = false;
      bool nextIsStreak = false;
      
      if (isStreakDay) {
        final prevDate = date.subtract(const Duration(days: 1));
        final prevStatus = taskProvider.getDayStreakStatus(prevDate, userId: userId);
        prevIsStreak = prevStatus == DayStreakStatus.perfect || prevStatus == DayStreakStatus.successful || prevStatus == DayStreakStatus.restored;
        
        final nextDate = date.add(const Duration(days: 1));
        final nextStatus = taskProvider.getDayStreakStatus(nextDate, userId: userId);
        nextIsStreak = nextStatus == DayStreakStatus.perfect || nextStatus == DayStreakStatus.successful || nextStatus == DayStreakStatus.restored;
      }
      
      // Determine day color based on status
      Color dayColor = Colors.transparent;
      Widget? centerWidget;
      
      switch (status) {
        case DayStreakStatus.perfect:
          dayColor = Colors.orange;
          centerWidget = const Icon(Icons.local_fire_department_rounded, color: Colors.white, size: 14);
          break;
        case DayStreakStatus.successful:
          dayColor = Colors.amber;
          centerWidget = const Icon(Icons.star_rounded, color: Colors.black, size: 14);
          break;
        case DayStreakStatus.restored:
          dayColor = Colors.purpleAccent;
          centerWidget = const Icon(Icons.restore_rounded, color: Colors.white, size: 14);
          break;
        case DayStreakStatus.missed:
          dayColor = AppColors.error.withOpacity(0.15);
          centerWidget = const Icon(Icons.close_rounded, color: AppColors.error, size: 12);
          break;
        case DayStreakStatus.paused:
          dayColor = Colors.blue.withOpacity(0.15);
          centerWidget = const Icon(Icons.pause_rounded, color: Colors.blueAccent, size: 12);
          break;
        case DayStreakStatus.partial:
          dayColor = AppColors.textSecondary.withOpacity(0.1);
          break;
        default:
          break;
      }
      
      currentWeek.add(Expanded(
        child: Container(
          height: 40,
          alignment: Alignment.center,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Connecting background strips
              if (isStreakDay)
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        color: prevIsStreak ? Colors.orange.withOpacity(0.25) : Colors.transparent,
                      ),
                    ),
                    Expanded(
                      child: Container(
                        color: nextIsStreak ? Colors.orange.withOpacity(0.25) : Colors.transparent,
                      ),
                    ),
                  ],
                ),
              // Circle Highlight
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: dayColor,
                  border: isToday && !isStreakDay
                      ? Border.all(color: Colors.white54, width: 2)
                      : null,
                ),
                alignment: Alignment.center,
                child: centerWidget ?? Text(
                  "$day",
                  style: TextStyle(
                    color: isStreakDay ? Colors.white : AppColors.textPrimary,
                    fontWeight: isStreakDay || isToday ? FontWeight.bold : FontWeight.normal,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
        ),
      ));
      
      if (currentWeek.length == 7) {
        weeks.add(Row(children: currentWeek));
        weeks.add(const SizedBox(height: 8));
        currentWeek = [];
      }
    }
    
    // Fill remaining slots
    if (currentWeek.isNotEmpty) {
      while (currentWeek.length < 7) {
        currentWeek.add(Expanded(child: Container()));
      }
      weeks.add(Row(children: currentWeek));
    }

    return Column(children: weeks);
  }

  String _getMonthName(int month) {
    const months = [
      "January", "February", "March", "April", "May", "June",
      "July", "August", "September", "October", "November", "December"
    ];
    return months[month - 1];
  }
}
