import 'dart:io';
import 'package:audioplayers/audioplayers.dart';

class AudioPlayerService {
  final AudioPlayer _player = AudioPlayer();
  bool _isPlaying = false;
  
  // Callback for state changes
  Function(bool)? onPlayingStateChanged;

  AudioPlayerService() {
    // Listen to player state changes
    _player.onPlayerStateChanged.listen((state) {
      final wasPlaying = _isPlaying;
      _isPlaying = state == PlayerState.playing;
      print('Player state changed: $state, isPlaying: $_isPlaying');
      
      // Notify listeners if state changed
      if (wasPlaying != _isPlaying && onPlayingStateChanged != null) {
        onPlayingStateChanged!(_isPlaying);
      }
    });
    
    // Listen to player completion
    _player.onPlayerComplete.listen((_) {
      _isPlaying = false;
      print('Audio playback completed');
      if (onPlayingStateChanged != null) {
        onPlayingStateChanged!(false);
      }
    });
    
    // Listen to errors
    _player.onLog.listen((message) {
      print('Audio player log: $message');
    });
    
    // Set volume to maximum
    _player.setVolume(1.0);
  }

  Future<bool> playAudio(String filePath) async {
    if (_isPlaying) {
      await stopAudio();
      // Wait a bit before starting new playback
      await Future.delayed(const Duration(milliseconds: 200));
    }

    try {
      // Check if file exists
      final file = File(filePath);
      if (!await file.exists()) {
        print('❌ Error: Audio file does not exist at path: $filePath');
        _isPlaying = false;
        if (onPlayingStateChanged != null) {
          onPlayingStateChanged!(false);
        }
        return false;
      }
      
      final fileSize = await file.length();
      print('🎵 Playing audio from: $filePath');
      print('📦 File size: $fileSize bytes');
      
      if (fileSize == 0) {
        print('❌ Error: Audio file is empty (0 bytes)');
        _isPlaying = false;
        if (onPlayingStateChanged != null) {
          onPlayingStateChanged!(false);
        }
        return false;
      }
      
      // Stop any current playback first
      await _player.stop();
      await Future.delayed(const Duration(milliseconds: 100));
      
      // Set player mode to media player for better audio output
      try {
        await _player.setPlayerMode(PlayerMode.mediaPlayer);
        print('✅ Player mode set to mediaPlayer');
      } catch (e) {
        print('⚠️ Could not set player mode: $e');
      }
      
      // Set volume to maximum
      await _player.setVolume(1.0);
      print('🔊 Volume set to 1.0');
      
      // Set release mode to keep the player alive
      await _player.setReleaseMode(ReleaseMode.stop);
      
      // Play the audio
      print('▶️ Starting playback...');
      await _player.play(DeviceFileSource(filePath));
      
      // Double check volume after play starts
      await Future.delayed(const Duration(milliseconds: 200));
      await _player.setVolume(1.0);
      print('🔊 Volume re-checked and set to 1.0');
      
      // Wait a bit and check if actually playing
      await Future.delayed(const Duration(milliseconds: 500));
      
      final state = _player.state;
      _isPlaying = state == PlayerState.playing;
      
      print('🎵 Audio playback status - state: $state, isPlaying: $_isPlaying');
      
      if (!_isPlaying) {
        print('⚠️ WARNING: Audio player state is not playing after start!');
        print('Current state: $state');
        // Try to get more info
        try {
          final duration = await _player.getDuration();
          final position = await _player.getCurrentPosition();
          print('Duration: $duration, Position: $position');
        } catch (e) {
          print('Could not get duration/position: $e');
        }
      } else {
        print('✅ Audio is playing successfully!');
      }
      
      if (onPlayingStateChanged != null) {
        onPlayingStateChanged!(_isPlaying);
      }
      
      return _isPlaying;
    } catch (e, stackTrace) {
      print('❌ Error playing audio: $e');
      print('Stack trace: $stackTrace');
      print('File path: $filePath');
      _isPlaying = false;
      if (onPlayingStateChanged != null) {
        onPlayingStateChanged!(false);
      }
      return false;
    }
  }

  Future<void> stopAudio() async {
    try {
      await _player.stop();
      _isPlaying = false;
      if (onPlayingStateChanged != null) {
        onPlayingStateChanged!(false);
      }
    } catch (e) {
      print('Error stopping audio: $e');
      _isPlaying = false;
      if (onPlayingStateChanged != null) {
        onPlayingStateChanged!(false);
      }
    }
  }

  Future<void> pauseAudio() async {
    try {
      await _player.pause();
      _isPlaying = false;
      if (onPlayingStateChanged != null) {
        onPlayingStateChanged!(false);
      }
    } catch (e) {
      print('Error pausing audio: $e');
      _isPlaying = false;
      if (onPlayingStateChanged != null) {
        onPlayingStateChanged!(false);
      }
    }
  }

  bool get isPlaying => _isPlaying;

  void dispose() {
    _player.dispose();
  }
}

