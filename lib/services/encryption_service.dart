import 'dart:convert';
import 'package:encrypt/encrypt.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

class EncryptionService {
  static final EncryptionService _instance = EncryptionService._internal();
  factory EncryptionService() => _instance;
  EncryptionService._internal();

  bool _initialized = false;
  late Key _key;
  late IV _iv;
  late Encrypter _encrypter;

  // Ideally, use flutter_secure_storage to store the encryption key.
  // For web compatibility or fallback, we use SharedPreferences.
  final _storage = const FlutterSecureStorage();

  Future<void> initialize() async {
    if (_initialized) return;

    try {
      String? keyBase64 = await _storage.read(key: 'db_encryption_key');
      
      if (keyBase64 == null) {
        // Generate a new 256-bit key
        final keyBytes = Key.fromSecureRandom(32);
        keyBase64 = base64Encode(keyBytes.bytes);
        await _storage.write(key: 'db_encryption_key', value: keyBase64);
      }
      
      _key = Key.fromBase64(keyBase64);
      // Use a static IV or generate per row. For simplicity in DB column encryption,
      // we use a deterministic IV based on a hash or a zero IV, or store it alongside data.
      // Better: Use a static IV for column encryption so search still works (not recommended for high security)
      // Best: Prepend IV to the encrypted text.
      _initialized = true;
    } catch (e) {
      // Fallback for environments where SecureStorage isn't supported (like some Web setups)
      final prefs = await SharedPreferences.getInstance();
      String? keyBase64 = prefs.getString('db_encryption_key_fallback');
      if (keyBase64 == null) {
        final keyBytes = Key.fromSecureRandom(32);
        keyBase64 = base64Encode(keyBytes.bytes);
        await prefs.setString('db_encryption_key_fallback', keyBase64);
      }
      _key = Key.fromBase64(keyBase64);
      _initialized = true;
    }
  }

  /// Encrypts a plain text string and returns a base64 encoded string containing the IV + encrypted data
  String encrypt(String plainText) {
    if (!_initialized || plainText.isEmpty) return plainText;
    final iv = IV.fromSecureRandom(16);
    final encrypter = Encrypter(AES(_key, mode: AESMode.cbc));
    final encrypted = encrypter.encrypt(plainText, iv: iv);
    
    // Combine IV and CipherText
    final ivBase64 = base64Encode(iv.bytes);
    final cipherBase64 = encrypted.base64;
    return '\$ENCRYPTED\$$ivBase64\$$cipherBase64';
  }

  /// Decrypts a base64 encoded string containing the IV + encrypted data
  String decrypt(String encryptedData) {
    if (!_initialized || encryptedData.isEmpty) return encryptedData;
    if (!encryptedData.startsWith('\$ENCRYPTED\$')) return encryptedData;

    try {
      final parts = encryptedData.split('\$');
      if (parts.length != 4) return encryptedData; // [ "", "ENCRYPTED", "iv", "cipher" ]

      final iv = IV.fromBase64(parts[2]);
      final cipherText = parts[3];
      
      final encrypter = Encrypter(AES(_key, mode: AESMode.cbc));
      final encrypted = Encrypted.fromBase64(cipherText);
      return encrypter.decrypt(encrypted, iv: iv);
    } catch (e) {
      print('Decryption failed: \$e');
      return encryptedData;
    }
  }
}
