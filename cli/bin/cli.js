private async encrypt(data: string) {
  if(this.key == null || this.salt == null) {
    await InputDialog.getPassword({title: 'Password'}).then(value => {
      if(value.value) {
        this.salt = CryptoJS.lib.WordArray.random(SALT_LENGTH);
        this.key = CryptoJS.PBKDF2(value.value, this.salt, {keySize: KEY_LENGTH});
      } else {
        showErrorMessage("Failed to get password", "Failed to get password")
      }
    });
  }
  if(this.key == null || this.salt == null) {
    return null;
  }
  const iv = CryptoJS.lib.WordArray.random(IV_LENGTH);
  const encrypted = CryptoJS.AES.encrypt(data, this.key, {
    iv: iv,
    mode: CryptoJS.mode.CBC,
    padding: CryptoJS.pad.Pkcs7,
  });
  return 'ciphertext:' + iv.concat(this.salt).concat(encrypted.ciphertext).toString(CryptoJS.enc.Base64);
}

private decrypt(password: string, data: string) {
  const binaryData = CryptoJS.enc.Base64.parse(data);
  const iv = binaryData.clone()
  iv.sigBytes = IV_LENGTH;
  iv.clamp();
  binaryData.words.splice(0, IV_LENGTH / 4)
  binaryData.sigBytes -= IV_LENGTH;
  const salt = binaryData.clone()
  salt.sigBytes = SALT_LENGTH;
  salt.clamp();
  binaryData.words.splice(0, SALT_LENGTH / 4)
  binaryData.sigBytes -= SALT_LENGTH;
  const key = CryptoJS.PBKDF2(password, salt, {keySize: KEY_LENGTH});
  const decrypted = CryptoJS.AES.decrypt({ciphertext: binaryData}, key, {
    iv: iv,
    mode: CryptoJS.mode.CBC,
    padding: CryptoJS.pad.Pkcs7,
  });
  return decrypted.toString(CryptoJS.enc.Utf8);
}
