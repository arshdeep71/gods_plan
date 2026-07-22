import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:encrypt/encrypt.dart' as encrypt;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

class EncryptionService {
  static final EncryptionService _instance = EncryptionService._internal();
  factory EncryptionService() => _instance;
  EncryptionService._internal();

  bool _initialized = false;
  encrypt.Key? _key;
  final _storage = const FlutterSecureStorage();

  Future<void> initialize() async {
    if (_initialized) return;

    try {
      if (kIsWeb) {
        final prefs = await SharedPreferences.getInstance();
        String? keyBase64 = prefs.getString('db_encryption_key_fallback');
        if (keyBase64 == null) {
          final keyBytes = encrypt.Key.fromSecureRandom(32);
          keyBase64 = base64Encode(keyBytes.bytes);
          await prefs.setString('db_encryption_key_fallback', keyBase64);
        }
        _key = encrypt.Key.fromBase64(keyBase64);
        _initialized = true;
        return;
      }

      String? keyBase64 = await _storage.read(key: 'db_encryption_key');
      
      if (keyBase64 == null) {
        final keyBytes = encrypt.Key.fromSecureRandom(32);
        keyBase64 = base64Encode(keyBytes.bytes);
        await _storage.write(key: 'db_encryption_key', value: keyBase64);
      }
      
      _key = encrypt.Key.fromBase64(keyBase64);
      _initialized = true;
    } catch (e) {
      try {
        final prefs = await SharedPreferences.getInstance();
        String? keyBase64 = prefs.getString('db_encryption_key_fallback');
        if (keyBase64 == null) {
          final keyBytes = encrypt.Key.fromSecureRandom(32);
          keyBase64 = base64Encode(keyBytes.bytes);
          await prefs.setString('db_encryption_key_fallback', keyBase64);
        }
        _key = encrypt.Key.fromBase64(keyBase64);
        _initialized = true;
      } catch (_) {
        _key = encrypt.Key.fromBase64(base64Encode(List.filled(32, 0)));
        _initialized = true;
      }
    }
  }

  /// Encrypts a plain text string and returns a base64 encoded string containing the IV + encrypted data
  String encryptString(String plainText) {
    if (!_initialized || _key == null || plainText.isEmpty) return plainText;
    try {
      final iv = encrypt.IV.fromSecureRandom(16);
      final encrypter = encrypt.Encrypter(encrypt.AES(_key!, mode: encrypt.AESMode.cbc));
      final encrypted = encrypter.encrypt(plainText, iv: iv);
      
      final ivBase64 = base64Encode(iv.bytes);
      final cipherBase64 = encrypted.base64;
      return '\$ENCRYPTED\$$ivBase64\$$cipherBase64';
    } catch (_) {
      return plainText;
    }
  }

  /// Backward compatibility wrapper for encrypt
  String encrypt(String plainText) => encryptString(plainText);

  /// Decrypts a base64 encoded string containing the IV + encrypted data
  String decrypt(String encryptedData) {
    if (!_initialized || _key == null || encryptedData.isEmpty) return encryptedData;
    if (!encryptedData.startsWith('\$ENCRYPTED\$')) return encryptedData;

    try {
      final parts = encryptedData.split('\$');
      if (parts.length != 4) return encryptedData;

      final iv = encrypt.IV.fromBase64(parts[2]);
      final cipherText = parts[3];
      
      final encrypter = encrypt.Encrypter(encrypt.AES(_key!, mode: encrypt.AESMode.cbc));
      final encrypted = encrypt.Encrypted.fromBase64(cipherText);
      return encrypter.decrypt(encrypted, iv: iv);
    } catch (e) {
      return encryptedData;
    }
  }
}
