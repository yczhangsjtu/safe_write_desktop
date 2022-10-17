import 'dart:convert';
import 'package:cryptography/cryptography.dart';

Future<SecretKey> _keyDerive(String password) async {
  final pbkdf2 = Pbkdf2(
    macAlgorithm: Hmac.sha256(),
    iterations: 100,
    bits: 128,
  );

  final secretKey = SecretKey(utf8.encode(password));
  final nonce = utf8.encode("safe_write");
  return await pbkdf2.deriveKey(secretKey: secretKey, nonce: nonce);
}

Future<String?> enc(String? plaintext, String? password) async {
  if (password == null || password.isEmpty) {
    return null;
  }
  if (plaintext == null || plaintext.isEmpty) {
    return "";
  }
  final skey = await _keyDerive(password);
  final data = utf8.encode(plaintext);
  final ciphertext = await AesCbc.with128bits(macAlgorithm: Hmac.sha256())
      .encrypt(data, secretKey: skey);
  return base64.encode(ciphertext.nonce) +
      "\n" +
      base64.encode(ciphertext.cipherText) +
      "\n" +
      base64.encode(ciphertext.mac.bytes);
}

Future<String?> dec(String? ciphertext, String? password) async {
  if (password == null || password.isEmpty) {
    print("password is null or empty");
    return null;
  }
  if (ciphertext == null || ciphertext.isEmpty) {
    print("ciphertext is null or empty");
    return "";
  }
  final skey = await _keyDerive(password);

  final parts = ciphertext.split("\n");
  if (parts.length < 3) {
    print("invalid ciphertext format");
    return null;
  }

  final nonce = base64.decode(parts[0]);
  final ct = base64.decode(parts[1]);
  final mac = base64.decode(parts[2]);
  SecretBox secretBox = SecretBox(ct, nonce: nonce, mac: Mac(mac));
  try {
    final plaintext = await AesCbc.with128bits(macAlgorithm: Hmac.sha256())
        .decrypt(secretBox, secretKey: skey);
    return utf8.decode(plaintext);
  } catch (e) {
    print(e);
    return null;
  }
}
