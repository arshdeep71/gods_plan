import '../services/database_service.dart';

class AnalyticsService {
  final DatabaseService _dbService = DatabaseService();

  // Calculate current user XP based on logged accomplishments
  Future<int> calculateTotalXp(String userId) async {
    int totalXp = 0;

    try {
      // 1. Task XP (+50 XP per completed task)
      final tasks = await _dbService.getLocalTasks(userId);
      final completedTasksCount = tasks.where((t) => t.isCompleted).length;
      totalXp += completedTasksCount * 50;

      // 2. Workout XP (+100 XP per exercise workout logged)
      final workouts = await _dbService.getLocalWorkouts(userId);
      totalXp += workouts.length * 100;

      // 3. Sleep XP (+50 XP per sleep log recorded)
      final sleepLogs = await _dbService.getLocalSleepLogs(userId);
      totalXp += sleepLogs.length * 50;

      // 4. Study XP (+100 XP per academic session logged)
      final studyLogs = await _dbService.getLocalStudyLogs(userId);
      totalXp += studyLogs.length * 100;

      // 5. Sobriety Day XP (+20 XP per clean day streak)
      final addictionLogs = await _dbService.getLocalAddictionLogs(userId);
      // Find streak based on relapse logs
      final relapseLogs = addictionLogs.where((l) => l.isRelapse).toList();
      if (relapseLogs.isEmpty) {
        totalXp += addictionLogs.length * 20;
      } else {
        relapseLogs.sort((a, b) => b.loggedAt.compareTo(a.loggedAt));
        final lastRelapse = relapseLogs.first.loggedAt;
        final cleanDays = DateTime.now().difference(lastRelapse).inDays;
        totalXp += cleanDays * 20;
      }
    } catch (_) {}

    return totalXp;
  }

  // Calculate Badge achievements
  Future<List<Map<String, dynamic>>> getBadgesStatus(String userId) async {
    final List<Map<String, dynamic>> badges = [
      {
        'id': 'early_bird',
        'name': 'Early Bird',
        'desc': 'Slept with quality score >= 8 or early bed',
        'icon': 'wb_sunny_rounded',
        'unlocked': false
      },
      {
        'id': 'hydration_king',
        'name': 'Hydration King',
        'desc': 'Drank 8+ glasses of water in a single day',
        'icon': 'water_drop_rounded',
        'unlocked': false
      },
      {
        'id': 'iron_will',
        'name': 'Iron Will',
        'desc': 'Achieved a clean streak of 7+ days',
        'icon': 'shield_rounded',
        'unlocked': false
      },
      {
        'id': 'math_genius',
        'name': 'Focus Master',
        'desc': 'Studied total of 5+ hours (300+ minutes)',
        'icon': 'menu_book_rounded',
        'unlocked': false
      },
      {
        'id': 'frugal_master',
        'name': 'Frugal Master',
        'desc': 'Kept an expense transaction under ₹200',
        'icon': 'savings_rounded',
        'unlocked': false
      }
    ];

    try {
      // 1. Check Sleep
      final sleepLogs = await _dbService.getLocalSleepLogs(userId);
      final hasEarlySleep = sleepLogs.any((l) => l.calculatedQuality >= 8);
      if (hasEarlySleep) {
        badges[0]['unlocked'] = true;
      }

      // 2. Check Water
      final waterLogs = await _dbService.getLocalWaterLogs(userId);
      final hasHydrationKing = waterLogs.any((l) => l.glasses >= 8);
      if (hasHydrationKing) {
        badges[1]['unlocked'] = true;
      }

      // 3. Check Sobriety
      final addictionLogs = await _dbService.getLocalAddictionLogs(userId);
      final relapses = addictionLogs.where((l) => l.isRelapse).toList();
      if (relapses.isEmpty && addictionLogs.isNotEmpty) {
        badges[2]['unlocked'] = true;
      } else if (relapses.isNotEmpty) {
        relapses.sort((a, b) => b.loggedAt.compareTo(a.loggedAt));
        final diff = DateTime.now().difference(relapses.first.loggedAt).inDays;
        if (diff >= 7) {
          badges[2]['unlocked'] = true;
        }
      }

      // 4. Check Study
      final studyLogs = await _dbService.getLocalStudyLogs(userId);
      final totalMinutes = studyLogs.fold(0, (sum, l) => sum + l.durationMinutes);
      if (totalMinutes >= 300) {
        badges[3]['unlocked'] = true;
      }

      // 5. Check Finance
      final txs = await _dbService.getLocalFinanceTransactions(userId);
      final hasFrugal = txs.any((t) => t.type == 'expense' && t.amount <= 200.0);
      if (hasFrugal) {
        badges[4]['unlocked'] = true;
      }
    } catch (_) {}

    return badges;
  }

  // Returns task compliance rate for the last 7 days
  Future<Map<String, double>> getWeeklyHabitCompliance(String userId) async {
    final Map<String, double> compliance = {};
    final now = DateTime.now();

    try {
      final tasks = await _dbService.getLocalTasks(userId);
      for (int i = 6; i >= 0; i--) {
        final date = now.subtract(Duration(days: i));
        final dateStr = "${date.year}-${date.month}-${date.day}";

        // Simple mock matching by day of week names
        final dayName = _getDayOfWeekName(date.weekday);

        final dailyTasks = tasks.where((t) {
          // If task has logged timestamp matching date
          final logged = t.createdAt;
          return logged.year == date.year && logged.month == date.month && logged.day == date.day;
        }).toList();

        if (dailyTasks.isEmpty) {
          // Default baseline compliance for demonstration
          compliance[dayName] = 0.5;
        } else {
          final completed = dailyTasks.where((t) => t.isCompleted).length;
          compliance[dayName] = completed / dailyTasks.length;
        }
      }
    } catch (_) {
      // Fallback baseline values
      compliance['Mon'] = 0.8;
      compliance['Tue'] = 0.6;
      compliance['Wed'] = 0.9;
      compliance['Thu'] = 0.7;
      compliance['Fri'] = 0.8;
      compliance['Sat'] = 0.5;
      compliance['Sun'] = 0.9;
    }

    return compliance;
  }

  // Returns sleep quality indicators for the last 7 logs
  Future<List<double>> getWeeklySleepQuality(String userId) async {
    final List<double> quality = [];
    try {
      final sleepLogs = await _dbService.getLocalSleepLogs(userId);
      sleepLogs.sort((a, b) => a.loggedAt.compareTo(b.loggedAt));
      final recent = sleepLogs.take(7);
      for (final log in recent) {
        quality.add(log.calculatedQuality.toDouble());
      }
    } catch (_) {}

    // Pad default values
    while (quality.length < 7) {
      quality.add(7.0);
    }
    return quality;
  }

  // Returns water logged indicators for the last 7 logs
  Future<List<double>> getWeeklyWaterLogged(String userId) async {
    final List<double> water = [];
    try {
      final waterLogs = await _dbService.getLocalWaterLogs(userId);
      waterLogs.sort((a, b) => a.loggedAt.compareTo(b.loggedAt));
      final recent = waterLogs.take(7);
      for (final log in recent) {
        water.add(log.glasses.toDouble());
      }
    } catch (_) {}

    // Pad default values
    while (water.length < 7) {
      water.add(6.0);
    }
    return water;
  }

  String _getDayOfWeekName(int weekday) {
    switch (weekday) {
      case 1: return 'Mon';
      case 2: return 'Tue';
      case 3: return 'Wed';
      case 4: return 'Thu';
      case 5: return 'Fri';
      case 6: return 'Sat';
      case 7: return 'Sun';
      default: return '';
    }
  }
}
