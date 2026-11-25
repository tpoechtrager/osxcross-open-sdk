/* SPDX-License-Identifier: 0BSD */
/* CommonCrypto from the SDK: digests, HMAC, AES, PBKDF2, random bytes. */
#include <CommonCrypto/CommonCrypto.h>
#include <CommonCrypto/CommonRandom.h>
#include <stdio.h>
#include <string.h>

static int hexeq(const unsigned char *d, size_t n, const char *hex) {
  char buf[129];
  for (size_t i = 0; i < n; i++) sprintf(buf + 2 * i, "%02x", d[i]);
  return strcmp(buf, hex) == 0;
}

#pragma clang diagnostic ignored "-Wdeprecated-declarations"

int main(void) {
  unsigned char d[CC_SHA256_DIGEST_LENGTH], m[CC_MD5_DIGEST_LENGTH];
  CC_SHA256("abc", 3, d);
  if (!hexeq(d, sizeof d, "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad")) return 1;
  CC_MD5("abc", 3, m);
  if (!hexeq(m, sizeof m, "900150983cd24fb0d6963f7d28e17f72")) return 2;
  unsigned char h[CC_SHA256_DIGEST_LENGTH];
  CCHmac(kCCHmacAlgSHA256, "key", 3, "The quick brown fox jumps over the lazy dog", 43, h);
  if (!hexeq(h, sizeof h, "f7bc83f430538424b13298e6aa6fb143ef4d59a14946175997479dbc2d1a3cd8")) return 3;
  unsigned char key[16] = {0}, in[16] = {0}, out[32];
  size_t n = 0;
  if (CCCrypt(kCCEncrypt, kCCAlgorithmAES, kCCOptionECBMode, key, 16, NULL, in, 16, out, sizeof out, &n) != kCCSuccess || n != 16) return 4;
  if (!hexeq(out, 16, "66e94bd4ef8a2c3b884cfa59ca342b2e")) return 5;
  unsigned char dk[20];
  if (CCKeyDerivationPBKDF(kCCPBKDF2, "password", 8, (const uint8_t *)"salt", 4, kCCPRFHmacAlgSHA1, 1, dk, sizeof dk) != 0) return 6;
  if (!hexeq(dk, sizeof dk, "0c60c80f961f0e71f3a9b524af6012062fe037a6")) return 7;
  unsigned char r[8];
  if (CCRandomGenerateBytes(r, sizeof r) != kCCSuccess) return 8;
  puts("commoncrypto ok");
  return 0;
}
