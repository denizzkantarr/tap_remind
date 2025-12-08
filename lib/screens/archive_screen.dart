import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
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
        title: const Text('Hatırlatıcıyı Sil'),
        content: const Text('Bu hatırlatıcıyı silmek istediğinize emin misiniz?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('İptal'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Sil', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _storageService.deleteReminder(reminder.id);
      _loadReminders();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Hatırlatıcı silindi')),
        );
      }
    }
  }

  Future<void> _playAudio(String audioPath) async {
    print('🎵 Attempting to play audio from: $audioPath');
    try {
      final success = await _audioPlayer.playAudio(audioPath);
      
      if (!success || !_audioPlayer.isPlaying) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Ses çalınamadı. Dosya yolu veya ses seviyesini kontrol edin.'),
              duration: Duration(seconds: 3),
            ),
          );
        }
      } else {
        print('✅ Audio is playing successfully');
      }
    } catch (e) {
      print('❌ Error playing audio: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ses dosyası oynatılamadı: $e'),
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
        title: const Text('Arşiv / Geçmiş'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Aktif'),
            Tab(text: 'Tamamlanan'),
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
                          ? 'Aktif hatırlatıcı yok'
                          : 'Tamamlanan hatırlatıcı yok',
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
        ? 'Ses kaydı (transkript yok)' 
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
            Text('Zaman: ${dateFormat.format(reminder.scheduledTime)}'),
            Text('Oluşturulma: ${dateFormat.format(reminder.createdAt)}'),
            if (reminder.audioPath.isNotEmpty)
              const SizedBox(height: 4),
            if (reminder.audioPath.isNotEmpty)
              const Text('🎵 Ses kaydı mevcut', style: TextStyle(fontSize: 12, color: Colors.grey)),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.play_arrow),
              onPressed: () => _playAudio(reminder.audioPath),
              tooltip: 'Oynat',
            ),
            IconButton(
              icon: const Icon(Icons.delete),
              onPressed: () => _deleteReminder(reminder),
              tooltip: 'Sil',
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

