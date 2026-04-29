import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../models/reminder.dart';
import '../services/audio_player_service.dart';
import '../services/storage_service.dart';
import '../theme/app_theme.dart';
import '../utils/screen_util.dart';
import 'reminder_dialog.dart';

class ArchiveScreen extends StatefulWidget {
  const ArchiveScreen({super.key});

  @override
  State<ArchiveScreen> createState() => _ArchiveScreenState();
}

class _ArchiveScreenState extends State<ArchiveScreen>
    with SingleTickerProviderStateMixin {
  final StorageService _storageService = StorageService();
  final AudioPlayerService _audioPlayer = AudioPlayerService();
  late final TabController _tabController;

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
    _audioPlayer.onPlayingStateChanged = (isPlaying) {
      if (mounted) setState(() { if (!isPlaying) _currentlyPlayingPath = null; });
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
    await _storageService.markExpiredRemindersAsCompleted();
    setState(() {
      _reminders = _selectedTab == 'active'
          ? _storageService.getActiveReminders()
          : _storageService.getCompletedReminders();
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
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            child: Text('delete'.tr()),
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
    if (_currentlyPlayingPath == audioPath && _audioPlayer.isPlaying) {
      await _audioPlayer.stopAudio();
      setState(() => _currentlyPlayingPath = null);
      return;
    }
    try {
      final success = await _audioPlayer.playAudio(audioPath);
      setState(() {
        _currentlyPlayingPath =
            (success && _audioPlayer.isPlaying) ? audioPath : null;
      });
      if (!success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('audio_playback_failed'.tr())),
        );
      }
    } catch (e) {
      setState(() => _currentlyPlayingPath = null);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('audio_file_playback_failed'
                .tr(namedArgs: {'error': e.toString()})),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final su = ScreenUtil.of(context);
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('archive'.tr()),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Container(
            decoration: const BoxDecoration(
              border:
                  Border(bottom: BorderSide(color: AppColors.border, width: 1)),
            ),
            child: TabBar(
              controller: _tabController,
              tabs: [
                Tab(text: 'active'.tr()),
                Tab(text: 'completed'.tr()),
              ],
            ),
          ),
        ),
      ),
      body: _reminders.isEmpty
          ? _EmptyState(
              message: _selectedTab == 'active'
                  ? 'no_active_reminders'.tr()
                  : 'no_completed_reminders'.tr(),
            )
          : ListView.builder(
              padding: EdgeInsets.symmetric(
                  horizontal: su.w(16), vertical: su.h(12)),
              itemCount: _reminders.length,
              itemBuilder: (context, index) {
                final r = _reminders[index];
                return _ReminderCard(
                  reminder: r,
                  isPlaying: _currentlyPlayingPath == r.audioPath &&
                      _audioPlayer.isPlaying,
                  onTap: () => showDialog(
                    context: context,
                    builder: (_) => ReminderDialog(reminder: r),
                  ),
                  onLongPress: () => _deleteReminder(r),
                  onPlayTap: r.audioPath.isNotEmpty
                      ? () => _playAudio(r.audioPath)
                      : null,
                  su: su,
                );
              },
            ),
    );
  }
}

// ─── Boş Durum ────────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  final String message;
  const _EmptyState({required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: const BoxDecoration(
              color: AppColors.surfaceVariant,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.notifications_none_rounded,
              size: 40,
              color: AppColors.textHint,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            message,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 15,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Hatırlatıcı Kartı ────────────────────────────────────────────────────────

class _ReminderCard extends StatelessWidget {
  final Reminder reminder;
  final bool isPlaying;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final VoidCallback? onPlayTap;
  final ScreenUtil su;

  const _ReminderCard({
    required this.reminder,
    required this.isPlaying,
    required this.onTap,
    required this.onLongPress,
    required this.onPlayTap,
    required this.su,
  });

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('dd MMM, HH:mm', 'tr_TR');
    final hasTranscript = reminder.transcript.isNotEmpty;
    final transcript = hasTranscript
        ? reminder.transcript
        : 'audio_recording_no_transcript'.tr();

    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Container(
        margin: EdgeInsets.only(bottom: su.h(10)),
        decoration: AppDecorations.card(
          borderColor: hasTranscript
              ? AppColors.primary.withValues(alpha: 0.25)
              : AppColors.border,
        ),
        child: Padding(
          padding: EdgeInsets.all(su.r(16)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: EdgeInsets.all(su.r(8)),
                    decoration: BoxDecoration(
                      color: hasTranscript
                          ? AppColors.primarySurface
                          : AppColors.surfaceVariant,
                      borderRadius:
                          BorderRadius.circular(AppRadius.sm),
                    ),
                    child: Icon(
                      hasTranscript
                          ? Icons.notifications_active_rounded
                          : Icons.mic_rounded,
                      size: su.sp(20),
                      color: hasTranscript
                          ? AppColors.primary
                          : AppColors.textSecondary,
                    ),
                  ),
                  SizedBox(width: su.w(12)),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          transcript,
                          style: TextStyle(
                            fontSize: su.sp(15),
                            fontWeight: hasTranscript
                                ? FontWeight.w600
                                : FontWeight.w400,
                            color: hasTranscript
                                ? AppColors.textPrimary
                                : AppColors.textSecondary,
                            height: 1.4,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (reminder.audioPath.isNotEmpty) ...[
                          SizedBox(height: su.h(4)),
                          const Row(
                            children: [
                              Icon(Icons.graphic_eq_rounded,
                                  size: 13, color: AppColors.textHint),
                              SizedBox(width: 4),
                              Text(
                                '● ses kaydı',
                                style: TextStyle(
                                    fontSize: 11, color: AppColors.textHint),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (onPlayTap != null) ...[
                    SizedBox(width: su.w(8)),
                    GestureDetector(
                      onTap: onPlayTap,
                      child: Container(
                        padding: EdgeInsets.all(su.r(8)),
                        decoration: BoxDecoration(
                          color: isPlaying
                              ? AppColors.error.withValues(alpha: 0.1)
                              : AppColors.primarySurface,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          isPlaying
                              ? Icons.stop_rounded
                              : Icons.play_arrow_rounded,
                          size: su.sp(20),
                          color: isPlaying
                              ? AppColors.error
                              : AppColors.primary,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              SizedBox(height: su.h(12)),
              const Divider(height: 1),
              SizedBox(height: su.h(10)),
              Row(
                children: [
                  const Icon(Icons.access_time_rounded,
                      size: 13, color: AppColors.textHint),
                  const SizedBox(width: 4),
                  Text(
                    dateFormat.format(reminder.scheduledTime),
                    style: TextStyle(
                      fontSize: su.sp(12),
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    'long_press_to_delete'.tr(),
                    style: const TextStyle(
                        fontSize: 11, color: AppColors.textHint),
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
