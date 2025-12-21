import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:easy_localization/easy_localization.dart';
import '../models/reminder.dart';
import '../services/storage_service.dart';
import '../services/audio_player_service.dart';
import 'reminder_dialog.dart';

class ArchiveScreen extends StatefulWidget {
  const ArchiveScreen({super.key});

  @override
  State<ArchiveScreen> createState() => _ArchiveScreenState();
}

class _ArchiveScreenState extends State<ArchiveScreen> with SingleTickerProviderStateMixin {
  final StorageService _storageService = StorageService();
  final AudioPlayerService _audioPlayer = AudioPlayerService();
  late TabController _tabController;
  List<Reminder> _reminders = [];
  String _selectedTab = 'active';
  String? _currentlyPlayingPath;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        setState(() {
          _selectedTab = _tabController.index == 0 ? 'active' : 'completed';
        });
        _loadReminders();
      }
    });
    // Listen to audio player state changes
    _audioPlayer.onPlayingStateChanged = (isPlaying) {
      if (mounted) {
        setState(() {
          // If not playing, always clear the currently playing path
          // This ensures the button returns to play icon when audio finishes
          if (!isPlaying) {
            print('🛑 Audio stopped, clearing _currentlyPlayingPath');
            _currentlyPlayingPath = null;
          }
          // Note: We don't set _currentlyPlayingPath here when isPlaying is true
          // because that's handled in _playAudio() method
        });
      }
    };
    _loadReminders();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _loadReminders() async {
    // Mark expired reminders as completed before loading
    await _storageService.markExpiredRemindersAsCompleted();
    
    setState(() {
      if (_selectedTab == 'active') {
        _reminders = _storageService.getActiveReminders();
      } else {
        _reminders = _storageService.getCompletedReminders();
      }
    });
  }

  Future<void> _deleteReminder(Reminder reminder) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Row(
          children: [
            Icon(
              Icons.warning_amber_rounded,
              color: Colors.red[600],
              size: 28,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'delete_reminder_title'.tr(),
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        content: Text(
          'delete_reminder_content'.tr(),
          style: const TextStyle(fontSize: 16),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
            child: Text(
              'cancel'.tr(),
              style: const TextStyle(fontSize: 16),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: Text(
              'delete'.tr(),
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _storageService.deleteReminder(reminder.id);
      _loadReminders();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('reminder_deleted'.tr())),
        );
      }
    }
  }

  Future<void> _playAudio(String audioPath) async {
    print('🎵 Attempting to play audio from: $audioPath');
    
    // If already playing this audio, stop it
    if (_currentlyPlayingPath == audioPath && _audioPlayer.isPlaying) {
      await _audioPlayer.stopAudio();
      setState(() {
        _currentlyPlayingPath = null;
      });
      return;
    }
    
    try {
      final success = await _audioPlayer.playAudio(audioPath);
      
      setState(() {
        if (success && _audioPlayer.isPlaying) {
          _currentlyPlayingPath = audioPath;
        } else {
          _currentlyPlayingPath = null;
        }
      });
      
      if (!success || !_audioPlayer.isPlaying) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('audio_playback_failed'.tr()),
              duration: const Duration(seconds: 3),
            ),
          );
        }
      } else {
        print('✅ Audio is playing successfully');
      }
    } catch (e) {
      print('❌ Error playing audio: $e');
      setState(() {
        _currentlyPlayingPath = null;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('audio_file_playback_failed'.tr(namedArgs: {'error': e.toString()})),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('archive'.tr()),
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(text: 'active'.tr()),
            Tab(text: 'completed'.tr()),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: _reminders.isEmpty
                ? Center(
                    child: Text(
                      _selectedTab == 'active'
                          ? 'no_active_reminders'.tr()
                          : 'no_completed_reminders'.tr(),
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  )
                : ListView.builder(
                    itemCount: _reminders.length,
                    itemBuilder: (context, index) {
                      final reminder = _reminders[index];
                      return _buildReminderCard(reminder);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildReminderCard(Reminder reminder) {
    final dateFormat = DateFormat('dd/MM/yyyy HH:mm', 'tr_TR');
    final transcript = reminder.transcript.isEmpty 
        ? 'audio_recording_no_transcript'.tr() 
        : reminder.transcript;
    final hasTranscript = reminder.transcript.isNotEmpty;
    final isPlaying = _currentlyPlayingPath == reminder.audioPath && _audioPlayer.isPlaying;
    
    return GestureDetector(
      onLongPress: () => _deleteReminder(reminder),
      onTap: () {
        showDialog(
          context: context,
          builder: (context) => ReminderDialog(reminder: reminder),
        );
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
          border: Border.all(
            color: hasTranscript ? const Color(0xFFFF6B35).withOpacity(0.3) : Colors.grey.withOpacity(0.2),
            width: 1,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header row with icon and status
              Row(
                children: [
                  hasTranscript
                      ? Image.asset(
                          'assets/images/logoBell.png',
                          width: 48,
                          height: 48,
                          fit: BoxFit.contain,
                          errorBuilder: (context, error, stackTrace) {
                            return Icon(
                              Icons.text_fields,
                              color: const Color(0xFFFF6B35),
                              size: 24,
                            );
                          },
                        )
                      : Icon(
                          Icons.mic,
                          color: Colors.grey[600],
                          size: 24,
                        ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          transcript,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: hasTranscript ? Colors.black87 : Colors.grey[600],
                            height: 1.3,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (reminder.audioPath.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(
                                Icons.audiotrack,
                                size: 14,
                                color: Colors.grey[600],
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'audio_recording_available'.tr(),
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                  // Play button
                  if (reminder.audioPath.isNotEmpty)
                    Container(
                      decoration: BoxDecoration(
                        color: isPlaying 
                            ? Colors.red.withOpacity(0.1)
                            : const Color(0xFFFF6B35).withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: IconButton(
                        icon: Icon(
                          isPlaying ? Icons.stop : Icons.play_arrow,
                          color: isPlaying ? Colors.red : const Color(0xFFFF6B35),
                        ),
                        onPressed: () => _playAudio(reminder.audioPath),
                        tooltip: isPlaying ? 'stop'.tr() : 'play'.tr(),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              // Divider
              Divider(
                height: 1,
                thickness: 1,
                color: Colors.grey.withOpacity(0.2),
              ),
              const SizedBox(height: 12),
              // Date and time info
              Row(
                children: [
                  Icon(
                    Icons.access_time,
                    size: 16,
                    color: Colors.grey[600],
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'time'.tr(namedArgs: {'time': dateFormat.format(reminder.scheduledTime)}),
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey[700],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Icon(
                    Icons.calendar_today,
                    size: 16,
                    color: Colors.grey[600],
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'created_at'.tr(namedArgs: {'time': dateFormat.format(reminder.createdAt)}),
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey[700],
                      ),
                    ),
                  ),
                ],
              ),
              // Long press hint
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    size: 14,
                    color: Colors.grey[400],
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'long_press_to_delete'.tr(),
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey[400],
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

