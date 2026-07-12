import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../providers/auth_provider.dart';
import '../../providers/health_provider.dart';
import '../../models/sleep_log.dart';
import '../../utils/colors.dart';

class SleepView extends StatefulWidget {
  const SleepView({super.key});

  @override
  State<SleepView> createState() => _SleepViewState();
}

class _SleepViewState extends State<SleepView> {
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

  void _showAddSleepSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.background,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => const AddSleepSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final healthProvider = context.watch<HealthProvider>();
    final authProvider = context.read<AuthProvider>();
    final latestLog = healthProvider.lastNightSleepLog;

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
          "Sleep Tracking",
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
                // Latest Sleep Quality Card
                if (latestLog != null) _buildSummaryCard(latestLog) else _buildEmptySummaryCard(),
                const SizedBox(height: 32),

                // Sleep Logs List
                const Text(
                  "Historical Sleep Logs",
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.0,
                  ),
                ),
                const SizedBox(height: 12),
                if (healthProvider.sleepLogs.isEmpty)
                  _buildEmptyState()
                else
                  ...healthProvider.sleepLogs.map((log) => _buildSleepTile(log)),
              ],
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddSleepSheet(context),
        backgroundColor: AppColors.primary,
        child: const Icon(Icons.bedtime_rounded, color: AppColors.textPrimary, size: 28),
      ),
    );
  }

  Widget _buildSummaryCard(SleepLog log) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: AppColors.darkCardGradient,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Last Night's Sleep",
            style: TextStyle(color: AppColors.primaryLight, fontWeight: FontWeight.bold, fontSize: 13, letterSpacing: 1.0),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("DURATION", style: TextStyle(color: AppColors.textMuted, fontSize: 10, letterSpacing: 1.0)),
                  const SizedBox(height: 4),
                  Text("${log.durationHours.toStringAsFixed(1)} Hours", style: const TextStyle(color: AppColors.textPrimary, fontSize: 20, fontWeight: FontWeight.bold)),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const Text("QUALITY INDEX", style: TextStyle(color: AppColors.textMuted, fontSize: 10, letterSpacing: 1.0)),
                  const SizedBox(height: 4),
                  Text("${log.calculatedQuality.toStringAsFixed(1)} / 10", style: const TextStyle(color: AppColors.secondary, fontSize: 20, fontWeight: FontWeight.bold)),
                ],
              ),
            ],
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16.0),
            child: Divider(color: AppColors.border),
          ),
          Row(
            children: [
              const Icon(Icons.star_rounded, color: AppColors.secondary, size: 18),
              const SizedBox(width: 6),
              Text(
                log.calculatedQuality >= 8.0
                    ? "Restful sleep. You met your 8-hour target."
                    : log.calculatedQuality >= 6.0
                        ? "Moderate rest. Muted quality due to sleep factors."
                        : "Poor sleep quality. Consider optimizing factors tonight.",
                style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
              ),
            ],
          )
        ],
      ),
    );
  }

  Widget _buildEmptySummaryCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          Text("Last Night's Sleep", style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
          SizedBox(height: 12),
          Text(
            "No data recorded. Log your bedtime and wake times using the log button.",
            style: TextStyle(color: AppColors.textMuted, fontSize: 13, height: 1.3),
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
          Icon(Icons.nights_stay_rounded, size: 48, color: AppColors.textSecondary),
          SizedBox(height: 16),
          Text(
            "No Logs Recorded",
            style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 16),
          ),
          SizedBox(height: 8),
          Text(
            "Log sleep factors and bedtime routines. Quality scales automatically based on rules.",
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.textSecondary, fontSize: 13, height: 1.3),
          ),
        ],
      ),
    );
  }

  Widget _buildSleepTile(SleepLog log) {
    final healthProvider = context.read<HealthProvider>();
    final sleepTimeStr = DateFormat('hh:mm a').format(log.sleepTime);
    final wakeTimeStr = DateFormat('hh:mm a').format(log.wakeTime);
    final logDate = DateFormat('MMM dd, yyyy').format(log.sleepTime);

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
        healthProvider.deleteSleepLog(log);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Sleep log deleted."),
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
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.1), shape: BoxShape.circle),
              child: const Icon(Icons.bedtime_outlined, color: AppColors.primaryLight, size: 22),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    logDate,
                    style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "$sleepTimeStr - $wakeTimeStr (${log.durationHours.toStringAsFixed(1)} hrs)",
                    style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                  ),
                ],
              ),
            ),
            // Sleep Index score badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.secondary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.secondary.withOpacity(0.3)),
              ),
              child: Text(
                "${log.calculatedQuality.toStringAsFixed(1)} Q",
                style: const TextStyle(color: AppColors.secondary, fontWeight: FontWeight.bold, fontSize: 13),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Add Sleep Log Sheet
class AddSleepSheet extends StatefulWidget {
  const AddSleepSheet({super.key});

  @override
  State<AddSleepSheet> createState() => _AddSleepSheetState();
}

class _AddSleepSheetState extends State<AddSleepSheet> {
  DateTime _sleepDateTime = DateTime.now().subtract(const Duration(hours: 8));
  DateTime _wakeDateTime = DateTime.now();
  double _reportedQuality = 8.0;
  bool _caffeineAfter3PM = false;
  bool _screenTimeInBed = false;
  bool _lateDinner = false;

  Future<void> _pickSleepTime() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _sleepDateTime,
      firstDate: DateTime.now().subtract(const Duration(days: 7)),
      lastDate: DateTime.now(),
    );
    if (date == null) return;

    if (mounted) {
      final time = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(_sleepDateTime),
      );
      if (time == null) return;

      setState(() {
        _sleepDateTime = DateTime(date.year, date.month, date.day, time.hour, time.minute);
        if (_wakeDateTime.isBefore(_sleepDateTime)) {
          _wakeDateTime = _sleepDateTime.add(const Duration(hours: 8));
        }
      });
    }
  }

  Future<void> _pickWakeTime() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _wakeDateTime,
      firstDate: _sleepDateTime,
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );
    if (date == null) return;

    if (mounted) {
      final time = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(_wakeDateTime),
      );
      if (time == null) return;

      setState(() {
        _wakeDateTime = DateTime(date.year, date.month, date.day, time.hour, time.minute);
      });
    }
  }

  void _submit() {
    if (_wakeDateTime.isBefore(_sleepDateTime)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Wake time cannot be before bedtime."), backgroundColor: AppColors.error),
      );
      return;
    }

    final user = Provider.of<AuthProvider>(context, listen: false).user;
    if (user != null) {
      Provider.of<HealthProvider>(context, listen: false).addSleepLog(
        userId: user.id,
        sleepTime: _sleepDateTime,
        wakeTime: _wakeDateTime,
        reportedQuality: _reportedQuality,
        caffeineAfter3PM: _caffeineAfter3PM,
        screenTimeInBed: _screenTimeInBed,
        lateDinner: _lateDinner,
      );
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final duration = _wakeDateTime.difference(_sleepDateTime).inMinutes / 60.0;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
        top: 24,
        left: 24,
        right: 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            "Log Sleep Log",
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
          ),
          const SizedBox(height: 24),

          // Bedtime / Wake selectors
          Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: _pickSleepTime,
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text("Bedtime", style: TextStyle(color: AppColors.textSecondary, fontSize: 11)),
                        const SizedBox(height: 6),
                        Text(
                          DateFormat('MMM dd - hh:mm a').format(_sleepDateTime),
                          style: const TextStyle(color: AppColors.textPrimary, fontSize: 13, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: InkWell(
                  onTap: _pickWakeTime,
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text("Waking time", style: TextStyle(color: AppColors.textSecondary, fontSize: 11)),
                        const SizedBox(height: 6),
                        Text(
                          DateFormat('MMM dd - hh:mm a').format(_wakeDateTime),
                          style: const TextStyle(color: AppColors.textPrimary, fontSize: 13, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          Center(
            child: Text(
              "Total Sleep: ${duration.toStringAsFixed(1)} Hours",
              style: const TextStyle(color: AppColors.primaryLight, fontWeight: FontWeight.bold, fontSize: 14),
            ),
          ),
          const SizedBox(height: 20),

          // Reported Quality Slider
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text("Base Quality Score", style: TextStyle(color: AppColors.textSecondary, fontSize: 13, fontWeight: FontWeight.bold)),
              Text("${_reportedQuality.toStringAsFixed(0)} / 10", style: const TextStyle(color: AppColors.secondary, fontWeight: FontWeight.bold)),
            ],
          ),
          Slider(
            value: _reportedQuality,
            min: 1.0,
            max: 10.0,
            divisions: 9,
            activeColor: AppColors.primary,
            inactiveColor: AppColors.border,
            onChanged: (val) => setState(() => _reportedQuality = val),
          ),
          const SizedBox(height: 16),

          // Sleep Factors Checkboxes
          const Text("Sleep Disrupting Factors", style: TextStyle(color: AppColors.textSecondary, fontSize: 13, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          CheckboxListTile(
            title: const Text("Caffeine after 3:00 PM (-1.5)", style: TextStyle(color: AppColors.textPrimary, fontSize: 13)),
            value: _caffeineAfter3PM,
            activeColor: AppColors.primary,
            contentPadding: EdgeInsets.zero,
            onChanged: (val) => setState(() => _caffeineAfter3PM = val ?? false),
          ),
          CheckboxListTile(
            title: const Text("Screen time logged in bed (-1.0)", style: TextStyle(color: AppColors.textPrimary, fontSize: 13)),
            value: _screenTimeInBed,
            activeColor: AppColors.primary,
            contentPadding: EdgeInsets.zero,
            onChanged: (val) => setState(() => _screenTimeInBed = val ?? false),
          ),
          CheckboxListTile(
            title: const Text("Dinner within 2 hours of sleep (-0.5)", style: TextStyle(color: AppColors.textPrimary, fontSize: 13)),
            value: _lateDinner,
            activeColor: AppColors.primary,
            contentPadding: EdgeInsets.zero,
            onChanged: (val) => setState(() => _lateDinner = val ?? false),
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
              "Log Sleep Session",
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
            ),
          ),
        ],
      ),
    );
  }
}
