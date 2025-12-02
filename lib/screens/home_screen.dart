import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/reminder.dart';
import '../services/audio_service.dart';
import '../services/speech_service.dart';
import '../services/storage_service.dart';
import '../services/notification_service.dart';
import '../widgets/tap_remind_logo.dart';
import 'archive_screen.dart';
import 'settings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final AudioService _audioService = AudioService();
  final SpeechService _speechService = SpeechService();
  final StorageService _storageService = StorageService();
  final NotificationService _notificationService = NotificationService();

  bool _isRecording = false;
  String? _currentButtonType;
  String _transcript = '';

  @override
  void initState() {
    super.initState();
    _speechService.initialize();
  }

  @override
  void dispose() {
    _audioService.dispose();
    super.dispose();
  }

  Future<void> _startRecording(String buttonType) async {
    setState(() {
      _isRecording = true;
      _currentButtonType = buttonType;
      _transcript = '';
    });

    await _audioService.startRecording();
    // Note: For real-time transcription, you would use _speechService.listenAndTranscribe()
    // For now, we'll transcribe after recording stops
  }

  Future<void> _stopRecording() async {
    if (!_isRecording) return;

    final audioPath = await _audioService.stopRecording();
    
    setState(() {
      _isRecording = false;
    });

    if (audioPath == null) {
      _showError('Kayıt sırasında bir hata oluştu');
      return;
    }

    // Simulate transcription (in production, use actual STT service)
    _transcript = 'Ses kaydı alındı'; // Placeholder - replace with actual transcription

    // Determine scheduled time based on button type
    DateTime? scheduledTime;
    
    if (_currentButtonType == 'quick_1h') {
      scheduledTime = DateTime.now().add(const Duration(hours: 1));
    } else if (_currentButtonType == 'quick_10h') {
      scheduledTime = DateTime.now().add(const Duration(hours: 10));
    } else if (_currentButtonType == 'tomorrow_9am') {
      final now = DateTime.now();
      final tomorrow = DateTime(now.year, now.month, now.day + 1, 9, 0);
      scheduledTime = tomorrow;
    } else if (_currentButtonType == 'random') {
      // Show date/time picker
      scheduledTime = await _showDateTimePicker();
      if (scheduledTime == null) {
        return; // User cancelled
      }
    }

    if (scheduledTime != null) {
      await _createReminder(audioPath, scheduledTime);
    }
  }

  Future<DateTime?> _showDateTimePicker() async {
    final now = DateTime.now();
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
    );

    if (pickedDate == null) return null;

    final pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(now),
    );

    if (pickedTime == null) return null;

    return DateTime(
      pickedDate.year,
      pickedDate.month,
      pickedDate.day,
      pickedTime.hour,
      pickedTime.minute,
    );
  }

  Future<void> _createReminder(String audioPath, DateTime scheduledTime) async {
    final reminder = Reminder(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      transcript: _transcript,
      audioPath: audioPath,
      scheduledTime: scheduledTime,
      createdAt: DateTime.now(),
      buttonType: _currentButtonType ?? 'manual',
    );

    await _storageService.saveReminder(reminder);
    await _notificationService.scheduleReminder(reminder);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Hatırlatıcı oluşturuldu: ${DateFormat('dd/MM/yyyy HH:mm', 'tr_TR').format(scheduledTime)}',
          ),
        ),
      );
    }
  }

  void _showError(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const TapRemindLogo(size: 160, showText: false),
        actions: [
          IconButton(
            icon: const Icon(Icons.list, color: Colors.black87),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const ArchiveScreen()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.settings, color: Colors.black87),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const SettingsScreen()),
              );
            },
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 40),
            // Main instruction text
            if (!_isRecording)
              const Text(
                'Press & Hold to Create Reminder',
                style: TextStyle(
                  fontSize: 18,
                  color: Colors.grey,
                  fontWeight: FontWeight.w400,
                ),
              )
            else
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    const CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFFF6B35)),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Recording...',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            color: Colors.grey[700],
                          ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 60),
            // 4 main buttons in a grid
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: GridView.count(
                  shrinkWrap: true,
                  crossAxisCount: 2,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  childAspectRatio: 1.1,
                  children: [
                    _buildPushToTalkButton(
                      '+1 Hour',
                      Icons.mic,
                      'quick_1h',
                    ),
                    _buildPushToTalkButton(
                      '+10 Hours',
                      Icons.mic,
                      'quick_10h',
                    ),
                    _buildPushToTalkButton(
                      'Tomorrow 9AM',
                      Icons.mic,
                      'tomorrow_9am',
                    ),
                    _buildPushToTalkButton(
                      'Random',
                      Icons.shuffle,
                      'random',
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            // Footer text
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 24.0),
              child: Text(
                'Presets save instantly. Random lets you pick time',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildPushToTalkButton(
    String label,
    IconData icon,
    String buttonType,
  ) {
    const orangeColor = Color(0xFFFF6B35);
    final isActive = _isRecording && _currentButtonType == buttonType;

    return GestureDetector(
      onTapDown: (_) => _startRecording(buttonType),
      onTapUp: (_) => _stopRecording(),
      onTapCancel: () => _stopRecording(),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.grey[200],
          borderRadius: BorderRadius.circular(20),
          border: isActive
              ? Border.all(color: orangeColor, width: 3)
              : Border.all(color: Colors.grey[300]!, width: 1),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 32,
              color: orangeColor,
            ),
            const SizedBox(height: 12),
            Text(
              label,
              style: TextStyle(
                color: Colors.black87,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

