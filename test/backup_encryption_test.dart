import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:trufit_bodamma/services/backup_encryption_service.dart';
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:encrypt/encrypt.dart' as enc;

void main() {
  group('BackupEncryptionService', () {
    const password = 'my_super_secret_password';
    final testData = Uint8List.fromList(utf8.encode('Hello TruFit Bodamma! This is a test backup payload.'));

    test('round-trip encryption and decryption (v2)', () {
      final encrypted = BackupEncryptionService.encryptBytes(testData, password);
      
      // Verify v2 header
      expect(encrypted[0], 84); // T
      expect(encrypted[1], 70); // F
      expect(encrypted[2], 66); // B
      expect(encrypted[3], 75); // K
      expect(encrypted[4], 2);  // version 2

      final decrypted = BackupEncryptionService.decryptBytes(encrypted, password);
      expect(decrypted, equals(testData));
    });

    test('rejection on wrong password (v2)', () {
      final encrypted = BackupEncryptionService.encryptBytes(testData, password);
      
      expect(
        () => BackupEncryptionService.decryptBytes(encrypted, 'wrong_password'),
        throwsA(isA<Exception>()),
      );
    });

    test('rejection on tampered bytes (GCM tag verification)', () {
      final encrypted = BackupEncryptionService.encryptBytes(testData, password);
      
      // Tamper with the ciphertext (last byte, which is part of the GCM auth tag)
      encrypted[encrypted.length - 1] ^= 0x01;
      
      expect(
        () => BackupEncryptionService.decryptBytes(encrypted, password),
        throwsA(isA<Exception>()),
      );
    });

    test('successful decryption of v1 legacy data', () {
      // Manually create v1 encrypted data
      final keyBytes = sha256.convert(utf8.encode(password)).bytes;
      final key = enc.Key(Uint8List.fromList(keyBytes));
      final iv = enc.IV.fromSecureRandom(16);
      
      final encrypter = enc.Encrypter(enc.AES(key, mode: enc.AESMode.cbc));
      final encryptedV1 = encrypter.encryptBytes(testData, iv: iv);
      
      final out = BytesBuilder();
      out.add(iv.bytes);
      out.add(encryptedV1.bytes);
      final v1Data = out.toBytes();

      // Verify BackupEncryptionService can decrypt it
      final decrypted = BackupEncryptionService.decryptBytes(v1Data, password);
      expect(decrypted, equals(testData));
    });
    
    test('rejection on wrong password (v1)', () {
      final keyBytes = sha256.convert(utf8.encode(password)).bytes;
      final key = enc.Key(Uint8List.fromList(keyBytes));
      final iv = enc.IV.fromSecureRandom(16);
      
      final encrypter = enc.Encrypter(enc.AES(key, mode: enc.AESMode.cbc));
      final encryptedV1 = encrypter.encryptBytes(testData, iv: iv);
      
      final out = BytesBuilder();
      out.add(iv.bytes);
      out.add(encryptedV1.bytes);
      final v1Data = out.toBytes();

      // Wrong password throws or returns garbage (since CBC doesn't have auth tag, it might just throw an alignment/padding error)
      expect(
        () => BackupEncryptionService.decryptBytes(v1Data, 'wrong_password'),
        throwsA(isA<ArgumentError>()),
      );
    });
  });
}
