import 'dart:math';

enum NotificationTemplateType {
  warning15m,
  warning5m,
  warning1m,
  startTime,
  motivation,
  streak,
  completion,
}

class NotificationTemplate {
  final String title;
  final String body;

  const NotificationTemplate({required this.title, required this.body});
}

class NotificationTemplates {
  static final Random _random = Random();

  static const List<NotificationTemplate> warning15mTemplates = [
    NotificationTemplate(title: "🏋️ Time to prepare", body: "Starts in 15 minutes. Stay consistent 💪"),
    NotificationTemplate(title: "📚 Your future self will thank you", body: "15 minutes away. Get your space ready! 🎯"),
    NotificationTemplate(title: "⚡ 15-Minute Nudge", body: "Almost time to focus. Finish what you're doing ⏰"),
    NotificationTemplate(title: "🎯 Setting up for success", body: "Your task begins in 15 minutes. Let's do this! 🚀"),
    NotificationTemplate(title: "💡 Clear your mind", body: "15 minutes until your scheduled session 🧠"),
    NotificationTemplate(title: "🔥 Keep the momentum", body: "15 minutes out. Ready to conquer your target? 🏆"),
  ];

  static const List<NotificationTemplate> warning5mTemplates = [
    NotificationTemplate(title: "🚀 Momentum > Motivation", body: "Starts in 5 minutes. Take a breath and focus! 💨"),
    NotificationTemplate(title: "🔥 Keep today's streak alive", body: "5 minutes left! Greatness requires discipline 🌟"),
    NotificationTemplate(title: "⏰ Don't miss this", body: "Only 5 minutes away. Step up to the baseline 🏁"),
    NotificationTemplate(title: "💪 One task closer", body: "5 minutes warning! Every step shapes your progress 📈"),
    NotificationTemplate(title: "⚡ Zero excuses", body: "Starting in 5 minutes. Ready when you are 👊"),
    NotificationTemplate(title: "🎯 Focus zone loading", body: "5 minutes to launch. Block out distractions 🎧"),
  ];

  static const List<NotificationTemplate> warning1mTemplates = [
    NotificationTemplate(title: "🚨 1 Minute Warning!", body: "Starts in 1 minute. Lock in now! 🔒"),
    NotificationTemplate(title: "⚡ Ready... Set...", body: "1 minute left! Time to make it count 🏁"),
    NotificationTemplate(title: "🎯 Final Countdown", body: "Starting in 60 seconds. Let's go! 🚀"),
    NotificationTemplate(title: "🔥 Show up for yourself", body: "1 minute away. Discipline is freedom 💪"),
  ];

  static const List<NotificationTemplate> startTimeTemplates = [
    NotificationTemplate(title: "🚀 It's Time!", body: "Your task starts right now. You got this! 🔥"),
    NotificationTemplate(title: "🎯 Let's finish this one", body: "Time to dive in and execute 💼"),
    NotificationTemplate(title: "🏆 Greatness begins now", body: "Action beats intention every time. Start now! ✨"),
    NotificationTemplate(title: "🔥 Show up & execute", body: "Your session has started. Focus on the task ahead 🎯"),
    NotificationTemplate(title: "✨ Make today count", body: "Time to complete your task and level up 🌟"),
  ];

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

  /// Get a random template for a given offset in minutes (15, 5, 1, or 0)
  static NotificationTemplate getCountdownTemplate(int offsetMinutes, String taskTitle) {
    List<NotificationTemplate> list;
    if (offsetMinutes == 15) {
      list = warning15mTemplates;
    } else if (offsetMinutes == 5) {
      list = warning5mTemplates;
    } else if (offsetMinutes == 1) {
      list = warning1mTemplates;
    } else {
      list = startTimeTemplates;
    }

    final selected = list[_random.nextInt(list.length)];
    // Customize body or title with task title if desirable
    return NotificationTemplate(
      title: "${selected.title} • $taskTitle",
      body: selected.body,
    );
  }

  /// Get a random motivation template
  static NotificationTemplate getRandomMotivation() {
    return motivationTemplates[_random.nextInt(motivationTemplates.length)];
  }
}
