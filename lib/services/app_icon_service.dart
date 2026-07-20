import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:hive/hive.dart';
import 'package:flutter_dynamic_icon_plus/flutter_dynamic_icon_plus.dart';
import '../models/app_icon_model.dart';

class AppIconService extends ChangeNotifier {
  static const String _boxName = 'settings_box';
  static const String _keySelectedIcon = 'selected_app_icon_id';
  static const String _keyFavorites = 'favorite_app_icon_ids';
  static const String _keyRecentlyUsed = 'recently_used_app_icon_ids';
  static const String _keyWarningFlag = 'show_removed_icon_warning';

  late Box _box;
  List<AppIconModel> _icons = [];
  Set<String> _favorites = {};
  List<String> _recentlyUsed = [];
  String _selectedIconId = 'default';
  bool _isInitialized = false;
  bool _showWarningFlag = false;

  List<AppIconModel> get icons => _icons;
  Set<String> get favorites => _favorites;
  List<String> get recentlyUsed => _recentlyUsed;
  String get selectedIconId => _selectedIconId;
  bool get showWarningFlag => _showWarningFlag;
  bool get isInitialized => _isInitialized;

  bool get _isIOS => !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;

  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      _box = Hive.isBoxOpen(_boxName) ? Hive.box(_boxName) : await Hive.openBox(_boxName);

      // 1. Load manifest
      final manifestJson = await rootBundle.loadString('assets/alternate_icons_manifest.json');
      final Map<String, dynamic> manifestMap = json.decode(manifestJson);
      final List<dynamic> iconsJson = manifestMap['icons'] ?? [];

      // 2. Load favorites & recently used from box
      final List<dynamic>? favList = _box.get(_keyFavorites) as List<dynamic>?;
      if (favList != null) {
        _favorites = Set<String>.from(favList.cast<String>());
      }

      final List<dynamic>? recentList = _box.get(_keyRecentlyUsed) as List<dynamic>?;
      if (recentList != null) {
        _recentlyUsed = List<String>.from(recentList.cast<String>());
      }

      // Parse icons
      _icons = iconsJson.map((e) {
        final iconId = e['id'] as String? ?? '';
        final isFav = _favorites.contains(iconId);
        return AppIconModel.fromJson(Map<String, dynamic>.from(e), favorite: isFav);
      }).toList();

      final hasDefault = _icons.any((icon) => icon.id == 'default');
      if (!hasDefault) {
        final virtualDefault = AppIconModel(
          id: 'default',
          name: 'System Default',
          assetPath: 'assets/app_logo_1.jpg',
          thumbnailPath: 'assets/app_logo_1.jpg',
          category: 'Default',
          author: 'System',
          addedAt: DateTime.fromMillisecondsSinceEpoch(0),
          tags: const ['default', 'system'],
          sortOrder: 0,
          favorite: _favorites.contains('default'),
        );
        _icons.insert(0, virtualDefault);
      }

      // 3. Load selected icon ID
      _selectedIconId = _box.get(_keySelectedIcon, defaultValue: 'default') as String;

      // 4. Preserve selection check (if selected icon no longer exists, revert to default)
      final iconExists = _icons.any((icon) => icon.id == _selectedIconId);
      if (!iconExists && _selectedIconId != 'default') {
        final oldIconId = _selectedIconId;
        _selectedIconId = 'default';
        await _box.put(_keySelectedIcon, 'default');
        
        // Revert iOS alternate icon name
        if (_isIOS) {
          try {
            await FlutterDynamicIconPlus.setAlternateIconName(iconName: null);
          } catch (_) {}
        }
        
        // Enable warning flag
        _showWarningFlag = true;
        await _box.put(_keyWarningFlag, true);

        if (kDebugMode) {
          print("App Icon Changed: Selection preserved. Old icon '$oldIconId' no longer exists. Reset to 'default'.");
        }
      } else {
        _showWarningFlag = _box.get(_keyWarningFlag, defaultValue: false) as bool;
      }

      // 5. Cleanup favorites & recently used from stale entries
      final validIds = _icons.map((e) => e.id).toSet();
      
      final prevFavCount = _favorites.length;
      _favorites.retainAll(validIds);
      if (_favorites.length != prevFavCount) {
        await _box.put(_keyFavorites, _favorites.toList());
      }

      final prevRecentCount = _recentlyUsed.length;
      _recentlyUsed.removeWhere((id) => !validIds.contains(id));
      if (_recentlyUsed.length != prevRecentCount) {
        await _box.put(_keyRecentlyUsed, _recentlyUsed);
      }

      // 6. Restore active icon on startup for iOS
      if (_isIOS) {
        await _restoreIconOnStartup();
      }

      _isInitialized = true;
      notifyListeners();
    } catch (e) {
      if (kDebugMode) {
        print("Error initializing AppIconService: $e");
      }
    }
  }

  Future<void> _restoreIconOnStartup() async {
    if (!_isIOS) return;
    try {
      final isSupported = await FlutterDynamicIconPlus.supportsAlternateIcons;
      if (!isSupported) return;
      
      // Attempt set alternate name (null for default)
      final nameToSet = _selectedIconId == 'default' ? null : _selectedIconId;
      await FlutterDynamicIconPlus.setAlternateIconName(iconName: nameToSet);
    } catch (_) {
      // Ignore silent errors during background restore
    }
  }

  Future<void> clearWarningFlag() async {
    _showWarningFlag = false;
    await _box.put(_keyWarningFlag, false);
    notifyListeners();
  }

  Future<void> toggleFavorite(String iconId) async {
    if (_favorites.contains(iconId)) {
      _favorites.remove(iconId);
    } else {
      _favorites.add(iconId);
    }
    await _box.put(_keyFavorites, _favorites.toList());

    // Update the favorite flag on model instances
    _icons = _icons.map((icon) {
      if (icon.id == iconId) {
        return icon.copyWith(favorite: _favorites.contains(iconId));
      }
      return icon;
    }).toList();

    notifyListeners();
  }

  Future<void> addToRecentlyUsed(String iconId) async {
    _recentlyUsed.remove(iconId);
    _recentlyUsed.insert(0, iconId);
    if (_recentlyUsed.length > 10) {
      _recentlyUsed = _recentlyUsed.sublist(0, 10);
    }
    await _box.put(_keyRecentlyUsed, _recentlyUsed);
    notifyListeners();
  }

  Future<void> applyIcon(String iconId) async {
    if (iconId == _selectedIconId) return;

    final oldId = _selectedIconId;

    if (_isIOS) {
      final isSupported = await FlutterDynamicIconPlus.supportsAlternateIcons;
      if (!isSupported) {
        throw Exception("Alternate icons not supported on this device.");
      }
      final nameToSet = iconId == 'default' ? null : iconId;
      await FlutterDynamicIconPlus.setAlternateIconName(iconName: nameToSet);
    }

    _selectedIconId = iconId;
    await _box.put(_keySelectedIcon, iconId);

    // Save to recently used queue
    await addToRecentlyUsed(iconId);

    if (kDebugMode) {
      print("App Icon Changed:\nOld: $oldId\nNew: $iconId\nTime: ${DateTime.now()}");
    }

    notifyListeners();
  }
}
