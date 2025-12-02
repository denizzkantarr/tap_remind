import 'package:hive_flutter/hive_flutter.dart';
import '../models/reminder.dart';

class StorageService {
  static const String _reminderBoxName = 'reminders';

  Future<void> init() async {
    // Adapter should be registered in main.dart
    await Hive.openBox<Reminder>(_reminderBoxName);
  }

  Box<Reminder> get _reminderBox => Hive.box<Reminder>(_reminderBoxName);

  Future<void> saveReminder(Reminder reminder) async {
    await _reminderBox.put(reminder.id, reminder);
  }

  Future<void> deleteReminder(String id) async {
    await _reminderBox.delete(id);
  }

  Future<Reminder?> getReminder(String id) async {
    return _reminderBox.get(id);
  }

  List<Reminder> getAllReminders() {
    return _reminderBox.values.toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  List<Reminder> getActiveReminders() {
    final now = DateTime.now();
    return _reminderBox.values
        .where((r) => !r.isCompleted && r.scheduledTime.isAfter(now))
        .toList()
      ..sort((a, b) => a.scheduledTime.compareTo(b.scheduledTime));
  }

  List<Reminder> getCompletedReminders() {
    return _reminderBox.values
        .where((r) => r.isCompleted)
        .toList()
      ..sort((a, b) => b.scheduledTime.compareTo(a.scheduledTime));
  }

  Future<void> markAsCompleted(String id) async {
    final reminder = _reminderBox.get(id);
    if (reminder != null) {
      await _reminderBox.put(
        id,
        reminder.copyWith(isCompleted: true),
      );
    }
  }
}

