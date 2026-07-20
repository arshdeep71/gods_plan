import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../models/app_icon_model.dart';
import '../../services/app_icon_service.dart';
import '../../widgets/app_icon_tile.dart';
import '../../widgets/current_icon_card.dart';
import '../../widgets/icon_preview_dialog.dart';

// ─── Sort Options ──────────────────────────────────────────────────────────────

enum IconSortOption {
  alphabetical,
  newest,
  favorites,
  recentlyUsed,
}

// ─── Screen ──────────────────────────────────────────────────────────────────

class AppIconView extends StatefulWidget {
  const AppIconView({super.key});

  @override
  State<AppIconView> createState() => _AppIconViewState();
}

class _AppIconViewState extends State<AppIconView> with TickerProviderStateMixin {
  static const _bgColor = Color(0xFF0D0D0F);
  static const _surfaceColor = Color(0xFF1C1C1E);
  static const _borderColor = Color(0xFF2C2C2E);
  static const _accentColor = Color(0xFFFFD60A);
  static const _textSecondary = Color(0xFF8E8E93);

  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  String _searchQuery = '';
  String? _selectedCategory;
  IconSortOption _sortOption = IconSortOption.alphabetical;
  bool _isChangingIcon = false;

  late AnimationController _warningAnimCtrl;
  late Animation<double> _warningAnim;

  bool get _isIOS => !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;

  @override
  void initState() {
    super.initState();

    _warningAnimCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _warningAnim = CurvedAnimation(parent: _warningAnimCtrl, curve: Curves.easeOut);

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final service = context.read<AppIconService>();
      if (!service.isInitialized) {
        await service.initialize();
      }
      if (service.showWarningFlag && mounted) {
        _warningAnimCtrl.forward();
        service.clearWarningFlag();
      }
    });

    _searchController.addListener(() {
      setState(() => _searchQuery = _searchController.text.trim().toLowerCase());
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    _warningAnimCtrl.dispose();
    super.dispose();
  }

  // ── Filtering & Sorting ──────────────────────────────────────────────────

  List<AppIconModel> _applyFilters(AppIconService service) {
    List<AppIconModel> icons = List.from(service.icons);

    // Search filter
    if (_searchQuery.isNotEmpty) {
      icons = icons.where((icon) {
        final q = _searchQuery;
        return icon.name.toLowerCase().contains(q) ||
            (icon.category?.toLowerCase().contains(q) ?? false) ||
            (icon.author?.toLowerCase().contains(q) ?? false) ||
            icon.tags.any((t) => t.toLowerCase().contains(q)) ||
            icon.id.toLowerCase().contains(q);
      }).toList();
    }

    // Category filter
    if (_selectedCategory != null) {
      icons = icons.where((icon) => icon.category == _selectedCategory).toList();
    }

    // Sort
    switch (_sortOption) {
      case IconSortOption.alphabetical:
        icons.sort((a, b) {
          if (a.id == 'default') return -1;
          if (b.id == 'default') return 1;
          return a.name.compareTo(b.name);
        });
        break;
      case IconSortOption.newest:
        icons.sort((a, b) {
          if (a.id == 'default') return -1;
          if (b.id == 'default') return 1;
          return b.addedAt.compareTo(a.addedAt);
        });
        break;
      case IconSortOption.favorites:
        icons.sort((a, b) {
          if (a.id == 'default') return -1;
          if (b.id == 'default') return 1;
          if (a.favorite == b.favorite) return a.name.compareTo(b.name);
          return a.favorite ? -1 : 1;
        });
        break;
      case IconSortOption.recentlyUsed:
        final recentOrder = service.recentlyUsed;
        icons.sort((a, b) {
          if (a.id == 'default') return -1;
          if (b.id == 'default') return 1;
          final ai = recentOrder.indexOf(a.id);
          final bi = recentOrder.indexOf(b.id);
          if (ai == -1 && bi == -1) return a.name.compareTo(b.name);
          if (ai == -1) return 1;
          if (bi == -1) return -1;
          return ai.compareTo(bi);
        });
        break;
    }

    return icons;
  }

  List<String> _getCategories(AppIconService service) {
    final cats = service.icons
        .map((e) => e.category ?? 'General')
        .toSet()
        .toList()
      ..sort();
    return cats;
  }

  // ── Icon Apply ────────────────────────────────────────────────────────────

  Future<void> _showPreview(AppIconModel icon, AppIconService service) async {
    if (_isChangingIcon) return;

    final isActive = service.selectedIconId == icon.id;

    await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => IconPreviewDialog(
        icon: icon,
        isActive: isActive,
        onApply: () async {
          setState(() => _isChangingIcon = true);
          try {
            await service.applyIcon(icon.id);
          } finally {
            if (mounted) setState(() => _isChangingIcon = false);
          }
        },
      ),
    );
  }

  // ── UI Helpers ────────────────────────────────────────────────────────────

  String _sortLabel(IconSortOption opt) {
    switch (opt) {
      case IconSortOption.alphabetical: return 'A → Z';
      case IconSortOption.newest: return 'Newest';
      case IconSortOption.favorites: return 'Favorites';
      case IconSortOption.recentlyUsed: return 'Recent';
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: _bgColor,
        body: Consumer<AppIconService>(
          builder: (context, service, _) {
            if (!service.isInitialized) {
              return const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(
                      color: _accentColor,
                      strokeWidth: 2.5,
                    ),
                    SizedBox(height: 16),
                    Text(
                      'Loading icons...',
                      style: TextStyle(color: Colors.white54, fontSize: 14),
                    ),
                  ],
                ),
              );
            }

            final allFiltered = _applyFilters(service);
            final categories = _getCategories(service);
            final selectedIcon = service.icons.isEmpty
                ? null
                : service.icons.firstWhere(
                    (i) => i.id == service.selectedIconId,
                    orElse: () => service.icons.first,
                  );

            // Build recently-used and favorites subsets for section headers
            final recentIds = service.recentlyUsed;
            final recentIcons = recentIds
                .map((id) => service.icons.where((i) => i.id == id).firstOrNull)
                .whereType<AppIconModel>()
                .toList();

            final favoriteIcons = service.icons.where((i) => i.favorite).toList();

            return CustomScrollView(
              controller: _scrollController,
              physics: const BouncingScrollPhysics(),
              slivers: [
                // ── App Bar ────────────────────────────────────────────────
                SliverAppBar(
                  backgroundColor: Colors.transparent,
                  surfaceTintColor: Colors.transparent,
                  expandedHeight: 0,
                  floating: true,
                  pinned: true,
                  flexibleSpace: ClipRect(
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                      child: Container(
                        color: _bgColor.withOpacity(0.7),
                      ),
                    ),
                  ),
                  leading: IconButton(
                    icon: const Icon(Icons.arrow_back_ios_rounded, color: Colors.white, size: 20),
                    onPressed: () => Navigator.pop(context),
                  ),
                  title: const Text(
                    'App Icon',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                  centerTitle: true,
                  actions: [
                    // Sort menu
                    PopupMenuButton<IconSortOption>(
                      color: _surfaceColor,
                      icon: const Icon(Icons.sort_rounded, color: Colors.white),
                      onSelected: (opt) => setState(() => _sortOption = opt),
                      itemBuilder: (_) => IconSortOption.values.map((opt) {
                        return PopupMenuItem<IconSortOption>(
                          value: opt,
                          child: Row(
                            children: [
                              if (_sortOption == opt)
                                const Icon(Icons.check_rounded, color: _accentColor, size: 16)
                              else
                                const SizedBox(width: 16),
                              const SizedBox(width: 10),
                              Text(
                                _sortLabel(opt),
                                style: TextStyle(
                                  color: _sortOption == opt ? _accentColor : Colors.white,
                                  fontWeight: _sortOption == opt ? FontWeight.bold : FontWeight.normal,
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),

                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // ── Removed Icon Warning Banner ───────────────────
                        SizeTransition(
                          sizeFactor: _warningAnim,
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 16),
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: Colors.orange.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: Colors.orange.withOpacity(0.3)),
                            ),
                            child: const Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(Icons.info_outline_rounded, color: Colors.orange, size: 20),
                                SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    'Your previously selected app icon is no longer available, so the default icon has been restored.',
                                    style: TextStyle(
                                      color: Colors.orange,
                                      fontSize: 13,
                                      height: 1.4,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                        // ── iOS-only notice ───────────────────────────────
                        if (!_isIOS)
                          Container(
                            margin: const EdgeInsets.only(bottom: 16),
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: _surfaceColor,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: _borderColor),
                            ),
                            child: const Row(
                              children: [
                                Icon(Icons.phone_iphone_rounded, color: Colors.white54, size: 20),
                                SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    'App icon switching is only available on iOS. You can browse and preview icons here.',
                                    style: TextStyle(color: Colors.white54, fontSize: 13, height: 1.4),
                                  ),
                                ),
                              ],
                            ),
                          ),

                        // ── Current Icon Card ─────────────────────────────
                        if (selectedIcon != null)
                          CurrentIconCard(currentIcon: selectedIcon),

                        const SizedBox(height: 20),

                        // ── Search Box ────────────────────────────────────
                        Container(
                          decoration: BoxDecoration(
                            color: _surfaceColor,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: _borderColor),
                          ),
                          child: TextField(
                            controller: _searchController,
                            style: const TextStyle(color: Colors.white, fontSize: 15),
                            cursorColor: _accentColor,
                            decoration: InputDecoration(
                              hintText: 'Search icons...',
                              hintStyle: const TextStyle(color: Colors.white38),
                              prefixIcon: const Icon(Icons.search_rounded, color: Colors.white38, size: 20),
                              suffixIcon: _searchQuery.isNotEmpty
                                  ? IconButton(
                                      icon: const Icon(Icons.close_rounded, color: Colors.white38, size: 18),
                                      onPressed: () {
                                        _searchController.clear();
                                        setState(() => _searchQuery = '');
                                      },
                                    )
                                  : null,
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 0, vertical: 14),
                            ),
                          ),
                        ),

                        const SizedBox(height: 14),

                        // ── Category Pills ────────────────────────────────
                        if (categories.length > 1)
                          SizedBox(
                            height: 36,
                            child: ListView.separated(
                              scrollDirection: Axis.horizontal,
                              itemCount: categories.length + 1, // +1 for "All"
                              separatorBuilder: (_, __) => const SizedBox(width: 8),
                              itemBuilder: (context, index) {
                                final isAll = index == 0;
                                final category = isAll ? null : categories[index - 1];
                                final label = isAll ? 'All' : category!;
                                final isSelected = _selectedCategory == category;

                                return GestureDetector(
                                  onTap: () => setState(() => _selectedCategory = category),
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 180),
                                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                                    decoration: BoxDecoration(
                                      color: isSelected ? _accentColor : _surfaceColor,
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(
                                        color: isSelected ? _accentColor : _borderColor,
                                      ),
                                    ),
                                    child: Text(
                                      label,
                                      style: TextStyle(
                                        color: isSelected ? Colors.black : Colors.white70,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),

                        const SizedBox(height: 8),
                      ],
                    ),
                  ),
                ),

                // ── Recently Used Section ─────────────────────────────────
                if (recentIcons.isNotEmpty && _searchQuery.isEmpty && _selectedCategory == null)
                  _buildSectionHeader('Recently Used', Icons.history_rounded),

                if (recentIcons.isNotEmpty && _searchQuery.isEmpty && _selectedCategory == null)
                  SliverToBoxAdapter(
                    child: SizedBox(
                      height: 180,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                        itemCount: recentIcons.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 10),
                        itemBuilder: (context, index) {
                          final icon = recentIcons[index];
                          final isSelected = service.selectedIconId == icon.id;
                          return SizedBox(
                            width: 140,
                            child: AppIconTile(
                              icon: icon,
                              isSelected: isSelected,
                              onTap: () => _showPreview(icon, service),
                              onFavoriteToggle: () => service.toggleFavorite(icon.id),
                            ),
                          );
                        },
                      ),
                    ),
                  ),

                // ── Favorites Section ────────────────────────────────────
                if (favoriteIcons.isNotEmpty && _searchQuery.isEmpty && _selectedCategory == null)
                  _buildSectionHeader('Favorites', Icons.favorite_rounded),

                if (favoriteIcons.isNotEmpty && _searchQuery.isEmpty && _selectedCategory == null)
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    sliver: SliverGrid(
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        crossAxisSpacing: 10,
                        mainAxisSpacing: 10,
                        childAspectRatio: 0.85,
                      ),
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final icon = favoriteIcons[index];
                          final isSelected = service.selectedIconId == icon.id;
                          return AppIconTile(
                            icon: icon,
                            isSelected: isSelected,
                            onTap: () => _showPreview(icon, service),
                            onFavoriteToggle: () => service.toggleFavorite(icon.id),
                          );
                        },
                        childCount: favoriteIcons.length,
                      ),
                    ),
                  ),

                // ── All Icons Section ─────────────────────────────────────
                _buildSectionHeader(
                  _searchQuery.isNotEmpty
                      ? 'Results (${allFiltered.length})'
                      : _selectedCategory != null
                          ? _selectedCategory!
                          : 'All Icons',
                  _searchQuery.isNotEmpty ? Icons.search_rounded : Icons.apps_rounded,
                ),

                if (allFiltered.isEmpty)
                  SliverToBoxAdapter(
                    child: _buildEmptyState(),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
                    sliver: SliverGrid(
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        crossAxisSpacing: 10,
                        mainAxisSpacing: 10,
                        childAspectRatio: 0.85,
                      ),
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final icon = allFiltered[index];
                          final isSelected = service.selectedIconId == icon.id;
                          return AppIconTile(
                            icon: icon,
                            isSelected: isSelected,
                            onTap: () => _showPreview(icon, service),
                            onFavoriteToggle: () => service.toggleFavorite(icon.id),
                          );
                        },
                        childCount: allFiltered.length,
                        // Only build what is visible, allowing Flutter to lazy-load
                        addAutomaticKeepAlives: false,
                        addRepaintBoundaries: true,
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 64, horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.image_search_rounded,
              size: 64,
              color: Colors.white24,
            ),
            const SizedBox(height: 16),
            Text(
              _searchQuery.isNotEmpty
                  ? 'No icons match "$_searchQuery"'
                  : 'No alternate icons found.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white54,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Add PNG icons (1024×1024) to the assets/alternate_icons/ folder and rebuild.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white38, fontSize: 13, height: 1.4),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String label, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 16, color: _textSecondary),
        const SizedBox(width: 6),
        Text(
          label.toUpperCase(),
          style: const TextStyle(
            color: _textSecondary,
            fontSize: 11,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.8,
          ),
        ),
      ],
    );
  }

  Widget _buildSectionTitleWidget(String label, IconData icon) => _buildSectionTitle(label, icon);

  SliverToBoxAdapter _buildSectionHeader(String label, IconData icon) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
        child: _buildSectionTitleWidget(label, icon),
      ),
    );
  }
}
