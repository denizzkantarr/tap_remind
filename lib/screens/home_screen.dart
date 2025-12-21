import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:permission_handler/permission_handler.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:easy_localization/easy_localization.dart';
import '../models/reminder.dart';
import '../services/audio_service.dart';
import '../services/speech_service.dart';
import '../services/storage_service.dart';
import '../services/notification_service.dart';
import '../widgets/tap_remind_logo.dart';
import 'archive_screen.dart';
import 'settings_screen.dart';
import '../utils/screen_util.dart';

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
    // iOS'ta mikrofon izni dialog'u genellikle gerçekten mikrofon kullanılmaya çalışıldığında çıkar
    // Bu yüzden sadece durumu kontrol ediyoruz, izin istemiyoruz
    // İzin, kullanıcı butona bastığında istenecek

    // Mikrofon izni durumu
    final micStatus = await Permission.microphone.status;
    print('📱 Initial microphone permission status: $micStatus');

    // Speech recognition izni durumu
    final speechStatus = await Permission.speech.status;
    print('📱 Initial speech permission status: $speechStatus');

    // Android'de mikrofon ve bildirim izinlerini erken iste
    if (Platform.isAndroid) {
      if (!micStatus.isGranted) {
        final micResult = await Permission.microphone.request();
        print('🎤 Microphone permission request result: $micResult');
      }

      final notifStatus = await Permission.notification.status;
      if (!notifStatus.isGranted) {
        final notifResult = await Permission.notification.request();
        print('🔔 Notification permission request result: $notifResult');
      }
    }

    // Speech service'i initialize et (bu da izin isteyebilir)
    _speechService.initialize();
  }

  Future<void> _checkOverdueReminders() async {
    // Check for reminders that should have fired but didn't
    final location = tz.getLocation('Europe/Istanbul');
    final now = tz.TZDateTime.now(location);
    final activeReminders = _storageService.getActiveReminders();

    for (var reminder in activeReminders) {
      final scheduledTime = tz.TZDateTime.from(
        reminder.scheduledTime,
        location,
      );
      // If reminder time passed but not completed, show notification
      if (scheduledTime.isBefore(now) && !reminder.isCompleted) {
        print(
          'Found overdue reminder: ${reminder.id}, scheduled: $scheduledTime',
        );
        // Show notification immediately
        await _notificationService.showOverdueNotification(reminder);
      }
    }
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

    // iOS'ta mikrofon izni dialog'u AudioRecorder.start() çağrıldığında otomatik çıkar
    // Bu yüzden önce izin kontrolü yapmıyoruz, direkt kayıt başlatıyoruz
    // Eğer izin yoksa, AudioRecorder.start() exception fırlatacak veya false dönecek

    // Android'de aynı anda hem recorder hem speech_to_text mikrofonu kullanamaz.
    // Bu nedenle Android'de sadece speech_to_text çalışsın; iOS'ta kayıt devam edebilir.
    bool recordingStarted = true;
    if (!Platform.isAndroid) {
      print(
        '🎤 Starting audio recording (iOS will request permission if needed)...',
      );
      recordingStarted = await _audioService.startRecording();
      print('Audio recording started: $recordingStarted');
    } else {
      print(
        '🎤 Skipping audio recorder on Android to avoid mic conflict with speech_to_text',
      );
    }

    // Eğer kayıt başlatılamadıysa, izin kontrolü yap
    if (!recordingStarted) {
      final micPermission = await Permission.microphone.status;
      print('Microphone permission status after failed start: $micPermission');

      if (micPermission.isPermanentlyDenied) {
        // iOS'ta permanently denied ise ayarlara yönlendir
        final shouldOpen = await _showPermissionDialog(
          'microphone_permission_required_title'.tr(),
          'microphone_permission_required_message'.tr(),
        );
        if (shouldOpen) {
          await openAppSettings();
        }
      } else if (!micPermission.isGranted) {
        // İzin henüz verilmemiş, kullanıcıya bilgi ver
        _showError('microphone_permission_required'.tr());
      } else {
        // İzin var ama kayıt başlatılamadı, başka bir sorun olabilir
        _showError('audio_recording_failed'.tr());
      }

      setState(() {
        _isRecording = false;
      });
      return;
    }

    // Start real-time speech recognition
    print('🎤 ===== Starting Speech Recognition =====');

    // iOS'ta speech recognition izni de gerçekten kullanılmaya çalışıldığında istenir
    // Speech service'in initialize() metodu içinde izin isteyecek
    // Bu yüzden burada önce izin kontrolü yapmıyoruz

    print('🔄 Initializing speech service...');
    final speechInitialized = await _speechService.initialize();
    print('✅ Speech initialized: $speechInitialized');

    // Eğer speech service initialize edilemediyse, hata mesajı göster
    if (!speechInitialized) {
      print('⚠️ Speech service initialization failed');
      // iOS'ta speech recognition izni speech.listen() çağrıldığında otomatik istenir
      // Bu yüzden burada izin kontrolü yapmıyoruz, direkt devam ediyoruz
      // İzin, speech.listen() çağrıldığında iOS tarafından otomatik istenecek
    }

    if (speechInitialized) {
      print('Starting speech recognition...');

      // Check if speech recognition is available
      final isAvailable = _speechService.speech.isAvailable;
      print('Speech recognition isAvailable: $isAvailable');

      if (!isAvailable) {
        print('⚠️ Speech recognition not available!');
        _showError('speech_recognition_not_available'.tr());
        setState(() {
          _isRecording = false;
        });
        await _audioService.stopRecording();
        return;
      }

      if (isAvailable) {
        print('Speech recognition available, starting listen...');

        // Check available locales
        final locales = await _speechService.speech.locales();
        print('Available locales count: ${locales.length}');
        if (locales.isNotEmpty) {
          print(
            'Sample locales: ${locales.take(5).map((l) => '${l.localeId} - ${l.name}').join(', ')}',
          );
        }

        // Try to find Turkish locale, fallback to default
        String localeId = 'en_US';
        String localeName = 'English';

        if (locales.isNotEmpty) {
          try {
            final turkishLocale = locales.firstWhere(
              (locale) => locale.localeId.startsWith('tr'),
            );
            localeId = turkishLocale.localeId;
            localeName = turkishLocale.name;
          } catch (e) {
            localeId = locales.first.localeId;
            localeName = locales.first.name;
          }
        }
        print('Using locale: $localeId - $localeName');

        try {
          print('🎯 Calling speech.listen() with locale: $localeId');
          print('📋 Listen parameters:');
          print('   - listenFor: 120 seconds');
          print('   - pauseFor: 5 seconds');
          print('   - partialResults: true');
          print('   - listenMode: dictation');
          print('   - cancelOnError: false');

          final listenResult = _speechService.speech.listen(
            onResult: (result) {
              print('🎯 ===== SPEECH RESULT RECEIVED =====');
              print('📝 Recognized words: "${result.recognizedWords}"');
              print('✅ Final result: ${result.finalResult}');
              print('📊 Has words: ${result.recognizedWords.isNotEmpty}');
              print(
                '📏 Word count: ${result.recognizedWords.split(" ").length}',
              );

              // Always update transcript when we get results
              setState(() {
                if (result.recognizedWords.isNotEmpty) {
                  _transcript = result.recognizedWords;
                  print('✅✅✅ Transcript updated in UI: "$_transcript"');
                  print('✅✅✅ Transcript length: ${_transcript.length}');
                } else {
                  // Even if empty, update to show we're listening
                  if (!result.finalResult) {
                    // Partial result but empty - still listening
                    print(
                      '⏳ Listening... (no words yet, but speech recognition is active)',
                    );
                  } else {
                    print(
                      '⚠️ Final result received but empty - no speech detected',
                    );
                  }
                }

                // If this is final result, mark that we're done waiting
                if (result.finalResult) {
                  _waitingForFinalResult = false;
                  print('✅ Final result received, done waiting');
                }
              });
            },
            listenFor: const Duration(seconds: 120),
            pauseFor: const Duration(seconds: 5),
            partialResults: true,
            localeId: localeId,
            listenMode: stt.ListenMode.dictation,
            cancelOnError: false,
            onSoundLevelChange: (level) {
              // Always print sound level to see if microphone is working
              print('🔊 Sound level: ${level.toStringAsFixed(3)}');
              // Update UI to show we're receiving audio
              if (mounted) {
                setState(() {
                  _soundLevel = level;
                });
              }
            },
          );

          print('🎯 speech.listen() called, result: $listenResult');
          print('✅ Speech recognition started with locale: $localeId');

          // Check status after a short delay
          Future.delayed(const Duration(milliseconds: 500), () async {
            final isListening = _speechService.speech.isListening;
            print('📊 Speech recognition isListening status: $isListening');
            if (mounted) {
              setState(() {
                _isSpeechListening = isListening;
              });
            }
            if (!isListening) {
              print('⚠️⚠️⚠️ WARNING: Speech recognition is NOT listening!');
              // İzin kontrolü yap
              final speechPermission = await Permission.speech.status;
              print('🔐 Speech permission status: $speechPermission');

              if (speechPermission.isPermanentlyDenied) {
                if (mounted) {
                  final shouldOpen = await _showPermissionDialog(
                    'speech_recognition_permission_required_title'.tr(),
                    'speech_recognition_permission_required_message'.tr(),
                  );
                  if (shouldOpen) {
                    await openAppSettings();
                  }
                }
              } else if (!speechPermission.isGranted) {
                if (mounted) {
                  _showError('speech_recognition_permission_required'.tr());
                }
              } else {
                if (mounted) {
                  _showError('speech_recognition_failed_to_start'.tr());
                }
              }
            } else {
              print('✅✅✅ Speech recognition is ACTIVE and listening!');
            }
          });

          // Periodic check to see if we're still listening
          Future.delayed(const Duration(seconds: 2), () {
            final isListening = _speechService.speech.isListening;
            print('📊 [2s check] Speech recognition isListening: $isListening');
            if (!isListening && mounted && _isRecording) {
              print('⚠️ Speech recognition stopped unexpectedly!');
              _showError('speech_recognition_stopped'.tr());
            }
          });

          // Check again after 5 seconds
          Future.delayed(const Duration(seconds: 5), () {
            final isListening = _speechService.speech.isListening;
            print('📊 [5s check] Speech recognition isListening: $isListening');
            if (isListening && _transcript.isEmpty && mounted) {
              print(
                '⚠️ Speech recognition is listening but no results yet. Speak louder!',
              );
            }
          });
        } catch (e, stackTrace) {
          print('❌❌❌ ERROR starting speech recognition: $e');
          print('Stack trace: $stackTrace');
          _showError(
            'speech_recognition_failed'.tr(namedArgs: {'error': e.toString()}),
          );
        }
      } else {
        print(
          'Speech recognition not available - check Google Speech Services',
        );
      }
    } else {
      print('Speech service initialization failed');
    }
  }

  Future<void> _stopRecording() async {
    if (!_isRecording) return;

    // Mark that we're waiting for final result
    setState(() {
      _waitingForFinalResult = true;
    });

    // Stop speech recognition first
    print('Stopping speech recognition...');
    _speechService.stopListening();

    // Wait for final transcription - wait up to 3 seconds for final result
    // Also check if speech recognition is still listening
    int waitCount = 0;
    while (_waitingForFinalResult &&
        waitCount < 30 &&
        _speechService.isListening) {
      await Future.delayed(const Duration(milliseconds: 100));
      waitCount++;
      print('Waiting for final result... ($waitCount/30)');
    }

    // Additional wait to ensure we get the final result
    await Future.delayed(const Duration(milliseconds: 800));

    // Check one more time if we got a final result
    if (_waitingForFinalResult) {
      print('⚠️ Still waiting for final result, forcing completion');
      setState(() {
        _waitingForFinalResult = false;
      });
    }

    // Get final transcript - use actual transcript if available
    String finalTranscript = _transcript.trim();

    // If transcript is empty, show a helpful message
    if (finalTranscript.isEmpty) {
      finalTranscript = 'no_speech_detected'.tr();
    }

    print('Final transcript after stop: "$finalTranscript"');
    print('Transcript length: ${finalTranscript.length}');

    // Stop audio recording
    String? audioPath;

    if (!Platform.isAndroid) {
      audioPath = await _audioService.stopRecording();
    } else {
      // Android'de bilinçli olarak ses kaydı YOK
      audioPath = null;
    }

    setState(() {
      _isRecording = false;
      _transcript = finalTranscript;
      _waitingForFinalResult = false;
    });

    // Android'de recorder çalıştırmıyoruz; bu nedenle audioPath null olabilir.
    if (audioPath == null) {
      if (Platform.isAndroid) {
        print('ℹ️ Android: audio recording skipped; using empty audio path.');
      } else {
        _showError('recording_error'.tr());
        return;
      }
    }

    // Check if file exists (skip on Android when recorder is off)
    if (Platform.isAndroid && audioPath == null) {
      audioPath = ''; // Placeholder for model; playback will be unavailable
    } else {
      final file = File(audioPath!);
      if (!await file.exists()) {
        _showError('audio_file_save_failed'.tr());
        return;
      }

      final fileSize = await file.length();
      print('Audio file saved: $audioPath, size: $fileSize bytes');
    }
    print('Final transcript: $finalTranscript');

    // Determine scheduled time based on button type
    DateTime? scheduledTime;

    // Use timezone-aware datetime
    final location = tz.getLocation('Europe/Istanbul');
    final now = tz.TZDateTime.now(location);

    if (_currentButtonType == 'quick_1h') {
      scheduledTime = now.add(const Duration(hours: 1));
    } else if (_currentButtonType == 'quick_10h') {
      scheduledTime = now.add(const Duration(hours: 10));
    } else if (_currentButtonType == 'tomorrow_9am') {
      final tomorrow = tz.TZDateTime(
        location,
        now.year,
        now.month,
        now.day + 1,
        9,
        0,
      );
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
    final location = tz.getLocation('Europe/Istanbul');
    final now = tz.TZDateTime.now(location);
    final localNow = DateTime(
      now.year,
      now.month,
      now.day,
      now.hour,
      now.minute,
    );

    final pickedDate = await showDatePicker(
      context: context,
      initialDate: localNow,
      firstDate: localNow,
      lastDate: localNow.add(const Duration(days: 365)),
    );

    if (pickedDate == null) return null;

    final pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(localNow),
    );

    if (pickedTime == null) return null;

    // Convert to timezone-aware datetime
    final scheduled = tz.TZDateTime(
      location,
      pickedDate.year,
      pickedDate.month,
      pickedDate.day,
      pickedTime.hour,
      pickedTime.minute,
    );

    return scheduled;
  }

  Future<void> _createReminder(String audioPath, DateTime scheduledTime) async {
    // Ensure scheduledTime is timezone-aware
    final location = tz.getLocation('Europe/Istanbul');
    final tzScheduledTime = scheduledTime is tz.TZDateTime
        ? scheduledTime
        : tz.TZDateTime.from(scheduledTime, location);

    // Final transcript - use actual transcript if available
    final finalTranscript = _transcript.isEmpty
        ? 'audio_recording_received'.tr()
        : _transcript;

    print('📝 Creating reminder with transcript: "$finalTranscript"');

    final reminder = Reminder(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      transcript: finalTranscript,
      audioPath: audioPath,
      scheduledTime: tzScheduledTime,
      createdAt: DateTime.now(),
      buttonType: _currentButtonType ?? 'manual',
    );

    await _storageService.saveReminder(reminder);
    await _notificationService.scheduleReminder(reminder);

    if (mounted) {
      // Show transcript in a more visible way
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.check_circle, color: Colors.white, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'reminder_created'.tr(
                        namedArgs: {
                          'time': DateFormat(
                            'dd/MM/yyyy HH:mm',
                            'tr_TR',
                          ).format(scheduledTime),
                        },
                      ),
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
              if (finalTranscript.isNotEmpty &&
                  finalTranscript != 'audio_recording_received'.tr()) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.text_fields,
                        color: Colors.white,
                        size: 16,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          finalTranscript,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
          duration: const Duration(seconds: 4),
          backgroundColor: Colors.green[700],
        ),
      );
    }
  }

  void _showError(String message) {
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
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

  @override
  Widget build(BuildContext context) {
    final su = ScreenUtil.of(context);
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: TapRemindLogo(size: su.w(160), showText: false),
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
            SizedBox(height: su.h(40)),
            // Main instruction text
            if (!_isRecording)
              Text(
                'press_hold_to_create_reminder'.tr(),
                style: TextStyle(
                  fontSize: su.sp(18),
                  color: Colors.grey,
                  fontWeight: FontWeight.w400,
                ),
              )
            else if (_isRecording)
              Padding(
                padding: EdgeInsets.all(su.r(16)),
                child: Column(
                  children: [
                    const CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(
                        Color(0xFFFF6B35),
                      ),
                    ),
                    SizedBox(height: su.h(16)),
                    Text(
                      'recording'.tr(),
                      style: Theme.of(
                        context,
                      ).textTheme.titleLarge?.copyWith(
                            color: Colors.grey[700],
                            fontSize: su.sp(
                              Theme.of(context).textTheme.titleLarge?.fontSize ??
                                  20,
                            ),
                          ),
                    ),
                    SizedBox(height: su.h(8)),
                    // Show speech recognition status
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          _isSpeechListening ? Icons.check_circle : Icons.error,
                          size: su.sp(16),
                          color: _isSpeechListening
                              ? Colors.green
                              : Colors.orange,
                        ),
                        SizedBox(width: su.w(4)),
                        Text(
                          _isSpeechListening
                              ? 'speech_recognition_active'.tr()
                              : 'speech_recognition_waiting'.tr(),
                          style: TextStyle(
                            fontSize: su.sp(12),
                            color: _isSpeechListening
                                ? Colors.green[700]
                                : Colors.orange[700],
                          ),
                        ),
                      ],
                    ),
                    // Show microphone level
                    if (_soundLevel > 0.01) ...[
                      SizedBox(height: su.h(4)),
                      Text(
                        'microphone_working'.tr(
                          namedArgs: {
                            'percent': (_soundLevel * 100).toStringAsFixed(0),
                          },
                        ),
                        style: TextStyle(
                          fontSize: su.sp(11),
                          color: Colors.green[700],
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                    SizedBox(height: su.h(24)),
                    // Transkript gösterimi - her zaman göster
                    Container(
                      width: double.infinity,
                      padding: EdgeInsets.all(su.r(16)),
                      decoration: BoxDecoration(
                        color: _transcript.isEmpty
                            ? Colors.grey[50]
                            : Colors.blue[50],
                        borderRadius: BorderRadius.circular(su.r(12)),
                        border: Border.all(
                          color: _transcript.isEmpty
                              ? Colors.grey[300]!
                              : const Color(0xFFFF6B35),
                          width: _transcript.isEmpty ? 1 : 2,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              _transcript.isEmpty
                                  ? Icon(
                                      Icons.mic,
                                      size: su.sp(18),
                                      color: Colors.grey[600],
                                    )
                                  : Image.asset(
                                      'assets/images/logoBell.png',
                                      width: su.w(18),
                                      height: su.w(18),
                                      fit: BoxFit.contain,
                                      errorBuilder:
                                          (context, error, stackTrace) {
                                            return Icon(
                                              Icons.text_fields,
                                              size: su.sp(18),
                                              color: const Color(0xFFFF6B35),
                                            );
                                          },
                                    ),
                              SizedBox(width: su.w(8)),

                              if (_transcript.isNotEmpty) ...[
                                SizedBox(width: su.w(8)),
                                Container(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: su.w(8),
                                    vertical: su.h(2),
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.green[100],
                                    borderRadius: BorderRadius.circular(
                                      su.r(12),
                                    ),
                                  ),
                                  child: Text(
                                    'working'.tr(),
                                    style: TextStyle(
                                      fontSize: su.sp(10),
                                      fontWeight: FontWeight.w600,
                                      color: Colors.green[800],
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          SizedBox(height: su.h(12)),
                          // Transkript metni - daha büyük ve belirgin
                          Container(
                            width: double.infinity,
                            padding: EdgeInsets.all(su.r(12)),
                            decoration: BoxDecoration(
                              color: _transcript.isEmpty
                                  ? Colors.transparent
                                  : Colors.white,
                              borderRadius: BorderRadius.circular(su.r(8)),
                            ),
                            child: Text(
                              _transcript.isEmpty
                                  ? 'speak_now'.tr()
                                  : _transcript,
                              style: TextStyle(
                                fontSize: su.sp(18),
                                color: _transcript.isEmpty
                                    ? Colors.grey[500]
                                    : Colors.black87,
                                fontWeight: _transcript.isEmpty
                                    ? FontWeight.normal
                                    : FontWeight.w600,
                                height: 1.5,
                                letterSpacing: 0.3,
                              ),
                              textAlign: TextAlign.left,
                            ),
                          ),
                          if (_transcript.isNotEmpty) ...[
                            SizedBox(height: su.h(8)),
                            Text(
                              'characters'.tr(
                                namedArgs: {
                                  'count': _transcript.length.toString(),
                                },
                              ),
                              style: TextStyle(
                                fontSize: su.sp(11),
                                color: Colors.grey[600],
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            SizedBox(height: su.h(20)),
            // 4 main buttons in a grid
            Expanded(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: su.w(24)),
                child: GridView.count(
                  shrinkWrap: true,
                  crossAxisCount: 2,
                  crossAxisSpacing: su.w(16),
                  mainAxisSpacing: su.h(16),
                  childAspectRatio: su.isTablet ? 1.2 : 1.05,
                  children: [
                    _buildPushToTalkButton(
                      'quick_1h'.tr(),
                      Icons.mic,
                      'quick_1h',
                    ),
                    _buildPushToTalkButton(
                      'quick_10h'.tr(),
                      Icons.mic,
                      'quick_10h',
                    ),
                    _buildPushToTalkButton(
                      'tomorrow_9am'.tr(),
                      Icons.mic,
                      'tomorrow_9am',
                    ),
                    _buildPushToTalkButton(
                      'random'.tr(),
                      Icons.shuffle,
                      'random',
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(height: su.h(20)),
            // Footer text
            Padding(
              padding: EdgeInsets.symmetric(horizontal: su.w(24)),
              child: Text(
                'presets_info'.tr(),
                style: TextStyle(
                  fontSize: su.sp(12),
                  color: Colors.grey,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            SizedBox(height: su.h(40)),
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
    final su = ScreenUtil.of(context);
    const orangeColor = Color(0xFFFF6B35);
    final isActive = _isRecording && _currentButtonType == buttonType;

    return GestureDetector(
      onTapDown: (_) => _startRecording(buttonType),
      onTapUp: (_) => _stopRecording(),
      onTapCancel: () => _stopRecording(),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.grey[200],
          borderRadius: BorderRadius.circular(su.r(20)),
          border: isActive
              ? Border.all(color: orangeColor, width: su.w(3))
              : Border.all(color: Colors.grey[300]!, width: su.w(1)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: su.sp(32), color: orangeColor),
            SizedBox(height: su.h(12)),
            Text(
              label,
              style: TextStyle(
                color: Colors.black87,
                fontSize: su.sp(16),
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
