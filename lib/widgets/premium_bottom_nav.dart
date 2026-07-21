import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import '../../services/haptic_service.dart';

/// iOS 26-style Liquid Glass floating tab bar.
/// Frosted translucent pill floating above content with a
/// sliding glass capsule indicator on the selected tab.
class PremiumBottomNav extends StatefulWidget {
  final int selectedIndex;
  final Function(int) onItemSelected;
  final ScrollController? scrollController;

  const PremiumBottomNav({
    super.key,
    required this.selectedIndex,
    required this.onItemSelected,
    this.scrollController,
  });

  @override
  State<PremiumBottomNav> createState() => _PremiumBottomNavState();
}

class _PremiumBottomNavState extends State<PremiumBottomNav>
    with SingleTickerProviderStateMixin {
  final HapticService _hapticService = HapticService();
  late AnimationController _scaleController;
  bool _isCompact = false;

  // Tab definitions — icons only, matching the app's 5 sections
  static const List<_NavTab> _tabs = [
    _NavTab(index: 0, activeIcon: Icons.home_rounded, inactiveIcon: Icons.home_outlined),
    _NavTab(index: 1, activeIcon: Icons.check_circle_rounded, inactiveIcon: Icons.check_circle_outline),
    _NavTab(index: 2, activeIcon: Icons.add_circle_rounded, inactiveIcon: Icons.add_circle_outline),
    _NavTab(index: 3, activeIcon: Icons.emoji_events_rounded, inactiveIcon: Icons.emoji_events_outlined),
    _NavTab(index: 4, activeIcon: Icons.settings_rounded, inactiveIcon: Icons.settings_outlined),
  ];

  @override
  void initState() {
    super.initState();
    _scaleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
      lowerBound: 0.0,
      upperBound: 1.0,
      value: 0.0,
    );
    widget.scrollController?.addListener(_onScroll);
  }

  @override
  void dispose() {
    widget.scrollController?.removeListener(_onScroll);
    _scaleController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (widget.scrollController == null) return;
    final dir = widget.scrollController!.position.userScrollDirection;
    if (dir == ScrollDirection.reverse && !_isCompact) {
      _isCompact = true;
      _scaleController.forward();
    } else if (dir == ScrollDirection.forward && _isCompact) {
      _isCompact = false;
      _scaleController.reverse();
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _scaleController,
      builder: (context, _) {
        // Shrink padding smoothly on scroll
        final hPad = lerpDouble(24, 48, _scaleController.value)!;
        final vPad = lerpDouble(12, 8, _scaleController.value)!;
        final innerVPad = lerpDouble(8, 5, _scaleController.value)!;
        final iconSz = lerpDouble(26, 22, _scaleController.value)!;
        final barRadius = lerpDouble(28, 22, _scaleController.value)!;

        return SafeArea(
          top: false,
          child: Padding(
            padding: EdgeInsets.only(left: hPad, right: hPad, bottom: vPad),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(barRadius),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
                child: Container(
                  padding: EdgeInsets.symmetric(vertical: innerVPad, horizontal: 6),
                  decoration: BoxDecoration(
                    // Semi-transparent glass tint
                    color: Colors.white.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(barRadius),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.25),
                      width: 0.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.15),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: _tabs.map((tab) {
                      return _buildTab(tab, iconSz, barRadius);
                    }).toList(),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildTab(_NavTab tab, double iconSize, double barRadius) {
    final isSelected = widget.selectedIndex == tab.index;

    return GestureDetector(
      onTap: () {
        if (widget.selectedIndex != tab.index) {
          _hapticService.selectionClick();
        }
        widget.onItemSelected(tab.index);
      },
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutCubic,
        padding: EdgeInsets.symmetric(
          horizontal: isSelected ? 18 : 14,
          vertical: isSelected ? 10 : 8,
        ),
        decoration: BoxDecoration(
          // The selected tab gets a brighter frosted capsule
          color: isSelected
              ? Colors.white.withOpacity(0.22)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(barRadius - 4),
          border: isSelected
              ? Border.all(color: Colors.white.withOpacity(0.3), width: 0.5)
              : null,
        ),
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          transitionBuilder: (child, anim) =>
              ScaleTransition(scale: anim, child: child),
          child: Icon(
            isSelected ? tab.activeIcon : tab.inactiveIcon,
            key: ValueKey<bool>(isSelected),
            color: isSelected ? Colors.white : Colors.white.withOpacity(0.55),
            size: iconSize,
          ),
        ),
      ),
    );
  }
}

class _NavTab {
  final int index;
  final IconData activeIcon;
  final IconData inactiveIcon;

  const _NavTab({
    required this.index,
    required this.activeIcon,
    required this.inactiveIcon,
  });
}
