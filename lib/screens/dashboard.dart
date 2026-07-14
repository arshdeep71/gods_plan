import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
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


  @override
  void initState() {
    super.initState();
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
  }

  void _refreshAllProviders(String userId) {
    if (!mounted) return;
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

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;
    final username = context.watch<AuthProvider>().username;

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
      body: SafeArea(
        child: pages[_selectedIndex],
      ),
      bottomNavigationBar: _buildBottomNavigationBar(),
    );
  }

  // Redesigned main home dashboard layout
  Widget _buildHomeDashboard(BuildContext context, String username) {
    final user = context.read<AuthProvider>().user;
    final healthProvider = context.watch<HealthProvider>();
    final minutesToday = healthProvider.exerciseMinutesLoggedToday;
    final latestSleep = healthProvider.lastNightSleepLog;
    final nutritionProvider = context.watch<NutritionProvider>();
    final caloriesLogged = nutritionProvider.caloriesLoggedToday;
    final caloriesTarget = nutritionProvider.profile.targetCalories;
    final addictionProvider = context.watch<AddictionProvider>();
    final currentStreak = addictionProvider.currentStreak;
    final financeProvider = context.watch<FinanceProvider>();
    final todayNetSaved = financeProvider.todayNetSavings;
    final dailySavingsTarget = financeProvider.dailySavingsTarget;
    final learningProvider = context.watch<LearningProvider>();
    final socialProvider = context.watch<SocialProvider>();
    final hasNeglected = socialProvider.hasNeglectedContacts;
    
    final todayStudyMins = learningProvider.studyLogs
        .where((log) =>
            log.loggedAt.year == DateTime.now().year &&
            log.loggedAt.month == DateTime.now().month &&
            log.loggedAt.day == DateTime.now().day)
        .fold(0, (sum, log) => sum + log.durationMinutes);

    final taskProvider = context.watch<TaskProvider>();
    final completedCount = taskProvider.completedTasks.length;
    final totalCount = taskProvider.tasks.length;
    final progressVal = totalCount > 0 ? completedCount / totalCount : 0.0;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. App Bar Header (matches Derek Doyle style)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                "Dashboard",
                style: TextStyle(color: AppColors.textSecondary, fontSize: 14, fontWeight: FontWeight.bold, letterSpacing: 0.5),
              ),
              Row(
                children: [
                  Stack(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.notifications_outlined, color: AppColors.textPrimary, size: 24),
                        onPressed: () {
                          if (user != null) {
                            Navigator.push(context, MaterialPageRoute(builder: (_) => AnalyticsView(userId: user.id)));
                          }
                        },
                      ),
                      Positioned(
                        right: 12,
                        top: 12,
                        child: Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: Colors.redAccent,
                            shape: BoxShape.circle,
                          ),
                        ),
                      )
                    ],
                  ),
                  const SizedBox(width: 8),
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
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: AppColors.primary, width: 1.5),
                        gradient: AppColors.primaryGradient,
                      ),
                      child: Center(
                        child: Text(
                          username.isNotEmpty ? username[0].toUpperCase() : 'U',
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            "Hello,\n$username 👋",
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 32,
              fontWeight: FontWeight.bold,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 28),

          // 2. Custom Tabs Row (Overview & Productivity)
          Row(
            children: [
              GestureDetector(
                onTap: () => setState(() => _activeTab = 0),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  decoration: BoxDecoration(
                    color: _activeTab == 0 ? const Color(0xFF2E6BFF) : Colors.transparent,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    "Overview",
                    style: TextStyle(
                      color: _activeTab == 0 ? Colors.white : AppColors.textSecondary,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              GestureDetector(
                onTap: () => setState(() => _activeTab = 1),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  decoration: BoxDecoration(
                    color: _activeTab == 1 ? const Color(0xFF2E6BFF) : Colors.transparent,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    "Productivity",
                    style: TextStyle(
                      color: _activeTab == 1 ? Colors.white : AppColors.textSecondary,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // 3. Render Tab Content
          if (_activeTab == 0) ...[
            // Overview Content:
            // A. Priority Task Progress Card (Journey progress in purple/pink gradient)
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF8E2DE2), Color(0xFFF000FF)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFF000FF).withOpacity(0.2),
                    blurRadius: 15,
                    offset: const Offset(0, 5),
                  )
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Journey Goal Cycle Progress",
                    style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        "${_progressPercentage.toStringAsFixed(0)}% is completed",
                        style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        "Day $_daysElapsed of $_totalDays",
                        style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                      value: _totalDays > 0 ? (_daysElapsed / _totalDays) : 0.0,
                      minHeight: 8,
                      backgroundColor: Colors.white.withOpacity(0.25),
                      valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // B. Daily Goal card (Graphite background with Cyan Progress indicator on the right)
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "Daily Goal",
                          style: TextStyle(color: AppColors.textSecondary, fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 12),
                        // Green tag pill
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.success.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppColors.success.withOpacity(0.2)),
                          ),
                          child: Text(
                            "$completedCount/$totalCount tasks",
                            style: const TextStyle(color: AppColors.success, fontWeight: FontWeight.bold, fontSize: 12),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          totalCount > 0 
                              ? "You marked $completedCount/$totalCount tasks are done! 🎉"
                              : "No tasks created for today yet.",
                          style: const TextStyle(color: AppColors.textPrimary, fontSize: 14, fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 16),
                        GestureDetector(
                          onTap: () => setState(() => _selectedIndex = 1),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFF6B21A8), Color(0xFFC084FC)],
                              ),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: const Text(
                              "All Task",
                              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  // Progress ring
                  SizedBox(
                    width: 72,
                    height: 72,
                    child: Stack(
                      children: [
                        Center(
                          child: SizedBox(
                            width: 64,
                            height: 64,
                            child: CircularProgressIndicator(
                              value: progressVal,
                              strokeWidth: 8,
                              backgroundColor: AppColors.border,
                              valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF4BF3C3)),
                            ),
                          ),
                        ),
                        Center(
                          child: Container(
                            width: 44,
                            height: 44,
                            decoration: const BoxDecoration(
                              color: AppColors.border,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.shield_rounded, color: Color(0xFF4BF3C3), size: 20),
                          ),
                        )
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // C. Completed in the last 7 Days bar chart
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Completed in the last 7 Days",
                    style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  const SizedBox(height: 20),
                  _buildCustomWeeklyBarChart(taskProvider.tasks),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        "$completedCount Tasks Done",
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                      Text(
                        "${totalCount - completedCount} Active Tasks",
                        style: const TextStyle(color: Color(0xFFD586FF), fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // D. Quick stats box row
            Row(
              children: [
                _buildStatsBox("Total Task", "$totalCount", Colors.orangeAccent),
                const SizedBox(width: 12),
                _buildStatsBox("Completed", "$completedCount", Colors.greenAccent),
                const SizedBox(width: 12),
                _buildStatsBox("Active", "${totalCount - completedCount}", Colors.purpleAccent),
              ],
            ),
            const SizedBox(height: 20),
            
            if (user != null)
              AiCoachCard(
                userId: user.id,
                username: username,
                remainingDays: _daysRemaining,
              ),
          ] else ...[
            // Productivity Tab Content: All Individual Module Trackers
            // 1. Tasks Card
            _buildProductivityCard(
              Icons.playlist_add_check_rounded,
              "Tasks Checklist",
              "Manage checklist routines & streaks",
              AppColors.primary,
              () => Navigator.push(context, MaterialPageRoute(builder: (_) => const TasksView())),
            ),
            const SizedBox(height: 16),
            // 2. Exercise Card
            _buildProductivityCard(
              Icons.directions_run_rounded,
              "Exercise Tracker",
              "Active today: $minutesToday / 30 mins",
              AppColors.info,
              () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ExerciseView())),
            ),
            const SizedBox(height: 16),
            // 3. Sleep Card
            _buildProductivityCard(
              Icons.bedtime_rounded,
              "Sleep Tracker",
              latestSleep != null
                  ? "${latestSleep.durationHours.toStringAsFixed(1)} hrs logged last night"
                  : "No logs recorded last night",
              AppColors.secondary,
              () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SleepView())),
            ),
            const SizedBox(height: 16),
            // 4. Nutrition Card
            _buildProductivityCard(
              Icons.restaurant_rounded,
              "Nutrition & Water",
              "${caloriesLogged.toStringAsFixed(0)} / ${caloriesTarget.toStringAsFixed(0)} kcal logged today",
              AppColors.success,
              () => Navigator.push(context, MaterialPageRoute(builder: (_) => const NutritionView())),
            ),
            const SizedBox(height: 16),
            // 5. Sobriety Card
            _buildProductivityCard(
              Icons.local_fire_department_rounded,
              "Sobriety & Addiction",
              "Sober Streak: $currentStreak days 🔥",
              AppColors.error,
              () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AddictionView())),
            ),
            const SizedBox(height: 16),
            // 6. Finance Card
            _buildProductivityCard(
              Icons.payments_rounded,
              "Money & Savings",
              "Saved: ₹${todayNetSaved.toStringAsFixed(0)} / ₹${dailySavingsTarget.toStringAsFixed(0)} today",
              Colors.green,
              () => Navigator.push(context, MaterialPageRoute(builder: (_) => const FinanceView())),
            ),
            const SizedBox(height: 16),
            // 7. Study Card
            _buildProductivityCard(
              Icons.menu_book_rounded,
              "Learning & Skills",
              "Logged: $todayStudyMins mins studied today",
              Colors.blue,
              () => Navigator.push(context, MaterialPageRoute(builder: (_) => const LearningView())),
            ),
            const SizedBox(height: 16),
            // 8. Social Card
            _buildProductivityCard(
              Icons.people_alt_rounded,
              "Social & Friends",
              hasNeglected ? "⚠️ Neglected contact warning!" : "All contacts up to date",
              hasNeglected ? Colors.redAccent : AppColors.accent,
              () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SocialView())),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildProductivityCard(IconData icon, String title, String subtitle, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: color, size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios_rounded, color: AppColors.textMuted, size: 14),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsBox(String title, String count, Color accentColor) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: accentColor,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              count,
              style: const TextStyle(color: AppColors.textPrimary, fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 11, fontWeight: FontWeight.bold),
            )
          ],
        ),
      ),
    );
  }

  // Draw 7-day custom vertical bar chart
  Widget _buildCustomWeeklyBarChart(List<dynamic> tasks) {
    final data = _getWeeklyChartData(tasks);
    // Find max value for scaling
    int maxVal = 1;
    for (final e in data) {
      if (e['count'] > maxVal) maxVal = e['count'];
    }

    return SizedBox(
      height: 120,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: data.map((e) {
          final int count = e['count'];
          final double ratio = count / maxVal;
          // Set a minimum height for zero values so the bar baseline caps are visible
          final double heightFactor = count == 0 ? 0.05 : ratio;
          
          return Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Expanded(
                  child: Center(
                    child: Container(
                      width: 14,
                      decoration: BoxDecoration(
                        color: AppColors.border,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      alignment: Alignment.bottomCenter,
                      child: FractionallySizedBox(
                        heightFactor: heightFactor,
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFFBB52FA), Color(0xFFD586FF)],
                              begin: Alignment.bottomCenter,
                              end: Alignment.topCenter,
                            ),
                            borderRadius: BorderRadius.circular(8),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFFBB52FA).withOpacity(0.4),
                                blurRadius: 4,
                                spreadRadius: 0.5,
                              )
                            ]
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  e['day'],
                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 10, fontWeight: FontWeight.bold),
                )
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  // Settings Tab Screen content
  Widget _buildSettingsTab(BuildContext context, String username) {
    final user = Provider.of<AuthProvider>(context, listen: false).user;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
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
    return Container(
      decoration: BoxDecoration(
        color: AppColors.background,
        border: const Border(
          top: BorderSide(color: AppColors.border, width: 1.0),
        ),
      ),
      child: BottomAppBar(
        color: AppColors.background,
        elevation: 0,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            // Tab 1: Dashboard
            IconButton(
              icon: Icon(
                _selectedIndex == 0 ? Icons.grid_view_rounded : Icons.grid_view_outlined,
                color: _selectedIndex == 0 ? const Color(0xFF2E6BFF) : AppColors.textMuted,
              ),
              onPressed: () => setState(() => _selectedIndex = 0),
            ),
            // Tab 2: Tasks Checklist
            IconButton(
              icon: Icon(
                _selectedIndex == 1 ? Icons.assignment_turned_in_rounded : Icons.assignment_turned_in_outlined,
                color: _selectedIndex == 1 ? const Color(0xFF2E6BFF) : AppColors.textMuted,
              ),
              onPressed: () => setState(() => _selectedIndex = 1),
            ),
            // Tab 3: Central floating plus log button
            GestureDetector(
              onTap: _showQuickLogSheet,
              child: Container(
                width: 48,
                height: 48,
                decoration: const BoxDecoration(
                  color: Color(0xFF2E6BFF),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Color(0xFF2E6BFF),
                      blurRadius: 10,
                      spreadRadius: 1,
                    )
                  ]
                ),
                child: const Icon(Icons.add_rounded, color: Colors.white, size: 30),
              ),
            ),
            // Tab 4: Badges & Levels
            IconButton(
              icon: Icon(
                _selectedIndex == 3 ? Icons.emoji_events_rounded : Icons.emoji_events_outlined,
                color: _selectedIndex == 3 ? const Color(0xFF2E6BFF) : AppColors.textMuted,
              ),
              onPressed: () => setState(() => _selectedIndex = 3),
            ),
            // Tab 5: Settings Page
            IconButton(
              icon: Icon(
                _selectedIndex == 4 ? Icons.settings_rounded : Icons.settings_outlined,
                color: _selectedIndex == 4 ? const Color(0xFF2E6BFF) : AppColors.textMuted,
              ),
              onPressed: () => setState(() => _selectedIndex = 4),
            ),
          ],
        ),
      ),
    );
  }
}
