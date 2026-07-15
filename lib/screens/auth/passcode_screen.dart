import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../services/database_service.dart';
import '../../utils/colors.dart';

class PasscodeScreen extends StatefulWidget {
  final VoidCallback onUnlocked;

  const PasscodeScreen({super.key, required this.onUnlocked});

  @override
  State<PasscodeScreen> createState() => _PasscodeScreenState();
}

class _PasscodeScreenState extends State<PasscodeScreen> {
  final DatabaseService _dbService = DatabaseService();
  String _enteredPin = "";
  String _errorMessage = "";

  void _onKeyPress(String val) {
    if (_enteredPin.length >= 4) return;

    setState(() {
      _errorMessage = "";
      _enteredPin += val;
    });

    if (_enteredPin.length == 4) {
      _verifyPin();
    }
  }

  void _onBackspace() {
    if (_enteredPin.isEmpty) return;
    setState(() {
      _errorMessage = "";
      _enteredPin = _enteredPin.substring(0, _enteredPin.length - 1);
    });
  }

  void _onClear() {
    setState(() {
      _errorMessage = "";
      _enteredPin = "";
    });
  }

  void _verifyPin() {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    final savedPin = userId != null ? _dbService.settingsBox.get('app_lock_pin_$userId') as String? : null;
    if (savedPin == _enteredPin) {
      widget.onUnlocked();
    } else {
      setState(() {
        _enteredPin = "";
        _errorMessage = "Incorrect PIN. Try again.";
      });
    }
  }

  Widget _buildDot(int index) {
    bool isActive = _enteredPin.length > index;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 10),
      width: 16,
      height: 16,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isActive ? AppColors.accent : AppColors.border,
      ),
    );
  }

  Widget _buildKey(String value) {
    return InkWell(
      onTap: () => _onKeyPress(value),
      borderRadius: BorderRadius.circular(40),
      child: Container(
        width: 70,
        height: 70,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: AppColors.border),
        ),
        child: Text(
          value,
          style: const TextStyle(color: AppColors.textPrimary, fontSize: 24, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.lock_rounded, color: AppColors.accent, size: 64),
            const SizedBox(height: 24),
            const Text(
              "App Locked",
              style: TextStyle(color: AppColors.textPrimary, fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              "Enter your 4-digit PIN to access logs",
              style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
            ),
            const SizedBox(height: 36),

            // PIN Dots Indicator
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(4, (i) => _buildDot(i)),
            ),
            const SizedBox(height: 20),

            if (_errorMessage.isNotEmpty)
              Text(
                _errorMessage,
                style: const TextStyle(color: Colors.redAccent, fontSize: 13, fontWeight: FontWeight.bold),
              ),

            const SizedBox(height: 48),

            // Number Pad Grid
            Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: ["1", "2", "3"].map((k) => _buildKey(k)).toList(),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: ["4", "5", "6"].map((k) => _buildKey(k)).toList(),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: ["7", "8", "9"].map((k) => _buildKey(k)).toList(),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.clear_rounded, color: AppColors.textSecondary, size: 28),
                      onPressed: _onClear,
                    ),
                    _buildKey("0"),
                    IconButton(
                      icon: const Icon(Icons.backspace_rounded, color: AppColors.textSecondary, size: 24),
                      onPressed: _onBackspace,
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
