import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../providers/auth_provider.dart';
import '../providers/task_provider.dart';
import '../providers/health_provider.dart';
import '../providers/nutrition_provider.dart';
import '../providers/addiction_provider.dart';
import '../providers/finance_provider.dart';
import '../providers/learning_provider.dart';
import '../providers/social_provider.dart';
import '../services/database_service.dart';
import '../services/sync_service.dart';
import '../utils/network_helper.dart';

class ProfileResetService {
  final DatabaseService _dbService = DatabaseService();

  Future<void> performProfileReset(BuildContext context) async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final userId = authProvider.user?.id;
    if (userId == null) return;

    // 1. Remote reset/delete on Supabase
    final bool online = await checkInternetConnection();
    bool isPendingDeletion = false;

    if (online) {
      try {
        final syncService = SyncService();
        await syncService.deleteRemoteUserProfileData(userId);
      } catch (e) {
        print("Failed remote deletion, queueing: $e");
        isPendingDeletion = true;
      }
    } else {
      isPendingDeletion = true;
    }

    if (isPendingDeletion) {
      await _dbService.settingsBox.put('pending_profile_deletion_$userId', true);
    }

    // 2. Clear local SQLite tables and Hive cache (preserving deletion flag if needed)
    await _dbService.clearLocalCacheExceptPendingDeletion(userId, isPendingDeletion);

    // 3. Clear all provider states
    if (context.mounted) {
      Provider.of<TaskProvider>(context, listen: false).clear();
      Provider.of<HealthProvider>(context, listen: false).clear();
      Provider.of<NutritionProvider>(context, listen: false).clear();
      Provider.of<AddictionProvider>(context, listen: false).clear();
      Provider.of<FinanceProvider>(context, listen: false).clear();
      Provider.of<LearningProvider>(context, listen: false).clear();
      Provider.of<SocialProvider>(context, listen: false).clear();
    }

    // 4. Auth Sign Out / Refresh session
    try {
      await Supabase.instance.client.auth.signOut();
    } catch (_) {}
    await authProvider.logOut(); // Wipes local credentials & _user = null
  }
}
