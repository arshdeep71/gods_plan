import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/addiction_provider.dart';
import '../../utils/colors.dart';

class AddictionView extends StatefulWidget {
  const AddictionView({super.key});

  @override
  State<AddictionView> createState() => _AddictionViewState();
}

class _AddictionViewState extends State<AddictionView> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final user = Provider.of<AuthProvider>(context, listen: false).user;
      if (user != null) {
        Provider.of<AddictionProvider>(context, listen: false).fetchAddictionLogs(user.id);
      }
    });
  }

  void _showLogUrgeModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      builder: (context) {
        return const LogUrgeSheet();
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final addictionProvider = context.watch<AddictionProvider>();
    final currentStreak = addictionProvider.currentStreak;
    final longestStreak = addictionProvider.longestStreak;
    final logs = addictionProvider.logs;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text("Discipline & Sobriety", style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded, color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: addictionProvider.isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.accent))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Streak Card
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          AppColors.accent.withOpacity(0.95),
                          AppColors.accent.withOpacity(0.7),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.accent.withOpacity(0.3),
                          blurRadius: 15,
                          offset: const Offset(0, 8),
                        )
                      ],
                    ),
                    child: Column(
                      children: [
                        const Icon(
                          Icons.local_fire_department_rounded,
                          size: 72,
                          color: Colors.white,
                        ),
                        const SizedBox(height: 10),
                        Text(
                          "$currentStreak ${currentStreak == 1 ? 'Day' : 'Days'} Clean",
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            "Record Streak: $longestStreak days",
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 30),

                  // Milestones Section
                  const Text(
                    "Milestones Status",
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildMilestonesTimeline(currentStreak),
                  const SizedBox(height: 30),

                  // Urge Logging section
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        "Discipline Logs",
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      TextButton.icon(
                        onPressed: () => _showLogUrgeModal(context),
                        icon: const Icon(Icons.add_circle_outline_rounded, color: AppColors.accent),
                        label: const Text(
                          "Log Urge / Relapse",
                          style: TextStyle(color: AppColors.accent, fontWeight: FontWeight.bold),
                        ),
                      )
                    ],
                  ),
                  const SizedBox(height: 10),

                  if (logs.isEmpty)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(32),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: const Column(
                        children: [
                          Icon(Icons.shield_outlined, size: 48, color: AppColors.textMuted),
                          SizedBox(height: 12),
                          Text(
                            "No logs recorded yet.",
                            style: TextStyle(color: AppColors.textSecondary, fontSize: 15),
                          ),
                          SizedBox(height: 4),
                          Text(
                            "Log urges to map triggers and build defense strategies.",
                            style: TextStyle(color: AppColors.textMuted, fontSize: 13),
                            textAlign: Center,
                          ),
                        ],
                      ),
                    )
                  else
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: logs.length,
                      itemBuilder: (context, index) {
                        final log = logs[index];
                        final user = Provider.of<AuthProvider>(context, listen: false).user;
                        return Dismissible(
                          key: Key(log.id),
                          direction: DismissDirection.endToStart,
                          background: Container(
                            alignment: Alignment.centerRight,
                            padding: const EdgeInsets.only(right: 20),
                            decoration: BoxDecoration(
                              color: Colors.red.withOpacity(0.8),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: const Icon(Icons.delete_rounded, color: Colors.white),
                          ),
                          onDismissed: (_) {
                            if (user != null) {
                              addictionProvider.deleteAddictionLog(user.id, log.id);
                            }
                          },
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: AppColors.surface,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: log.isRelapse
                                    ? Colors.red.withOpacity(0.3)
                                    : AppColors.border,
                              ),
                            ),
                            child: Row(
                              children: [
                                CircleAvatar(
                                  backgroundColor: log.isRelapse
                                      ? Colors.red.withOpacity(0.1)
                                      : AppColors.accent.withOpacity(0.1),
                                  child: Icon(
                                    log.isRelapse
                                        ? Icons.error_outline_rounded
                                        : Icons.verified_user_rounded,
                                    color: log.isRelapse ? Colors.red : AppColors.accent,
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            log.isRelapse ? "Relapse Logged" : "Urge Overcome",
                                            style: TextStyle(
                                              color: log.isRelapse ? Colors.red : AppColors.textPrimary,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 16,
                                            ),
                                          ),
                                          Text(
                                            _formatTime(log.loggedAt),
                                            style: const TextStyle(
                                              color: AppColors.textMuted,
                                              fontSize: 12,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        "Trigger: ${log.trigger}  |  Urge: ${log.urgeLevel}/10",
                                        style: const TextStyle(
                                          color: AppColors.textSecondary,
                                          fontSize: 13,
                                        ),
                                      ),
                                      if (log.helperStrategy.isNotEmpty && !log.isRelapse) ...[
                                        const SizedBox(height: 4),
                                        Text(
                                          "Strategy: ${log.helperStrategy}",
                                          style: const TextStyle(
                                            color: AppColors.accent,
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                      if (log.notes.isNotEmpty) ...[
                                        const SizedBox(height: 6),
                                        Text(
                                          log.notes,
                                          style: const TextStyle(
                                            color: AppColors.textMuted,
                                            fontSize: 12,
                                            fontStyle: FontStyle.italic,
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                ],
              ),
            ),
    );
  }

  Widget _buildMilestonesTimeline(int currentStreak) {
    final milestones = [
      {'days': 1, 'label': '1 Day'},
      {'days': 3, 'label': '3 Days'},
      {'days': 7, 'label': '7 Days'},
      {'days': 14, 'label': '14 Days'},
      {'days': 30, 'label': '30 Days'},
    ];

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: List.generate(milestones.length, (index) {
          final m = milestones[index];
          final days = m['days'] as int;
          final label = m['label'] as String;
          final isUnlocked = currentStreak >= days;

          return IntrinsicHeight(
            child: Row(
              children: [
                Column(
                  children: [
                    Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        color: isUnlocked ? AppColors.accent : Colors.transparent,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isUnlocked ? AppColors.accent : AppColors.textMuted,
                          width: 2,
                        ),
                      ),
                      child: isUnlocked
                          ? const Icon(Icons.check, size: 14, color: Colors.white)
                          : null,
                    ),
                    if (index < milestones.length - 1)
                      Expanded(
                        child: Container(
                          width: 2,
                          color: currentStreak >= (milestones[index + 1]['days'] as int)
                              ? AppColors.accent
                              : AppColors.border,
                        ),
                      ),
                  ],
                ),
                const SizedBox(width: 16),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  child: Text(
                    label,
                    style: TextStyle(
                      color: isUnlocked ? AppColors.textPrimary : AppColors.textSecondary,
                      fontSize: 15,
                      fontWeight: isUnlocked ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                ),
                const Spacer(),
                if (!isUnlocked)
                  Text(
                    "${days - currentStreak} days left",
                    style: const TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 13,
                    ),
                  )
                else
                  const Icon(Icons.stars_rounded, color: Colors.amber, size: 18),
              ],
            ),
          );
        }),
      ),
    );
  }

  String _formatTime(DateTime time) {
    final local = time.toLocal();
    final hour = local.hour > 12 ? local.hour - 12 : (local.hour == 0 ? 12 : local.hour);
    final period = local.hour >= 12 ? 'PM' : 'AM';
    final minuteString = local.minute.toString().padLeft(2, '0');
    final monthString = _monthAbbr(local.month);
    return "$monthString ${local.day}, $hour:$minuteString $period";
  }

  String _monthAbbr(int month) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return months[month - 1];
  }
}

class LogUrgeSheet extends StatefulWidget {
  const LogUrgeSheet({super.key});

  @override
  State<LogUrgeSheet> createState() => _LogUrgeSheetState();
}

class _LogUrgeSheetState extends State<LogUrgeSheet> {
  int _urgeLevel = 5;
  String _feeling = "Neutral";
  String _trigger = "Boredom";
  String _strategy = "Exercise";
  bool _isRelapse = false;
  final TextEditingController _notesController = TextEditingController();

  final List<String> _feelings = ["Strong (No urge)", "Good", "Neutral", "Struggling", "Strong urge"];
  final List<String> _triggers = ["Stress", "Boredom", "Fatigue", "Loneliness", "Anger", "Habit", "Other"];
  final List<String> _strategies = ["Exercise", "Called friend", "Cold shower", "Meditation", "Distracted", "Prayed", "None"];

  @override
  Widget build(BuildContext context) {
    final addictionProvider = Provider.of<AddictionProvider>(context, listen: false);
    final user = Provider.of<AuthProvider>(context, listen: false).user;

    return Padding(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              "Log Urge / Relapse",
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 24),

            // Relapse toggle card
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: _isRelapse ? Colors.red.withOpacity(0.05) : AppColors.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: _isRelapse ? Colors.red.withOpacity(0.5) : AppColors.border,
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Did you Relapse?",
                        style: TextStyle(
                          color: _isRelapse ? Colors.red : AppColors.textPrimary,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 2),
                      const Text(
                        "Resets your clean streak.",
                        style: TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                  Switch.adaptive(
                    activeColor: Colors.red,
                    value: _isRelapse,
                    onChanged: (val) {
                      setState(() {
                        _isRelapse = val;
                        if (val) {
                          _feeling = "Relapsed";
                          _urgeLevel = 10;
                        } else {
                          _feeling = "Neutral";
                          _urgeLevel = 5;
                        }
                      });
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            if (!_isRelapse) ...[
              // Urge Level Slider
              Text(
                "Urge Level: $_urgeLevel/10",
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Slider(
                value: _urgeLevel.toDouble(),
                min: 1,
                max: 10,
                divisions: 9,
                activeColor: AppColors.accent,
                inactiveColor: AppColors.border,
                onChanged: (val) {
                  setState(() {
                    _urgeLevel = val.toInt();
                  });
                },
              ),
              const SizedBox(height: 16),

              // Feeling
              const Text(
                "How are you feeling?",
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: _feelings.contains(_feeling) ? _feeling : _feelings[2],
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
                dropdownColor: AppColors.surface,
                items: _feelings.map((f) {
                  return DropdownMenuItem(
                    value: f,
                    child: Text(f, style: const TextStyle(color: AppColors.textPrimary)),
                  );
                }).toList(),
                onChanged: (val) {
                  if (val != null) {
                    setState(() {
                      _feeling = val;
                    });
                  }
                },
              ),
              const SizedBox(height: 16),
            ],

            // Trigger
            const Text(
              "Urge Trigger",
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 15,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              value: _trigger,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
              dropdownColor: AppColors.surface,
              items: _triggers.map((t) {
                return DropdownMenuItem(
                  value: t,
                  child: Text(t, style: const TextStyle(color: AppColors.textPrimary)),
                );
              }).toList(),
              onChanged: (val) {
                if (val != null) {
                  setState(() {
                    _trigger = val;
                  });
                }
              },
            ),
            const SizedBox(height: 16),

            if (!_isRelapse) ...[
              // Relief Strategy
              const Text(
                "What helped you overcome it?",
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: _strategy,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
                dropdownColor: AppColors.surface,
                items: _strategies.map((s) {
                  return DropdownMenuItem(
                    value: s,
                    child: Text(s, style: const TextStyle(color: AppColors.textPrimary)),
                  );
                }).toList(),
                onChanged: (val) {
                  if (val != null) {
                    setState(() {
                      _strategy = val;
                    });
                  }
                },
              ),
              const SizedBox(height: 16),
            ],

            // Notes
            const Text(
              "Notes (Optional)",
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 15,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _notesController,
              maxLines: 3,
              style: const TextStyle(color: AppColors.textPrimary),
              decoration: InputDecoration(
                hintText: _isRelapse
                    ? "What led to the relapse? Document it to avoid it next time..."
                    : "Add any context, thoughts, or feelings...",
                hintStyle: const TextStyle(color: AppColors.textMuted),
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 24),

            // Save button
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: _isRelapse ? Colors.red : AppColors.accent,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: () {
                  if (user != null) {
                    addictionProvider.logUrge(
                      userId: user.id,
                      feeling: _isRelapse ? "Relapsed" : _feeling,
                      urgeLevel: _isRelapse ? 10 : _urgeLevel,
                      trigger: _trigger,
                      helperStrategy: _isRelapse ? "None" : _strategy,
                      isRelapse: _isRelapse,
                      notes: _notesController.text,
                    );
                  }
                  Navigator.pop(context);
                },
                child: Text(
                  _isRelapse ? "Log Relapse" : "Log Urge",
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
