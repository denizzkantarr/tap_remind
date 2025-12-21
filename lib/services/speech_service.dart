import 'dart:io';

import 'package:permission_handler/permission_handler.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

class SpeechService {
  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _isInitialized = false;
  
  // Expose _speech for direct access in home_screen
  stt.SpeechToText get speech => _speech;

  Future<bool> initialize() async {
    if (_isInitialized) {
      print('✅ Speech service already initialized');
      return true;
    }

    // Android requires runtime microphone permission
    if (Platform.isAndroid) {
      final micStatus = await Permission.microphone.status;
      if (!micStatus.isGranted) {
        final result = await Permission.microphone.request();
        print('🎤 Microphone permission (Android) request result: $result');
        if (!result.isGranted) {
          print('❌ Microphone permission not granted. Speech init aborted.');
          return false;
        }
      }
    }

    // iOS'ta speech recognition izni speech.listen() çağrıldığında otomatik istenir
    // Bu yüzden burada izin kontrolü yapmıyoruz, direkt initialize ediyoruz
    // İzin, speech.listen() çağrıldığında iOS tarafından otomatik istenecek

    print('🔄 Initializing speech_to_text...');
    _isInitialized = await _speech.initialize(
      onStatus: (status) {
        print('📡 Speech service status: $status');
      },
      onError: (error) {
        print('❌ Speech service error: $error');
        print('   Error details: ${error.errorMsg}');
      },
    );

    print('✅ Speech service initialized: $_isInitialized');
    if (_isInitialized) {
      final isAvailable = _speech.isAvailable;
      print('📊 Speech recognition available: $isAvailable');
      if (!isAvailable) {
        print('⚠️ WARNING: Speech recognition is not available!');
        print('   This might be because:');
        print('   1. Google Speech Services not installed');
        print('   2. Internet connection required');
        print('   3. Device language settings');
      }
    }

    return _isInitialized;
  }

  Future<String> transcribeAudio(String audioPath) async {
    if (!_isInitialized) {
      await initialize();
    }

    // Note: speech_to_text package doesn't directly transcribe audio files
    // It's designed for real-time speech recognition. For file transcription,
    // we would need a different service (like Google Cloud Speech-to-Text API).
    // For now, we'll use a placeholder that indicates transcription is needed.
    
    // In a production app, you would:
    // 1. Use Google Cloud Speech-to-Text API
    // 2. Use Azure Speech Services
    // 3. Use a local ML model
    
    // For this implementation, we'll simulate transcription
    // You'll need to integrate with a proper STT service for production
    
    return 'Ses kaydı transkript edildi'; // Placeholder
  }

  Future<String> listenAndTranscribe() async {
    if (!_isInitialized) {
      final initialized = await initialize();
      if (!initialized) {
        return '';
      }
    }

    String transcript = '';
    bool isListening = false;

    await _speech.listen(
      onResult: (result) {
        transcript = result.recognizedWords;
        if (result.finalResult) {
          isListening = false;
        }
      },
      listenFor: const Duration(seconds: 30),
      pauseFor: const Duration(seconds: 3),
      partialResults: true,
      localeId: 'tr_TR', // Turkish locale
    );

    // Wait for final result
    while (isListening) {
      await Future.delayed(const Duration(milliseconds: 100));
    }

    return transcript;
  }

  void stopListening() {
    _speech.stop();
  }

  bool get isListening => _speech.isListening;
}

