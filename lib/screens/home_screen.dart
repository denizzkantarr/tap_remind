import 'dart:io';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:timezone/timezone.dart' as tz;

import '../models/reminder.dart';
import '../services/audio_service.dart';
import '../services/notification_service.dart';
import '../services/speech_service.dart';
import '../services/storage_service.dart';
import '../theme/app_theme.dart';
import '../utils/screen_util.dart';
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
  bool _waitingForFinalResult = false;
  double _soundLevel = 0.0;
  bool _isSpeechListening = false;

  @override
  void initState() {
    super.initState();
    _checkAndRequestPermissions();
    _checkOverdueReminders();
  }

  Future<void> _checkAndRequestPermissions() async {
    if (Platform.isAndroid) {
      final micStatus = await Permission.microphone.status;
      if (!micStatus.isGranted) await Permission.microphone.request();
      final notifStatus = await Permission.notification.status;
      if (!notifStatus.isGranted) await Permission.notification.request();
    }
    _speechService.initialize();
  }

  Future<void> _checkOverdueReminders() async {
    final location = tz.getLocation('Europe/Istanbul');
    final now = tz.TZDateTime.now(location);
    for (var reminder in _storageService.getActiveReminders()) {
      final scheduled = tz.TZDateTime.from(reminder.scheduledTime, location);
      if (scheduled.isBefore(now) && !reminder.isCompleted) {
        await _notificationService.showOverdueNotification(reminder);
      }
    }
  }

  @override
  void dispose() {
    _audioService.dispose();
    super.dispose();
  }

  // ─── Kayıt Başlat ──────────────────────────────────────────────────────────

  Future<void> _startRecording(String buttonType) async {
    setState(() {
      _isRecording = true;
      _currentButtonType = buttonType;
      _transcript = '';
    });

    bool recordingStarted = true;
    if (!Platform.isAndroid) {
      recordingStarted = await _audioService.startRecording();
    }

    if (!recordingStarted) {
      final micPermission = await Permission.microphone.status;
      if (micPermission.isPermanentlyDenied) {
        final shouldOpen = await _showPermissionDialog(
          'microphone_permission_required_title'.tr(),
          'microphone_permission_required_message'.tr(),
        );
        if (shouldOpen) await openAppSettings();
      } else if (!micPermission.isGranted) {
        _showError('microphone_permission_required'.tr());
      } else {
        _showError('audio_recording_failed'.tr());
      }
      setState(() => _isRecording = false);
      return;
    }

    final speechInitialized = await _speechService.initialize();

    if (speechInitialized) {
      final isAvailable = _speechService.speech.isAvailable;

      if (!isAvailable) {
        _showError('speech_recognition_not_available'.tr());
        setState(() => _isRecording = false);
        await _audioService.stopRecording();
        return;
      }

      final locales = await _speechService.speech.locales();
      String localeId = 'en_US';
      if (locales.isNotEmpty) {
        try {
          localeId = locales
              .firstWhere((l) => l.localeId.startsWith('tr'))
              .localeId;
        } catch (_) {
          localeId = locales.first.localeId;
        }
      }

      try {
        _speechService.speech.listen(
          onResult: (result) {
            setState(() {
              if (result.recognizedWords.isNotEmpty) {
                _transcript = result.recognizedWords;
              }
              if (result.finalResult) _waitingForFinalResult = false;
            });
          },
          listenFor: const Duration(seconds: 120),
          pauseFor: const Duration(seconds: 5),
          localeId: localeId,
          onSoundLevelChange: (level) {
            if (mounted) setState(() => _soundLevel = level);
          },
          listenOptions: stt.SpeechListenOptions(
            partialResults: true,
            listenMode: stt.ListenMode.dictation,
            cancelOnError: false,
          ),
        );

        Future.delayed(const Duration(milliseconds: 500), () async {
          final listening = _speechService.speech.isListening;
          if (mounted) setState(() => _isSpeechListening = listening);
          if (!listening) {
            final perm = await Permission.speech.status;
            if (perm.isPermanentlyDenied) {
              if (mounted) {
                final ok = await _showPermissionDialog(
                  'speech_recognition_permission_required_title'.tr(),
                  'speech_recognition_permission_required_message'.tr(),
                );
                if (ok) await openAppSettings();
              }
            } else if (!perm.isGranted) {
              if (mounted) _showError('speech_recognition_permission_required'.tr());
            } else {
              if (mounted) _showError('speech_recognition_failed_to_start'.tr());
            }
          }
        });

        Future.delayed(const Duration(seconds: 2), () {
          if (!_speechService.speech.isListening && mounted && _isRecording) {
            _showError('speech_recognition_stopped'.tr());
          }
        });
      } catch (e) {
        _showError('speech_recognition_failed'.tr(namedArgs: {'error': e.toString()}));
      }
    }
  }

  // ─── Kayıt Durdur ──────────────────────────────────────────────────────────

  Future<void> _stopRecording() async {
    if (!_isRecording) return;

    setState(() => _waitingForFinalResult = true);
    _speechService.stopListening();

    int waitCount = 0;
    while (_waitingForFinalResult && waitCount < 30 && _speechService.isListening) {
      await Future.delayed(const Duration(milliseconds: 100));
      waitCount++;
    }
    await Future.delayed(const Duration(milliseconds: 800));

    if (_waitingForFinalResult) setState(() => _waitingForFinalResult = false);

    String finalTranscript = _transcript.trim();
    if (finalTranscript.isEmpty) finalTranscript = 'no_speech_detected'.tr();

    String? audioPath;
    if (!Platform.isAndroid) {
      audioPath = await _audioService.stopRecording();
    }

    setState(() {
      _isRecording = false;
      _transcript = finalTranscript;
      _waitingForFinalResult = false;
    });

    if (audioPath == null) {
      if (!Platform.isAndroid) {
        _showError('recording_error'.tr());
        return;
      }
      audioPath = '';
    } else {
      final file = File(audioPath);
      if (!await file.exists()) {
        _showError('audio_file_save_failed'.tr());
        return;
      }
    }

    final location = tz.getLocation('Europe/Istanbul');
    final now = tz.TZDateTime.now(location);
    DateTime? scheduledTime;

    if (_currentButtonType == 'quick_1h') {
      scheduledTime = now.add(const Duration(hours: 1));
    } else if (_currentButtonType == 'quick_10h') {
      scheduledTime = now.add(const Duration(hours: 10));
    } else if (_currentButtonType == 'tomorrow_9am') {
      scheduledTime = tz.TZDateTime(location, now.year, now.month, now.day + 1, 9);
    } else if (_currentButtonType == 'random') {
      scheduledTime = await _showDateTimePicker();
      if (scheduledTime == null) return;
    }

    if (scheduledTime != null) await _createReminder(audioPath, scheduledTime);
  }

  // ─── Tarih / Saat Seçici ───────────────────────────────────────────────────

  Future<DateTime?> _showDateTimePicker() async {
    final location = tz.getLocation('Europe/Istanbul');
    final now = tz.TZDateTime.now(location);
    final localNow = DateTime(now.year, now.month, now.day, now.hour, now.minute);

    final pickedDate = await showDatePicker(
      context: context,
      initialDate: localNow,
      firstDate: localNow,
      lastDate: localNow.add(const Duration(days: 365)),
    );
    if (pickedDate == null) return null;
    if (!mounted) return null;

    final pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(localNow),
    );
    if (pickedTime == null) return null;

    return tz.TZDateTime(
      location,
      pickedDate.year,
      pickedDate.month,
      pickedDate.day,
      pickedTime.hour,
      pickedTime.minute,
    );
  }

  // ─── Hatırlatıcı Oluştur ───────────────────────────────────────────────────

  Future<void> _createReminder(String audioPath, DateTime scheduledTime) async {
    final location = tz.getLocation('Europe/Istanbul');
    final tzScheduled = scheduledTime is tz.TZDateTime
        ? scheduledTime
        : tz.TZDateTime.from(scheduledTime, location);

    final finalTranscript =
        _transcript.isEmpty ? 'audio_recording_received'.tr() : _transcript;

    final reminder = Reminder(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      transcript: finalTranscript,
      audioPath: audioPath,
      scheduledTime: tzScheduled,
      createdAt: DateTime.now(),
      buttonType: _currentButtonType ?? 'manual',
    );

    await _storageService.saveReminder(reminder);
    await _notificationService.scheduleReminder(reminder);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'reminder_created'.tr(
                    namedArgs: {
                      'time': DateFormat('dd/MM/yyyy HH:mm', 'tr_TR')
                          .format(scheduledTime),
                    },
                  ),
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          duration: const Duration(seconds: 4),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
        ),
      );
    }
  }

  // ─── Yardımcılar ───────────────────────────────────────────────────────────

  void _showError(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
        ),
      );
    }
  }

  Future<bool> _showPermissionDialog(String title, String message) async {
    if (!mounted) return false;
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text('cancel'.tr()),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text('go_to_settings'.tr()),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  // ─── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final su = ScreenUtil.of(context);
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: TapRemindLogo(size: su.w(160), showText: false),
        actions: [
          _AppBarIconButton(
            icon: Icons.format_list_bulleted_rounded,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ArchiveScreen()),
            ),
          ),
          _AppBarIconButton(
            icon: Icons.settings_outlined,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SettingsScreen()),
            ),
          ),
          SizedBox(width: su.w(4)),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            SizedBox(height: su.h(32)),

            // ── Durum alanı ─────────────────────────────────────────────────
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              switchInCurve: Curves.easeOut,
              switchOutCurve: Curves.easeIn,
              child: _isRecording
                  ? _RecordingPanel(
                      key: const ValueKey('recording'),
                      transcript: _transcript,
                      isSpeechListening: _isSpeechListening,
                      soundLevel: _soundLevel,
                      su: su,
                    )
                  : Padding(
                      key: const ValueKey('idle'),
                      padding: EdgeInsets.symmetric(horizontal: su.w(32)),
                      child: Text(
                        'press_hold_to_create_reminder'.tr(),
                        style: TextStyle(
                          fontSize: su.sp(15),
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w500,
                          height: 1.5,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
            ),

            SizedBox(height: su.h(24)),

            // ── Butonlar ────────────────────────────────────────────────────
            Expanded(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: su.w(20)),
                child: GridView.count(
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisCount: 2,
                  crossAxisSpacing: su.w(14),
                  mainAxisSpacing: su.h(14),
                  childAspectRatio: su.isTablet ? 1.2 : 1.0,
                  children: [
                    _PushToTalkButton(
                      label: 'quick_1h'.tr(),
                      icon: Icons.bolt_rounded,
                      buttonType: 'quick_1h',
                      isActive: _isRecording && _currentButtonType == 'quick_1h',
                      onTapDown: () => _startRecording('quick_1h'),
                      onTapEnd: _stopRecording,
                      su: su,
                    ),
                    _PushToTalkButton(
                      label: 'quick_10h'.tr(),
                      icon: Icons.nightlight_round,
                      buttonType: 'quick_10h',
                      isActive: _isRecording && _currentButtonType == 'quick_10h',
                      onTapDown: () => _startRecording('quick_10h'),
                      onTapEnd: _stopRecording,
                      su: su,
                    ),
                    _PushToTalkButton(
                      label: 'tomorrow_9am'.tr(),
                      icon: Icons.wb_sunny_rounded,
                      buttonType: 'tomorrow_9am',
                      isActive: _isRecording && _currentButtonType == 'tomorrow_9am',
                      onTapDown: () => _startRecording('tomorrow_9am'),
                      onTapEnd: _stopRecording,
                      su: su,
                    ),
                    _PushToTalkButton(
                      label: 'random'.tr(),
                      icon: Icons.tune_rounded,
                      buttonType: 'random',
                      isActive: _isRecording && _currentButtonType == 'random',
                      onTapDown: () => _startRecording('random'),
                      onTapEnd: _stopRecording,
                      su: su,
                    ),
                  ],
                ),
              ),
            ),

            // ── Alt bilgi ───────────────────────────────────────────────────
            Padding(
              padding: EdgeInsets.fromLTRB(su.w(24), su.h(12), su.w(24), su.h(32)),
              child: Text(
                'presets_info'.tr(),
                style: TextStyle(
                  fontSize: su.sp(12),
                  color: AppColors.textHint,
                  height: 1.4,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── AppBar İkon Butonu ───────────────────────────────────────────────────────

class _AppBarIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _AppBarIconButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: AppColors.surfaceVariant,
          borderRadius: BorderRadius.circular(AppRadius.sm),
        ),
        child: Icon(icon, size: 20, color: AppColors.textPrimary),
      ),
    );
  }
}

// ─── Push-to-Talk Butonu ──────────────────────────────────────────────────────

class _PushToTalkButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final String buttonType;
  final bool isActive;
  final VoidCallback onTapDown;
  final VoidCallback onTapEnd;
  final ScreenUtil su;

  const _PushToTalkButton({
    required this.label,
    required this.icon,
    required this.buttonType,
    required this.isActive,
    required this.onTapDown,
    required this.onTapEnd,
    required this.su,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => onTapDown(),
      onTapUp: (_) => onTapEnd(),
      onTapCancel: onTapEnd,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        decoration: AppDecorations.pushButton(isActive: isActive),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: EdgeInsets.all(su.r(12)),
              decoration: BoxDecoration(
                color: isActive
                    ? AppColors.primary
                    : AppColors.primarySurface,
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: su.sp(26),
                color: isActive ? AppColors.onPrimary : AppColors.primary,
              ),
            ),
            SizedBox(height: su.h(10)),
            Text(
              label,
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: su.sp(14),
                fontWeight: FontWeight.w600,
                letterSpacing: -0.1,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: su.h(4)),
            Text(
              isActive ? '●  ●  ●' : 'mic'.tr(),
              style: TextStyle(
                fontSize: su.sp(11),
                color: isActive ? AppColors.primary : AppColors.textHint,
                fontWeight: isActive ? FontWeight.w700 : FontWeight.w400,
                letterSpacing: isActive ? 2 : 0,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Kayıt Paneli ─────────────────────────────────────────────────────────────

class _RecordingPanel extends StatelessWidget {
  final String transcript;
  final bool isSpeechListening;
  final double soundLevel;
  final ScreenUtil su;

  const _RecordingPanel({
    super.key,
    required this.transcript,
    required this.isSpeechListening,
    required this.soundLevel,
    required this.su,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: su.w(20)),
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.all(su.r(18)),
        decoration: AppDecorations.transcriptBox(hasContent: transcript.isNotEmpty),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Durum başlığı
            Row(
              children: [
                _PulsingDot(isActive: isSpeechListening),
                SizedBox(width: su.w(8)),
                Text(
                  isSpeechListening
                      ? 'speech_recognition_active'.tr()
                      : 'speech_recognition_waiting'.tr(),
                  style: TextStyle(
                    fontSize: su.sp(12),
                    fontWeight: FontWeight.w600,
                    color: isSpeechListening
                        ? AppColors.success
                        : AppColors.warning,
                  ),
                ),
                if (soundLevel > 0.01) ...[
                  const Spacer(),
                  _SoundBar(level: soundLevel),
                ],
              ],
            ),
            SizedBox(height: su.h(12)),

            // Transkript içeriği
            Text(
              transcript.isEmpty ? 'speak_now'.tr() : transcript,
              style: TextStyle(
                fontSize: su.sp(17),
                color: transcript.isEmpty
                    ? AppColors.textHint
                    : AppColors.textPrimary,
                fontWeight: transcript.isEmpty
                    ? FontWeight.w400
                    : FontWeight.w600,
                height: 1.5,
                letterSpacing: transcript.isEmpty ? 0 : -0.2,
              ),
            ),

            if (transcript.isNotEmpty) ...[
              SizedBox(height: su.h(8)),
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: su.w(8),
                  vertical: su.h(3),
                ),
                decoration: BoxDecoration(
                  color: AppColors.successSurface,
                  borderRadius: BorderRadius.circular(AppRadius.xs),
                ),
                child: Text(
                  'characters'
                      .tr(namedArgs: {'count': transcript.length.toString()}),
                  style: TextStyle(
                    fontSize: su.sp(11),
                    color: AppColors.successText,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ─── Küçük Bileşenler ─────────────────────────────────────────────────────────

class _PulsingDot extends StatefulWidget {
  final bool isActive;
  const _PulsingDot({required this.isActive});

  @override
  State<_PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<_PulsingDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _anim = Tween<double>(begin: 0.4, end: 1.0).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.isActive ? AppColors.success : AppColors.warning;
    return FadeTransition(
      opacity: _anim,
      child: Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
    );
  }
}

class _SoundBar extends StatelessWidget {
  final double level;
  const _SoundBar({required this.level});

  @override
  Widget build(BuildContext context) {
    final bars = 4;
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: List.generate(bars, (i) {
        final height = 4.0 + (i + 1) * 3.0 * (level.clamp(0.0, 1.0));
        return Container(
          width: 3,
          height: height.clamp(4.0, 16.0),
          margin: const EdgeInsets.only(left: 2),
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.5 + i * 0.15),
            borderRadius: BorderRadius.circular(2),
          ),
        );
      }),
    );
  }
}
