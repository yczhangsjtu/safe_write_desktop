import CryptoJS from "crypto-js";
import prompt from 'prompt';
import * as fs from 'fs';

const IV_LENGTH = 16;
const SALT_LENGTH = 16;
const KEY_LENGTH = 16;

function decrypt(password: string, data: string): string {
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
  const decrypted = CryptoJS.AES.decrypt(binaryData.toString(CryptoJS.enc.Base64), key, {iv: iv});
  return decrypted.toString(CryptoJS.enc.Utf8);
}


if(process.argv.length < 4) {
  console.log("Usage: npx ts-node index.ts path filename [filename2 [...]]");
  process.exit(-1);
}

var path = process.argv[2];
var filenames = process.argv.slice(3);
var include_plaintexts = process.env.SAFE_WRITE_PLAINTEXT;
var renumber = process.env.SAFE_WRITE_RENUMBER;

prompt.start();
prompt.get({
  properties: {
    password: {
      hidden: true
    }
  }
}, function(err, result) {
  if(err) {
    console.log(`Error getting password: ${err}`);
    return;
  }
  var plaintext = "";
  var count = 0;
  for(var k = 0; k < filenames.length; k++) {
    var filename = filenames[k];
    var data = fs.readFileSync(`${path}/${filename}.ipynb`).toString();
    var nbdata = JSON.parse(data);
    for(var i in nbdata.cells) {
      var cell = nbdata.cells[i];
      if(cell.cell_type == "markdown") {
        var data = cell.source[0] as string;
        if(data.startsWith("ciphertext:")) {
          if (renumber && !include_plaintexts) {
            if(plaintext.length > 0) {
              plaintext += "\n\n";
            }
            plaintext += `## ${count+1}`;
            count += 1;
          }
          if(plaintext.length > 0) {
            plaintext += "\n\n";
          }
          plaintext += decrypt(result.password as string, data.slice(11));
        } else if (include_plaintexts) {
          if(plaintext.length > 0) {
            plaintext += "\n\n";
          }
          plaintext += data;
        }
      }
    }
  }
  fs.writeFileSync("/tmp/pt", plaintext);
});
