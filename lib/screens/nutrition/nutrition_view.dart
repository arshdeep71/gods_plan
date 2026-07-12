import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../providers/auth_provider.dart';
import '../../providers/health_provider.dart';
import '../../providers/nutrition_provider.dart';
import '../../models/nutrition_profile.dart';
import '../../models/food_log.dart';
import '../../utils/colors.dart';

class NutritionView extends StatefulWidget {
  const NutritionView({super.key});

  @override
  State<NutritionView> createState() => _NutritionViewState();
}

class _NutritionViewState extends State<NutritionView> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final user = Provider.of<AuthProvider>(context, listen: false).user;
      if (user != null) {
        Provider.of<NutritionProvider>(context, listen: false).fetchNutritionData(user.id);
        Provider.of<HealthProvider>(context, listen: false).fetchHealthData(user.id);
      }
    });
  }

  void _showAddFoodSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.background,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => const AddFoodSheet(),
    );
  }

  void _showProfileCalculatorSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.background,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => const ProfileCalculatorSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final nutritionProvider = context.watch<NutritionProvider>();
    final healthProvider = context.watch<HealthProvider>();
    final authProvider = context.read<AuthProvider>();

    final double caloriesTarget = nutritionProvider.profile.targetCalories;
    final double caloriesLogged = nutritionProvider.caloriesLoggedToday;
    final double calorieProgress = (caloriesLogged / caloriesTarget).clamp(0.0, 1.0);

    // Water math: linked to active exercise minutes today
    final exerciseMinutes = healthProvider.exerciseMinutesLoggedToday;
    final waterTarget = nutritionProvider.getCalculatedWaterTarget(exerciseMinutes);
    final waterLogged = nutritionProvider.waterGlassesLoggedToday;

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
          "Nutrition & Water",
          style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.calculate_rounded, color: AppColors.primaryLight),
            onPressed: () => _showProfileCalculatorSheet(context),
            tooltip: "BMR/TDEE Calculator",
          ),
          if (nutritionProvider.isSyncing)
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
                  nutritionProvider.fetchNutritionData(authProvider.user!.id);
                }
              },
            ),
        ],
      ),
      body: nutritionProvider.isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : ListView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              children: [
                // 1. Calories Ring Card
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    gradient: AppColors.darkCardGradient,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                "DAILY CALORIES",
                                style: TextStyle(color: AppColors.textMuted, fontSize: 10, letterSpacing: 1.0, fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                "${caloriesLogged.toStringAsFixed(0)} / ${caloriesTarget.toStringAsFixed(0)} kcal",
                                style: const TextStyle(color: AppColors.textPrimary, fontSize: 18, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              nutritionProvider.profile.goal.replaceAll('_', ' ').toUpperCase(),
                              style: const TextStyle(color: AppColors.primaryLight, fontSize: 10, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: LinearProgressIndicator(
                          value: calorieProgress,
                          minHeight: 12,
                          backgroundColor: AppColors.border,
                          valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // 2. Macros Progress Grid
                _buildMacrosPanel(nutritionProvider),
                const SizedBox(height: 24),

                // 3. Water Tracker Panel (Reactive to Exercise)
                _buildWaterPanel(nutritionProvider, waterLogged, waterTarget, exerciseMinutes, authProvider.user?.id),
                const SizedBox(height: 32),

                // 4. Food diary log entries
                const Text(
                  "Food Diary Today",
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.0,
                  ),
                ),
                const SizedBox(height: 12),
                if (nutritionProvider.foodLogs.isEmpty)
                  _buildEmptyState()
                else
                  ...nutritionProvider.foodLogs.map((log) => _buildFoodTile(log)),
              ],
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddFoodSheet(context),
        backgroundColor: AppColors.primary,
        child: const Icon(Icons.add_rounded, color: AppColors.textPrimary, size: 30),
      ),
    );
  }

  Widget _buildMacrosPanel(NutritionProvider np) {
    final double targetP = np.profile.targetProteinGrams;
    final double targetC = np.profile.targetCarbGrams;
    final double targetF = np.profile.targetFatGrams;

    final double loggedP = np.proteinLoggedToday;
    final double loggedC = np.carbsLoggedToday;
    final double loggedF = np.fatsLoggedToday;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildMacroRow("Protein", loggedP, targetP, AppColors.info, "g"),
          const SizedBox(height: 16),
          _buildMacroRow("Carbs", loggedC, targetC, AppColors.success, "g"),
          const SizedBox(height: 16),
          _buildMacroRow("Fats", loggedF, targetF, AppColors.secondary, "g"),
        ],
      ),
    );
  }

  Widget _buildMacroRow(String title, double current, double target, Color barColor, String unit) {
    final progress = target > 0 ? (current / target).clamp(0.0, 1.0) : 0.0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(title, style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 14)),
            Text(
              "${current.toStringAsFixed(1)} / ${target.toStringAsFixed(0)} $unit",
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 6,
            backgroundColor: AppColors.border,
            valueColor: AlwaysStoppedAnimation<Color>(barColor),
          ),
        ),
      ],
    );
  }

  Widget _buildWaterPanel(NutritionProvider np, int logged, int target, int exerciseMinutes, String? userId) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("WATER INTAKE", style: TextStyle(color: AppColors.textMuted, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.0)),
                  const SizedBox(height: 4),
                  Text("$logged / $target Glasses", style: const TextStyle(color: AppColors.textPrimary, fontSize: 18, fontWeight: FontWeight.bold)),
                ],
              ),
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.remove_circle_outline_rounded, color: AppColors.textSecondary),
                    onPressed: () {
                      if (userId != null && logged > 0) {
                        np.setWaterGlasses(userId, logged - 1);
                      }
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.add_circle_outline_rounded, color: AppColors.info),
                    onPressed: () {
                      if (userId != null) {
                        np.setWaterGlasses(userId, logged + 1);
                      }
                    },
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            exerciseMinutes > 0
                ? "Target raised from 8 to $target glasses due to $exerciseMinutes minutes of exercise logged today."
                : "Target is 8 glasses. Log active exercise sessions to automatically raise target.",
            style: const TextStyle(color: AppColors.textSecondary, fontSize: 12, height: 1.3),
          ),
          const SizedBox(height: 16),
          // Glasses grid list
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: List.generate(target, (index) {
              final isFilled = index < logged;
              return Icon(
                isFilled ? Icons.local_drink_rounded : Icons.local_drink_outlined,
                color: isFilled ? AppColors.info : AppColors.textMuted,
                size: 28,
              );
            }),
          ),
        ],
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
          Icon(Icons.restaurant_rounded, size: 48, color: AppColors.textSecondary),
          SizedBox(height: 16),
          Text(
            "No Foods Logged Today",
            style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 16),
          ),
          SizedBox(height: 8),
          Text(
            "Record your daily meals to monitor calories and macronutrient ratios.",
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.textSecondary, fontSize: 13, height: 1.3),
          ),
        ],
      ),
    );
  }

  Widget _buildFoodTile(FoodLog log) {
    final np = context.read<NutritionProvider>();
    final formattedTime = DateFormat('hh:mm a').format(log.loggedAt);

    return Dismissible(
      key: Key(log.id),
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
        np.deleteFoodLog(log);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("${log.foodName} deleted."),
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
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    log.foodName,
                    style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "$formattedTime • P:${log.protein.toStringAsFixed(0)}g C:${log.carbs.toStringAsFixed(0)}g F:${log.fats.toStringAsFixed(0)}g",
                    style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                  ),
                ],
              ),
            ),
            Text(
              "${log.calories.toStringAsFixed(0)} kcal",
              style: const TextStyle(color: AppColors.secondary, fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ],
        ),
      ),
    );
  }
}

// Add Food Sheet
class AddFoodSheet extends StatefulWidget {
  const AddFoodSheet({super.key});

  @override
  State<AddFoodSheet> createState() => _AddFoodSheetState();
}

class _AddFoodSheetState extends State<AddFoodSheet> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _caloriesController = TextEditingController();
  final _proteinController = TextEditingController();
  final _carbsController = TextEditingController();
  final _fatsController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    _caloriesController.dispose();
    _proteinController.dispose();
    _carbsController.dispose();
    _fatsController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;

    final user = Provider.of<AuthProvider>(context, listen: false).user;
    if (user != null) {
      final name = _nameController.text;
      final kcal = double.parse(_caloriesController.text);
      final p = double.parse(_proteinController.text);
      final c = double.parse(_carbsController.text);
      final f = double.parse(_fatsController.text);

      Provider.of<NutritionProvider>(context, listen: false).addFoodLog(
        userId: user.id,
        foodName: name,
        calories: kcal,
        protein: p,
        carbs: c,
        fats: f,
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
              "Log Food Item",
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
            ),
            const SizedBox(height: 24),

            // Food Name
            TextFormField(
              controller: _nameController,
              style: const TextStyle(color: AppColors.textPrimary),
              decoration: InputDecoration(
                labelText: "Food Name",
                labelStyle: const TextStyle(color: AppColors.textSecondary),
                filled: true,
                fillColor: AppColors.surface,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
              validator: (val) => (val == null || val.isEmpty) ? "Enter food name" : null,
            ),
            const SizedBox(height: 16),

            // Calories
            TextFormField(
              controller: _caloriesController,
              keyboardType: TextInputType.number,
              style: const TextStyle(color: AppColors.textPrimary),
              decoration: InputDecoration(
                labelText: "Calories (kcal)",
                labelStyle: const TextStyle(color: AppColors.textSecondary),
                filled: true,
                fillColor: AppColors.surface,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
              validator: (val) {
                if (val == null || val.isEmpty) return "Enter calories";
                if (double.tryParse(val) == null) return "Enter valid number";
                return null;
              },
            ),
            const SizedBox(height: 16),

            // Macros inputs side by side
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _proteinController,
                    keyboardType: TextInputType.number,
                    style: const TextStyle(color: AppColors.textPrimary),
                    decoration: InputDecoration(
                      labelText: "Protein (g)",
                      labelStyle: const TextStyle(color: AppColors.textSecondary),
                      filled: true,
                      fillColor: AppColors.surface,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    validator: (val) => (val == null || val.isEmpty) ? "Enter g" : null,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextFormField(
                    controller: _carbsController,
                    keyboardType: TextInputType.number,
                    style: const TextStyle(color: AppColors.textPrimary),
                    decoration: InputDecoration(
                      labelText: "Carbs (g)",
                      labelStyle: const TextStyle(color: AppColors.textSecondary),
                      filled: true,
                      fillColor: AppColors.surface,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    validator: (val) => (val == null || val.isEmpty) ? "Enter g" : null,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextFormField(
                    controller: _fatsController,
                    keyboardType: TextInputType.number,
                    style: const TextStyle(color: AppColors.textPrimary),
                    decoration: InputDecoration(
                      labelText: "Fats (g)",
                      labelStyle: const TextStyle(color: AppColors.textSecondary),
                      filled: true,
                      fillColor: AppColors.surface,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    validator: (val) => (val == null || val.isEmpty) ? "Enter g" : null,
                  ),
                ),
              ],
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
                "Add to Diary",
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Profile settings (BMR / TDEE Calculator) sheet
class ProfileCalculatorSheet extends StatefulWidget {
  const ProfileCalculatorSheet({super.key});

  @override
  State<ProfileCalculatorSheet> createState() => _ProfileCalculatorSheetState();
}

class _ProfileCalculatorSheetState extends State<ProfileCalculatorSheet> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _weightController;
  late TextEditingController _heightController;
  late TextEditingController _ageController;
  late String _activity;
  late String _goal;

  @override
  void initState() {
    super.initState();
    final profile = Provider.of<NutritionProvider>(context, listen: false).profile;
    _weightController = TextEditingController(text: profile.weightKg.toStringAsFixed(1));
    _heightController = TextEditingController(text: profile.heightCm.toStringAsFixed(0));
    _ageController = TextEditingController(text: profile.ageYears.toString());
    _activity = profile.activityFactor;
    _goal = profile.goal;
  }

  @override
  void dispose() {
    _weightController.dispose();
    _heightController.dispose();
    _ageController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;

    final weight = double.parse(_weightController.text);
    final height = double.parse(_heightController.text);
    final age = int.parse(_ageController.text);

    final newProfile = NutritionProfile(
      weightKg: weight,
      heightCm: height,
      ageYears: age,
      activityFactor: _activity,
      goal: _goal,
    );

    Provider.of<NutritionProvider>(context, listen: false).saveNutritionProfile(newProfile);
    Navigator.pop(context);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("BMR & calorie targets updated!"),
        backgroundColor: AppColors.success,
        behavior: SnackBarBehavior.floating,
      ),
    );
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
              "Calorie & Target Calculator",
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
            ),
            const SizedBox(height: 24),

            Row(
              children: [
                Expanded(
                  child: TextFormField(
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
                    validator: (val) => (val == null || val.isEmpty) ? "Required" : null,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextFormField(
                    controller: _heightController,
                    keyboardType: TextInputType.number,
                    style: const TextStyle(color: AppColors.textPrimary),
                    decoration: InputDecoration(
                      labelText: "Height (cm)",
                      labelStyle: const TextStyle(color: AppColors.textSecondary),
                      filled: true,
                      fillColor: AppColors.surface,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    validator: (val) => (val == null || val.isEmpty) ? "Required" : null,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextFormField(
                    controller: _ageController,
                    keyboardType: TextInputType.number,
                    style: const TextStyle(color: AppColors.textPrimary),
                    decoration: InputDecoration(
                      labelText: "Age (years)",
                      labelStyle: const TextStyle(color: AppColors.textSecondary),
                      filled: true,
                      fillColor: AppColors.surface,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    validator: (val) => (val == null || val.isEmpty) ? "Required" : null,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Activity level dropdown
            DropdownButtonFormField<String>(
              value: _activity,
              dropdownColor: AppColors.surface,
              style: const TextStyle(color: AppColors.textPrimary),
              decoration: InputDecoration(
                labelText: "Activity Factor",
                labelStyle: const TextStyle(color: AppColors.textSecondary),
                filled: true,
                fillColor: AppColors.surface,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
              items: const [
                DropdownMenuItem(value: 'sedentary', child: Text("Sedentary (BMR x 1.2)")),
                DropdownMenuItem(value: 'light', child: Text("Light (BMR x 1.375)")),
                DropdownMenuItem(value: 'moderate', child: Text("Moderate (BMR x 1.55)")),
                DropdownMenuItem(value: 'active', child: Text("Active (BMR x 1.725)")),
              ],
              onChanged: (val) {
                if (val != null) setState(() => _activity = val);
              },
            ),
            const SizedBox(height: 16),

            // Goal dropdown
            DropdownButtonFormField<String>(
              value: _goal,
              dropdownColor: AppColors.surface,
              style: const TextStyle(color: AppColors.textPrimary),
              decoration: InputDecoration(
                labelText: "Fitness Goal",
                labelStyle: const TextStyle(color: AppColors.textSecondary),
                filled: true,
                fillColor: AppColors.surface,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
              items: const [
                DropdownMenuItem(value: 'muscle_building', child: Text("Muscle Building (TDEE + 300 kcal)")),
                DropdownMenuItem(value: 'fat_loss', child: Text("Fat Loss (TDEE - 500 kcal)")),
              ],
              onChanged: (val) {
                if (val != null) setState(() => _goal = val);
              },
            ),
            const SizedBox(height: 28),

            // Submit button
            ElevatedButton(
              onPressed: _submit,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text(
                "Save & Calculate",
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
