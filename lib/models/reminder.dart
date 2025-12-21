import 'package:hive/hive.dart';

part 'reminder.g.dart';

@HiveType(typeId: 0)
class Reminder extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String transcript;

  @HiveField(2)
  final String audioPath; // Empty string on Android when recording is skipped

  @HiveField(3)
  final DateTime scheduledTime;

  @HiveField(4)
  final DateTime createdAt;

  @HiveField(5)
  final bool isCompleted;

  @HiveField(6)
  final String buttonType; // 'quick_1h', 'quick_30m', 'quick_15m', 'manual'

  Reminder({
    required this.id,
    required this.transcript,
    required this.audioPath,
    required this.scheduledTime,
    required this.createdAt,
    this.isCompleted = false,
    required this.buttonType,
  });

  Reminder copyWith({
    String? id,
    String? transcript,
    String? audioPath,
    DateTime? scheduledTime,
    DateTime? createdAt,
    bool? isCompleted,
    String? buttonType,
  }) {
    return Reminder(
      id: id ?? this.id,
      transcript: transcript ?? this.transcript,
      audioPath: audioPath ?? this.audioPath,
      scheduledTime: scheduledTime ?? this.scheduledTime,
      createdAt: createdAt ?? this.createdAt,
      isCompleted: isCompleted ?? this.isCompleted,
      buttonType: buttonType ?? this.buttonType,
    );
  }
}

