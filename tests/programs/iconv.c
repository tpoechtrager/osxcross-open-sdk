/* SPDX-License-Identifier: 0BSD */
/* libiconv: UTF-8 to ISO-8859-1 and UTF-16LE and back. */
#include <iconv.h>
#include <stdio.h>
#include <string.h>

static size_t conv(const char *to, const char *from, const char *in, size_t inlen, char *out, size_t outsz) {
  iconv_t cd = iconv_open(to, from);
  if (cd == (iconv_t)-1) return (size_t)-1;
  char *ip = (char *)in, *op = out;
  size_t il = inlen, ol = outsz;
  size_t r = iconv(cd, &ip, &il, &op, &ol);
  iconv_close(cd);
  return r == (size_t)-1 ? r : outsz - ol;
}

int main(void) {
  const char *s = "Gr\xc3\xbc\xc3\x9f" "e";            /* "Grüße" in UTF-8 */
  char latin[16], u16[32], back[32];
  size_t n = conv("ISO-8859-1", "UTF-8", s, strlen(s), latin, sizeof latin);
  if (n != 5 || (unsigned char)latin[2] != 0xfc || (unsigned char)latin[3] != 0xdf) return 1;
  size_t m = conv("UTF-16LE", "ISO-8859-1", latin, n, u16, sizeof u16);
  if (m != 10 || (unsigned char)u16[4] != 0xfc || u16[5] != 0) return 2;
  size_t k = conv("UTF-8", "UTF-16LE", u16, m, back, sizeof back);
  if (k != strlen(s) || memcmp(back, s, k) != 0) return 3;
  if (conv("ASCII", "UTF-8", s, strlen(s), back, sizeof back) != (size_t)-1) return 4;  /* ü has no ASCII */
  printf("iconv: ok\n");
  return 0;
}
