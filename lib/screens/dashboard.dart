import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../screens/tasks/streak_view.dart';
import '../providers/auth_provider.dart';
import '../providers/task_provider.dart';
import '../services/database_service.dart';
import '../utils/colors.dart';
import 'auth/login_screen.dart';
import 'tasks/tasks_view.dart';
import 'exercise/exercise_view.dart';
import 'sleep/sleep_view.dart';
import 'nutrition/nutrition_view.dart';
import 'addiction/addiction_view.dart';
import 'finance/finance_view.dart';
import '../providers/health_provider.dart';
import '../providers/nutrition_provider.dart';
import '../providers/addiction_provider.dart';
import '../providers/finance_provider.dart';
import '../providers/learning_provider.dart';
import '../providers/social_provider.dart';
import 'learning/learning_view.dart';
import 'social/social_view.dart';
import 'widgets/ai_coach_card.dart';
import 'settings/app_lock_view.dart';
import '../services/analytics_service.dart';
import 'dashboard/badges_view.dart';
import 'dashboard/analytics_view.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/sync_service.dart';


class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final DatabaseService _dbService = DatabaseService();
  final AnalyticsService _analyticsService = AnalyticsService();
  
  // Navigation & Tabs state
  int _selectedIndex = 0; // 0 = Home, 1 = Tasks, 2 = Placeholder (+), 3 = Stats/Badges, 4 = Settings
  int _activeTab = 0; // 0 = Overview, 1 = Productivity/Trackers

  int _totalDays = 0;
  int _daysElapsed = 0;
  int _daysRemaining = 0;
  double _progressPercentage = 0.0;
  int _totalXp = 0;

  // Real-time synchronization channels
  final List<RealtimeChannel> _realtimeSyncChannels = [];

  // Real-time calendar & tasks filter state
  late DateTime _selectedCalendarDay;
  late DateTime _currentWeekStart;

  DateTime getMondayOfCurrentWeek(DateTime date) {
    int difference = date.weekday - DateTime.monday;
    return DateTime(date.year, date.month, date.day).subtract(Duration(days: difference));
  }


  @override
  void initState() {
    super.initState();
    _selectedCalendarDay = DateTime.now();
    _currentWeekStart = getMondayOfCurrentWeek(DateTime.now());
    _calculateTimeline();
    _loadXp();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final user = Provider.of<AuthProvider>(context, listen: false).user;
      if (user != null) {
        Provider.of<HealthProvider>(context, listen: false).fetchHealthData(user.id);
        Provider.of<NutritionProvider>(context, listen: false).fetchNutritionData(user.id);
        Provider.of<AddictionProvider>(context, listen: false).fetchAddictionLogs(user.id);
        Provider.of<FinanceProvider>(context, listen: false).fetchTransactions(user.id);
        Provider.of<LearningProvider>(context, listen: false).fetchLearningData(user.id);
        Provider.of<SocialProvider>(context, listen: false).fetchContacts(user.id);
        Provider.of<TaskProvider>(context, listen: false).fetchTasks(user.id);
        
        _setupRealtimeSyncListeners(user.id);
      }
    });
  }

  @override
  void dispose() {
    for (final channel in _realtimeSyncChannels) {
      channel.unsubscribe();
    }
    super.dispose();
  }

  void _setupRealtimeSyncListeners(String userId) {
    // Unsubscribe existing first
    for (final channel in _realtimeSyncChannels) {
      channel.unsubscribe();
    }
    _realtimeSyncChannels.clear();

    final client = Supabase.instance.client;
    final syncService = SyncService();

    final tables = [
      'tasks',
      'task_completions',
      'task_exceptions',
      'workouts',
      'sleep_logs',
      'food_logs',
      'water_logs',
      'addiction_logs',
      'finance_transactions',
      'social_contacts',
      'learning_subjects',
      'study_logs',
      'goals'
    ];

    for (final table in tables) {
      final channelName = 'public:$table:$userId';
      final channel = client.channel(channelName).onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: table,
        filter: PostgresChangeFilter(
          type: PostgresChangeFilterType.eq,
          column: 'user_id',
          value: userId,
        ),
        callback: (payload) async {
          // Trigger pull sync
          await syncService.sync(userId);
          // Refresh local providers
          _refreshAllProviders(userId);
        },
      );
      channel.subscribe();
      _realtimeSyncChannels.add(channel);
    }

    // Subscribe to profiles table with 'id' column filter
    final profileChannel = client.channel('public:profiles:$userId').onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'profiles',
      filter: PostgresChangeFilter(
        type: PostgresChangeFilterType.eq,
        column: 'id',
        value: userId,
      ),
      callback: (payload) async {
        await syncService.sync(userId);
        _refreshAllProviders(userId);
      },
    );
    profileChannel.subscribe();
    _realtimeSyncChannels.add(profileChannel);
  }

  void _refreshAllProviders(String userId) {
    if (!mounted) return;
    _calculateTimeline();
    Provider.of<AuthProvider>(context, listen: false).loadUserProfile();
    Provider.of<TaskProvider>(context, listen: false).fetchTasks(userId);
    Provider.of<HealthProvider>(context, listen: false).fetchHealthData(userId);
    Provider.of<NutritionProvider>(context, listen: false).fetchNutritionData(userId);
    Provider.of<AddictionProvider>(context, listen: false).fetchAddictionLogs(userId);
    Provider.of<FinanceProvider>(context, listen: false).fetchTransactions(userId);
    Provider.of<LearningProvider>(context, listen: false).fetchLearningData(userId);
    Provider.of<SocialProvider>(context, listen: false).fetchContacts(userId);
  }

  void _showEditProfileDialog() {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final user = authProvider.user;
    if (user == null) return;

    final controller = TextEditingController(text: authProvider.username);
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: AppColors.surface,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              title: const Text(
                "Edit Profile Name",
                style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold),
              ),
              content: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      "Your Account Information",
                      style: TextStyle(color: AppColors.textSecondary, fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),
                    // Read-only email field
                    TextFormField(
                      initialValue: user.email,
                      enabled: false,
                      style: const TextStyle(color: AppColors.textMuted),
                      decoration: InputDecoration(
                        labelText: "Email Address",
                        labelStyle: const TextStyle(color: AppColors.textMuted),
                        filled: true,
                        fillColor: AppColors.background.withOpacity(0.5),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                        prefixIcon: const Icon(Icons.email_outlined, color: AppColors.textMuted),
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Username editable field
                    TextFormField(
                      controller: controller,
                      style: const TextStyle(color: AppColors.textPrimary),
                      decoration: InputDecoration(
                        labelText: "Username / Name",
                        labelStyle: const TextStyle(color: AppColors.textSecondary),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: AppColors.border)),
                        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: AppColors.primary)),
                        errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Colors.redAccent)),
                        focusedErrorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Colors.redAccent)),
                        prefixIcon: const Icon(Icons.person_outline_rounded, color: AppColors.textSecondary),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return "Name cannot be empty";
                        }
                        return null;
                      },
                    ),
                  ],
                ),
              ),
              actionsPadding: const EdgeInsets.only(bottom: 20, right: 20, left: 20),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text("Cancel", style: TextStyle(color: AppColors.textSecondary)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  ),
                  onPressed: () async {
                    if (formKey.currentState!.validate()) {
                      final newName = controller.text.trim();
                      Navigator.pop(context);
                      
                      final success = await authProvider.updateUsername(newName);
                      if (context.mounted) {
                        if (success) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text("Profile name updated successfully!"),
                              backgroundColor: AppColors.success,
                            ),
                          );
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text("Failed to update name: ${authProvider.errorMessage}"),
                              backgroundColor: AppColors.error,
                            ),
                          );
                        }
                      }
                    }
                  },
                  child: const Text("Save Changes", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  String _getCurrentFormattedDate() {
    final now = DateTime.now();
    final weekdays = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return "${weekdays[now.weekday - 1]}, ${now.day} ${months[now.month - 1]}";
  }

  void _calculateTimeline() {
    final dates = _dbService.getLocalGoalDates();
    if (dates == null) return;

    final start = DateTime.parse(dates['start_date']!);
    final end = DateTime.parse(dates['end_date']!);
    final now = DateTime.now();

    final total = end.difference(start).inDays;
    final elapsed = now.difference(start).inDays;

    setState(() {
      _totalDays = total;
      _daysElapsed = elapsed.clamp(0, total);
      _daysRemaining = (total - elapsed).clamp(0, total);
      _progressPercentage = total > 0 ? (elapsed / total * 100).clamp(0.0, 100.0) : 0.0;
    });
  }

  Future<void> _loadXp() async {
    final user = Provider.of<AuthProvider>(context, listen: false).user;
    if (user != null) {
      final xp = await _analyticsService.calculateTotalXp(user.id);
      if (mounted) {
        setState(() {
          _totalXp = xp;
        });
      }
    }
  }

  Future<void> _handleLogout() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    await authProvider.logOut();
    
    if (mounted) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (route) => false,
      );
    }
  }

  // Get weekly checklist task completed count for bar chart
  List<Map<String, dynamic>> _getWeeklyChartData(List<dynamic> tasks) {
    final days = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
    final now = DateTime.now();
    final List<Map<String, dynamic>> data = [];
    
    for (int i = 6; i >= 0; i--) {
      final date = now.subtract(Duration(days: i));
      final dayLabel = days[(date.weekday - 1) % 7];
      
      final count = tasks.where((t) {
        if (!t.isCompleted) return false;
        final compDate = t.updatedAt;
        return compDate.year == date.year &&
               compDate.month == date.month &&
               compDate.day == date.day;
      }).length;
      
      data.add({
        'day': dayLabel,
        'count': count,
      });
    }
    return data;
  }

  // Show bottom sheet to log anything instantly
  void _showQuickLogSheet() {
    final user = Provider.of<AuthProvider>(context, listen: false).user;
    if (user == null) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.background,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    "Quick Log Activities",
                    style: TextStyle(color: AppColors.textPrimary, fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: AppColors.textSecondary),
                    onPressed: () => Navigator.pop(context),
                  )
                ],
              ),
              const SizedBox(height: 20),
              GridView.count(
                shrinkWrap: true,
                crossAxisCount: 4,
                mainAxisSpacing: 16,
                crossAxisSpacing: 16,
                children: [
                  _buildQuickLogItem(context, Icons.playlist_add_check_rounded, "Add Task", AppColors.primary, () {
                    Navigator.pop(context);
                    setState(() => _selectedIndex = 1);
                  }),
                  _buildQuickLogItem(context, Icons.directions_run_rounded, "Workout", AppColors.info, () {
                    Navigator.pop(context);
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const ExerciseView()));
                  }),
                  _buildQuickLogItem(context, Icons.bedtime_rounded, "Sleep", AppColors.secondary, () {
                    Navigator.pop(context);
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const SleepView()));
                  }),
                  _buildQuickLogItem(context, Icons.restaurant_rounded, "Nutrition", AppColors.success, () {
                    Navigator.pop(context);
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const NutritionView()));
                  }),
                  _buildQuickLogItem(context, Icons.local_fire_department_rounded, "Sobriety", AppColors.error, () {
                    Navigator.pop(context);
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const AddictionView()));
                  }),
                  _buildQuickLogItem(context, Icons.payments_rounded, "Finance", Colors.green, () {
                    Navigator.pop(context);
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const FinanceView()));
                  }),
                  _buildQuickLogItem(context, Icons.menu_book_rounded, "Study", Colors.blue, () {
                    Navigator.pop(context);
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const LearningView()));
                  }),
                  _buildQuickLogItem(context, Icons.people_alt_rounded, "Social", AppColors.accent, () {
                    Navigator.pop(context);
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const SocialView()));
                  }),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildQuickLogItem(BuildContext context, IconData icon, String label, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: color.withOpacity(0.2)),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: const TextStyle(color: AppColors.textSecondary, fontSize: 10, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          )
        ],
      ),
    );
  }

  void _showCongratsDialog(BuildContext context, TaskProvider taskProvider) {
    taskProvider.clearCongrats();
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        final authProvider = Provider.of<AuthProvider>(context, listen: false);
        final currentStreak = taskProvider.calculateCurrentStreak(authProvider.user?.id ?? '');
        
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 24),
          child: Container(
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              color: const Color(0xFF1C1C1E),
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TweenAnimationBuilder<double>(
                  tween: Tween<double>(begin: 0.0, end: 1.0),
                  duration: const Duration(milliseconds: 600),
                  curve: Curves.elasticOut,
                  builder: (context, value, child) {
                    return Transform.scale(
                      scale: value,
                      child: child,
                    );
                  },
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.orange.withOpacity(0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.local_fire_department_rounded,
                      color: Colors.orange,
                      size: 72,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  "CONGRATULATIONS!",
                  style: TextStyle(
                    color: AppColors.accent,
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.5,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  "Goal Reached! You have successfully completed at least 80% of your tasks for today!",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppColors.textPrimary.withOpacity(0.9),
                    fontSize: 15,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.orange.withOpacity(0.3)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.local_fire_department_rounded, color: Colors.orange, size: 24),
                      const SizedBox(width: 8),
                      Text(
                        "$currentStreak Day Streak!",
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 28),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.accent,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      elevation: 0,
                    ),
                    onPressed: () {
                      Navigator.pop(context);
                    },
                    child: const Text(
                      "Awesome!",
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showXpNotification(BuildContext context, TaskProvider taskProvider) {
    final amount = taskProvider.lastAwardedXpAmount;
    taskProvider.clearXpAnimation();
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: const BoxDecoration(
                color: Colors.amber,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.star_rounded, color: Colors.black, size: 18),
            ),
            const SizedBox(width: 12),
            Text(
              "+$amount XP Earned!",
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
            ),
          ],
        ),
        backgroundColor: Colors.indigo,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;
    final username = context.watch<AuthProvider>().username;
    final taskProvider = context.watch<TaskProvider>();

    if (taskProvider.shouldShowCongrats || taskProvider.shouldShowXpAnimation) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (taskProvider.shouldShowCongrats) {
          _showCongratsDialog(context, taskProvider);
        } else if (taskProvider.shouldShowXpAnimation) {
          _showXpNotification(context, taskProvider);
        }
      });
    }

    // Build the bottom nav pages
    final List<Widget> pages = [
      _buildHomeDashboard(context, username),
      const TasksView(isTab: true),
      const SizedBox.shrink(), // Placeholder for central button
      user != null ? BadgesView(userId: user.id, username: username) : const SizedBox.shrink(),
      _buildSettingsTab(context, username),
    ];

    return Scaffold(
      backgroundColor: AppColors.background,
      extendBody: true,
      body: SafeArea(
        bottom: false,
        child: pages[_selectedIndex],
      ),
      bottomNavigationBar: _buildBottomNavigationBar(),
    );
  }

  // Redesigned main home dashboard layout strictly showing Current Week data
  Widget _buildHomeDashboard(BuildContext context, String username) {
    final taskProvider = context.watch<TaskProvider>();
    final user = context.read<AuthProvider>().user;
    
    // Calculate Today's stats
    final activeToday = taskProvider.activeTasks.length;
    final completedToday = taskProvider.completedTasks.length;
    final totalToday = activeToday + completedToday;
    final todayProgress = totalToday > 0 ? (completedToday / totalToday * 100).toInt() : 0;
    
    // Calculate Current Week stats (Monday to Sunday)
    final now = DateTime.now();
    final currentDayOfWeek = now.weekday; // 1 = Monday, 7 = Sunday
    final startOfWeek = now.subtract(Duration(days: currentDayOfWeek - 1));
    
    int weeklyCompleted = 0;
    int weeklyPending = 0;
    int weeklyMissed = 0;
    
    for (int i = 0; i < 7; i++) {
      final checkDate = startOfWeek.add(Duration(days: i));
      final dateString = "${checkDate.year}-${checkDate.month.toString().padLeft(2, '0')}-${checkDate.day.toString().padLeft(2, '0')}";
      
      final activeForDay = taskProvider.getActiveTasksForDate(checkDate);
      final completedForDay = taskProvider.getCompletedTasksForDate(checkDate);
      
      weeklyCompleted += completedForDay.length;
      
      if (checkDate.isBefore(DateTime(now.year, now.month, now.day))) {
        weeklyMissed += activeForDay.length;
      } else {
        weeklyPending += activeForDay.length;
      }
    }
    
    final totalWeekly = weeklyCompleted + weeklyPending + weeklyMissed;
    final weeklyProgress = totalWeekly > 0 ? (weeklyCompleted / totalWeekly * 100).toInt() : 0;
    
    // Calculate Global Streak
    final currentStreak = user != null ? taskProvider.calculateCurrentStreak(user.id) : 0;

    final endOfWeek = startOfWeek.add(const Duration(days: 6));
    final monthNames = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"];
    final weekString = "${startOfWeek.day} ${monthNames[startOfWeek.month - 1]} - ${endOfWeek.day} ${monthNames[endOfWeek.month - 1]}";

    // Compute dynamic greeting based on system time
    final hour = DateTime.now().hour;
    String greeting = "Good Morning";
    if (hour >= 12 && hour < 17) {
      greeting = "Good Afternoon";
    } else if (hour >= 17 || hour < 4) {
      greeting = "Good Evening";
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.only(left: 24.0, right: 24.0, top: 40.0, bottom: 120.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Good Morning Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "$greeting,\n$username",
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  height: 1.2,
                ),
              ),
              GestureDetector(
                onTap: () {
                  if (user != null) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => BadgesView(userId: user.id, username: username)),
                    );
                  }
                },
                child: Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.primary, width: 2),
                    gradient: AppColors.primaryGradient,
                  ),
                  child: Center(
                    child: Text(
                      username.isNotEmpty ? username[0].toUpperCase() : 'U',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 20),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 40),

          // Current Week Banner
          Container(
            padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF2C2C2E), Color(0xFF1C1C1E)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: AppColors.border),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.4),
                  blurRadius: 15,
                  offset: const Offset(0, 8),
                )
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      "Current Week",
                      style: TextStyle(color: AppColors.textSecondary, fontSize: 14, fontWeight: FontWeight.w600),
                    ),
                    Text(
                      weekString,
                      style: const TextStyle(color: AppColors.textPrimary, fontSize: 14, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      "Progress",
                      style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 24, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      "$weeklyProgress%",
                      style: const TextStyle(color: AppColors.primary, fontSize: 28, fontWeight: FontWeight.w900),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: totalWeekly > 0 ? (weeklyCompleted / totalWeekly) : 0.0,
                    minHeight: 12,
                    backgroundColor: Colors.white.withOpacity(0.1),
                    valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Stats Grid
          Row(
            children: [
              Expanded(
                child: _buildStatCard("Today's Tasks", "$completedToday / $totalToday", Icons.check_circle_outline, AppColors.primary),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildStatCard("Today's Progress", "$todayProgress%", Icons.trending_up, Colors.greenAccent),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildStatCard("Weekly Completed", "$weeklyCompleted", Icons.done_all, Colors.blueAccent),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildStatCard("Pending", "$weeklyPending", Icons.hourglass_empty, Colors.orangeAccent),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildStatCard("Missed", "$weeklyMissed", Icons.close, Colors.redAccent),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const StreakView()),
                    );
                  },
                  child: _buildStatCard("Current Streak", "$currentStreak Days", Icons.local_fire_department, Colors.orange),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1C1C1E),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 16),
          Text(
            value,
            style: const TextStyle(color: AppColors.textPrimary, fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: const TextStyle(color: AppColors.textSecondary, fontSize: 13, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }


  Widget _buildSettingsTab(BuildContext context, String username) {
    final user = Provider.of<AuthProvider>(context, listen: false).user;
    return SingleChildScrollView(
      padding: const EdgeInsets.only(left: 24.0, right: 24.0, top: 24.0, bottom: 120.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Settings",
            style: TextStyle(color: AppColors.textPrimary, fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 24),
          
          // Profile Details
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: [
                Container(
                  width: 50,
                  height: 50,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: AppColors.primaryGradient,
                  ),
                  child: Center(
                    child: Text(
                      username.isNotEmpty ? username[0].toUpperCase() : 'U',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 20),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        username,
                        style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        user?.email ?? "No Email connected",
                        style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.edit_rounded, color: AppColors.primaryLight, size: 20),
                  tooltip: "Edit Profile Name",
                  onPressed: _showEditProfileDialog,
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Settings Options
          const Text("Account Details", style: TextStyle(color: AppColors.textSecondary, fontSize: 13, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
          const SizedBox(height: 12),
          _buildSettingsTile(
            Icons.person_rounded,
            "Edit Profile Name",
            "Change your profile display name",
            _showEditProfileDialog,
          ),
          const SizedBox(height: 16),
          const Text("Security & Setup", style: TextStyle(color: AppColors.textSecondary, fontSize: 13, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
          const SizedBox(height: 12),
          _buildSettingsTile(
            Icons.lock_rounded,
            "App Lock PIN Code",
            "Configure or update your lock passcode",
            () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AppLockView())),
          ),
          const SizedBox(height: 16),
          _buildSettingsTile(
            Icons.restart_alt_rounded,
            "Clear Local Cache",
            "Reset all stored databases on this device",
            () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  backgroundColor: AppColors.background,
                  title: const Text("Reset Cache", style: TextStyle(color: Colors.white)),
                  content: const Text("Are you absolutely sure you want to clear all local cache data? This action cannot be undone.", style: TextStyle(color: AppColors.textSecondary)),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Cancel")),
                    TextButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text("Reset", style: TextStyle(color: Colors.red)),
                    ),
                  ],
                ),
              );

              if (confirm == true) {
                await _dbService.clearLocalCache();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Databases cleared successfully. Resetting application...")),
                  );
                  _handleLogout();
                }
              }
            },
          ),
          const SizedBox(height: 16),
          _buildSettingsTile(
            Icons.logout_rounded,
            "Log Out Account",
            "Disconnect your current session",
            _handleLogout,
            textColor: AppColors.error,
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsTile(IconData icon, String title, String subtitle, VoidCallback onTap, {Color? textColor}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Icon(icon, color: textColor ?? AppColors.textPrimary, size: 24),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(color: textColor ?? AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                  ),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios_rounded, color: AppColors.textMuted, size: 14),
          ],
        ),
      ),
    );
  }

  // Draw navigation bar matching the inspiration mockup style
  Widget _buildBottomNavigationBar() {
    return SafeArea(
      top: false,
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(36),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.35),
              blurRadius: 15,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(36),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
              decoration: BoxDecoration(
                color: const Color(0xFF101012).withOpacity(0.65),
                borderRadius: BorderRadius.circular(36),
                border: Border.all(
                  color: Colors.white.withOpacity(0.08),
                  width: 1.0,
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildNavItem(0, Icons.grid_view_rounded, "Summary"),
                  _buildNavItem(1, Icons.assignment_turned_in_rounded, "Tasks"),
                  
                  // Central plus log item
                  GestureDetector(
                    onTap: _showQuickLogSheet,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.add_rounded,
                            color: Colors.white.withOpacity(0.8),
                            size: 24,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            "Log",
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.8),
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  
                  _buildNavItem(3, Icons.emoji_events_rounded, "Awards"),
                  _buildNavItem(4, Icons.settings_rounded, "Settings"),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(int index, IconData icon, String label) {
    final isSelected = _selectedIndex == index;
    return GestureDetector(
      onTap: () => setState(() => _selectedIndex = index),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF2C2C2E) : Colors.transparent,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: isSelected ? AppColors.accent : Colors.white,
              size: 24,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? AppColors.accent : Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

}
