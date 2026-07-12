import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../providers/auth_provider.dart';
import '../../providers/health_provider.dart';
import '../../models/workout.dart';
import '../../utils/colors.dart';

class ExerciseView extends StatefulWidget {
  const ExerciseView({super.key});

  @override
  State<ExerciseView> createState() => _ExerciseViewState();
}

class _ExerciseViewState extends State<ExerciseView> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final user = Provider.of<AuthProvider>(context, listen: false).user;
      if (user != null) {
        Provider.of<HealthProvider>(context, listen: false).fetchHealthData(user.id);
      }
    });
  }

  void _showAddWorkoutSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.background,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => const AddWorkoutSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final healthProvider = context.watch<HealthProvider>();
    final authProvider = context.read<AuthProvider>();
    final minutesToday = healthProvider.exerciseMinutesLoggedToday;
    final progressFactor = (minutesToday / 30.0).clamp(0.0, 1.0);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          "Exercise & Workouts",
          style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold),
        ),
        actions: [
          if (healthProvider.isSyncing)
            const Center(
              child: Padding(
                padding: EdgeInsets.only(right: 16.0),
                child: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primaryLight),
                ),
              ),
            )
          else
            IconButton(
              icon: const Icon(Icons.cloud_sync_rounded, color: AppColors.success),
              onPressed: () {
                if (authProvider.user != null) {
                  healthProvider.fetchHealthData(authProvider.user!.id);
                }
              },
            ),
        ],
      ),
      body: healthProvider.isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : ListView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              children: [
                // Daily Minutes Target Circular Ring
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    gradient: AppColors.darkCardGradient,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Row(
                    children: [
                      // Radial Progress Ring
                      SizedBox(
                        width: 100,
                        height: 100,
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            CircularProgressIndicator(
                              value: progressFactor,
                              strokeWidth: 10,
                              backgroundColor: AppColors.border,
                              color: AppColors.primary,
                            ),
                            Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    "$minutesToday",
                                    style: const TextStyle(
                                      color: AppColors.textPrimary,
                                      fontSize: 22,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const Text(
                                    "/30 min",
                                    style: TextStyle(
                                      color: AppColors.textSecondary,
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 28),
                      // Text info
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              "Daily Target",
                              style: TextStyle(
                                color: AppColors.primaryLight,
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.0,
                              ),
                            ),
                            const SizedBox(height: 6),
                            const Text(
                              "30 Minutes Active",
                              style: TextStyle(
                                color: AppColors.textPrimary,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              minutesToday >= 30
                                  ? "Goal achieved! Excellent work today staying active."
                                  : "${30 - minutesToday} minutes remaining to hit your target today.",
                              style: const TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 13,
                                height: 1.3,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),

                // Workout Logs List
                const Text(
                  "Recent Workout Logs",
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.0,
                  ),
                ),
                const SizedBox(height: 12),
                if (healthProvider.workouts.isEmpty)
                  _buildEmptyState()
                else
                  ...healthProvider.workouts.map((workout) => _buildWorkoutTile(workout)),
              ],
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddWorkoutSheet(context),
        backgroundColor: AppColors.primary,
        child: const Icon(Icons.add_rounded, color: AppColors.textPrimary, size: 30),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: const [
          Icon(Icons.directions_run_rounded, size: 48, color: AppColors.textSecondary),
          SizedBox(height: 16),
          Text(
            "No Workouts Logged Yet",
            style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 16),
          ),
          SizedBox(height: 8),
          Text(
            "Track active sessions. Calorie metrics calculate automatically using MET equations.",
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.textSecondary, fontSize: 13, height: 1.3),
          ),
        ],
      ),
    );
  }

  Widget _buildWorkoutTile(Workout workout) {
    final healthProvider = context.read<HealthProvider>();
    final formattedDate = DateFormat('MMM dd - hh:mm a').format(workout.loggedAt);

    IconData activityIcon;
    switch (workout.activityType.toLowerCase()) {
      case 'running':
        activityIcon = Icons.directions_run_rounded;
        break;
      case 'strength':
        activityIcon = Icons.fitness_center_rounded;
        break;
      case 'yoga':
        activityIcon = Icons.self_improvement_rounded;
        break;
      case 'sports':
        activityIcon = Icons.sports_soccer_rounded;
        break;
      default:
        activityIcon = Icons.directions_walk_rounded;
    }

    return Dismissible(
      key: Key(workout.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: AppColors.error.withOpacity(0.15),
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Icon(Icons.delete_sweep_rounded, color: AppColors.error, size: 28),
      ),
      onDismissed: (_) {
        healthProvider.deleteWorkout(workout);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Logged workout deleted."),
            backgroundColor: AppColors.border,
            behavior: SnackBarBehavior.floating,
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            // Icon
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(activityIcon, color: AppColors.primaryLight, size: 24),
            ),
            const SizedBox(width: 16),
            // Middle text
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    workout.activityType.toUpperCase(),
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "$formattedDate • ${workout.duration} mins",
                    style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                  ),
                ],
              ),
            ),
            // Calories burned
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  "${workout.caloriesBurned.toStringAsFixed(0)} kcal",
                  style: const TextStyle(
                    color: AppColors.secondary,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  "MET: ${Workout.getMET(workout.activityType)}",
                  style: const TextStyle(color: AppColors.textMuted, fontSize: 10),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// Add Workout Sheet
class AddWorkoutSheet extends StatefulWidget {
  const AddWorkoutSheet({super.key});

  @override
  State<AddWorkoutSheet> createState() => _AddWorkoutSheetState();
}

class _AddWorkoutSheetState extends State<AddWorkoutSheet> {
  final _formKey = GlobalKey<FormState>();
  final _durationController = TextEditingController();
  final _weightController = TextEditingController(text: '70'); // Default weight
  String _activityType = 'running';

  @override
  void dispose() {
    _durationController.dispose();
    _weightController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;

    final user = Provider.of<AuthProvider>(context, listen: false).user;
    if (user != null) {
      final duration = int.parse(_durationController.text);
      final weight = double.parse(_weightController.text);

      Provider.of<HealthProvider>(context, listen: false).addWorkout(
        userId: user.id,
        activityType: _activityType,
        duration: duration,
        weightKg: weight,
      );
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
        top: 24,
        left: 24,
        right: 24,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              "Log Workout",
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
            ),
            const SizedBox(height: 24),

            // Activity selector dropdown
            DropdownButtonFormField<String>(
              value: _activityType,
              dropdownColor: AppColors.surface,
              style: const TextStyle(color: AppColors.textPrimary),
              decoration: InputDecoration(
                labelText: "Activity Type",
                labelStyle: const TextStyle(color: AppColors.textSecondary),
                filled: true,
                fillColor: AppColors.surface,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
              items: const [
                DropdownMenuItem(value: 'running', child: Text("Running")),
                DropdownMenuItem(value: 'strength', child: Text("Gym (Strength)")),
                DropdownMenuItem(value: 'yoga', child: Text("Yoga")),
                DropdownMenuItem(value: 'sports', child: Text("Sports")),
                DropdownMenuItem(value: 'walking', child: Text("Walking")),
              ],
              onChanged: (val) {
                if (val != null) {
                  setState(() => _activityType = val);
                }
              },
            ),
            const SizedBox(height: 20),

            // Duration input
            TextFormField(
              controller: _durationController,
              keyboardType: TextInputType.number,
              style: const TextStyle(color: AppColors.textPrimary),
              decoration: InputDecoration(
                labelText: "Duration (minutes)",
                labelStyle: const TextStyle(color: AppColors.textSecondary),
                filled: true,
                fillColor: AppColors.surface,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
              validator: (val) {
                if (val == null || val.isEmpty) return "Enter duration";
                if (int.tryParse(val) == null || int.parse(val) <= 0) return "Enter a valid duration";
                return null;
              },
            ),
            const SizedBox(height: 20),

            // Weight input
            TextFormField(
              controller: _weightController,
              keyboardType: TextInputType.number,
              style: const TextStyle(color: AppColors.textPrimary),
              decoration: InputDecoration(
                labelText: "Weight (kg)",
                labelStyle: const TextStyle(color: AppColors.textSecondary),
                filled: true,
                fillColor: AppColors.surface,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
              validator: (val) {
                if (val == null || val.isEmpty) return "Enter your weight";
                if (double.tryParse(val) == null || double.parse(val) <= 0) return "Enter a valid weight";
                return null;
              },
            ),
            const SizedBox(height: 28),

            // Submit Button
            ElevatedButton(
              onPressed: _submit,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text(
                "Save Workout",
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
