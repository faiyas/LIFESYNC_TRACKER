import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:encrypt/encrypt.dart' as encrypt_pkg;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class EncryptionService {
  static final EncryptionService instance = EncryptionService._init();
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  static const String _vaultKeyAlias = 'lifesync_vault_master_key';

  EncryptionService._init();

  Future<String> _getOrCreateMasterKey() async {
    String? existingKey = await _storage.read(key: _vaultKeyAlias);
    if (existingKey == null) {
      final key = encrypt_pkg.Key.fromSecureRandom(32);
      existingKey = key.base64;
      await _storage.write(key: _vaultKeyAlias, value: existingKey);
    }
    return existingKey;
  }

  Future<String> encryptText(String plainText) async {
    if (plainText.isEmpty) return '';
    final keyBase64 = await _getOrCreateMasterKey();
    final key = encrypt_pkg.Key.fromBase64(keyBase64);
    final iv = encrypt_pkg.IV.fromLength(16);
    final encrypter = encrypt_pkg.Encrypter(encrypt_pkg.AES(key));

    final encrypted = encrypter.encrypt(plainText, iv: iv);
    return '${iv.base64}:${encrypted.base64}';
  }

  Future<String> decryptText(String encryptedString) async {
    if (encryptedString.isEmpty || !encryptedString.contains(':')) return encryptedString;
    try {
      final parts = encryptedString.split(':');
      final iv = encrypt_pkg.IV.fromBase64(parts[0]);
      final encryptedData = encrypt_pkg.Encrypted.fromBase64(parts[1]);

      final keyBase64 = await _getOrCreateMasterKey();
      final key = encrypt_pkg.Key.fromBase64(keyBase64);
      final encrypter = encrypt_pkg.Encrypter(encrypt_pkg.AES(key));

      return encrypter.decrypt(encryptedData, iv: iv);
    } catch (e) {
      return '[Decryption Error]';
    }
  }

  String hashPin(String pin) {
    final bytes = utf8.encode('salt_lifesync_$pin');
    return sha256.convert(bytes).toString();
  }
}
