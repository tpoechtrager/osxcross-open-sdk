#include <CoreFoundation/CoreFoundation.h>
#include <Security/Security.h>
#include <stdio.h>

int main(void) {
  unsigned char r[16]; int rc = SecRandomCopyBytes(kSecRandomDefault, sizeof r, r); printf("SecRandom rc=%d\n", rc);
  int bits = 256; CFNumberRef nb = CFNumberCreate(NULL, kCFNumberIntType, &bits);
  const void *k[] = { kSecAttrKeyType, kSecAttrKeySizeInBits }; const void *v[] = { kSecAttrKeyTypeECSECPrimeRandom, nb };
  CFDictionaryRef par = CFDictionaryCreate(NULL, k, v, 2, &kCFTypeDictionaryKeyCallBacks, &kCFTypeDictionaryValueCallBacks);
  CFErrorRef err = NULL; SecKeyRef priv = SecKeyCreateRandomKey(par, &err); printf("SecKey generated=%d\n", priv != NULL);
  if (!priv) return 1;
  SecKeyRef pub = SecKeyCopyPublicKey(priv); CFDataRef msg = CFDataCreate(NULL, (const UInt8 *)"hello", 5);
  CFDataRef sig = SecKeyCreateSignature(priv, kSecKeyAlgorithmECDSASignatureMessageX962SHA256, msg, &err);
  Boolean ok = sig && SecKeyVerifySignature(pub, kSecKeyAlgorithmECDSASignatureMessageX962SHA256, msg, sig, &err);
  printf("ECDSA sign+verify=%d sigbytes>0=%d\n", ok, sig && CFDataGetLength(sig) > 0);
  return ok ? 0 : 2;
}
