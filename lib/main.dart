import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'providers/auth_provider.dart';
import 'providers/task_provider.dart';
import 'providers/health_provider.dart';
import 'providers/nutrition_provider.dart';
import 'providers/addiction_provider.dart';
import 'providers/finance_provider.dart';
import 'providers/learning_provider.dart';
import 'providers/social_provider.dart';
import 'services/database_service.dart';
import 'services/encryption_service.dart';
import 'services/notification_service.dart';
import 'services/app_icon_service.dart';
import 'services/live_activity_service.dart';
import 'utils/constants.dart';
import 'utils/colors.dart';
import 'screens/auth/login_screen.dart';
import 'screens/goal_setup.dart';
import 'screens/dashboard.dart';
import 'screens/auth/passcode_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Custom renderer error handler
  ErrorWidget.builder = (FlutterErrorDetails details) {
    return MaterialApp(
      home: Scaffold(
        backgroundColor: const Color(0xFF0F0F1A),
        body: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.bug_report, color: Colors.amberAccent, size: 64),
                const SizedBox(height: 16),
                const Text(
                  'Render / Widget Error',
                  style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                Text(
                  '${details.exception}\n\nStack Trace:\n${details.stack}',
                  style: const TextStyle(color: Colors.amberAccent, fontSize: 12),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  };

  try {
    debugPrint("STEP 1: Starting EncryptionService initialization");
    await EncryptionService().initialize();
    debugPrint("STEP 1: EncryptionService initialized");
  } catch (e) {
    debugPrint("STEP 1 Error (continuing startup): $e");
  }

  try {
    debugPrint("STEP 2: Starting DatabaseService initialization");
    final dbService = DatabaseService();
    await dbService.initDatabase();
    debugPrint("STEP 2: DatabaseService initialized");
  } catch (e) {
    debugPrint("STEP 2 Error (continuing startup): $e");
  }

  try {
    debugPrint("STEP 3: Starting NotificationService init");
    await NotificationService().init();
    debugPrint("STEP 3: NotificationService initialized");
  } catch (e) {
    debugPrint("STEP 3 Error (continuing startup): $e");
  }

  try {
    debugPrint("STEP 4: Restoring Scheduled Notifications");
    await NotificationService().restoreScheduledNotifications();
    debugPrint("STEP 4: Scheduled Notifications restored");
  } catch (e) {
    debugPrint("STEP 4 Error (continuing startup): $e");
  }

  try {
    debugPrint("STEP 5: Starting LiveActivityService initialization");
    final liveActivityService = LiveActivityService();
    await liveActivityService.init();
    debugPrint("STEP 5: LiveActivityService init finished");

    debugPrint("STEP 6: LiveActivityService ending all activities");
    await liveActivityService.endAllActivities();
    debugPrint("STEP 6: LiveActivityService ended all activities");
  } catch (e) {
    debugPrint("STEP 5/6 Error (continuing startup): $e");
  }

  debugPrint("STEP 7: Checking Supabase Configuration");
  bool isSupabaseConfigured = false;
  if (SupabaseConstants.supabaseUrl != 'YOUR_SUPABASE_PROJECT_URL' &&
      SupabaseConstants.supabaseAnonKey != 'YOUR_SUPABASE_ANON_KEY' &&
      SupabaseConstants.supabaseUrl.isNotEmpty &&
      SupabaseConstants.supabaseAnonKey.isNotEmpty) {
    try {
      debugPrint("STEP 8: Initializing Supabase");
      await Supabase.initialize(
        url: SupabaseConstants.supabaseUrl,
        anonKey: SupabaseConstants.supabaseAnonKey,
      );
      isSupabaseConfigured = true;
      debugPrint("STEP 8: Supabase Initialized");
    } catch (e) {
      debugPrint("STEP 8: Supabase initialization failed: $e");
      isSupabaseConfigured = false;
    }
  }

  try {
    debugPrint("STEP 9: Starting runApp");

    runApp(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => AuthProvider()),
          ChangeNotifierProvider(create: (_) => TaskProvider()),
          ChangeNotifierProvider(create: (_) => HealthProvider()),
          ChangeNotifierProvider(create: (_) => NutritionProvider()),
          ChangeNotifierProvider(create: (_) => AddictionProvider()),
          ChangeNotifierProvider(create: (_) => FinanceProvider()),
          ChangeNotifierProvider(create: (_) => LearningProvider()),
          ChangeNotifierProvider(create: (_) => SocialProvider()),
          ChangeNotifierProvider(create: (_) => AppIconService()..initialize()),
        ],
        child: MyApp(isSupabaseConfigured: isSupabaseConfigured),
      ),
    );
  } catch (error, stackTrace) {
    debugPrint("Error launching runApp: $error\n$stackTrace");
    runApp(
      MaterialApp(
        home: Scaffold(
          backgroundColor: const Color(0xFF0F0F1A),
          body: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, color: Colors.redAccent, size: 64),
                  const SizedBox(height: 16),
                  const Text(
                    'App Initialization Error',
                    style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    error.toString(),
                    style: const TextStyle(color: Colors.redAccent, fontSize: 14),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    stackTrace.toString(),
                    style: const TextStyle(color: Colors.grey, fontSize: 10),
                    textAlign: TextAlign.left,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class MyApp extends StatelessWidget {
  final bool isSupabaseConfigured;

  const MyApp({super.key, required this.isSupabaseConfigured});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: "God's Plan",
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        fontFamily: 'Inter',
        scaffoldBackgroundColor: AppColors.background,
        primaryColor: AppColors.primary,
        colorScheme: const ColorScheme.dark(
          primary: AppColors.primary,
          secondary: AppColors.secondary,
          surface: AppColors.surface,
          background: AppColors.background,
        ),
      ),
      home: _getHomeRoute(context),
    );
  }

  Widget _getHomeRoute(BuildContext context) {
    // If Supabase is not configured yet, show a beautiful configuration guide
    if (!isSupabaseConfigured) {
      return const SupabaseConfigErrorScreen();
    }

    final authProvider = Provider.of<AuthProvider>(context);
    final dbService = DatabaseService();

    if (!authProvider.isInitialized) {
      return const Scaffold(
        backgroundColor: AppColors.background,
        body: Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
          ),
        ),
      );
    }

    if (authProvider.isAuthenticated) {
      if (dbService.isOnboarded) {
        return const AppLockWrapper();
      } else {
        return const GoalSetupScreen();
      }
    } else {
      return const LoginScreen();
    }
  }
}

class AppLockWrapper extends StatefulWidget {
  const AppLockWrapper({super.key});

  @override
  State<AppLockWrapper> createState() => _AppLockWrapperState();
}

class _AppLockWrapperState extends State<AppLockWrapper> with WidgetsBindingObserver {
  final DatabaseService _dbService = DatabaseService();
  bool _isUnlocked = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkLockStatus();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Lock the app immediately when it goes to the background
    if (state == AppLifecycleState.paused) {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      final pin = userId != null ? _dbService.settingsBox.get('app_lock_pin_$userId') as String? : null;
      if (pin != null && pin.isNotEmpty) {
        setState(() {
          _isUnlocked = false;
        });
      }
    }
  }

  void _checkLockStatus() {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    final pin = userId != null ? _dbService.settingsBox.get('app_lock_pin_$userId') as String? : null;
    if (pin == null || pin.isEmpty) {
      _isUnlocked = true;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isUnlocked) {
      return const DashboardScreen();
    }
    return PasscodeScreen(
      onUnlocked: () {
        setState(() {
          _isUnlocked = true;
        });
      },
    );
  }
}

// Visual screen to guide the user when Supabase is not configured yet
class SupabaseConfigErrorScreen extends StatelessWidget {
  const SupabaseConfigErrorScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32.0, vertical: 24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Icon(
                Icons.cloud_off_rounded,
                size: 80,
                color: AppColors.secondary,
              ),
              const SizedBox(height: 28),
              const Text(
                "Supabase Setup Required",
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                "Before launching God's Plan on your device, you need to hook up your Supabase project credentials in the codebase.",
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 15,
                  color: AppColors.textSecondary,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 36),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Instructions:",
                      style: TextStyle(color: AppColors.primaryLight, fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      "1. Open lib/utils/constants.dart in your workspace.",
                      style: TextStyle(color: AppColors.textPrimary, fontSize: 13, height: 1.3),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      "2. Replace 'YOUR_SUPABASE_PROJECT_URL' and 'YOUR_SUPABASE_ANON_KEY' with your actual Supabase API keys.",
                      style: TextStyle(color: AppColors.textPrimary, fontSize: 13, height: 1.3),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      "3. Run the schema migrations from supabase_schema.sql in the Supabase SQL editor.",
                      style: TextStyle(color: AppColors.textPrimary, fontSize: 13, height: 1.3),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 48),
              const Text(
                "Waiting for credentials update...",
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 12,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
