import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
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
    final now = DateTime.now();

    // Calculate Global Streak
    int currentStreak = 0;
    DateTime streakCheckDate = DateTime(now.year, now.month, now.day);
    
    final todayActive = taskProvider.getActiveTasksForDate(streakCheckDate);
    final todayCompleted = taskProvider.getCompletedTasksForDate(streakCheckDate);
    if (todayActive.isEmpty && todayCompleted.isNotEmpty) {
      currentStreak++;
    }
    
    streakCheckDate = streakCheckDate.subtract(const Duration(days: 1));
    while (true) {
      final active = taskProvider.getActiveTasksForDate(streakCheckDate);
      final completed = taskProvider.getCompletedTasksForDate(streakCheckDate);
      
      if (active.isEmpty && completed.isNotEmpty) {
        currentStreak++;
        streakCheckDate = streakCheckDate.subtract(const Duration(days: 1));
      } else if (active.isEmpty && completed.isEmpty) {
        streakCheckDate = streakCheckDate.subtract(const Duration(days: 1));
        if (streakCheckDate.isBefore(now.subtract(const Duration(days: 365)))) break;
      } else {
        break;
      }
    }

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
                      currentStreak > 0 ? "You're on fire! Keep it up!" : "Complete all tasks today to start your streak!",
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                    ),
                  )
                ],
              ),
            ),
            const SizedBox(height: 32),

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
            const SizedBox(height: 16),
            
            // Month Calendar (Duolingo Style Pill Highlights)
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: AppColors.border),
              ),
              child: _buildMonthCalendar(taskProvider),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMonthCalendar(TaskProvider taskProvider) {
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
      
      final active = taskProvider.getActiveTasksForDate(date);
      final completed = taskProvider.getCompletedTasksForDate(date);
      
      bool isStreakDay = active.isEmpty && completed.isNotEmpty;
      bool isMissed = active.isNotEmpty && date.isBefore(DateTime(now.year, now.month, now.day));
      
      // Determine if previous/next days are streak days to connect pills
      bool prevIsStreak = false;
      bool nextIsStreak = false;
      
      if (isStreakDay) {
        final prevDate = date.subtract(const Duration(days: 1));
        final prevActive = taskProvider.getActiveTasksForDate(prevDate);
        final prevCompleted = taskProvider.getCompletedTasksForDate(prevDate);
        prevIsStreak = (prevActive.isEmpty && prevCompleted.isNotEmpty);
        
        final nextDate = date.add(const Duration(days: 1));
        final nextActive = taskProvider.getActiveTasksForDate(nextDate);
        final nextCompleted = taskProvider.getCompletedTasksForDate(nextDate);
        nextIsStreak = (nextActive.isEmpty && nextCompleted.isNotEmpty);
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
                  color: isStreakDay
                      ? Colors.orange
                      : (isMissed ? AppColors.error.withOpacity(0.2) : Colors.transparent),
                  border: isToday && !isStreakDay
                      ? Border.all(color: Colors.white54, width: 2)
                      : null,
                ),
                alignment: Alignment.center,
                child: Text(
                  "$day",
                  style: TextStyle(
                    color: isStreakDay ? Colors.white : (isMissed ? AppColors.error : AppColors.textPrimary),
                    fontWeight: isStreakDay || isToday ? FontWeight.bold : FontWeight.normal,
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
