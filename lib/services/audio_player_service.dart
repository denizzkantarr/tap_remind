import 'dart:io';
import 'package:audioplayers/audioplayers.dart';

class AudioPlayerService {
  final AudioPlayer _player = AudioPlayer();
  bool _isPlaying = false;

  Function(bool)? onPlayingStateChanged;

  AudioPlayerService() {
    _player.onPlayerStateChanged.listen((state) {
      final wasPlaying = _isPlaying;
      _isPlaying = state == PlayerState.playing;
      if (wasPlaying != _isPlaying && onPlayingStateChanged != null) {
        onPlayingStateChanged!(_isPlaying);
      }
    });

    _player.onPlayerComplete.listen((_) {
      _isPlaying = false;
      onPlayingStateChanged?.call(false);
    });

    _player.setVolume(1.0);
  }

  Future<bool> playAudio(String filePath) async {
    if (_isPlaying) {
      await stopAudio();
      await Future.delayed(const Duration(milliseconds: 200));
    }

    try {
      final file = File(filePath);
      if (!await file.exists()) {
        _notifyState(false);
        return false;
      }

      final fileSize = await file.length();
      if (fileSize == 0) {
        _notifyState(false);
        return false;
      }

      await _player.stop();
      await Future.delayed(const Duration(milliseconds: 100));

      try {
        await _player.setPlayerMode(PlayerMode.mediaPlayer);
      } catch (_) {}

      await _player.setVolume(1.0);
      await _player.setReleaseMode(ReleaseMode.stop);
      await _player.play(DeviceFileSource(filePath));

      await Future.delayed(const Duration(milliseconds: 700));

      _isPlaying = _player.state == PlayerState.playing;
      _notifyState(_isPlaying);
      return _isPlaying;
    } catch (e) {
      _notifyState(false);
      return false;
    }
  }

  Future<void> stopAudio() async {
    try {
      await _player.stop();
    } catch (_) {}
    _notifyState(false);
  }

  Future<void> pauseAudio() async {
    try {
      await _player.pause();
    } catch (_) {}
    _notifyState(false);
  }

  void _notifyState(bool playing) {
    _isPlaying = playing;
    onPlayingStateChanged?.call(playing);
  }

  bool get isPlaying => _isPlaying;

  void dispose() {
    _player.dispose();
  }
}
