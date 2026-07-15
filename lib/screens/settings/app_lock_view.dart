import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../services/database_service.dart';
import '../../utils/colors.dart';
import '../../models/sync_item.dart';

class AppLockView extends StatefulWidget {
  const AppLockView({super.key});

  @override
  State<AppLockView> createState() => _AppLockViewState();
}

class _AppLockViewState extends State<AppLockView> {
  final DatabaseService _dbService = DatabaseService();
  final _pinController = TextEditingController();
  final _confirmPinController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  bool _isLockEnabled = false;
  String? _savedPin;

  String? get _userId => Supabase.instance.client.auth.currentUser?.id;

  @override
  void initState() {
    super.initState();
    _loadAppLockStatus();
  }

  void _loadAppLockStatus() {
    final uid = _userId;
    final pin = uid != null ? _dbService.settingsBox.get('app_lock_pin_$uid') as String? : null;
    setState(() {
      _savedPin = pin;
      _isLockEnabled = pin != null && pin.isNotEmpty;
    });
  }

  Future<void> _savePin() async {
    if (_formKey.currentState!.validate()) {
      final pin = _pinController.text;
      final uid = _userId;
      if (uid != null) {
        await _dbService.settingsBox.put('app_lock_pin_$uid', pin);
        await _syncProfileAppLockPin(uid, pin);
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("App Lock PIN configured successfully!"),
          backgroundColor: AppColors.success,
        ),
      );
      _pinController.clear();
      _confirmPinController.clear();
      _loadAppLockStatus();
    }
  }

  Future<void> _disableLock() async {
    final uid = _userId;
    if (uid != null) {
      await _dbService.settingsBox.delete('app_lock_pin_$uid');
      await _syncProfileAppLockPin(uid, null);
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("App Lock PIN disabled!"),
        backgroundColor: Colors.orangeAccent,
      ),
    );
    _loadAppLockStatus();
  }

  Future<void> _syncProfileAppLockPin(String userId, String? pin) async {
    try {
      await Supabase.instance.client
          .from('profiles')
          .update({'app_lock_pin': pin})
          .eq('id', userId);
    } catch (e) {
      final syncItem = SyncItem(
        actionType: 'UPDATE',
        tableName: 'profiles',
        recordId: userId,
        payload: {
          'id': userId,
          'app_lock_pin': pin,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        },
      );
      await _dbService.queueMutation(syncItem);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
        title: const Text(
          "App Lock Settings",
          style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Status Card
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                children: [
                  Icon(
                    _isLockEnabled ? Icons.lock_outline_rounded : Icons.lock_open_rounded,
                    color: _isLockEnabled ? AppColors.accent : AppColors.textMuted,
                    size: 32,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "PIN Security Status",
                          style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _isLockEnabled
                              ? "Passcode prompt is ACTIVE on launch."
                              : "Passcode prompt is currently INACTIVE.",
                          style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),

            if (!_isLockEnabled) ...[
              const Text(
                "Configure 4-Digit Passcode",
                style: TextStyle(color: AppColors.textPrimary, fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              Form(
                key: _formKey,
                child: Column(
                  children: [
                    TextFormField(
                      controller: _pinController,
                      obscureText: true,
                      keyboardType: TextInputType.number,
                      maxLength: 4,
                      style: const TextStyle(color: AppColors.textPrimary),
                      decoration: const InputDecoration(
                        labelText: "Enter 4-Digit PIN",
                        labelStyle: TextStyle(color: AppColors.textSecondary),
                        enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: AppColors.border)),
                        focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: AppColors.accent)),
                      ),
                      validator: (v) {
                        if (v == null || v.length != 4 || int.tryParse(v) == null) {
                          return "PIN must be exactly 4 digits";
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _confirmPinController,
                      obscureText: true,
                      keyboardType: TextInputType.number,
                      maxLength: 4,
                      style: const TextStyle(color: AppColors.textPrimary),
                      decoration: const InputDecoration(
                        labelText: "Confirm 4-Digit PIN",
                        labelStyle: TextStyle(color: AppColors.textSecondary),
                        enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: AppColors.border)),
                        focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: AppColors.accent)),
                      ),
                      validator: (v) {
                        if (v != _pinController.text) {
                          return "PINs do not match";
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.accent,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                        onPressed: _savePin,
                        child: const Text(
                          "Enable App Lock",
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ] else ...[
              const Text(
                "Deactivate Security Pin",
                style: TextStyle(color: AppColors.textPrimary, fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              const Text(
                "Once disabled, anyone opening the application can view your logs directly.",
                style: TextStyle(color: AppColors.textSecondary, fontSize: 13, height: 1.4),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.redAccent,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  onPressed: _disableLock,
                  child: const Text(
                    "Disable App Lock",
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ),
              ),
            ]
          ],
        ),
      ),
    );
  }
}
