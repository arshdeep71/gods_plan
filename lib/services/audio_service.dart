import 'package:audioplayers/audioplayers.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AudioService {
  static final AudioService _instance = AudioService._internal();
  factory AudioService() => _instance;
  AudioService._internal();

  bool _soundsEnabled = true;
  double _uiVolume = 0.8;

  // We keep a small pool of players so rapid clicks don't cut off previous sounds
  final List<AudioPlayer> _pool = List.generate(3, (_) => AudioPlayer());
  int _poolIndex = 0;

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _soundsEnabled = prefs.getBool('sounds_enabled') ?? true;
    _uiVolume = prefs.getDouble('ui_volume') ?? 0.8;
  }

  Future<void> toggleSounds(bool isEnabled) async {
    _soundsEnabled = isEnabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('sounds_enabled', isEnabled);
    if (isEnabled) playSuccess();
  }

  Future<void> setVolume(double volume) async {
    _uiVolume = volume;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('ui_volume', volume);
  }

  bool get isEnabled => _soundsEnabled;
  double get volume => _uiVolume;

  void _playSound(String assetPath) {
    if (!_soundsEnabled) return;
    try {
      final player = _pool[_poolIndex];
      player.setVolume(_uiVolume);
      player.play(AssetSource(assetPath));
      _poolIndex = (_poolIndex + 1) % _pool.length;
    } catch (e) {
      print("Audio playback error: \$e");
    }
  }

  // --- Premium UI Sound Hooks ---

  void playTaskComplete() {
    _playSound('sounds/task_complete.mp3'); // We'll add this asset next
  }

  void playAchievementUnlocked() {
    _playSound('sounds/achievement.mp3');
  }

  void playSuccess() {
    _playSound('sounds/success_chime.mp3');
  }

  void playError() {
    _playSound('sounds/error_buzz.mp3');
  }

  void playLevelUp() {
    _playSound('sounds/level_up.mp3');
  }
}
