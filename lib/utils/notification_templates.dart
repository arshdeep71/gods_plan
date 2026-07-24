import 'dart:math';

enum NotificationTemplateType {
  warning15m,
  warning5m,
  warning1m,
  startTime,
  motivation,
  instant,
  missedFollowUp,
}

class NotificationTemplate {
  final String title;
  final String body;

  const NotificationTemplate({required this.title, required this.body});
}

class NotificationTemplates {
  static final Random _random = Random();

  /// 15-minute warning: "🏋️ Gym begins in 15 minutes", "Time to prepare."
  static NotificationTemplate get15MinTemplate(String taskTitle) {
    return NotificationTemplate(
      title: "🏋️ $taskTitle begins in 15 minutes",
      body: "Time to prepare.",
    );
  }

  /// 5-minute warning: "🏋️ Gym starts in 5 minutes", "Almost time. Get ready 🚀"
  static NotificationTemplate get5MinTemplate(String taskTitle) {
    return NotificationTemplate(
      title: "🏋️ $taskTitle starts in 5 minutes",
      body: "Almost time. Get ready 🚀",
    );
  }

  /// 1-minute warning: "🏋️ Gym starts in 1 minute", "You're almost there."
  static NotificationTemplate get1MinTemplate(String taskTitle) {
    return NotificationTemplate(
      title: "🏋️ $taskTitle starts in 1 minute",
      body: "You're almost there.",
    );
  }

  /// Start reminder: "🎯 It's time for Gym", "Let's get started 💪"
  static NotificationTemplate getStartTemplate(String taskTitle) {
    return NotificationTemplate(
      title: "🎯 It's time for $taskTitle",
      body: "Let's get started 💪",
    );
  }

  /// Instant confirmation (0-3m or 3-20m away)
  static NotificationTemplate getInstantTemplate(String taskTitle, int remainingMinutes) {
    final timeStr = remainingMinutes <= 1 ? "1 minute" : "$remainingMinutes minutes";
    return NotificationTemplate(
      title: "🏋️ $taskTitle starts in $timeStr",
      body: "Get ready. Stay consistent 💪",
    );
  }

  /// Missed task follow-up (5 minutes post-start)
  static NotificationTemplate getMissedFollowUpTemplate(String taskTitle) {
    return NotificationTemplate(
      title: "⏳ Haven't started $taskTitle yet?",
      body: "You can still keep today's streak alive 💪",
    );
  }

  static const List<NotificationTemplate> motivationTemplates = [
    NotificationTemplate(title: "💪 Stay Consistent", body: "Keep going. Every small step counts towards your ultimate goal!"),
    NotificationTemplate(title: "🔥 Maintain Your Streak", body: "Don't break today's momentum. You are stronger than your excuses!"),
    NotificationTemplate(title: "🚀 Build Your Future", body: "You are building your future right now with every decision you make."),
    NotificationTemplate(title: "✨ One Task at a Time", body: "One single focus at a time. Quality over speed always wins."),
    NotificationTemplate(title: "🎯 Mindful Execution", body: "Focus deeply on what matters most today. Eliminate the noise."),
    NotificationTemplate(title: "🌟 Remember Your Why", body: "You started this journey for a reason. Keep pushing forward!"),
    NotificationTemplate(title: "🧠 Discipline equals Freedom", body: "Do what needs to be done, even when you don't feel like it."),
    NotificationTemplate(title: "📈 Progress Over Perfection", body: "Done is better than perfect. Take action today!"),
    NotificationTemplate(title: "⚡ Fuel Your Drive", body: "Small wins compound into massive results over time."),
    NotificationTemplate(title: "🏆 Champions Show Up", body: "Show up every day. Consistency is the ultimate competitive advantage."),
  ];

  static NotificationTemplate getCountdownTemplate(int offsetMinutes, String taskTitle) {
    if (offsetMinutes == 15) return get15MinTemplate(taskTitle);
    if (offsetMinutes == 5) return get5MinTemplate(taskTitle);
    if (offsetMinutes == 1) return get1MinTemplate(taskTitle);
    return getStartTemplate(taskTitle);
  }

  static NotificationTemplate getRandomMotivation() {
    return motivationTemplates[_random.nextInt(motivationTemplates.length)];
  }
}
