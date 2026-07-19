import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/task_provider.dart';
import '../../models/task.dart';
import '../../utils/colors.dart';
import 'dart:convert';
import 'package:file_picker/file_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/services.dart';
import '../../services/ai_import_service.dart';

class TasksView extends StatefulWidget {
  final bool isTab;
  final DateTime? initialDate;
  const TasksView({super.key, this.isTab = false, this.initialDate});

  @override
  State<TasksView> createState() => _TasksViewState();
}

class _TasksViewState extends State<TasksView> {
  late DateTime _selectedDate;

  bool isPastDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final target = DateTime(date.year, date.month, date.day);
    return target.isBefore(today);
  }

  void _showArchivedFABDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1C1C1E),
        title: Row(
          children: const [
            Icon(Icons.lock_rounded, color: AppColors.error),
            SizedBox(width: 8),
            Text(
              "Archived Day",
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: const Text(
          "You can't add tasks to past dates. Switch to today or a future date to create new tasks.",
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text(
              "OK",
              style: TextStyle(color: AppColors.accent, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _selectedDate = widget.initialDate ?? DateTime.now();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final user = Provider.of<AuthProvider>(context, listen: false).user;
      if (user != null) {
        Provider.of<TaskProvider>(context, listen: false).fetchTasks(user.id);
      }
    });
  }

  @override
  void didUpdateWidget(TasksView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialDate != oldWidget.initialDate && widget.initialDate != null) {
      setState(() {
        _selectedDate = widget.initialDate!;
      });
    }
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

  void _showPlusOptionsSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1C1C1E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetCtx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                margin: const EdgeInsets.only(top: 12, bottom: 8),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[700],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 16.0),
                child: Text(
                  "Create Tasks",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const Divider(color: Colors.white10, height: 1),
              ListTile(
                leading: const Icon(Icons.edit_rounded, color: AppColors.accent),
                title: const Text("Add Manually", style: TextStyle(color: Colors.white)),
                onTap: () {
                  Navigator.pop(sheetCtx);
                  _showAddTaskSheet(context);
                },
              ),
              const Divider(color: Colors.white10, height: 1),
              ListTile(
                leading: const Icon(Icons.star_rounded, color: Color(0xFF9D4EDD)),
                title: const Text("Plan with AI", style: TextStyle(color: Colors.white)),
                onTap: () {
                  Navigator.pop(sheetCtx);
                  _showPlanWithAIDialog(context);
                },
              ),
              const Divider(color: Colors.white10, height: 1),
              ListTile(
                leading: const Icon(Icons.file_download_rounded, color: Colors.blueAccent),
                title: const Text("Import AI Plan", style: TextStyle(color: Colors.white)),
                onTap: () {
                  Navigator.pop(sheetCtx);
                  _importAIPlan(context);
                },
              ),
              const SizedBox(height: 12),
            ],
          ),
        );
      },
    );
  }

  void _showPlanWithAIDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogCtx) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1C1C1E),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text("Plan with AI", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              Text("You'll be redirected to ChatGPT.", style: TextStyle(color: Colors.white, fontSize: 14)),
              SizedBox(height: 16),
              Text("1. Describe your schedule naturally.", style: TextStyle(color: Colors.white70, fontSize: 13)),
              SizedBox(height: 8),
              Text("2. Download the generated .gplan file.", style: TextStyle(color: Colors.white70, fontSize: 13)),
              SizedBox(height: 8),
              Text("3. Return here and tap 'Import AI Plan'.", style: TextStyle(color: Colors.white70, fontSize: 13)),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogCtx),
              child: const Text("Cancel", style: TextStyle(color: AppColors.textSecondary)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accent,
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () {
                Navigator.pop(dialogCtx);
                _launchAIPlanner();
              },
              child: const Text("Continue"),
            ),
          ],
        );
      },
    );
  }

  Future<void> _launchAIPlanner() async {
    final selectedDateStr = "${_selectedDate.year}-${_selectedDate.month.toString().padLeft(2, '0')}-${_selectedDate.day.toString().padLeft(2, '0')}";
    final prompt = """
You are the AI Planner for "God's Plan", an offline-first productivity and task tracking application.
Your goal is to turn the user's natural language schedule, list of tasks, or daily description into a structured task import file.

The user is planning tasks specifically for: $selectedDateStr.

Follow these strict rules when generating the plan:
1. The first line of the document must be exactly:
# God's Plan Import v1

2. Do not output any dates or other fields.

3. For each task, output a structured block exactly like this:
Title: [Short descriptive name of the task]
Start: [HH:mm format (24-hour, e.g. 08:30 or 15:00)]
End: [HH:mm format (24-hour, e.g. 09:30 or 16:00, must be later than Start time)]
Notes: [Optional details, or leave empty]

4. Separate each task block with a line containing exactly three dashes: ---
For example:
Title: Gym
Start: 06:00
End: 07:00
Notes: Morning workout

---

Title: Study DSA
Start: 19:00
End: 21:00
Notes: Binary Trees

---

5. Do not include any chat conversation, introductory remarks, or concluding comments.
6. Return ONLY the raw document text. Do not wrap the document in triple backticks or any Markdown code fence.
7. The user will save this output text as a `.gplan` or `.md` file to import it into the app.

User request/schedule to plan:
""";

    // Copy prompt to clipboard
    try {
      await Clipboard.setData(ClipboardData(text: prompt));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              "Prompt copied. Paste it into ChatGPT and describe your schedule.",
              style: TextStyle(color: Colors.white),
            ),
            backgroundColor: Color(0xFF1C1C1E),
            duration: Duration(seconds: 4),
          ),
        );
      }
    } catch (_) {}

    final appUri = Uri.parse("chatgpt://");
    final webUri = Uri.parse("https://chatgpt.com/");
    
    try {
      final launched = await launchUrl(
        appUri,
        mode: LaunchMode.externalNonBrowserApplication,
      );
      if (!launched) {
        await launchUrl(webUri, mode: LaunchMode.externalApplication);
      }
    } catch (_) {
      try {
        await launchUrl(webUri, mode: LaunchMode.externalApplication);
      } catch (_) {
        await launchUrl(webUri);
      }
    }
  }

  Future<void> _importAIPlan(BuildContext context) async {
    debugPrint("[AI IMPORT] Import started");
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['gplan', 'md'],
        withData: true,
      );

      if (result == null || result.files.isEmpty) {
        debugPrint("[AI IMPORT] Canceled by user");
        return; // User canceled
      }

      final file = result.files.first;
      debugPrint("[AI IMPORT] Selected file: ${file.name} (size: ${file.size} bytes)");
      final bytes = file.bytes;
      if (bytes == null) {
        debugPrint("[AI IMPORT] Error - Could not read file bytes");
        _showErrorDialog(context, "Could not read file data.");
        return;
      }

      final content = utf8.decode(bytes);
      debugPrint("[AI IMPORT] File content loaded. Characters: ${content.length}");
      if (content.isEmpty) {
        debugPrint("[AI IMPORT] Error - File content is empty");
        _showErrorDialog(context, "The imported file is empty.");
        return;
      }

      final selectedDateStr = "${_selectedDate.year}-${_selectedDate.month.toString().padLeft(2, '0')}-${_selectedDate.day.toString().padLeft(2, '0')}";
      debugPrint("[AI IMPORT] Current selected date context: $selectedDateStr");

      // Parse
      List<ParsedTask> parsedTasks;
      try {
        parsedTasks = AiImportService.parseGPlanContent(content, selectedDateStr);
        debugPrint("[AI IMPORT] Parsed ${parsedTasks.length} tasks");
      } catch (e) {
        debugPrint("[AI IMPORT] Parser Error: $e");
        _showErrorDialog(context, e.toString().replaceFirst("Exception: ", ""));
        return;
      }

      if (parsedTasks.isEmpty) {
        debugPrint("[AI IMPORT] Error - Parser returned 0 tasks");
        _showErrorDialog(context, "No tasks found in the plan file.");
        return;
      }

      // Validate
      for (int i = 0; i < parsedTasks.length; i++) {
        final error = AiImportService.validateParsedTask(parsedTasks[i], i);
        if (error != null) {
          debugPrint("[AI IMPORT] Validation failed for task index $i: $error");
          _showErrorDialog(context, error);
          return;
        }
      }
      debugPrint("[AI IMPORT] Validation successful for all tasks");

      // Show Preview Screen
      _showImportPreviewSheet(context, parsedTasks);

    } catch (e) {
      debugPrint("[AI IMPORT] Unexpected Error: $e");
      _showErrorDialog(context, "Failed to read or parse file: ${e.toString()}");
    }
  }

  void _showErrorDialog(BuildContext context, String message) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1C1C1E),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: const [
              Icon(Icons.error_outline_rounded, color: AppColors.error),
              SizedBox(width: 10),
              Text("Import Error", style: TextStyle(color: Colors.white)),
            ],
          ),
          content: Text(
            message,
            style: const TextStyle(color: Colors.white70),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("OK", style: TextStyle(color: AppColors.accent)),
            ),
          ],
        );
      },
    );
  }

  void _showImportPreviewSheet(BuildContext context, List<ParsedTask> parsedTasks) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1C1C1E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        return DraggableScrollableSheet(
          initialChildSize: 0.6,
          maxChildSize: 0.9,
          minChildSize: 0.4,
          expand: false,
          builder: (sheetContext, scrollController) {
            return Column(
              children: [
                Container(
                  margin: const EdgeInsets.only(top: 12, bottom: 8),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[700],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12.0),
                  child: Text(
                    "Import Tasks",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const Divider(color: Colors.white10, height: 1),
                Expanded(
                  child: ListView.builder(
                    controller: scrollController,
                    itemCount: parsedTasks.length,
                    itemBuilder: (context, index) {
                      final t = parsedTasks[index];
                      return ListTile(
                        leading: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppColors.accent.withOpacity(0.1),
                          ),
                          child: const Icon(Icons.check, color: AppColors.accent, size: 18),
                        ),
                        title: Text(t.title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                        subtitle: Text(
                          "${t.date}  •  ${t.start} - ${t.end}${t.notes.isNotEmpty ? '  •  ${t.notes}' : ''}",
                          style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                        ),
                      );
                    },
                  ),
                ),
                const Divider(color: Colors.white10, height: 1),
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.white,
                            side: const BorderSide(color: Colors.white24),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          onPressed: () => Navigator.pop(sheetContext),
                          child: const Text("Cancel"),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.accent,
                            foregroundColor: Colors.black,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          onPressed: () async {
                            Navigator.pop(sheetContext); // Close preview sheet
                            await _processImport(context, parsedTasks);
                          },
                          child: const Text("Import", style: TextStyle(fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _processImport(BuildContext context, List<ParsedTask> parsedTasks) async {
    debugPrint("[AI IMPORT] Processing import for ${parsedTasks.length} tasks");
    final taskProvider = Provider.of<TaskProvider>(context, listen: false);
    final user = Provider.of<AuthProvider>(context, listen: false).user;
    if (user == null) {
      debugPrint("[AI IMPORT] Error - No authenticated user found");
      return;
    }

    int importedCount = 0;
    int skippedCount = 0;

    try {
      debugPrint("[AI IMPORT] Visible task count before import: ${taskProvider.tasks.length}");
      for (var importedTask in parsedTasks) {
        // Search for duplicates
        Task? duplicate;
        for (var t in taskProvider.tasks) {
          if (AiImportService.isDuplicate(t, importedTask)) {
            duplicate = t;
            break;
          }
        }

        if (duplicate != null) {
          debugPrint("[AI IMPORT] Duplicate found for task '${importedTask.title}'");
          final choice = await _showConflictDialog(context, importedTask);
          debugPrint("[AI IMPORT] User conflict choice: $choice");
          if (choice == 'skip' || choice == null) {
            skippedCount++;
            continue;
          } else if (choice == 'replace') {
            await taskProvider.deleteTask(duplicate);
            await _insertImportedTask(taskProvider, importedTask, user.id, triggerSync: false);
            importedCount++;
          } else if (choice == 'keep_both') {
            await _insertImportedTask(taskProvider, importedTask, user.id, triggerSync: false);
            importedCount++;
          }
        } else {
          debugPrint("[AI IMPORT] No duplicate for task '${importedTask.title}', inserting...");
          await _insertImportedTask(taskProvider, importedTask, user.id, triggerSync: false);
          importedCount++;
        }
      }

      debugPrint("[AI IMPORT] Import processing complete. Imported: $importedCount, Skipped: $skippedCount");
      debugPrint("[AI IMPORT] Visible task count after import (before sync): ${taskProvider.tasks.length}");

      if (importedCount > 0) {
        debugPrint("[AI IMPORT] Triggering single synchronization session for user ${user.id}");
        await taskProvider.triggerSync(user.id);
      }

      if (context.mounted) {
        _showSuccessSummaryDialog(context, importedCount, skippedCount);
      }
    } catch (e) {
      debugPrint("[AI IMPORT] Exception in _processImport: $e");
      if (context.mounted) {
        _showErrorDialog(context, "Error during import: ${e.toString()}");
      }
    }
  }

  Future<String?> _showConflictDialog(BuildContext context, ParsedTask task) async {
    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1C1C1E),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: const [
              Icon(Icons.warning_amber_rounded, color: Colors.orangeAccent),
              SizedBox(width: 10),
              Text("Conflict Detected", style: TextStyle(color: Colors.white)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Task '${task.title}' on ${task.date} at ${task.start} already exists in your list.",
                style: const TextStyle(color: Colors.white70, fontSize: 14),
              ),
              const SizedBox(height: 12),
              const Text(
                "What would you like to do?",
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
              ),
            ],
          ),
          actionsAlignment: MainAxisAlignment.spaceBetween,
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, 'skip'),
              child: const Text("Skip", style: TextStyle(color: AppColors.textSecondary)),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, 'replace'),
              child: const Text("Replace", style: TextStyle(color: AppColors.accent)),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, 'keep_both'),
              child: const Text("Keep Both", style: TextStyle(color: Colors.blueAccent)),
            ),
          ],
        );
      },
    );
  }

  void _showSuccessSummaryDialog(BuildContext context, int imported, int skipped) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1C1C1E),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: const [
              Icon(Icons.check_circle_outline_rounded, color: AppColors.success),
              SizedBox(width: 10),
              Text("Imported Successfully", style: TextStyle(color: Colors.white)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("✓ $imported Tasks Imported", style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
              if (skipped > 0) ...[
                const SizedBox(height: 8),
                Text("⚠ $skipped Duplicates Skipped", style: const TextStyle(color: Colors.orangeAccent, fontSize: 14)),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Done", style: TextStyle(color: AppColors.accent, fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  Future<void> _insertImportedTask(TaskProvider taskProvider, ParsedTask imported, String userId, {bool triggerSync = true}) async {
    final tImported = AiImportService.parseDueTime(imported.start);
    String? formattedDueTime;
    if (tImported != null) {
      final hour = tImported.hour;
      final minute = tImported.minute;
      final amPm = hour >= 12 ? 'PM' : 'AM';
      final displayHour = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
      formattedDueTime = "$displayHour:${minute.toString().padLeft(2, '0')} $amPm";
    }

    debugPrint("[AI IMPORT] Inserting task '${imported.title}' for date ${imported.date} at $formattedDueTime");
    await taskProvider.addTask(
      userId: userId,
      title: imported.title.trim(),
      isRecurring: false,
      repeatType: 'never',
      dueTime: formattedDueTime,
      scheduledDate: imported.date,
      triggerSync: triggerSync,
    );
    debugPrint("[AI IMPORT] Successfully inserted task '${imported.title}'");
  }

  void _showTaskOptionsSheet(Task task) {
    final taskProvider = Provider.of<TaskProvider>(context, listen: false);
    final selectedDateStr = "${_selectedDate.year}-${_selectedDate.month.toString().padLeft(2, '0')}-${_selectedDate.day.toString().padLeft(2, '0')}";

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1C1C1E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        final isCompleted = taskProvider.completions.any((c) => c['task_id'] == task.id && c['completed_date'] == selectedDateStr);
        final isArchived = isPastDate(_selectedDate);

        if (isArchived) {
          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: const [
                      Icon(Icons.lock_rounded, color: AppColors.error, size: 20),
                      SizedBox(width: 8),
                      Text(
                        "Archived Task Details",
                        style: TextStyle(
                          color: AppColors.error,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Text(
                    task.title,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Icon(
                        task.isRecurring ? Icons.repeat_rounded : Icons.calendar_today_rounded,
                        color: AppColors.textSecondary,
                        size: 16,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        task.isRecurring
                            ? "Daily Habit"
                            : "Single Task • ${task.scheduledDate ?? 'No date'}",
                        style: const TextStyle(color: AppColors.textSecondary, fontSize: 14),
                      ),
                    ],
                  ),
                  if (task.dueTime != null) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(Icons.access_time_rounded, color: AppColors.textSecondary, size: 16),
                        const SizedBox(width: 8),
                        Text(
                          task.dueTime!,
                          style: const TextStyle(color: AppColors.textSecondary, fontSize: 14),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.surface,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        side: const BorderSide(color: AppColors.border),
                      ),
                      onPressed: () => Navigator.pop(context),
                      child: const Text("Close", style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                margin: const EdgeInsets.only(top: 12, bottom: 8),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[700],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            task.title,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            task.isRecurring
                                ? "Daily habit • ${task.dueTime ?? 'Anytime'}"
                                : "Single task • ${task.scheduledDate ?? 'No date'} • ${task.dueTime ?? 'Anytime'}",
                            style: const TextStyle(color: AppColors.textMuted, fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                    if (task.isPaused)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.error.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Text(
                          "PAUSED",
                          style: TextStyle(color: AppColors.error, fontSize: 10, fontWeight: FontWeight.bold),
                        ),
                      ),
                  ],
                ),
              ),
              const Divider(color: AppColors.border, height: 1),
              ListTile(
                leading: Icon(
                  isCompleted ? Icons.radio_button_unchecked_rounded : Icons.check_circle_rounded,
                  color: isCompleted ? AppColors.textSecondary : AppColors.accent,
                ),
                title: Text(
                  isCompleted ? "Mark as Active" : "Mark as Completed",
                  style: const TextStyle(color: AppColors.textPrimary),
                ),
                onTap: () {
                  Navigator.pop(context);
                  taskProvider.toggleTaskCompletion(task, date: _selectedDate);
                },
              ),
              ListTile(
                leading: Icon(
                  task.isPaused ? Icons.play_arrow_rounded : Icons.pause_rounded,
                  color: Colors.amber,
                ),
                title: Text(
                  task.isPaused ? "Resume Habit" : "Pause Habit",
                  style: const TextStyle(color: AppColors.textPrimary),
                ),
                onTap: () {
                  Navigator.pop(context);
                  taskProvider.toggleTaskPause(task);
                },
              ),
              ListTile(
                leading: const Icon(Icons.edit_rounded, color: Colors.blue),
                title: const Text("Edit Task Details", style: TextStyle(color: AppColors.textPrimary)),
                onTap: () {
                  Navigator.pop(context);
                  _showEditTaskSheet(task);
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete_forever_rounded, color: AppColors.error),
                title: const Text("Delete Task", style: TextStyle(color: AppColors.textPrimary)),
                onTap: () {
                  Navigator.pop(context);
                  taskProvider.deleteTask(task);
                },
              ),
              const SizedBox(height: 12),
            ],
          ),
        );
      },
    );
  }

  void _showEditTaskSheet(Task task) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.background,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => EditTaskSheet(task: task),
    );
  }

  Widget _buildWeeklyCalendar(TaskProvider taskProvider) {
    final now = DateTime.now();
    final currentDayOfWeek = _selectedDate.weekday;
    final startOfWeek = _selectedDate.subtract(Duration(days: currentDayOfWeek - 1));
    final monthNames = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"];
    
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "${monthNames[startOfWeek.month - 1]} ${startOfWeek.year}",
                style: const TextStyle(color: AppColors.textPrimary, fontSize: 18, fontWeight: FontWeight.bold),
              ),
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.chevron_left_rounded, color: AppColors.textSecondary),
                    onPressed: () {
                      setState(() {
                        _selectedDate = _selectedDate.subtract(const Duration(days: 7));
                      });
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.chevron_right_rounded, color: AppColors.textSecondary),
                    onPressed: () {
                      setState(() {
                        _selectedDate = _selectedDate.add(const Duration(days: 7));
                      });
                    },
                  ),
                ],
              )
            ],
          ),
        ),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Row(
            children: List.generate(7, (index) {
              final dayDate = startOfWeek.add(Duration(days: index));
              final dayNames = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"];
              
              final isSelected = dayDate.year == _selectedDate.year && dayDate.month == _selectedDate.month && dayDate.day == _selectedDate.day;
              final isToday = dayDate.year == now.year && dayDate.month == now.month && dayDate.day == now.day;
              
              final active = taskProvider.getActiveTasksForDate(dayDate);
              final completed = taskProvider.getCompletedTasksForDate(dayDate);
              
              Color statusColor = Colors.transparent;
              if (isSelected) {
                statusColor = AppColors.accent;
              } else if (active.isEmpty && completed.isNotEmpty) {
                statusColor = Colors.greenAccent.withOpacity(0.2);
              } else if (active.isNotEmpty && dayDate.isBefore(DateTime(now.year, now.month, now.day))) {
                statusColor = AppColors.error.withOpacity(0.2);
              } else if (isToday) {
                statusColor = Colors.white.withOpacity(0.1);
              }
              
              return GestureDetector(
                onTap: () {
                  setState(() {
                    _selectedDate = dayDate;
                  });
                },
                child: Container(
                  width: 54,
                  margin: const EdgeInsets.symmetric(horizontal: 6),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: isSelected ? AppColors.accent : statusColor,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isSelected ? AppColors.accent : (isToday ? Colors.white54 : Colors.transparent),
                    ),
                  ),
                  child: Column(
                    children: [
                      Text(
                        dayNames[index],
                        style: TextStyle(
                          color: isSelected ? Colors.black : AppColors.textSecondary,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      isPastDate(dayDate)
                          ? Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  "${dayDate.day}",
                                  style: TextStyle(
                                    color: isSelected ? Colors.black : AppColors.textPrimary,
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(width: 2),
                                Icon(
                                  Icons.lock_rounded,
                                  color: isSelected ? Colors.black54 : AppColors.textSecondary,
                                  size: 10,
                                ),
                              ],
                            )
                          : Text(
                              "${dayDate.day}",
                              style: TextStyle(
                                color: isSelected ? Colors.black : AppColors.textPrimary,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                      const SizedBox(height: 6),
                      if (active.isEmpty && completed.isNotEmpty && !isSelected)
                        const Icon(Icons.check_circle_rounded, color: Colors.greenAccent, size: 12)
                      else if (active.isNotEmpty && dayDate.isBefore(DateTime(now.year, now.month, now.day)) && !isSelected)
                        const Icon(Icons.close_rounded, color: AppColors.error, size: 12)
                      else
                        const SizedBox(height: 12),
                    ],
                  ),
                ),
              );
            }),
          ),
        ),
      ],
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
    final taskProvider = context.watch<TaskProvider>();
    final authProvider = context.read<AuthProvider>();

    final active = taskProvider.getActiveTasksForDate(_selectedDate);
    final completed = taskProvider.getCompletedTasksForDate(_selectedDate);
    final paused = taskProvider.tasks.where((t) => t.isPaused).toList();

    debugPrint("[UI] Rebuilt. Selected Date: $_selectedDate. Active tasks count: ${active.length}. Completed tasks count: ${completed.length}. Total tasks count: ${taskProvider.tasks.length}");

    if (taskProvider.shouldShowCongrats || taskProvider.shouldShowXpAnimation) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (taskProvider.shouldShowCongrats) {
          _showCongratsDialog(context, taskProvider);
        } else if (taskProvider.shouldShowXpAnimation) {
          _showXpNotification(context, taskProvider);
        }
      });
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: widget.isTab
            ? null
            : IconButton(
                icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppColors.textPrimary),
                onPressed: () => Navigator.pop(context),
              ),
        title: const Text(
          "Tasks Checklist",
          style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold),
        ),
        actions: [
          if (taskProvider.isSyncing)
            const Center(
              child: Padding(
                padding: EdgeInsets.only(right: 16.0),
                child: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.accent,
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
          ? const Center(child: CircularProgressIndicator(color: AppColors.accent))
          : Column(
              children: [
                _buildWeeklyCalendar(taskProvider),
                if (isPastDate(_selectedDate)) ...[
                  const SizedBox(height: 6),
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppColors.error.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.error.withOpacity(0.3)),
                    ),
                    child: Row(
                      children: const [
                        Icon(Icons.lock_rounded, color: AppColors.error, size: 16),
                        SizedBox(width: 8),
                        Text(
                          "Archived Day (Read-only)",
                          style: TextStyle(
                            color: AppColors.error,
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                Expanded(
                  child: taskProvider.tasks.isEmpty
                    ? _buildEmptyState(context)
                    : (isPastDate(_selectedDate)
                        ? ListView(
                            padding: const EdgeInsets.only(left: 20.0, right: 20.0, top: 12.0, bottom: 120.0),
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
                              ],
                              if (active.isNotEmpty && (completed.isNotEmpty || paused.isNotEmpty))
                                const SizedBox(height: 24),
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
                              ],
                              if (completed.isNotEmpty && paused.isNotEmpty)
                                const SizedBox(height: 24),
                              if (paused.isNotEmpty) ...[
                                const Text(
                                  "Paused Habits",
                                  style: TextStyle(
                                    color: AppColors.textMuted,
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 1.0,
                                  ),
                                ),
                                const SizedBox(height: 10),
                                ...paused.map((task) => _buildTaskTile(task)),
                              ],
                            ],
                          )
                        : ReorderableListView(
                            buildDefaultDragHandles: false,
                            padding: const EdgeInsets.only(left: 20.0, right: 20.0, top: 12.0, bottom: 120.0),
                            header: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
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
                                ],
                              ],
                            ),
                            footer: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (active.isNotEmpty) const SizedBox(height: 24),
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
                                  const SizedBox(height: 24),
                                ],
                                if (paused.isNotEmpty) ...[
                                  const Text(
                                    "Paused Habits",
                                    style: TextStyle(
                                      color: AppColors.textMuted,
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 1.0,
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  ...paused.map((task) => _buildTaskTile(task)),
                                ]
                              ],
                            ),
                            onReorder: (oldIndex, newIndex) {
                              taskProvider.reorderTasks(oldIndex, newIndex, _selectedDate);
                            },
                            children: active.asMap().entries.map((entry) {
                              final index = entry.key;
                              final task = entry.value;
                              return _buildTaskTile(task, index: index);
                            }).toList(),
                          )),
                ),
              ],
            ),
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 96.0, right: 8.0),
        child: FloatingActionButton(
          onPressed: isPastDate(_selectedDate)
              ? () => _showArchivedFABDialog()
              : () => _showPlusOptionsSheet(context),
          backgroundColor: isPastDate(_selectedDate)
              ? AppColors.border
              : AppColors.accent,
          child: Icon(
            isPastDate(_selectedDate) ? Icons.lock_outline_rounded : Icons.add_rounded,
            color: isPastDate(_selectedDate) ? AppColors.textSecondary : Colors.black,
            size: 30,
          ),
        ),
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

  Widget _buildTaskTile(Task task, {int? index}) {
    final taskProvider = context.read<TaskProvider>();
    final selectedDateStr = "${_selectedDate.year}-${_selectedDate.month.toString().padLeft(2, '0')}-${_selectedDate.day.toString().padLeft(2, '0')}";
    final isCompleted = taskProvider.completions.any((c) => c['task_id'] == task.id && c['completed_date'] == selectedDateStr);

    final isArchived = isPastDate(_selectedDate);

    return Dismissible(
      key: Key(task.id),
      direction: isArchived ? DismissDirection.none : DismissDirection.endToStart,
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
            color: isCompleted ? Colors.transparent : AppColors.border,
            width: 1.2,
          ),
        ),
        child: ListTile(
          onTap: isArchived
              ? null
              : () {
                  taskProvider.toggleTaskCompletion(task, date: _selectedDate);
                },
          onLongPress: () => _showTaskOptionsSheet(task),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          leading: task.isPaused
              ? const Icon(Icons.pause_circle_filled_rounded, color: Colors.amber, size: 28)
              : Transform.scale(
                  scale: 1.1,
                  child: Checkbox(
                    value: isCompleted,
                    activeColor: isArchived ? AppColors.textMuted : AppColors.accent,
                    checkColor: Colors.black,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                    side: const BorderSide(color: AppColors.textSecondary, width: 1.5),
                    onChanged: isArchived
                        ? null
                        : (_) {
                            taskProvider.toggleTaskCompletion(task, date: _selectedDate);
                          },
                  ),
                ),
          title: Text(
            task.title,
            style: TextStyle(
              color: task.isPaused
                  ? AppColors.textMuted
                  : (isCompleted 
                      ? AppColors.textMuted 
                      : (() {
                          final checkDate = task.isRecurring ? _selectedDate : (task.scheduledDate != null ? DateTime.parse(task.scheduledDate!) : _selectedDate);
                          final now = DateTime.now();
                          if (checkDate.isBefore(DateTime(now.year, now.month, now.day))) {
                            return AppColors.error; // Missed
                          }
                          return AppColors.textPrimary;
                        })()),
              fontSize: 16,
              fontWeight: FontWeight.w600,
              decoration: isCompleted ? TextDecoration.lineThrough : null,
            ),
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 8.0),
            child: Row(
              children: [
                if (task.isRecurring) ...[
                  const Icon(Icons.repeat_rounded, color: AppColors.accent, size: 14),
                  const SizedBox(width: 4),
                  const Text(
                    "Daily Habit",
                    style: TextStyle(color: AppColors.accent, fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                  if (task.streakCount > 0) ...[
                    const SizedBox(width: 12),
                    Text(
                      "🔥 ${task.streakCount} day streak",
                      style: const TextStyle(color: Colors.orange, fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                  ],
                ] else ...[
                  const Icon(Icons.calendar_today_rounded, color: AppColors.textSecondary, size: 12),
                  const SizedBox(width: 4),
                  Text(
                    task.scheduledDate ?? "Today",
                    style: const TextStyle(color: AppColors.textSecondary, fontSize: 11),
                  ),
                ],
                if (task.dueTime != null) ...[
                  const SizedBox(width: 12),
                  const Icon(Icons.access_time_rounded, color: AppColors.textSecondary, size: 12),
                  const SizedBox(width: 4),
                  Text(
                    task.dueTime!,
                    style: const TextStyle(color: AppColors.textSecondary, fontSize: 11),
                  ),
                ]
              ],
            ),
          ),
          trailing: index != null
              ? ReorderableDragStartListener(
                  index: index,
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
                    child: Icon(
                      Icons.reorder_rounded,
                      color: AppColors.textSecondary,
                      size: 24,
                    ),
                  ),
                )
              : null,
        ),
      ),
    );
  }
}

class AddTaskSheet extends StatefulWidget {
  const AddTaskSheet({super.key});

  @override
  State<AddTaskSheet> createState() => _AddTaskSheetState();
}

class _AddTaskSheetState extends State<AddTaskSheet> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  bool _isRecurring = true; // By default everyday is true!
  DateTime _scheduledDate = DateTime.now();
  TimeOfDay? _selectedTime;

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _scheduledDate,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: AppColors.accent,
              onPrimary: Colors.black,
              surface: Color(0xFF1C1C1E),
              onSurface: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        _scheduledDate = picked;
      });
    }
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime ?? TimeOfDay.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: AppColors.accent,
              onPrimary: Colors.black,
              surface: Color(0xFF1C1C1E),
              onSurface: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        _selectedTime = picked;
      });
    }
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;

    final user = Provider.of<AuthProvider>(context, listen: false).user;
    if (user != null) {
      String? formattedTime;
      if (_selectedTime != null) {
        final localizations = MaterialLocalizations.of(context);
        formattedTime = localizations.formatTimeOfDay(_selectedTime!, alwaysUse24HourFormat: false);
      }

      final formattedDate = "${_scheduledDate.year}-${_scheduledDate.month.toString().padLeft(2, '0')}-${_scheduledDate.day.toString().padLeft(2, '0')}";

      Provider.of<TaskProvider>(context, listen: false).addTask(
        userId: user.id,
        title: _titleController.text.trim(),
        isRecurring: _isRecurring,
        dueTime: formattedTime,
        scheduledDate: _isRecurring ? null : formattedDate,
      );
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final formattedDateStr = "${_scheduledDate.day} ${_getMonthName(_scheduledDate.month)} ${_scheduledDate.year}";
    final timeStr = _selectedTime != null
        ? _selectedTime!.format(context)
        : "Anytime";

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
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  "New Task",
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, color: AppColors.textSecondary),
                  onPressed: () => Navigator.pop(context),
                )
              ],
            ),
            const SizedBox(height: 20),

            TextFormField(
              controller: _titleController,
              autofocus: true,
              style: const TextStyle(color: AppColors.textPrimary),
              decoration: InputDecoration(
                hintText: "Enter task name",
                hintStyle: const TextStyle(color: AppColors.textMuted),
                filled: true,
                fillColor: const Color(0xFF1C1C1E),
                contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: AppColors.accent, width: 1.5),
                ),
              ),
              validator: (val) {
                if (val == null || val.trim().isEmpty) return "Task title cannot be empty";
                return null;
              },
            ),
            const SizedBox(height: 20),

            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFF1C1C1E),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text(
                        "Repeat Everyday",
                        style: TextStyle(color: AppColors.textPrimary, fontSize: 15, fontWeight: FontWeight.w600),
                      ),
                      SizedBox(height: 2),
                      Text(
                        "Task repeats daily",
                        style: TextStyle(color: AppColors.textMuted, fontSize: 12),
                      ),
                    ],
                  ),
                  Switch(
                    value: _isRecurring,
                    activeColor: AppColors.accent,
                    activeTrackColor: AppColors.accent.withOpacity(0.3),
                    inactiveThumbColor: Colors.grey,
                    inactiveTrackColor: Colors.black26,
                    onChanged: (val) => setState(() => _isRecurring = val),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            if (!_isRecurring) ...[
              GestureDetector(
                onTap: _pickDate,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1C1C1E),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: const [
                          Icon(Icons.calendar_today_rounded, color: AppColors.accent, size: 20),
                          SizedBox(width: 12),
                          Text(
                            "Select Date",
                            style: TextStyle(color: AppColors.textPrimary, fontSize: 15, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                      Text(
                        formattedDateStr,
                        style: const TextStyle(color: AppColors.accent, fontSize: 14, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],

            GestureDetector(
              onTap: _pickTime,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                decoration: BoxDecoration(
                  color: const Color(0xFF1C1C1E),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: const [
                        Icon(Icons.access_time_filled_rounded, color: AppColors.accent, size: 20),
                        SizedBox(width: 12),
                        Text(
                          "Select Time",
                          style: TextStyle(color: AppColors.textPrimary, fontSize: 15, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                    Text(
                      timeStr,
                      style: const TextStyle(color: AppColors.accent, fontSize: 14, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            ElevatedButton(
              onPressed: _submit,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accent,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                elevation: 0,
              ),
              child: const Text(
                "Save Task",
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getMonthName(int month) {
    const months = [
      "Jan", "Feb", "Mar", "Apr", "May", "Jun",
      "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"
    ];
    if (month >= 1 && month <= 12) return months[month - 1];
    return "";
  }
}

class EditTaskSheet extends StatefulWidget {
  final Task task;
  const EditTaskSheet({super.key, required this.task});

  @override
  State<EditTaskSheet> createState() => _EditTaskSheetState();
}

class _EditTaskSheetState extends State<EditTaskSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleController;
  late bool _isRecurring;
  late DateTime _scheduledDate;
  TimeOfDay? _selectedTime;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.task.title);
    _isRecurring = widget.task.isRecurring;
    if (widget.task.scheduledDate != null) {
      try {
        _scheduledDate = DateTime.parse(widget.task.scheduledDate!);
      } catch (_) {
        _scheduledDate = DateTime.now();
      }
    } else {
      _scheduledDate = DateTime.now();
    }
    
    if (widget.task.dueTime != null) {
      final parts = widget.task.dueTime!.split(" ");
      if (parts.isNotEmpty) {
        final timeParts = parts[0].split(":");
        if (timeParts.length >= 2) {
          int hour = int.tryParse(timeParts[0]) ?? 12;
          int minute = int.tryParse(timeParts[1]) ?? 0;
          if (parts.length > 1 && parts[1].toLowerCase() == "pm" && hour < 12) {
            hour += 12;
          } else if (parts.length > 1 && parts[1].toLowerCase() == "am" && hour == 12) {
            hour = 0;
          }
          _selectedTime = TimeOfDay(hour: hour, minute: minute);
        }
      }
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _scheduledDate,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: AppColors.accent,
              onPrimary: Colors.black,
              surface: Color(0xFF1C1C1E),
              onSurface: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        _scheduledDate = picked;
      });
    }
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime ?? TimeOfDay.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: AppColors.accent,
              onPrimary: Colors.black,
              surface: Color(0xFF1C1C1E),
              onSurface: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        _selectedTime = picked;
      });
    }
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;

    String? formattedTime;
    if (_selectedTime != null) {
      final localizations = MaterialLocalizations.of(context);
      formattedTime = localizations.formatTimeOfDay(_selectedTime!, alwaysUse24HourFormat: false);
    }

    final formattedDate = "${_scheduledDate.year}-${_scheduledDate.month.toString().padLeft(2, '0')}-${_scheduledDate.day.toString().padLeft(2, '0')}";

    Provider.of<TaskProvider>(context, listen: false).updateTask(
      taskId: widget.task.id,
      title: _titleController.text.trim(),
      isRecurring: _isRecurring,
      dueTime: formattedTime,
      scheduledDate: _isRecurring ? null : formattedDate,
    );
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final formattedDateStr = "${_scheduledDate.day} ${_getMonthName(_scheduledDate.month)} ${_scheduledDate.year}";
    final timeStr = _selectedTime != null
        ? _selectedTime!.format(context)
        : "Anytime";

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
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  "Edit Task",
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, color: AppColors.textSecondary),
                  onPressed: () => Navigator.pop(context),
                )
              ],
            ),
            const SizedBox(height: 20),

            TextFormField(
              controller: _titleController,
              autofocus: true,
              style: const TextStyle(color: AppColors.textPrimary),
              decoration: InputDecoration(
                hintText: "Enter task name",
                hintStyle: const TextStyle(color: AppColors.textMuted),
                filled: true,
                fillColor: const Color(0xFF1C1C1E),
                contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: AppColors.accent, width: 1.5),
                ),
              ),
              validator: (val) {
                if (val == null || val.trim().isEmpty) return "Task title cannot be empty";
                return null;
              },
            ),
            const SizedBox(height: 20),

            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFF1C1C1E),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text(
                        "Repeat Everyday",
                        style: TextStyle(color: AppColors.textPrimary, fontSize: 15, fontWeight: FontWeight.w600),
                      ),
                      SizedBox(height: 2),
                      Text(
                        "Task repeats daily",
                        style: TextStyle(color: AppColors.textMuted, fontSize: 12),
                      ),
                    ],
                  ),
                  Switch(
                    value: _isRecurring,
                    activeColor: AppColors.accent,
                    activeTrackColor: AppColors.accent.withOpacity(0.3),
                    inactiveThumbColor: Colors.grey,
                    inactiveTrackColor: Colors.black26,
                    onChanged: (val) => setState(() => _isRecurring = val),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            if (!_isRecurring) ...[
              GestureDetector(
                onTap: _pickDate,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1C1C1E),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: const [
                          Icon(Icons.calendar_today_rounded, color: AppColors.accent, size: 20),
                          SizedBox(width: 12),
                          Text(
                            "Select Date",
                            style: TextStyle(color: AppColors.textPrimary, fontSize: 15, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                      Text(
                        formattedDateStr,
                        style: const TextStyle(color: AppColors.accent, fontSize: 14, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],

            GestureDetector(
              onTap: _pickTime,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                decoration: BoxDecoration(
                  color: const Color(0xFF1C1C1E),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: const [
                        Icon(Icons.access_time_filled_rounded, color: AppColors.accent, size: 20),
                        SizedBox(width: 12),
                        Text(
                          "Select Time",
                          style: TextStyle(color: AppColors.textPrimary, fontSize: 15, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                    Text(
                      timeStr,
                      style: const TextStyle(color: AppColors.accent, fontSize: 14, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            ElevatedButton(
              onPressed: _submit,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accent,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                elevation: 0,
              ),
              child: const Text(
                "Save Changes",
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getMonthName(int month) {
    const months = [
      "Jan", "Feb", "Mar", "Apr", "May", "Jun",
      "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"
    ];
    if (month >= 1 && month <= 12) return months[month - 1];
    return "";
  }
}
