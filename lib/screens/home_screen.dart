import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:permission_handler/permission_handler.dart';
import 'package:timezone/timezone.dart' as tz;
import '../models/reminder.dart';
import '../services/audio_service.dart';
import '../services/speech_service.dart';
import '../services/storage_service.dart';
import '../services/notification_service.dart';
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
  bool _isSimpleTranscription = false;
  String _finalTranscription = '';
  bool _waitingForFinalResult = false;
  double _soundLevel = 0.0;
  bool _isSpeechListening = false;

  @override
  void initState() {
    super.initState();
    _speechService.initialize();
    _checkOverdueReminders();
  }
  
  Future<void> _checkOverdueReminders() async {
    // Check for reminders that should have fired but didn't
    final now = tz.TZDateTime.now(tz.local);
    final activeReminders = _storageService.getActiveReminders();
    
    for (var reminder in activeReminders) {
      final scheduledTime = tz.TZDateTime.from(reminder.scheduledTime, tz.local);
      // If reminder time passed but not completed, show notification
      if (scheduledTime.isBefore(now) && !reminder.isCompleted) {
        print('Found overdue reminder: ${reminder.id}, scheduled: $scheduledTime');
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

  Future<void> _startSimpleTranscription() async {
    setState(() {
      _isSimpleTranscription = true;
      _finalTranscription = '';
    });
    await _startRecording('simple_transcription');
  }

  Future<void> _startRecording(String buttonType) async {
    setState(() {
      _isRecording = true;
      _currentButtonType = buttonType;
      _transcript = '';
    });

    // Check microphone permission first
    final micPermission = await Permission.microphone.status;
    print('Microphone permission status: $micPermission');
    
    if (!micPermission.isGranted) {
      final micResult = await Permission.microphone.request();
      print('Microphone permission request result: $micResult');
      if (!micResult.isGranted) {
        _showError('Mikrofon izni gerekli');
        setState(() {
          _isRecording = false;
        });
        return;
      }
    }
    
    // Start audio recording
    final recordingStarted = await _audioService.startRecording();
    print('Audio recording started: $recordingStarted');
    
    // Start real-time speech recognition
    print('🎤 ===== Starting Speech Recognition =====');
    
    // Check speech permission
    final speechPermission = await Permission.speech.status;
    print('🔐 Speech permission status: $speechPermission');
    
    if (!speechPermission.isGranted) {
      print('⚠️ Speech permission not granted, requesting...');
      final speechResult = await Permission.speech.request();
      print('🔐 Speech permission request result: $speechResult');
      if (!speechResult.isGranted) {
        print('❌ Speech permission denied! Speech-to-text will not work.');
        _showError('Konuşma tanıma izni gerekli');
        setState(() {
          _isRecording = false;
        });
        await _audioService.stopRecording();
        return;
      }
    }
    
    print('🔄 Initializing speech service...');
    final speechInitialized = await _speechService.initialize();
    print('✅ Speech initialized: $speechInitialized');
    
    if (speechInitialized) {
      print('Starting speech recognition...');
      
      // Check if speech recognition is available
      final isAvailable = _speechService.speech.isAvailable;
      print('Speech recognition isAvailable: $isAvailable');
      
      if (!isAvailable) {
        print('⚠️ Speech recognition not available!');
        _showError('Konuşma tanıma kullanılamıyor. Emülatörde çalışmayabilir. Gerçek cihazda deneyin.');
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
          print('Sample locales: ${locales.take(5).map((l) => '${l.localeId} - ${l.name}').join(', ')}');
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
              print('📏 Word count: ${result.recognizedWords.split(" ").length}');
              
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
                    print('⏳ Listening... (no words yet, but speech recognition is active)');
                  } else {
                    print('⚠️ Final result received but empty - no speech detected');
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
          Future.delayed(const Duration(milliseconds: 500), () {
            final isListening = _speechService.speech.isListening;
            print('📊 Speech recognition isListening status: $isListening');
            if (mounted) {
              setState(() {
                _isSpeechListening = isListening;
              });
            }
            if (!isListening) {
              print('⚠️⚠️⚠️ WARNING: Speech recognition is NOT listening!');
              if (mounted) {
                _showError('Speech recognition başlatılamadı. Lütfen tekrar deneyin.');
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
              _showError('Speech recognition durdu. Mikrofon ve internet bağlantınızı kontrol edin.');
            }
          });
          
          // Check again after 5 seconds
          Future.delayed(const Duration(seconds: 5), () {
            final isListening = _speechService.speech.isListening;
            print('📊 [5s check] Speech recognition isListening: $isListening');
            if (isListening && _transcript.isEmpty && mounted) {
              print('⚠️ Speech recognition is listening but no results yet. Speak louder!');
            }
          });
        } catch (e, stackTrace) {
          print('❌❌❌ ERROR starting speech recognition: $e');
          print('Stack trace: $stackTrace');
          _showError('Konuşma tanıma başlatılamadı: $e');
        }
      } else {
        print('Speech recognition not available - check Google Speech Services');
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
    while (_waitingForFinalResult && waitCount < 30 && _speechService.isListening) {
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
      finalTranscript = 'Konuşma algılanamadı.\n\n⚠️ Emülatör kullanıyorsanız:\n• Speech-to-text emülatörde çalışmayabilir\n• Gerçek bir Android/iOS cihazında test edin\n\nDiğer durumlar:\n• Mikrofonunuzun çalıştığından emin olun\n• Yüksek sesle ve net konuşun\n• İnternet bağlantınızı kontrol edin\n• Google Speech Services yüklü mü kontrol edin';
    }
    
    print('Final transcript after stop: "$finalTranscript"');
    print('Transcript length: ${finalTranscript.length}');
    
    // Stop audio recording
    final audioPath = await _audioService.stopRecording();
    
    setState(() {
      _isRecording = false;
      _transcript = finalTranscript;
      _waitingForFinalResult = false;
    });

    // If this is simple transcription mode, just show the result
    if (_isSimpleTranscription) {
      setState(() {
        _finalTranscription = finalTranscript;
        _isSimpleTranscription = false;
      });
      return;
    }

    if (audioPath == null) {
      _showError('Kayıt sırasında bir hata oluştu');
      return;
    }

    // Check if file exists
    final file = File(audioPath);
    if (!await file.exists()) {
      _showError('Ses dosyası kaydedilemedi');
      return;
    }
    
    final fileSize = await file.length();
    print('Audio file saved: $audioPath, size: $fileSize bytes');
    print('Final transcript: $finalTranscript');

    // Determine scheduled time based on button type
    DateTime? scheduledTime;
    
    // Use timezone-aware datetime
    final now = tz.TZDateTime.now(tz.local);
    
    if (_currentButtonType == 'quick_1h') {
      scheduledTime = now.add(const Duration(hours: 1));
    } else if (_currentButtonType == 'quick_10h') {
      scheduledTime = now.add(const Duration(hours: 10));
    } else if (_currentButtonType == 'tomorrow_9am') {
      final tomorrow = tz.TZDateTime(
        tz.local,
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
    final now = tz.TZDateTime.now(tz.local);
    final localNow = DateTime(now.year, now.month, now.day, now.hour, now.minute);
    
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
      tz.local,
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
    final tzScheduledTime = scheduledTime is tz.TZDateTime 
        ? scheduledTime 
        : tz.TZDateTime.from(scheduledTime, tz.local);
    
    // Final transcript - use actual transcript if available
    final finalTranscript = _transcript.isEmpty 
        ? 'Ses kaydı alındı' 
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
                      'Hatırlatıcı oluşturuldu: ${DateFormat('dd/MM/yyyy HH:mm', 'tr_TR').format(scheduledTime)}',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
              if (finalTranscript.isNotEmpty && finalTranscript != 'Ses kaydı alındı') ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.text_fields, color: Colors.white, size: 16),
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const TapRemindLogo(size: 160, showText: false),
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
            const SizedBox(height: 20),
            // Simple transcription button
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: GestureDetector(
                onTapDown: (_) => _startSimpleTranscription(),
                onTapUp: (_) => _stopRecording(),
                onTapCancel: () => _stopRecording(),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  decoration: BoxDecoration(
                    color: _isRecording && _isSimpleTranscription
                        ? const Color(0xFFFF6B35)
                        : Colors.blue[600],
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        _isRecording && _isSimpleTranscription
                            ? Icons.stop_circle
                            : Icons.mic,
                        color: Colors.white,
                        size: 28,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        _isRecording && _isSimpleTranscription
                            ? 'Kaydı Durdur'
                            : 'Basılı Tut - Konuşmayı Yazıya Çevir',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
            // Display final transcription result
            if (_finalTranscription.isNotEmpty && !_isRecording)
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.green[50],
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: Colors.green[300]!,
                        width: 2,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.text_fields,
                              color: Colors.green[700],
                              size: 24,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Yazıya Çevrilen Metin:',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.green[700],
                              ),
                            ),
                            const Spacer(),
                            IconButton(
                              icon: const Icon(Icons.close),
                              onPressed: () {
                                setState(() {
                                  _finalTranscription = '';
                                });
                              },
                              color: Colors.green[700],
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Expanded(
                          child: SingleChildScrollView(
                            child: Text(
                              _finalTranscription,
                              style: const TextStyle(
                                fontSize: 20,
                                color: Colors.black87,
                                fontWeight: FontWeight.w500,
                                height: 1.6,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              )
            else if (!_isRecording)
              const SizedBox(height: 20),
            // Main instruction text
            if (!_isRecording && _finalTranscription.isEmpty)
              const Text(
                'Press & Hold to Create Reminder',
                style: TextStyle(
                  fontSize: 18,
                  color: Colors.grey,
                  fontWeight: FontWeight.w400,
                ),
              )
            else if (_isRecording)
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    const CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFFF6B35)),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Recording...',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            color: Colors.grey[700],
                          ),
                    ),
                    const SizedBox(height: 8),
                    // Show speech recognition status
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          _isSpeechListening ? Icons.check_circle : Icons.error,
                          size: 16,
                          color: _isSpeechListening ? Colors.green : Colors.orange,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _isSpeechListening 
                              ? 'Speech recognition aktif' 
                              : 'Speech recognition bekleniyor...',
                          style: TextStyle(
                            fontSize: 12,
                            color: _isSpeechListening ? Colors.green[700] : Colors.orange[700],
                          ),
                        ),
                      ],
                    ),
                    // Show microphone level
                    if (_soundLevel > 0.01) ...[
                      const SizedBox(height: 4),
                      Text(
                        'Mikrofon çalışıyor (${(_soundLevel * 100).toStringAsFixed(0)}%)',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.green[700],
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                    const SizedBox(height: 24),
                    // Transkript gösterimi - her zaman göster
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: _transcript.isEmpty 
                            ? Colors.grey[50] 
                            : Colors.blue[50],
                        borderRadius: BorderRadius.circular(12),
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
                              Icon(
                                _transcript.isEmpty
                                    ? Icons.mic
                                    : Icons.text_fields,
                                size: 18,
                                color: _transcript.isEmpty
                                    ? Colors.grey[600]
                                    : const Color(0xFFFF6B35),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Speech-to-Text:',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: _transcript.isEmpty
                                      ? Colors.grey[600]
                                      : const Color(0xFFFF6B35),
                                ),
                              ),
                              if (_transcript.isNotEmpty) ...[
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.green[100],
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    '✓ Çalışıyor',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.green[800],
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 12),
                          // Transkript metni - daha büyük ve belirgin
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: _transcript.isEmpty
                                  ? Colors.transparent
                                  : Colors.white,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              _transcript.isEmpty
                                  ? '🎤 Konuşun... (Speech-to-Text dinliyor)'
                                  : _transcript,
                              style: TextStyle(
                                fontSize: 18,
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
                            const SizedBox(height: 8),
                            Text(
                              '${_transcript.length} karakter',
                              style: TextStyle(
                                fontSize: 11,
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
            if (_finalTranscription.isEmpty) ...[
              const SizedBox(height: 20),
              // 4 main buttons in a grid
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0),
                  child: GridView.count(
                    shrinkWrap: true,
                    crossAxisCount: 2,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                    childAspectRatio: 1.1,
                    children: [
                      _buildPushToTalkButton(
                        '+1 Hour',
                        Icons.mic,
                        'quick_1h',
                      ),
                      _buildPushToTalkButton(
                        '+10 Hours',
                        Icons.mic,
                        'quick_10h',
                      ),
                      _buildPushToTalkButton(
                        'Tomorrow 9AM',
                        Icons.mic,
                        'tomorrow_9am',
                      ),
                      _buildPushToTalkButton(
                        'Random',
                        Icons.shuffle,
                        'random',
                      ),
                    ],
                  ),
                ),
              ),
            ] else
              const SizedBox(height: 20),
            if (_finalTranscription.isEmpty) ...[
              const SizedBox(height: 20),
              // Footer text
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 24.0),
                child: Text(
                  'Presets save instantly. Random lets you pick time',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 40),
            ],
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
    const orangeColor = Color(0xFFFF6B35);
    final isActive = _isRecording && _currentButtonType == buttonType;

    return GestureDetector(
      onTapDown: (_) => _startRecording(buttonType),
      onTapUp: (_) => _stopRecording(),
      onTapCancel: () => _stopRecording(),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.grey[200],
          borderRadius: BorderRadius.circular(20),
          border: isActive
              ? Border.all(color: orangeColor, width: 3)
              : Border.all(color: Colors.grey[300]!, width: 1),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 32,
              color: orangeColor,
            ),
            const SizedBox(height: 12),
            Text(
              label,
              style: TextStyle(
                color: Colors.black87,
                fontSize: 16,
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

