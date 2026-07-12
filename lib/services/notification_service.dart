import 'package:flutter/material.dart';
import '../utils/colors.dart';

class NotificationService {
  // Return notification body for a specific daily schedule alert
  Map<String, String> getNotificationForTime(String timeKey, int remainingDays) {
    switch (timeKey) {
      case '6:00 AM':
        return {
          'title': '🌅 Morning Focus',
          'body': 'Good morning! $remainingDays days left to achieve your goals!\n\nToday\'s focus:\n• Exercise (30 min)\n• Study practice (60 min)\n• Complete all active tasks\n• Meet your budget goals\n\nYou\'ve got this! 🚀'
        };
      case '5:00 PM':
        return {
          'title': '🏃‍♂️ Exercise Time',
          'body': 'Exercise time! 30 minutes to complete your daily activity target and maintain your clean streak.'
        };
      case '6:00 PM':
        return {
          'title': '📚 Study Focus',
          'body': 'Study practice time! Open your active subject setup and log at least 45 minutes of learning.'
        };
      case '7:00 PM':
        return {
          'title': '🥗 Dinner & Macros Log',
          'body': 'Macro check! Remember to log your dinner foods and hit your protein target today.'
        };
      case '8:00 PM':
        return {
          'title': '💤 Sleep Wind Down',
          'body': 'Wind down in 2 hours! Put away all electronic screens and prepare for deep rest.'
        };
      case '9:00 PM':
        return {
          'title': '🌙 Daily Summary',
          'body': 'Daily Summary\n\n✅ COMPLETED TODAY:\n✓ Task Checklist (75% completed)\n✓ Exercise logged\n✓ Study logs recorded\n✓ Water goal matched\n\nReady for tomorrow? Sleep tight! 😴'
        };
      default:
        return {
          'title': '🔔 Goal Tracker Reminder',
          'body': 'Stay consistent with your daily habit goals today!'
        };
    }
  }

  // Show a simulated native push notification as an in-app overlay dialog
  void showSimulatedPush(BuildContext context, String timeKey, int remainingDays) {
    final alert = getNotificationForTime(timeKey, remainingDays);

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: AppColors.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
            side: const BorderSide(color: AppColors.border),
          ),
          title: Row(
            children: [
              const Icon(Icons.notifications_active_rounded, color: AppColors.accent),
              const SizedBox(width: 12),
              Text(
                alert['title']!,
                style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          content: Text(
            alert['body']!,
            style: const TextStyle(color: AppColors.textSecondary, fontSize: 14, height: 1.4),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Dismiss", style: TextStyle(color: AppColors.textSecondary)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.accent),
              onPressed: () => Navigator.pop(context),
              child: const Text("Log Progress", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }
}
