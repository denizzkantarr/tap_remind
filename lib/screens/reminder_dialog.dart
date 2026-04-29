import 'dart:io';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../models/reminder.dart';
import '../services/audio_player_service.dart';
import '../theme/app_theme.dart';
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
    _audioPlayer.onPlayingStateChanged = (isPlaying) {
      if (mounted) setState(() => _isPlaying = isPlaying);
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
      setState(() => _isPlaying = false);
      return;
    }
    try {
      final success = await _audioPlayer.playAudio(widget.reminder.audioPath);
      setState(() => _isPlaying = _audioPlayer.isPlaying);
      if (!success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('audio_playback_failed'.tr())),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('audio_file_playback_failed'
                .tr(namedArgs: {'error': e.toString()})),
          ),
        );
      }
      setState(() => _isPlaying = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final su = ScreenUtil.of(context);
    final dateFormat = DateFormat('dd MMM yyyy, HH:mm', 'tr_TR');
    final hasTranscript = widget.reminder.transcript.isNotEmpty;

    return Dialog(
      child: Padding(
        padding: EdgeInsets.all(su.r(24)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: EdgeInsets.all(su.r(8)),
                  decoration: BoxDecoration(
                    color: AppColors.primarySurface,
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                  ),
                  child: Icon(Icons.notifications_active_rounded,
                      size: su.sp(20), color: AppColors.primary),
                ),
                SizedBox(width: su.w(12)),
                Text(
                  'reminder_title'.tr(),
                  style: TextStyle(
                    fontSize: su.sp(17),
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                    letterSpacing: -0.3,
                  ),
                ),
              ],
            ),
            SizedBox(height: su.h(20)),
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(su.r(14)),
              decoration: AppDecorations.bordered(
                bg: AppColors.surfaceVariant,
                borderColor: AppColors.border,
                radius: AppRadius.md,
              ),
              child: Text(
                hasTranscript
                    ? widget.reminder.transcript
                    : 'audio_recording_no_transcript'.tr(),
                style: TextStyle(
                  fontSize: su.sp(15),
                  fontWeight: hasTranscript ? FontWeight.w600 : FontWeight.w400,
                  color: hasTranscript
                      ? AppColors.textPrimary
                      : AppColors.textSecondary,
                  height: 1.5,
                ),
              ),
            ),
            SizedBox(height: su.h(16)),
            _InfoRow(
              icon: Icons.access_time_rounded,
              text: 'time'.tr(namedArgs: {
                'time': dateFormat.format(widget.reminder.scheduledTime),
              }),
              su: su,
            ),
            SizedBox(height: su.h(8)),
            _InfoRow(
              icon: Icons.calendar_today_rounded,
              text: 'created_at'.tr(namedArgs: {
                'time': dateFormat.format(widget.reminder.createdAt),
              }),
              su: su,
            ),
            if (!Platform.isAndroid && widget.reminder.audioPath.isNotEmpty) ...[
              SizedBox(height: su.h(20)),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _togglePlayback,
                  icon: Icon(
                    _isPlaying ? Icons.stop_rounded : Icons.play_arrow_rounded,
                    size: su.sp(20),
                  ),
                  label: Text(
                    _isPlaying ? 'stop'.tr() : 'play'.tr(),
                    style: TextStyle(fontSize: su.sp(15), fontWeight: FontWeight.w600),
                  ),
                  style: FilledButton.styleFrom(
                    backgroundColor: _isPlaying ? AppColors.error : AppColors.primary,
                    padding: EdgeInsets.symmetric(vertical: su.h(14)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.md),
                    ),
                  ),
                ),
              ),
            ],
            SizedBox(height: su.h(16)),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text('close'.tr()),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String text;
  final ScreenUtil su;
  const _InfoRow({required this.icon, required this.text, required this.su});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: su.sp(14), color: AppColors.textHint),
        SizedBox(width: su.w(6)),
        Expanded(
          child: Text(
            text,
            style: TextStyle(fontSize: su.sp(13), color: AppColors.textSecondary),
          ),
        ),
      ],
    );
  }
}
