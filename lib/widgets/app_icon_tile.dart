import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/app_icon_model.dart';

class AppIconTile extends StatelessWidget {
  final AppIconModel icon;
  final bool isSelected;
  final VoidCallback onTap;
  final VoidCallback onFavoriteToggle;

  const AppIconTile({
    super.key,
    required this.icon,
    required this.isSelected,
    required this.onTap,
    required this.onFavoriteToggle,
  });

  @override
  Widget build(BuildContext context) {
    // Theme colors fallback
    const surfaceColor = Color(0xFF1C1C1E);
    const borderColor = Color(0xFF2C2C2E);
    const accentColor = Color(0xFFFFD60A); // Gold/yellow selection/favorite color

    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
        decoration: BoxDecoration(
          color: surfaceColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? accentColor : borderColor,
            width: isSelected ? 2.0 : 1.0,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: accentColor.withOpacity(0.15),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: Stack(
            children: [
              // Main tile content
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Icon Image container
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      color: Colors.black.withOpacity(0.2),
                      child: Center(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: AspectRatio(
                            aspectRatio: 1,
                            child: Hero(
                              tag: 'icon_preview_${icon.id}',
                              child: Image.asset(
                                icon.thumbnailPath,
                                fit: BoxFit.cover,
                                cacheWidth: 150,
                                cacheHeight: 150,
                                errorBuilder: (context, error, stackTrace) {
                                  // Fallback to original full resolution image if thumbnail fails
                                  return Image.asset(
                                    icon.assetPath,
                                    fit: BoxFit.cover,
                                    cacheWidth: 150,
                                    cacheHeight: 150,
                                    errorBuilder: (context, err, st) {
                                      // Secondary fallback in case of missing asset
                                      return Container(
                                        color: Colors.grey[900],
                                        child: const Icon(
                                          Icons.broken_image_rounded,
                                          color: Colors.white54,
                                          size: 32,
                                        ),
                                      );
                                    },
                                  );
                                },
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  
                  // Label & Info
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          icon.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                icon.category ?? 'General',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white54,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                            if (isSelected)
                              const Icon(
                                Icons.check_circle_rounded,
                                color: accentColor,
                                size: 14,
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              // Favorite Heart Button Overlay
              Positioned(
                top: 4,
                right: 4,
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(20),
                    onTap: () {
                      HapticFeedback.mediumImpact();
                      onFavoriteToggle();
                    },
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      child: Icon(
                        icon.favorite ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                        color: icon.favorite ? Colors.redAccent : Colors.white38,
                        size: 18,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
