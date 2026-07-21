import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import '../../services/haptic_service.dart';

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

class _PremiumBottomNavState extends State<PremiumBottomNav> with SingleTickerProviderStateMixin {
  late AnimationController _shrinkController;
  final HapticService _hapticService = HapticService();
  bool _isCompact = false;

  @override
  void initState() {
    super.initState();
    _shrinkController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
      value: 0.0, // 0 = full size, 1 = compact
    );
    widget.scrollController?.addListener(_scrollListener);
  }

  @override
  void dispose() {
    widget.scrollController?.removeListener(_scrollListener);
    _shrinkController.dispose();
    super.dispose();
  }

  void _scrollListener() {
    if (widget.scrollController == null) return;

    if (widget.scrollController!.position.userScrollDirection == ScrollDirection.reverse) {
      // Scrolling up (content moves up) -> shrink
      if (!_isCompact) {
        _isCompact = true;
        _shrinkController.forward();
      }
    } else if (widget.scrollController!.position.userScrollDirection == ScrollDirection.forward) {
      // Scrolling down (content moves down) -> expand
      if (_isCompact) {
        _isCompact = false;
        _shrinkController.reverse();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _shrinkController,
      builder: (context, child) {
        // Interpolate padding: full = 14, compact = 8
        final verticalPadding = lerpDouble(14, 8, _shrinkController.value)!;
        final iconSize = lerpDouble(26, 22, _shrinkController.value)!;
        final bottomMargin = lerpDouble(0, 0, _shrinkController.value)!;

        return Container(
          margin: EdgeInsets.only(bottom: bottomMargin),
          decoration: const BoxDecoration(
            color: Color(0xFF111111),
            border: Border(
              top: BorderSide(color: Colors.white12, width: 0.5),
            ),
          ),
          child: SafeArea(
            top: false,
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: verticalPadding),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildNavIcon(0, Icons.home_rounded, Icons.home_outlined, iconSize),
                  _buildNavIcon(1, Icons.check_circle_rounded, Icons.check_circle_outline_rounded, iconSize),
                  _buildCenterButton(iconSize),
                  _buildNavIcon(3, Icons.emoji_events_rounded, Icons.emoji_events_outlined, iconSize),
                  _buildNavIcon(4, Icons.settings_rounded, Icons.settings_outlined, iconSize),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildNavIcon(int index, IconData activeIcon, IconData inactiveIcon, double size) {
    final isSelected = widget.selectedIndex == index;

    return GestureDetector(
      onTap: () {
        if (widget.selectedIndex != index) {
          _hapticService.selectionClick();
          widget.onItemSelected(index);
        }
      },
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 52,
        height: 40,
        child: Center(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            transitionBuilder: (child, animation) =>
                ScaleTransition(scale: animation, child: child),
            child: Icon(
              isSelected ? activeIcon : inactiveIcon,
              key: ValueKey<bool>(isSelected),
              color: isSelected ? Colors.white : Colors.white54,
              size: size,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCenterButton(double size) {
    return GestureDetector(
      onTap: () {
        _hapticService.selectionClick();
        widget.onItemSelected(2);
      },
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 52,
        height: 40,
        child: Center(
          child: Icon(
            Icons.add_box_outlined,
            color: Colors.white54,
            size: size,
          ),
        ),
      ),
    );
  }
}
