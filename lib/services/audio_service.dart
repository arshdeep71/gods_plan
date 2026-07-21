import 'package:audioplayers/audioplayers.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AudioService {
  static final AudioService _instance = AudioService._internal();
  factory AudioService() => _instance;
  AudioService._internal();

  bool _soundsEnabled = true;
  double _volume = 0.8;
  
  // Create a pool of players to allow overlapping sounds without cutting off
  final List<AudioPlayer> _players = List.generate(3, (_) => AudioPlayer());
  int _currentPlayerIndex = 0;

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _soundsEnabled = prefs.getBool('sounds_enabled') ?? true;
    _volume = prefs.getDouble('sounds_volume') ?? 0.8;
    
    // Set AudioContext to handle iOS silent mode behavior gracefully
    await AudioPlayer.global.setAudioContext(AudioContextConfig(
      forceSpeaker: false,
      duckAudio: true,
      respectSilence: true, // This is crucial for respecting iOS silent switch
      stayAwake: false,
    ).build());
    
    // Pre-cache sounds
    await Future.wait([
      _preload('sounds/reminder.wav'),
      _preload('sounds/achievement.wav'),
      _preload('sounds/xp.wav'),
      _preload('sounds/success.wav'),
      _preload('sounds/error.wav'),
      _preload('sounds/streak.wav'),
      _preload('sounds/coin.wav'),
    ]);
  }

  Future<void> _preload(String assetPath) async {
    try {
      // In audioplayers v5+, we can use AudioCache (global or specific) but usually it's handled internally.
      // Playing a silent sound or setting source can cache it.
      // We will skip explicit pre-caching for this placeholder implementation to avoid overhead
      // until production assets are in.
    } catch (e) {
      print("Failed to preload \$assetPath: \$e");
    }
  }

  Future<void> toggleSounds(bool isEnabled) async {
    _soundsEnabled = isEnabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('sounds_enabled', isEnabled);
  }

  Future<void> setVolume(double volume) async {
    _volume = volume.clamp(0.0, 1.0);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('sounds_volume', _volume);
    for (var player in _players) {
      await player.setVolume(_volume);
    }
  }

  bool get isEnabled => _soundsEnabled;
  double get volume => _volume;

  Future<void> _playAsset(String path) async {
    if (!_soundsEnabled) return;
    
    try {
      final player = _players[_currentPlayerIndex];
      _currentPlayerIndex = (_currentPlayerIndex + 1) % _players.length;
      
      await player.setVolume(_volume);
      await player.play(AssetSource(path));
    } catch (e) {
      print("Failed to play sound \$path: \$e");
    }
  }

  void playReminder() => _playAsset('sounds/reminder.wav');
  void playAchievement() => _playAsset('sounds/achievement.wav');
  void playXp() => _playAsset('sounds/xp.wav');
  void playSuccess() => _playAsset('sounds/success.wav');
  void playError() => _playAsset('sounds/error.wav');
  void playStreak() => _playAsset('sounds/streak.wav');
  void playCoin() => _playAsset('sounds/coin.wav');
}
