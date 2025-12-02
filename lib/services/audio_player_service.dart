import 'package:audioplayers/audioplayers.dart';

class AudioPlayerService {
  final AudioPlayer _player = AudioPlayer();
  bool _isPlaying = false;

  Future<void> playAudio(String filePath) async {
    if (_isPlaying) {
      await stopAudio();
    }

    try {
      await _player.play(DeviceFileSource(filePath));
      _isPlaying = true;
    } catch (e) {
      print('Error playing audio: $e');
    }
  }

  Future<void> stopAudio() async {
    try {
      await _player.stop();
      _isPlaying = false;
    } catch (e) {
      print('Error stopping audio: $e');
    }
  }

  Future<void> pauseAudio() async {
    try {
      await _player.pause();
      _isPlaying = false;
    } catch (e) {
      print('Error pausing audio: $e');
    }
  }

  bool get isPlaying => _isPlaying;

  void dispose() {
    _player.dispose();
  }
}

