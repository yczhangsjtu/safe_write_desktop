import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
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

class Passage {
  String title;
  String content;
  Passage(this.title, this.content);

  String toBase64() {
    return "${base64.encode(utf8.encode(title))}-${base64.encode(utf8.encode(content))}";
  }
}

class Plaintext {
  int fontSize;
  List<Passage> passages;
  Plaintext(this.passages, {this.fontSize = 18});

  Future<String?> encrypt(String? password) async {
    final plaintext =
        passages.map((p) => p.toBase64()).join("|") + ":FontSize=$fontSize";
    return enc(plaintext, password);
  }
}

void main(List<String> arguments) async {
  if (arguments.length < 1) {
    print("Usage: dart run bin/cli.dart title");
    return;
  }
  var file = File('/tmp/pt');
  var data = await file.readAsString();
  String title = arguments[0];
  List<Passage> passages = [];
  while (data.isNotEmpty) {
    int next_title =
        data.startsWith("## ") ? 0 : data.indexOf(RegExp(r'\n\n## .*\n\n'));
    if (next_title < 0) {
      passages.add(Passage(title, data));
      break;
    }
    if (next_title == 0) {
      title = data.split("\n")[0].substring(3);
      data = data.substring(title.length + 3).trimLeft();
      continue;
    }
    passages.add(Passage(title, data.substring(0, next_title)));
    data = data.substring(next_title + 5);
    title = data.split("\n")[0];
    data = data.substring(title.length).trimLeft();
  }
  print('Enter password: ');
  stdin.echoMode = false;
  var password = stdin.readLineSync();
  var plaintext = Plaintext(passages);
  var ct = await plaintext.encrypt(password);
  var ctfile = File('/tmp/ct.safe');
  var wt = ctfile.openWrite();
  wt.write(ct);
}
