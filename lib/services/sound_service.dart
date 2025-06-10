import 'package:audioplayers/audioplayers.dart';
import '../providers/theme_provider.dart';
import 'base/base_service.dart';
import 'base/service_result.dart';

/// Service for playing meme sounds
class SoundService extends BaseService {
  final ThemeProvider _themeProvider;
  final AudioPlayer _audioPlayer = AudioPlayer();

  // Sound file paths
  static const _soundPath = 'sounds/';
  static const _sounds = {
    'startup': 'startup.mp3',
    'success': 'success.mp3',
    'error': 'error.mp3',
    'send': 'send.mp3',
    'receive': 'receive.mp3',
    'tap': 'tap.mp3',
    'chaos': 'chaos.mp3',
    'moon': 'moon.mp3',
    'rekt': 'rekt.mp3',
  };

  SoundService(this._themeProvider) : super('SoundService') {
    _initializePlayer();
  }

  /// Initialize audio player
  void _initializePlayer() {
    _audioPlayer.setReleaseMode(ReleaseMode.stop);
    _audioPlayer.setPlayerMode(PlayerMode.lowLatency);
  }

  /// Play sound effect
  Future<ServiceResult<void>> playSound(String soundName) async {
    if (!_themeProvider.soundEnabled) {
      return const Success(null);
    }

    return executeOperation(
      operation: () async {
        final soundFile = _sounds[soundName];
        if (soundFile == null) {
          throw Exception('Sound not found: $soundName');
        }

        await _audioPlayer.play(
          AssetSource('$_soundPath$soundFile'),
          volume: _getVolumeForChaosLevel(),
        );
      },
      operationName: 'play sound $soundName',
    );
  }

  /// Get volume based on chaos level
  double _getVolumeForChaosLevel() {
    final chaos = _themeProvider.chaosLevel;
    // Higher chaos = louder sounds
    return 0.3 + (chaos * 0.07);
  }

  /// Play startup sound
  Future<void> startup() async {
    await playSound('startup');
  }

  /// Play success sound
  Future<void> success() async {
    await playSound('success');
  }

  /// Play error sound
  Future<void> error() async {
    await playSound('error');
  }

  /// Play send transaction sound
  Future<void> sendTransaction() async {
    if (_themeProvider.chaosLevel >= 8) {
      await playSound('chaos');
    } else {
      await playSound('send');
    }
  }

  /// Play receive transaction sound
  Future<void> receiveTransaction() async {
    if (_themeProvider.chaosLevel >= 7) {
      await playSound('moon');
    } else {
      await playSound('receive');
    }
  }

  /// Play tap sound
  Future<void> tap() async {
    if (_themeProvider.chaosLevel >= 5) {
      await playSound('tap');
    }
  }

  /// Play chaos sound for high chaos moments
  Future<void> chaos() async {
    await playSound('chaos');
  }

  /// Play rekt sound for errors
  Future<void> rekt() async {
    await playSound('rekt');
  }

  /// Dispose audio player
  void dispose() {
    _audioPlayer.dispose();
  }
}
