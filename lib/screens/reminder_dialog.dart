import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/reminder.dart';
import '../services/audio_player_service.dart';

class ReminderDialog extends StatefulWidget {
  final Reminder reminder;

  const ReminderDialog({super.key, required this.reminder});

  @override
  State<ReminderDialog> createState() => _ReminderDialogState();
}

class _ReminderDialogState extends State<ReminderDialog> {
  final AudioPlayerService _audioPlayer = AudioPlayerService();
  bool _isPlaying = false;

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _togglePlayback() async {
    if (_isPlaying) {
      await _audioPlayer.stopAudio();
      setState(() {
        _isPlaying = false;
      });
    } else {
      await _audioPlayer.playAudio(widget.reminder.audioPath);
      setState(() {
        _isPlaying = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('dd/MM/yyyy HH:mm', 'tr_TR');
    
    return AlertDialog(
      title: const Text('Hatırlatıcı'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.reminder.transcript,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          Text('Zaman: ${dateFormat.format(widget.reminder.scheduledTime)}'),
          const SizedBox(height: 8),
          Text('Oluşturulma: ${dateFormat.format(widget.reminder.createdAt)}'),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: _togglePlayback,
            icon: Icon(_isPlaying ? Icons.stop : Icons.play_arrow),
            label: Text(_isPlaying ? 'Durdur' : 'Oynat'),
            style: ElevatedButton.styleFrom(
              minimumSize: const Size(double.infinity, 48),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Kapat'),
        ),
      ],
    );
  }
}

