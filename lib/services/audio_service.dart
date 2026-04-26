import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

class AudioService {
  final AudioRecorder _recorder = AudioRecorder();
  bool _isRecording = false;
  String? _currentRecordingPath;

  Future<bool> startRecording() async {
    if (_isRecording) return false;

    try {
      final directory = await getApplicationDocumentsDirectory();
      final audioDir = Directory('${directory.path}/recordings');
      if (!await audioDir.exists()) {
        await audioDir.create(recursive: true);
      }

      final timestamp = DateTime.now().millisecondsSinceEpoch;
      _currentRecordingPath = '${audioDir.path}/recording_$timestamp.m4a';

      // iOS'ta mikrofon izni dialog'u AudioRecorder.start() çağrıldığında otomatik çıkar
      // Bu yüzden önce Permission.microphone.request() yapmıyoruz
      // iOS otomatik olarak izin isteyecek
      await _recorder.start(
        const RecordConfig(
          encoder: AudioEncoder.aacLc,
          bitRate: 128000,
          sampleRate: 44100,
        ),
        path: _currentRecordingPath!,
      );

      _isRecording = true;
      return true;
    } catch (e) {
      // iOS'ta izin reddedilirse exception fırlatılır
      // Bu durumda false döndürüyoruz
      return false;
    }
  }

  Future<String?> stopRecording() async {
    if (!_isRecording) return null;

    try {
      final path = await _recorder.stop();
      _isRecording = false;
      _currentRecordingPath = path;
      return path;
    } catch (e) {
      _isRecording = false;
      return null;
    }
  }

  bool get isRecording => _isRecording;

  void dispose() {
    _recorder.dispose();
  }
}

