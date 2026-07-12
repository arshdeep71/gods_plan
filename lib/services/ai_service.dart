import 'dart:convert';
import '../services/database_service.dart';
import '../models/food_log.dart';
import '../models/sleep_log.dart';
import '../models/addiction_log.dart';
import '../models/nutrition_profile.dart';

class AiService {
  final DatabaseService _dbService = DatabaseService();

  // Scan local data and return active heuristic tip blocks
  Future<List<String>> generateHeuristicTips(String userId) async {
    final List<String> tips = [];
    final now = DateTime.now();
    final yesterday = now.subtract(const Duration(days: 1));

    // 1. Protein Intake Check
    try {
      final foodLogs = await _dbService.getLocalFoodLogs(userId);
      // Filter yesterday's logs
      final yesterdayLogs = foodLogs.where((f) =>
          f.loggedAt.year == yesterday.year &&
          f.loggedAt.month == yesterday.month &&
          f.loggedAt.day == yesterday.day);

      double yesterdayProtein = yesterdayLogs.fold(0.0, (sum, f) => sum + f.protein);

      // Fetch target protein
      double targetProtein = 150.0; // Default
      final rawProfile = _dbService.settingsBox.get('nutrition_profile');
      if (rawProfile != null) {
        final Map<String, dynamic> jsonMap = Map<String, dynamic>.from(
          rawProfile is String ? jsonDecode(rawProfile) : rawProfile,
        );
        final profile = NutritionProfile.fromJson(jsonMap);
        targetProtein = profile.targetProtein.toDouble();
      }

      if (yesterdayProtein < (0.8 * targetProtein)) {
        tips.add(
          "Your protein intake was low yesterday (${yesterdayProtein.toStringAsFixed(0)}g logged vs ${targetProtein.toStringAsFixed(0)}g target). Consider adding eggs, Greek yogurt, or chicken breast to your meals today. 🍗"
        );
      }
    } catch (_) {}

    // 2. Sleep Quality Decline Check
    try {
      final sleepLogs = await _dbService.getLocalSleepLogs(userId);
      // Sort sleep logs descending
      sleepLogs.sort((a, b) => b.loggedAt.compareTo(a.loggedAt));

      if (sleepLogs.length >= 3) {
        final double scoreToday = sleepLogs[0].qualityScore.toDouble();
        final double scorePrev = sleepLogs[2].qualityScore.toDouble();
        
        if (scorePrev - scoreToday >= 2.0) {
          tips.add(
            "Your sleep quality has declined. The data shows screen time was logged close to bedtime on these days. Try placing your phone away 30 minutes before sleep tonight. 😴"
          );
        }
      }
    } catch (_) {}

    // 3. Urge Window Check (clusters between 3:00 PM and 5:00 PM)
    try {
      final addictionLogs = await _dbService.getLocalAddictionLogs(userId);
      int afternoonCravings = 0;

      for (final log in addictionLogs) {
        final hour = log.loggedAt.hour;
        if (hour >= 15 && hour <= 17 && log.urgeLevel >= 3) {
          afternoonCravings++;
        }
      }

      if (afternoonCravings >= 2) {
        tips.add(
          "You commonly experience cravings between 3:00 PM and 5:00 PM. Plan a workout session or call a friend during this window today to stay strong. 🔥"
        );
      }
    } catch (_) {}

    // Fallback if no triggers fired
    if (tips.isEmpty) {
      tips.add("Consistency is power! All trackers are in healthy parameters. Keep your momentum going today. 🚀");
      tips.add("Remember to check your task checklist today. Small daily wins build massive results. 🎯");
    }

    return tips;
  }

  // Local Offline Chatbot Responder
  String getChatResponse(String input, String userId) {
    final query = input.toLowerCase();

    if (query.contains("relapse") || query.contains("urge") || query.contains("fap") || query.contains("relapsed")) {
      return "That's okay. Each attempt makes you stronger. Let's analyze what triggered it:\n"
             "- What time of day did it happen?\n"
             "- What were you feeling right before (boredom, stress, tiredness)?\n"
             "- What can we do differently next time (moving phone away, taking a cold shower)?\n"
             "You've got this! Let's get back to Day 1 and stay focused! 💪";
    }

    if (query.contains("protein") || query.contains("food") || query.contains("diet") || query.contains("eat")) {
      return "I see you're tracking your protein. Here are 5 quick sources to hit your targets:\n"
             "1. Eggs (approx. 6g protein each)\n"
             "2. Greek yogurt (approx. 17g per 200g bowl)\n"
             "3. Chicken breast (approx. 31g per 100g cooked)\n"
             "4. Lentils (approx. 9g per cooked cup)\n"
             "5. Paneer / Cottage cheese (approx. 18g per 100g)\n"
             "Try adding one of these to your next meal or snack! 🍗";
    }

    if (query.contains("sleep") || query.contains("tired") || query.contains("night")) {
      return "Sleep quality dictates your willpower. Here are 3 key habits for restful sleep:\n"
             "- No screens 30 minutes before closing your eyes.\n"
             "- Keep the bedroom completely dark and cool.\n"
             "- Try reading a physical book to trigger natural melatonin production.\n"
             "Wind down early tonight! 😴";
    }

    if (query.contains("study") || query.contains("learn") || query.contains("german") || query.contains("subject")) {
      return "To learn complex skills efficiently:\n"
             "- Study in 25-minute Pomodoro blocks with 5-minute rests.\n"
             "- Review key concepts right before sleep to improve long-term memory retention.\n"
             "- Eliminate all phone notifications during practice. Consistent daily focus wins! 📚";
    }

    if (query.contains("money") || query.contains("save") || query.contains("finance") || query.contains("budget")) {
      return "Small savings add up to big achievements. To stay on track:\n"
             "- Categorize every single transaction immediately.\n"
             "- Ask yourself if impulse buys are necessary before tapping pay.\n"
             "- Keep your eyes fixed on your savings goal milestones! 💰";
    }

    return "Good day! I'm scanning your daily timeline. Focus on completing your active habits, logging meals, and maintaining your clean streaks. Let me know if you need specific advice on sleep, exercise, nutrition, discipline, or finance! 🤖";
  }
}
