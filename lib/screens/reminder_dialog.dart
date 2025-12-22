import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:easy_localization/easy_localization.dart';
import '../models/reminder.dart';
import '../services/audio_player_service.dart';
import '../utils/screen_util.dart';

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
              SnackBar(
                content: Text('audio_playback_failed'.tr()),
                duration: const Duration(seconds: 3),
              ),
            );
          }
        }
      } catch (e) {
        print('❌ Error playing audio: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('audio_file_playback_failed'.tr(namedArgs: {'error': e.toString()})),
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
    final su = ScreenUtil.of(context);
    final dateFormat = DateFormat('dd/MM/yyyy HH:mm', 'tr_TR');
    
    return AlertDialog(
      title: Text(
        'reminder_title'.tr(),
        style: TextStyle(
          fontSize: su.sp(18),
          fontWeight: FontWeight.w700,
        ),
      ),
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
                size: su.sp(20),
                color: widget.reminder.transcript.isEmpty
                    ? Colors.grey
                    : const Color(0xFFFF6B35),
              ),
              SizedBox(width: su.w(8)),
              Text(
                'transcript'.tr(),
                style: TextStyle(
                  fontSize: su.sp(14),
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
          SizedBox(height: su.h(8)),
          // Transkript içeriği
          Container(
            width: double.infinity,
            padding: EdgeInsets.all(su.r(12)),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: BorderRadius.circular(su.r(8)),
              border: Border.all(
                color: Colors.grey[300]!,
                width: su.w(1),
              ),
            ),
            child: Text(
              widget.reminder.transcript.isEmpty
                  ? 'audio_recording_no_transcript'.tr()
                  : widget.reminder.transcript,
              style: TextStyle(
                fontSize: su.sp(16),
                fontWeight: FontWeight.w500,
                color: widget.reminder.transcript.isEmpty
                    ? Colors.grey[600]
                    : Colors.black87,
              ),
            ),
          ),
          SizedBox(height: su.h(16)),
          Text(
            'time'.tr(
              namedArgs: {'time': dateFormat.format(widget.reminder.scheduledTime)},
            ),
            style: TextStyle(fontSize: su.sp(14)),
          ),
          SizedBox(height: su.h(8)),
          Text(
            'created_at'.tr(
              namedArgs: {'time': dateFormat.format(widget.reminder.createdAt)},
            ),
            style: TextStyle(fontSize: su.sp(14)),
          ),
          SizedBox(height: su.h(16)),
          if (!Platform.isAndroid) ...[
            ElevatedButton.icon(
              onPressed: _togglePlayback,
              icon: Icon(
                _isPlaying ? Icons.stop : Icons.play_arrow,
                size: su.sp(20),
              ),
              label: Text(
                _isPlaying ? 'stop'.tr() : 'play'.tr(),
                style: TextStyle(fontSize: su.sp(15)),
              ),
              style: ElevatedButton.styleFrom(
                minimumSize: Size(double.infinity, su.h(48)),
                backgroundColor: _isPlaying ? Colors.red : Colors.blue,
                foregroundColor: Colors.white,
              ),
            ),
            if (_isPlaying) ...[
              SizedBox(height: su.h(8)),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.volume_up, size: su.sp(16), color: Colors.green[700]),
                  SizedBox(width: su.w(4)),
                  Text(
                    'audio_playing'.tr(),
                    style: TextStyle(
                      fontSize: su.sp(12),
                      color: Colors.green[700],
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(
            'close'.tr(),
            style: TextStyle(fontSize: su.sp(14)),
          ),
        ),
      ],
    );
  }
}

