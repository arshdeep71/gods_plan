import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:path_provider/path_provider.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:uuid/uuid.dart';
import 'package:flutter_dynamic_icon_plus/flutter_dynamic_icon_plus.dart';

import '../../utils/colors.dart';

// ─── Model ───────────────────────────────────────────────────────────────────

class CustomIconMeta {
  final String id;
  String name;
  final String path;
  final String createdAt;
  bool favorite;

  CustomIconMeta({
    required this.id,
    required this.name,
    required this.path,
    required this.createdAt,
    this.favorite = false,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'path': path,
        'createdAt': createdAt,
        'favorite': favorite,
      };

  factory CustomIconMeta.fromMap(Map<String, dynamic> m) => CustomIconMeta(
        id: m['id'] as String,
        name: m['name'] as String,
        path: m['path'] as String,
        createdAt: m['createdAt'] as String,
        favorite: m['favorite'] as bool? ?? false,
      );
}

// ─── Bundled Icon Definition ─────────────────────────────────────────────────

class _BundledIcon {
  final String label;
  final String? iconName; // null = default system icon
  final String assetPath;

  const _BundledIcon({
    required this.label,
    required this.iconName,
    required this.assetPath,
  });
}

const List<_BundledIcon> _bundledIcons = [
  _BundledIcon(
    label: 'Default',
    iconName: null,
    assetPath: 'assets/alternate_icons/icon_default.png',
  ),
  _BundledIcon(
    label: 'Dark',
    iconName: 'icon_dark',
    assetPath: 'assets/alternate_icons/icon_dark.png',
  ),
];

// ─── Screen ──────────────────────────────────────────────────────────────────

class AppIconView extends StatefulWidget {
  const AppIconView({super.key});

  @override
  State<AppIconView> createState() => _AppIconViewState();
}

class _AppIconViewState extends State<AppIconView> {
  static const String _hiveCustomIconsKey = 'custom_icons';
  static const String _hiveSelectedIconKey = 'selected_icon';

  late Box _settingsBox;
  List<CustomIconMeta> _customIcons = [];
  String? _selectedIconName; // null = default
  bool _isSwitching = false;

  @override
  void initState() {
    super.initState();
    _settingsBox = Hive.box('settings_box');
    _loadState();
    _restoreIconOnStartup();
  }

  // ── Persistence ─────────────────────────────────────────────────────────

  void _loadState() {
    _selectedIconName = _settingsBox.get(_hiveSelectedIconKey) as String?;
    final raw = _settingsBox.get(_hiveCustomIconsKey) as String?;
    if (raw != null) {
      try {
        final list = jsonDecode(raw) as List<dynamic>;
        _customIcons =
            list.map((e) => CustomIconMeta.fromMap(Map<String, dynamic>.from(e as Map))).toList();
      } catch (_) {
        _customIcons = [];
      }
    }
  }

  Future<void> _saveCustomIcons() async {
    final encoded = jsonEncode(_customIcons.map((e) => e.toMap()).toList());
    await _settingsBox.put(_hiveCustomIconsKey, encoded);
  }

  // ── Startup Restore (refinement #11) ─────────────────────────────────────

  Future<void> _restoreIconOnStartup() async {
    if (!Platform.isIOS) return;
    try {
      final desired = _selectedIconName;
      final isSupported = await FlutterDynamicIconPlus.supportsAlternateIcons;
      if (!isSupported) return;

      // Only call setAlternateIconName if the desired icon is NOT already active.
      // We can't query the current icon on all versions, so we attempt a no-op
      // by setting the same name. If it throws, we catch silently.
      await FlutterDynamicIconPlus.setAlternateIconName(desired);
    } catch (_) {
      // Silently ignore – icon may already be set or unsupported on simulator
    }
  }

  // ── Switch Bundled Icon ──────────────────────────────────────────────────

  Future<void> _switchBundledIcon(String? iconName) async {
    if (_isSwitching) return;
    if (_selectedIconName == iconName) return; // Already selected, skip call

    if (!Platform.isIOS) {
      _showSnack('Icon switching is only supported on iOS.');
      return;
    }

    setState(() => _isSwitching = true);

    try {
      final isSupported = await FlutterDynamicIconPlus.supportsAlternateIcons;
      if (!isSupported) {
        _showSnack('Alternate icons are not supported on this device.');
        return;
      }

      await FlutterDynamicIconPlus.setAlternateIconName(iconName);
      await _settingsBox.put(_hiveSelectedIconKey, iconName);

      if (mounted) {
        setState(() => _selectedIconName = iconName);
        _showSnack(iconName == null
            ? 'Restored default app icon.'
            : 'App icon switched to ${_bundledIcons.firstWhere((b) => b.iconName == iconName).label}.');
      }
    } catch (e) {
      _showSnack('Failed to change app icon. Error: $e');
    } finally {
      if (mounted) setState(() => _isSwitching = false);
    }
  }

  // ── Import Flow ──────────────────────────────────────────────────────────

  Future<void> _importNewIcon() async {
    try {
      final picker = ImagePicker();
      final XFile? picked =
          await picker.pickImage(source: ImageSource.gallery, imageQuality: 100);
      if (picked == null) return; // Cancelled

      // Validate resolution
      final bytes = await picked.readAsBytes();
      final image = await decodeImageFromList(bytes);
      if (image.width < 512 || image.height < 512) {
        _showSnack(
            'Image resolution too small. Choose a higher quality image (recommended: 1024×1024).');
        return;
      }

      // Crop 1:1
      final cropped = await ImageCropper().cropImage(
        sourcePath: picked.path,
        aspectRatio: const CropAspectRatio(ratioX: 1, ratioY: 1),
        aspectRatioPresets: [CropAspectRatioPreset.square],
        uiSettings: [
          IOSUiSettings(
            title: 'Crop Icon',
            aspectRatioLockEnabled: true,
            resetAspectRatioEnabled: false,
            aspectRatioPickerButtonHidden: true,
            rotateButtonsHidden: false,
            doneButtonTitle: 'Save',
            cancelButtonTitle: 'Cancel',
          ),
          AndroidUiSettings(
            toolbarTitle: 'Crop Icon',
            lockAspectRatio: true,
            hideBottomControls: true,
            initAspectRatio: CropAspectRatioPreset.square,
          ),
        ],
      );

      if (cropped == null) return; // User cancelled crop

      await _saveCroppedIcon(cropped.path);
    } on Exception catch (e) {
      _showSnack('Import failed: $e');
    }
  }

  Future<void> _saveCroppedIcon(String croppedPath) async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final iconsDir = Directory('${dir.path}/app_icons');
      if (!iconsDir.existsSync()) iconsDir.createSync(recursive: true);

      // Generate sequential filename
      final count = _customIcons.length + 1;
      final filename =
          'icon_${count.toString().padLeft(3, '0')}.png';
      final destPath = '${iconsDir.path}/$filename';

      // Read cropped file, re-encode as PNG 1024×1024
      final rawBytes = await File(croppedPath).readAsBytes();
      final src = await decodeImageFromList(rawBytes);

      // Resize to 1024×1024 using Flutter's codec
      final recorder = PictureRecorder();
      final canvas = Canvas(recorder,
          Rect.fromLTWH(0, 0, 1024, 1024));
      final paint = Paint()..filterQuality = FilterQuality.high;
      canvas.drawImageRect(
        src,
        Rect.fromLTWH(0, 0, src.width.toDouble(), src.height.toDouble()),
        const Rect.fromLTWH(0, 0, 1024, 1024),
        paint,
      );
      final picture = recorder.endRecording();
      final img = await picture.toImage(1024, 1024);
      final pngBytes = await img.toByteData(format: ImageByteFormat.png);
      if (pngBytes == null) throw Exception('Failed to encode PNG');

      await File(destPath).writeAsBytes(pngBytes.buffer.asUint8List());

      final meta = CustomIconMeta(
        id: const Uuid().v4(),
        name: 'My Icon $count',
        path: destPath,
        createdAt: DateTime.now().toIso8601String(),
        favorite: false,
      );

      setState(() => _customIcons.add(meta));
      await _saveCustomIcons();
      _showSnack('Icon saved successfully.');
    } catch (e) {
      _showSnack('Failed to save icon: $e');
    }
  }

  // ── Delete ───────────────────────────────────────────────────────────────

  Future<void> _deleteIcon(CustomIconMeta meta) async {
    try {
      final file = File(meta.path);
      if (file.existsSync()) file.deleteSync();
    } catch (_) {}
    setState(() => _customIcons.removeWhere((e) => e.id == meta.id));
    await _saveCustomIcons();
    _showSnack('Icon deleted.');
  }

  // ── Rename ───────────────────────────────────────────────────────────────

  Future<void> _renameIcon(CustomIconMeta meta) async {
    final controller = TextEditingController(text: meta.name);
    final newName = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1C1C1E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Rename Icon',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: 'Icon name',
            hintStyle: const TextStyle(color: Colors.white38),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.border)),
            focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.accent)),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel',
                  style: TextStyle(color: AppColors.textSecondary))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.accent,
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text('Save',
                style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (newName != null && newName.isNotEmpty) {
      setState(() => meta.name = newName);
      await _saveCustomIcons();
    }
  }

  // ── Preview Dialog ────────────────────────────────────────────────────────

  void _showPreviewDialog(CustomIconMeta meta) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1C1C1E),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Drag handle
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2)),
            ),
            // Preview image
            ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: Image.file(
                File(meta.path),
                width: 180,
                height: 180,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  width: 180,
                  height: 180,
                  color: AppColors.surface,
                  child: const Icon(Icons.broken_image_rounded,
                      color: AppColors.textMuted, size: 48),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              meta.name,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            const Divider(color: Colors.white12),
            const SizedBox(height: 12),
            // Actions row
            Row(
              children: [
                Expanded(
                  child: _actionButton(
                    icon: Icons.edit_rounded,
                    label: 'Rename',
                    color: Colors.blueAccent,
                    onTap: () {
                      Navigator.pop(ctx);
                      _renameIcon(meta);
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _actionButton(
                    icon: Icons.delete_rounded,
                    label: 'Delete',
                    color: AppColors.error,
                    onTap: () {
                      Navigator.pop(ctx);
                      _deleteIcon(meta);
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            const Divider(color: Colors.white12),
            const SizedBox(height: 16),
            // iOS limitation section
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.04),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: const [
                      Icon(Icons.home_rounded,
                          color: AppColors.textSecondary, size: 18),
                      SizedBox(width: 8),
                      Text(
                        'Home Screen Icon',
                        style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 14),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.error.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      'Unavailable',
                      style: TextStyle(
                          color: AppColors.error,
                          fontSize: 11,
                          fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Custom images are saved locally. Only bundled app icons can be applied to the iPhone Home Screen because of iOS restrictions.',
                    style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                        height: 1.5),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _actionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: color.withOpacity(0.12),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withOpacity(0.25)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 6),
            Text(label,
                style: TextStyle(
                    color: color, fontSize: 12, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  // ── Snack ─────────────────────────────────────────────────────────────────

  void _showSnack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: const TextStyle(color: Colors.white)),
      backgroundColor: const Color(0xFF2C2C2E),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      duration: const Duration(seconds: 3),
    ));
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'App Icon',
          style: TextStyle(
              color: AppColors.textPrimary, fontWeight: FontWeight.bold),
        ),
      ),
      body: ListView(
        padding:
            const EdgeInsets.only(left: 20, right: 20, top: 8, bottom: 48),
        children: [
          // ── Import Button ─────────────────────────────────────────────────
          _buildImportButton(),
          const SizedBox(height: 28),

          // ── Current Icon ──────────────────────────────────────────────────
          _sectionLabel('Current Icon'),
          const SizedBox(height: 12),
          _buildCurrentIconCard(),
          const SizedBox(height: 28),

          // ── Bundled Icons ─────────────────────────────────────────────────
          _sectionLabel('Bundled Icons'),
          const SizedBox(height: 12),
          _buildBundledIconsGrid(),
          const SizedBox(height: 28),

          // ── My Icons ──────────────────────────────────────────────────────
          _sectionLabel('My Icons'),
          const SizedBox(height: 4),
          const Text(
            'Saved locally for reference only.',
            style: TextStyle(
                color: AppColors.textMuted, fontSize: 12, height: 1.4),
          ),
          const SizedBox(height: 12),
          _buildCustomIconsGrid(),
        ],
      ),
    );
  }

  // ── Section Label ─────────────────────────────────────────────────────────

  Widget _sectionLabel(String text) => Text(
        text.toUpperCase(),
        style: const TextStyle(
          color: AppColors.textSecondary,
          fontSize: 12,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.8,
        ),
      );

  // ── Import Button ─────────────────────────────────────────────────────────

  Widget _buildImportButton() {
    return InkWell(
      onTap: _importNewIcon,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding:
            const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              AppColors.accent.withOpacity(0.15),
              AppColors.primary.withOpacity(0.10),
            ],
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.accent.withOpacity(0.35)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            Icon(Icons.add_photo_alternate_rounded,
                color: AppColors.accent, size: 22),
            SizedBox(width: 10),
            Text(
              'Import New Icon',
              style: TextStyle(
                  color: AppColors.accent,
                  fontWeight: FontWeight.bold,
                  fontSize: 15),
            ),
          ],
        ),
      ),
    );
  }

  // ── Current Icon Card ─────────────────────────────────────────────────────

  Widget _buildCurrentIconCard() {
    final current = _bundledIcons.firstWhere(
      (b) => b.iconName == _selectedIconName,
      orElse: () => _bundledIcons.first,
    );

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.accent.withOpacity(0.4), width: 1.5),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Image.asset(
              current.assetPath,
              width: 72,
              height: 72,
              fit: BoxFit.cover,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  current.label,
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16),
                ),
                const SizedBox(height: 4),
                const Text('Active',
                    style: TextStyle(
                        color: AppColors.accent,
                        fontSize: 12,
                        fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: AppColors.accent.withOpacity(0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.check_rounded,
                color: AppColors.accent, size: 18),
          ),
        ],
      ),
    );
  }

  // ── Bundled Icons Grid ────────────────────────────────────────────────────

  Widget _buildBundledIconsGrid() {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _bundledIcons.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 0.82,
      ),
      itemBuilder: (_, i) {
        final icon = _bundledIcons[i];
        final isSelected = _selectedIconName == icon.iconName;
        return GestureDetector(
          onTap: () => _switchBundledIcon(icon.iconName),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color:
                    isSelected ? AppColors.accent : AppColors.border,
                width: isSelected ? 2.5 : 1,
              ),
              color: isSelected
                  ? AppColors.accent.withOpacity(0.08)
                  : AppColors.surface,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Stack(
                  alignment: Alignment.topRight,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: Image.asset(
                        icon.assetPath,
                        width: 64,
                        height: 64,
                        fit: BoxFit.cover,
                      ),
                    ),
                    if (isSelected)
                      Container(
                        padding: const EdgeInsets.all(3),
                        decoration: const BoxDecoration(
                            color: AppColors.accent,
                            shape: BoxShape.circle),
                        child: const Icon(Icons.check_rounded,
                            color: Colors.black, size: 10),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  icon.label,
                  style: TextStyle(
                    color: isSelected
                        ? AppColors.accent
                        : AppColors.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ── Custom Icons Grid ─────────────────────────────────────────────────────

  Widget _buildCustomIconsGrid() {
    if (_customIcons.isEmpty) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 32),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        child: const Column(
          children: [
            Icon(Icons.image_outlined,
                color: AppColors.textMuted, size: 40),
            SizedBox(height: 12),
            Text(
              'No custom icons yet.',
              style: TextStyle(
                  color: AppColors.textMuted, fontSize: 13),
            ),
            SizedBox(height: 4),
            Text(
              'Tap "Import New Icon" above to add one.',
              style: TextStyle(
                  color: AppColors.textMuted, fontSize: 12),
            ),
          ],
        ),
      );
    }

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _customIcons.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 0.82,
      ),
      itemBuilder: (_, i) {
        final meta = _customIcons[i];
        return GestureDetector(
          onTap: () => _showPreviewDialog(meta),
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: Image.file(
                    File(meta.path),
                    width: 64,
                    height: 64,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      width: 64,
                      height: 64,
                      color: AppColors.background,
                      child: const Icon(Icons.broken_image_rounded,
                          color: AppColors.textMuted, size: 28),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: Text(
                    meta.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 11,
                        fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
