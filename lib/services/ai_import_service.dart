import 'package:flutter/material.dart';
import '../models/task.dart';

class ParsedTask {
  final String title;
  final String date;
  final String start;
  final String end;
  final String notes;

  ParsedTask({
    required this.title,
    required this.date,
    required this.start,
    required this.end,
    required this.notes,
  });
}

class AiImportService {
  /// Parses .gplan or .md content containing task import instructions.
  /// Throws descriptive exception if the header is invalid.
  static List<ParsedTask> parseGPlanContent(String content, String selectedDate) {
    // Unwrapping code fence blocks if any
    if (content.contains("```")) {
      content = content.replaceAll(RegExp(r'^```[a-zA-Z]*\n', multiLine: true), '');
      content = content.replaceAll(RegExp(r'\n```$', multiLine: true), '');
      content = content.replaceAll('```', '');
    }

    final lines = content.split('\n').map((l) => l.trim()).toList();
    
    // Find version header
    String firstLine = '';
    for (var line in lines) {
      if (line.isNotEmpty) {
        firstLine = line;
        break;
      }
    }

    if (!firstLine.startsWith("# God's Plan Import v")) {
      throw Exception("This is not a valid God's Plan import file.");
    }

    final versionStr = firstLine.substring("# God's Plan Import v".length).trim();
    final version = int.tryParse(versionStr) ?? 1;
    if (version != 1) {
      throw Exception("Unsupported import version: v$version");
    }

    final tasks = <ParsedTask>[];
    
    // Split content by dashes separator
    final blocks = content.split(RegExp(r'\n\s*---\s*\n|\n\s*---|\s*---\s*\n'));
    
    for (var block in blocks) {
      final blockLines = block.split('\n').map((l) => l.trim()).toList();
      
      String title = '';
      String start = '';
      String end = '';
      StringBuffer notesBuffer = StringBuffer();
      bool parsingNotes = false;

      for (var line in blockLines) {
        if (line.isEmpty) continue;
        if (line.startsWith('#')) continue; // Skip header comments or titles if present in the block
        if (line == '---') continue;

        final lowerLine = line.toLowerCase();
        if (lowerLine.startsWith('title:')) {
          title = line.substring('title:'.length).trim();
          parsingNotes = false;
        } else if (lowerLine.startsWith('start:')) {
          start = line.substring('start:'.length).trim();
          parsingNotes = false;
        } else if (lowerLine.startsWith('end:')) {
          end = line.substring('end:'.length).trim();
          parsingNotes = false;
        } else if (lowerLine.startsWith('notes:')) {
          parsingNotes = true;
          final restOfLine = line.substring('notes:'.length).trim();
          if (restOfLine.isNotEmpty) {
            notesBuffer.write(restOfLine);
          }
        } else if (lowerLine.startsWith('task:')) {
          // Just ignore the 'Task:' prefix line
          parsingNotes = false;
        } else {
          if (parsingNotes) {
            if (notesBuffer.isNotEmpty) notesBuffer.write('\n');
            notesBuffer.write(line);
          }
        }
      }

      // If we got a block with at least title or times, let's add it
      if (title.isNotEmpty || start.isNotEmpty || end.isNotEmpty) {
        tasks.add(ParsedTask(
          title: title,
          date: selectedDate,
          start: start,
          end: end,
          notes: notesBuffer.toString(),
        ));
      }
    }
    return tasks;
  }

  /// Validates a parsed task index. Returns a readable error string if invalid, or null if valid.
  static String? validateParsedTask(ParsedTask task, int taskIndex) {
    final taskNum = taskIndex + 1;
    
    if (task.title.isEmpty) {
      return "Task $taskNum\nInvalid Title\nTitle cannot be empty.";
    }
    
    // Date format YYYY-MM-DD
    final dateReg = RegExp(r'^\d{4}-\d{2}-\d{2}$');
    if (!dateReg.hasMatch(task.date)) {
      return "Task $taskNum\nInvalid Date\n${task.date.isEmpty ? 'Missing Date' : task.date}";
    }
    if (DateTime.tryParse(task.date) == null) {
      return "Task $taskNum\nInvalid Date Value\n${task.date}";
    }

    // Time formats HH:mm (24-hour)
    final timeReg = RegExp(r'^\d{2}:\d{2}$');
    if (!timeReg.hasMatch(task.start)) {
      return "Task $taskNum\nInvalid Start Time\n${task.start.isEmpty ? 'Missing Start Time' : task.start}";
    }
    if (!timeReg.hasMatch(task.end)) {
      return "Task $taskNum\nInvalid End Time\n${task.end.isEmpty ? 'Missing End Time' : task.end}";
    }

    final startParts = task.start.split(':');
    final endParts = task.end.split(':');
    final startHour = int.tryParse(startParts[0]) ?? -1;
    final startMin = int.tryParse(startParts[1]) ?? -1;
    final endHour = int.tryParse(endParts[0]) ?? -1;
    final endMin = int.tryParse(endParts[1]) ?? -1;

    if (startHour < 0 || startHour > 23 || startMin < 0 || startMin > 59) {
      return "Task $taskNum\nInvalid Start Time\n${task.start}";
    }
    if (endHour < 0 || endHour > 23 || endMin < 0 || endMin > 59) {
      return "Task $taskNum\nInvalid End Time\n${task.end}";
    }

    final startMinutes = startHour * 60 + startMin;
    final endMinutes = endHour * 60 + endMin;
    if (endMinutes <= startMinutes) {
      return "Task $taskNum\nInvalid Time Range\nEnd time (${task.end}) must be after start time (${task.start}).";
    }

    return null; // Valid!
  }

  /// Parses 12-hour or 24-hour time string into TimeOfDay
  static TimeOfDay? parseDueTime(String? dueTime) {
    if (dueTime == null || dueTime.isEmpty) return null;
    
    // Try 24h format (e.g. "19:00" or "08:00")
    final reg24 = RegExp(r'^(\d{1,2}):(\d{2})$');
    final match24 = reg24.firstMatch(dueTime.trim());
    if (match24 != null) {
      final g1 = match24.group(1);
      final g2 = match24.group(2);
      if (g1 != null && g2 != null) {
        final h = int.tryParse(g1) ?? 0;
        final m = int.tryParse(g2) ?? 0;
        return TimeOfDay(hour: h, minute: m);
      }
    }
    
    // Try 12h format (e.g. "7:00 PM" or "8:00 AM" or "08:00 AM")
    final reg12 = RegExp(r'^(\d{1,2}):(\d{2})\s*(AM|PM|am|pm)$');
    final match12 = reg12.firstMatch(dueTime.trim());
    if (match12 != null) {
      final g1 = match12.group(1);
      final g2 = match12.group(2);
      final g3 = match12.group(3);
      if (g1 != null && g2 != null && g3 != null) {
        var h = int.tryParse(g1) ?? 0;
        final m = int.tryParse(g2) ?? 0;
        final amPm = g3.toUpperCase();
        if (amPm == 'PM' && h < 12) {
          h += 12;
        } else if (amPm == 'AM' && h == 12) {
          h = 0;
        }
        return TimeOfDay(hour: h, minute: m);
      }
    }
    return null;
  }

  /// Checks if task matches duplicate rules: same title, same date, same start time
  static bool isDuplicate(Task existing, ParsedTask imported) {
    // Title matches (case-insensitive)
    if (existing.title.trim().toLowerCase() != imported.title.trim().toLowerCase()) {
      return false;
    }
    
    // Date matches (AI Planner tasks are one-day only so they are non-recurring)
    final sameDate = !existing.isRecurring && existing.scheduledDate == imported.date;
    if (!sameDate) return false;
    
    // Start time matches
    final tExisting = parseDueTime(existing.dueTime);
    final tImported = parseDueTime(imported.start);
    if (tExisting == null || tImported == null) return false;
    
    return tExisting.hour == tImported.hour && tExisting.minute == tImported.minute;
  }
}
