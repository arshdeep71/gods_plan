import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/app_icon_model.dart';

class IconPreviewDialog extends StatefulWidget {
  final AppIconModel icon;
  final bool isActive;
  final Future<void> Function() onApply;

  const IconPreviewDialog({
    super.key,
    required this.icon,
    required this.isActive,
    required this.onApply,
  });

  @override
  State<IconPreviewDialog> createState() => _IconPreviewDialogState();
}

class _IconPreviewDialogState extends State<IconPreviewDialog> with SingleTickerProviderStateMixin {
  bool _isApplying = false;
  bool _isSuccess = false;
  String? _errorMessage;

  late AnimationController _checkController;
  late Animation<double> _checkAnimation;

  @override
  void initState() {
    super.initState();
    _checkController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _checkAnimation = CurvedAnimation(
      parent: _checkController,
      curve: Curves.elasticOut,
    );
  }

  @override
  void dispose() {
    _checkController.dispose();
    super.dispose();
  }

  Future<void> _handleApply() async {
    if (_isApplying || widget.isActive) return;

    setState(() {
      _isApplying = true;
      _errorMessage = null;
    });

    try {
      await widget.onApply();
      
      // Animate success checkmark
      setState(() {
        _isApplying = false;
        _isSuccess = true;
      });
      HapticFeedback.heavyImpact();
      await _checkController.forward();
      
      // Wait to let user appreciate the animation
      await Future.delayed(const Duration(milliseconds: 1800));
      
      if (mounted) {
        Navigator.of(context).pop(true); // Return true for success
      }
    } catch (e) {
      setState(() {
        _isApplying = false;
        _errorMessage = e.toString().replaceFirst('Exception: ', '');
      });
      HapticFeedback.error();
    }
  }

  @override
  Widget build(BuildContext context) {
    const bgColor = Color(0xFF151517);
    const surfaceColor = Color(0xFF1C1C1E);
    const borderColor = Color(0xFF2C2C2E);
    const accentColor = Color(0xFFFFD60A); // Gold/yellow selection
    const successColor = Color(0xFF34C759); // Apple Green

    return Container(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 16,
        bottom: 24 + MediaQuery.of(context).viewInsets.bottom,
      ),
      decoration: const BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Drag handle indicator
          Center(
            child: Container(
              width: 40,
              height: 5,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2.5),
              ),
            ),
          ),
          const SizedBox(height: 24),

          if (!_isSuccess) ...[
            // Icon Info & Hero
            Center(
              child: Container(
                width: 160,
                height: 160,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(36),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.5),
                      blurRadius: 24,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(36),
                  child: Hero(
                    tag: 'icon_preview_${widget.icon.id}',
                    child: Image.asset(
                      widget.icon.assetPath,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          color: Colors.grey[900],
                          child: const Icon(
                            Icons.broken_image_rounded,
                            color: Colors.white38,
                            size: 48,
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Metadata info
            Text(
              widget.icon.name,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),

            Text(
              "${widget.icon.category ?? 'General'} • By ${widget.icon.author ?? 'System'}",
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white38,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
            
            if (widget.icon.tags.isNotEmpty) ...[
              const SizedBox(height: 12),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 6,
                runSpacing: 6,
                children: widget.icon.tags.map((tag) => Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: surfaceColor,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: borderColor),
                  ),
                  child: Text(
                    "#$tag",
                    style: const TextStyle(
                      color: Colors.white54,
                      fontSize: 11,
                    ),
                  ),
                )).toList(),
              ),
            ],

            const SizedBox(height: 32),

            if (_errorMessage != null) ...[
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.redAccent,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Action Buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: const BorderSide(color: borderColor),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    onPressed: _isApplying ? null : () => Navigator.of(context).pop(),
                    child: const Text(
                      "Cancel",
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: widget.isActive ? surfaceColor : accentColor,
                      foregroundColor: widget.isActive ? Colors.white30 : Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      disabledBackgroundColor: surfaceColor,
                    ),
                    onPressed: (_isApplying || widget.isActive) ? null : _handleApply,
                    child: _isApplying
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.black),
                            ),
                          )
                        : Text(
                            widget.isActive ? "Currently Active" : "Apply Icon",
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: widget.isActive ? Colors.white38 : Colors.black,
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ] else ...[
            // Success animation
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 40.0),
              child: ScaleTransition(
                scale: _checkAnimation,
                child: Column(
                  children: [
                    Container(
                      width: 80,
                      height: 80,
                      decoration: const BoxDecoration(
                        color: successColor,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.check_rounded,
                        color: Colors.black,
                        size: 48,
                      ),
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      "Icon Applied",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      "Home Screen Updated",
                      style: TextStyle(
                        color: Colors.white54,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
