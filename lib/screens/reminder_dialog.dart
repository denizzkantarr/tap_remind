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
  void initState() {
    super.initState();
    // Listen to audio player state changes
    _audioPlayer.onPlayingStateChanged = (isPlaying) {
      if (mounted) {
        setState(() {
          _isPlaying = isPlaying;
        });
      }
    };
  }

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
      print('🎵 Attempting to play audio from: ${widget.reminder.audioPath}');
      try {
        final success = await _audioPlayer.playAudio(widget.reminder.audioPath);
        
        // Update state immediately
        setState(() {
          _isPlaying = _audioPlayer.isPlaying;
        });
        
        if (!success || !_isPlaying) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Ses çalınamadı. Dosya yolu veya ses seviyesini kontrol edin.'),
                duration: Duration(seconds: 3),
              ),
            );
          }
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
        setState(() {
          _isPlaying = false;
        });
      }
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
          // Transkript başlığı
          Row(
            children: [
              Icon(
                widget.reminder.transcript.isEmpty
                    ? Icons.mic
                    : Icons.text_fields,
                size: 20,
                color: widget.reminder.transcript.isEmpty
                    ? Colors.grey
                    : const Color(0xFFFF6B35),
              ),
              const SizedBox(width: 8),
              Text(
                'Transkript:',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Transkript içeriği
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: Colors.grey[300]!,
                width: 1,
              ),
            ),
            child: Text(
              widget.reminder.transcript.isEmpty
                  ? 'Ses kaydı (transkript yok)'
                  : widget.reminder.transcript,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: widget.reminder.transcript.isEmpty
                    ? Colors.grey[600]
                    : Colors.black87,
              ),
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
              backgroundColor: _isPlaying ? Colors.red : Colors.blue,
              foregroundColor: Colors.white,
            ),
          ),
          if (_isPlaying) ...[
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.volume_up, size: 16, color: Colors.green[700]),
                const SizedBox(width: 4),
                Text(
                  'Ses çalınıyor...',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.green[700],
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
          ],
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

