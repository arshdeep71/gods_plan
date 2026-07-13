import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/learning_provider.dart';
import '../../utils/colors.dart';

class LearningView extends StatefulWidget {
  const LearningView({super.key});

  @override
  State<LearningView> createState() => _LearningViewState();
}

class _LearningViewState extends State<LearningView> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final user = Provider.of<AuthProvider>(context, listen: false).user;
      if (user != null) {
        Provider.of<LearningProvider>(context, listen: false).fetchLearningData(user.id);
      }
    });
  }

  void _showAddSubjectDialog() {
    final nameController = TextEditingController();
    final dailyTargetController = TextEditingController();
    final totalTargetController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: AppColors.surface,
          title: const Text(
            "Add New Subject",
            style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold),
          ),
          content: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: nameController,
                    style: const TextStyle(color: AppColors.textPrimary),
                    decoration: const InputDecoration(
                      labelText: "Subject Name",
                      labelStyle: TextStyle(color: AppColors.textSecondary),
                      enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: AppColors.border)),
                      focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: AppColors.accent)),
                    ),
                    validator: (v) => v == null || v.isEmpty ? "Required" : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: dailyTargetController,
                    keyboardType: TextInputType.number,
                    style: const TextStyle(color: AppColors.textPrimary),
                    decoration: const InputDecoration(
                      labelText: "Daily Target (Minutes)",
                      labelStyle: TextStyle(color: AppColors.textSecondary),
                      enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: AppColors.border)),
                      focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: AppColors.accent)),
                    ),
                    validator: (v) => v == null || int.tryParse(v) == null ? "Enter valid number" : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: totalTargetController,
                    keyboardType: TextInputType.number,
                    style: const TextStyle(color: AppColors.textPrimary),
                    decoration: const InputDecoration(
                      labelText: "Total Target (Hours)",
                      labelStyle: TextStyle(color: AppColors.textSecondary),
                      enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: AppColors.border)),
                      focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: AppColors.accent)),
                    ),
                    validator: (v) => v == null || int.tryParse(v) == null ? "Enter valid number" : null,
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel", style: TextStyle(color: AppColors.textSecondary)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.accent),
              onPressed: () {
                if (formKey.currentState!.validate()) {
                  final user = Provider.of<AuthProvider>(context, listen: false).user;
                  if (user != null) {
                    Provider.of<LearningProvider>(context, listen: false).addSubject(
                      user.id,
                      nameController.text,
                      int.parse(dailyTargetController.text),
                      int.parse(totalTargetController.text),
                    );
                  }
                  Navigator.pop(context);
                }
              },
              child: const Text("Add", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  void _showLogTimeDialog(String subjectId, String name) {
    final minutesController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: AppColors.surface,
          title: Text(
            "Log Time for $name",
            style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold),
          ),
          content: Form(
            key: formKey,
            child: TextFormField(
              controller: minutesController,
              keyboardType: TextInputType.number,
              style: const TextStyle(color: AppColors.textPrimary),
              decoration: const InputDecoration(
                labelText: "Minutes Studied",
                labelStyle: TextStyle(color: AppColors.textSecondary),
                enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: AppColors.border)),
                focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: AppColors.accent)),
              ),
              validator: (v) => v == null || int.tryParse(v) == null ? "Enter valid minutes" : null,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel", style: TextStyle(color: AppColors.textSecondary)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.accent),
              onPressed: () {
                if (formKey.currentState!.validate()) {
                  final user = Provider.of<AuthProvider>(context, listen: false).user;
                  if (user != null) {
                    Provider.of<LearningProvider>(context, listen: false).addStudyLog(
                      user.id,
                      subjectId,
                      int.parse(minutesController.text),
                    );
                  }
                  Navigator.pop(context);
                }
              },
              child: const Text("Log", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<LearningProvider>();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
        title: const Text(
          "Learning & Skills",
          style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold),
        ),
      ),
      body: provider.isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.accent))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title Header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        "Study Tracker",
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      IconButton(
                        onPressed: _showAddSubjectDialog,
                        icon: const Icon(Icons.add_circle_outline_rounded, color: AppColors.accent, size: 28),
                      ),
                    ],
                  ),
                  const SizedBox(height: 15),

                  if (provider.subjects.isEmpty)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: const Text(
                        "No subjects added yet. Tap '+' to create your academic categories.",
                        style: TextStyle(color: AppColors.textSecondary, height: 1.4),
                        textAlign: TextAlign.center,
                      ),
                    )
                  else
                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: provider.subjects.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 20),
                      itemBuilder: (context, index) {
                        final subject = provider.subjects[index];
                        final loggedToday = provider.getMinutesLoggedToday(subject.id);
                        final totalHours = provider.getTotalHoursLogged(subject.id);
                        final streak = provider.getStudyStreak(subject.id);

                        final progress = subject.dailyTargetMinutes > 0
                            ? (loggedToday / subject.dailyTargetMinutes).clamp(0.0, 1.0)
                            : 0.0;
                        final percent = (progress * 100).toStringAsFixed(0);

                        String statusText = "Good job!";
                        if (loggedToday >= subject.dailyTargetMinutes) {
                          statusText = "Daily target completed! 🎉";
                        } else {
                          statusText = "${subject.dailyTargetMinutes - loggedToday} min remaining today";
                        }

                        return Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Subject Header
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Text(
                                      subject.name.toUpperCase(),
                                      style: const TextStyle(
                                        color: AppColors.textPrimary,
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  if (streak > 0)
                                    Row(
                                      children: [
                                        Text(
                                          "$streak Day Streak",
                                          style: const TextStyle(
                                            color: AppColors.accent,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 13,
                                          ),
                                        ),
                                        const SizedBox(width: 4),
                                        const Icon(Icons.local_fire_department_rounded, color: AppColors.accent, size: 18),
                                      ],
                                    ),
                                ],
                              ),
                              const SizedBox(height: 8),

                              // Target Label
                              Text(
                                "Daily Target: ${subject.dailyTargetMinutes} min | Today: ${loggedToday} min ($percent%)",
                                style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
                              ),
                              const SizedBox(height: 12),

                              // Progress bar
                              ClipRRect(
                                borderRadius: BorderRadius.circular(10),
                                child: LinearProgressIndicator(
                                  value: progress,
                                  minHeight: 12,
                                  backgroundColor: AppColors.border,
                                  valueColor: const AlwaysStoppedAnimation<Color>(AppColors.accent),
                                ),
                              ),
                              const SizedBox(height: 16),

                              // Total info & Actions
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        "Total: ${totalHours.toStringAsFixed(1)} hrs / ${subject.totalTargetHours} hrs target",
                                        style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        statusText,
                                        style: const TextStyle(
                                          color: AppColors.success,
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                  ElevatedButton.icon(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppColors.accent.withOpacity(0.1),
                                      foregroundColor: AppColors.accent,
                                      elevation: 0,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        side: const BorderSide(color: AppColors.accent),
                                      ),
                                    ),
                                    onPressed: () => _showLogTimeDialog(subject.id, subject.name),
                                    icon: const Icon(Icons.timer_outlined, size: 16),
                                    label: const Text("Log Time", style: TextStyle(fontWeight: FontWeight.bold)),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                ],
              ),
            ),
    );
  }
}
