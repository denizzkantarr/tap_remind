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
        title: Text('delete_reminder_title'.tr()),
        content: Text('delete_reminder_content'.tr()),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('cancel'.tr()),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('delete'.tr(), style: const TextStyle(color: Colors.red)),
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
    
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: ListTile(
        leading: hasTranscript
            ? const Icon(Icons.text_fields, color: Color(0xFFFF6B35))
            : const Icon(Icons.mic, color: Colors.grey),
        title: Text(
          transcript,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
            color: hasTranscript ? Colors.black87 : Colors.grey[600],
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text('time'.tr(namedArgs: {'time': dateFormat.format(reminder.scheduledTime)})),
            Text('created_at'.tr(namedArgs: {'time': dateFormat.format(reminder.createdAt)})),
            if (reminder.audioPath.isNotEmpty)
              const SizedBox(height: 4),
            if (reminder.audioPath.isNotEmpty)
              Text('audio_recording_available'.tr(), style: const TextStyle(fontSize: 12, color: Colors.grey)),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (reminder.audioPath.isNotEmpty)
              IconButton(
                icon: Icon(
                  _currentlyPlayingPath == reminder.audioPath
                      ? Icons.stop
                      : Icons.play_arrow,
                ),
                onPressed: () => _playAudio(reminder.audioPath),
                tooltip: _currentlyPlayingPath == reminder.audioPath
                    ? 'stop'.tr()
                    : 'play'.tr(),
                color: _currentlyPlayingPath == reminder.audioPath
                    ? Colors.red
                    : null,
              ),
            IconButton(
              icon: const Icon(Icons.delete),
              onPressed: () => _deleteReminder(reminder),
              tooltip: 'delete'.tr(),
              color: Colors.red,
            ),
          ],
        ),
        onTap: () {
          showDialog(
            context: context,
            builder: (context) => ReminderDialog(reminder: reminder),
          );
        },
      ),
    );
  }
}

