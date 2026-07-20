import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import '../../services/haptic_service.dart';

class PremiumBottomNav extends StatefulWidget {
  final int selectedIndex;
  final Function(int) onItemSelected;
  final ScrollController? scrollController; // To detect scroll direction for hiding

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
  late AnimationController _hideController;
  final HapticService _hapticService = HapticService();

  @override
  void initState() {
    super.initState();
    _hideController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
      value: 1.0, // 1.0 = fully visible
    );

    widget.scrollController?.addListener(_scrollListener);
  }

  @override
  void dispose() {
    widget.scrollController?.removeListener(_scrollListener);
    _hideController.dispose();
    super.dispose();
  }

  void _scrollListener() {
    if (widget.scrollController == null) return;
    
    if (widget.scrollController!.position.userScrollDirection == ScrollDirection.reverse) {
      if (_hideController.status != AnimationStatus.reverse) {
        _hideController.reverse(); // Hide
      }
    } else if (widget.scrollController!.position.userScrollDirection == ScrollDirection.forward) {
      if (_hideController.status != AnimationStatus.forward) {
        _hideController.forward(); // Show
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return SizeTransition(
      sizeFactor: _hideController,
      axisAlignment: -1.0,
      child: Container(
        margin: const EdgeInsets.only(left: 16, right: 16, bottom: 24),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFF161622).withOpacity(0.9), // AMOLED dark theme
          borderRadius: BorderRadius.circular(32),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.5),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
          border: Border.all(color: Colors.white12, width: 1),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _buildNavItem(0, Icons.home_rounded, Icons.home_outlined, 'Home'),
            _buildNavItem(1, Icons.track_changes_rounded, Icons.track_changes_outlined, 'Focus'),
            
            // Center Floating Action Button styling
            GestureDetector(
              onTap: () {
                _hapticService.selectionClick();
                // We'll pass an impossible index or a specific callback for the FAB
                widget.onItemSelected(2); 
              },
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Colors.blueAccent, Colors.purpleAccent],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.blueAccent.withOpacity(0.3),
                      blurRadius: 10,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: const Icon(Icons.add_rounded, color: Colors.white, size: 28),
              ),
            ),

            _buildNavItem(3, Icons.bar_chart_rounded, Icons.bar_chart_outlined, 'Stats'),
            _buildNavItem(4, Icons.person_rounded, Icons.person_outline, 'Profile'),
          ],
        ),
      ),
    );
  }

  Widget _buildNavItem(int index, IconData activeIcon, IconData inactiveIcon, String label) {
    final bool isSelected = widget.selectedIndex == index;

    return GestureDetector(
      onTap: () {
        if (widget.selectedIndex != index) {
          _hapticService.selectionClick(); // Native tactile feedback
          widget.onItemSelected(index);
        }
      },
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOutBack, // Fluid Spring Physics curve
        padding: EdgeInsets.symmetric(horizontal: isSelected ? 16 : 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white.withOpacity(0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          children: [
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              transitionBuilder: (child, animation) {
                return ScaleTransition(scale: animation, child: child);
              },
              child: Icon(
                isSelected ? activeIcon : inactiveIcon,
                key: ValueKey<bool>(isSelected),
                color: isSelected ? Colors.white : Colors.white54,
                size: 26,
              ),
            ),
            if (isSelected) ...[
              const SizedBox(width: 6),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
            ]
          ],
        ),
      ),
    );
  }
}
