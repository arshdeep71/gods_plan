import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/task_provider.dart';
import '../../models/task.dart';
import '../../utils/colors.dart';

class TasksView extends StatefulWidget {
  const TasksView({super.key});

  @override
  State<TasksView> createState() => _TasksViewState();
}

class _TasksViewState extends State<TasksView> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final user = Provider.of<AuthProvider>(context, listen: false).user;
      if (user != null) {
        Provider.of<TaskProvider>(context, listen: false).fetchTasks(user.id);
      }
    });
  }

  void _showAddTaskSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.background,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => const AddTaskSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final taskProvider = context.watch<TaskProvider>();
    final authProvider = context.read<AuthProvider>();
    final active = taskProvider.activeTasks;
    final completed = taskProvider.completedTasks;

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
          "Tasks Checklist",
          style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold),
        ),
        actions: [
          // Syncing Spinner Indicator
          if (taskProvider.isSyncing)
            const Center(
              child: Padding(
                padding: EdgeInsets.only(right: 16.0),
                child: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.primaryLight,
                  ),
                ),
              ),
            )
          else
            IconButton(
              icon: const Icon(Icons.cloud_sync_rounded, color: AppColors.success),
              onPressed: () {
                if (authProvider.user != null) {
                  taskProvider.fetchTasks(authProvider.user!.id);
                }
              },
            ),
        ],
      ),
      body: taskProvider.isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            )
          : taskProvider.tasks.isEmpty
              ? _buildEmptyState(context)
              : ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  children: [
                    if (active.isNotEmpty) ...[
                      const Text(
                        "Active Tasks",
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.0,
                        ),
                      ),
                      const SizedBox(height: 10),
                      ...active.map((task) => _buildTaskTile(task)),
                      const SizedBox(height: 24),
                    ],
                    if (completed.isNotEmpty) ...[
                      const Text(
                        "Completed",
                        style: TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.0,
                        ),
                      ),
                      const SizedBox(height: 10),
                      ...completed.map((task) => _buildTaskTile(task)),
                    ]
                  ],
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddTaskSheet(context),
        backgroundColor: AppColors.primary,
        child: const Icon(Icons.add_rounded, color: AppColors.textPrimary, size: 30),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppColors.surface,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.border),
              ),
              child: const Icon(
                Icons.playlist_add_check_rounded,
                size: 64,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              "No Tasks Logged",
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              "Tap the + button below to add your first checklist item. Data will sync automatically when online.",
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 14,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTaskTile(Task task) {
    final taskProvider = context.read<TaskProvider>();

    Color priorityColor;
    switch (task.priority) {
      case 'high':
        priorityColor = AppColors.error;
        break;
      case 'medium':
        priorityColor = AppColors.secondary;
        break;
      default:
        priorityColor = AppColors.textSecondary;
    }

    int xpGained = 10;
    if (task.difficulty == 'medium') xpGained = 25;
    if (task.difficulty == 'hard') xpGained = 50;

    return Dismissible(
      key: Key(task.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20.0),
        decoration: BoxDecoration(
          color: AppColors.error.withOpacity(0.15),
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Icon(Icons.delete_sweep_rounded, color: AppColors.error, size: 28),
      ),
      onDismissed: (_) {
        taskProvider.deleteTask(task);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Task \"${task.title}\" deleted."),
            backgroundColor: AppColors.border,
            behavior: SnackBarBehavior.floating,
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: task.isCompleted ? Colors.transparent : AppColors.border,
            width: 1.2,
          ),
        ),
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          leading: Transform.scale(
            scale: 1.1,
            child: Checkbox(
              value: task.isCompleted,
              activeColor: AppColors.success,
              checkColor: AppColors.background,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
              side: const BorderSide(color: AppColors.textSecondary, width: 1.5),
              onChanged: (_) {
                taskProvider.toggleTaskCompletion(task);
              },
            ),
          ),
          title: Text(
            task.title,
            style: TextStyle(
              color: task.isCompleted ? AppColors.textMuted : AppColors.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w600,
              decoration: task.isCompleted ? TextDecoration.lineThrough : null,
            ),
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 8.0),
            child: Row(
              children: [
                // Priority Tag Indicator
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: priorityColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: priorityColor.withOpacity(0.3), width: 1),
                  ),
                  child: Text(
                    task.priority.toUpperCase(),
                    style: TextStyle(color: priorityColor, fontSize: 10, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(width: 8),
                // XP Reward Badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    "+$xpGained XP",
                    style: const TextStyle(color: AppColors.primaryLight, fontSize: 10, fontWeight: FontWeight.bold),
                  ),
                ),
                if (task.isRecurring) ...[
                  const SizedBox(width: 8),
                  const Icon(Icons.repeat_rounded, color: AppColors.textMuted, size: 14),
                ]
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// Add Task Bottom Sheet view
class AddTaskSheet extends StatefulWidget {
  const AddTaskSheet({super.key});

  @override
  State<AddTaskSheet> createState() => _AddTaskSheetState();
}

class _AddTaskSheetState extends State<AddTaskSheet> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  String _difficulty = 'easy'; // 'easy', 'medium', 'hard'
  String _priority = 'medium'; // 'low', 'medium', 'high'
  bool _isRecurring = false;

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;

    final user = Provider.of<AuthProvider>(context, listen: false).user;
    if (user != null) {
      Provider.of<TaskProvider>(context, listen: false).addTask(
        userId: user.id,
        title: _titleController.text.trim(),
        difficulty: _difficulty,
        priority: _priority,
        isRecurring: _isRecurring,
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
              "New Task",
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 20),

            // Task Title Input
            TextFormField(
              controller: _titleController,
              autofocus: true,
              style: const TextStyle(color: AppColors.textPrimary),
              decoration: InputDecoration(
                hintText: "What do you need to do?",
                hintStyle: const TextStyle(color: AppColors.textMuted),
                filled: true,
                fillColor: AppColors.surface,
                contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.primary, width: 2),
                ),
              ),
              validator: (val) {
                if (val == null || val.trim().isEmpty) return "Task title cannot be empty";
                return null;
              },
            ),
            const SizedBox(height: 20),

            // Difficulty Selector Block
            const Text("Difficulty", style: TextStyle(color: AppColors.textSecondary, fontSize: 13, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Row(
              children: [
                _buildSegmentChip('Easy', 'easy', _difficulty, (val) => setState(() => _difficulty = val)),
                const SizedBox(width: 8),
                _buildSegmentChip('Medium', 'medium', _difficulty, (val) => setState(() => _difficulty = val)),
                const SizedBox(width: 8),
                _buildSegmentChip('Hard', 'hard', _difficulty, (val) => setState(() => _difficulty = val)),
              ],
            ),
            const SizedBox(height: 20),

            // Priority Selector Block
            const Text("Priority", style: TextStyle(color: AppColors.textSecondary, fontSize: 13, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Row(
              children: [
                _buildSegmentChip('Low', 'low', _priority, (val) => setState(() => _priority = val)),
                const SizedBox(width: 8),
                _buildSegmentChip('Medium', 'medium', _priority, (val) => setState(() => _priority = val)),
                const SizedBox(width: 8),
                _buildSegmentChip('High', 'high', _priority, (val) => setState(() => _priority = val)),
              ],
            ),
            const SizedBox(height: 20),

            // Recurring Switch Card
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text("Daily Recurring Task", style: TextStyle(color: AppColors.textPrimary, fontSize: 14)),
                  Switch(
                    value: _isRecurring,
                    activeColor: AppColors.primary,
                    onChanged: (val) => setState(() => _isRecurring = val),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),

            // Save Task Button
            ElevatedButton(
              onPressed: _submit,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text(
                "Save Task",
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSegmentChip(String label, String value, String currentValue, ValueChanged<String> onSelected) {
    final isSelected = value == currentValue;
    return Expanded(
      child: ChoiceChip(
        label: Center(
          child: Text(
            label,
            style: TextStyle(
              color: isSelected ? AppColors.textPrimary : AppColors.textSecondary,
              fontWeight: FontWeight.bold,
              fontSize: 13,
            ),
          ),
        ),
        selected: isSelected,
        onSelected: (selected) {
          if (selected) onSelected(value);
        },
        selectedColor: AppColors.primary,
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: BorderSide(color: isSelected ? Colors.transparent : AppColors.border),
        ),
        showCheckmark: false,
      ),
    );
  }
}
