/* -lresolv: res_query and dn_expand (libresolv.9.dylib), not part of libSystem */
#include <sys/types.h>
#include <netinet/in.h>
#include <arpa/nameser.h>
#include <resolv.h>
#include <stdio.h>
#include <string.h>

int main(void) {
  unsigned char buf[NS_PACKETSZ];
  char name[NS_MAXDNAME];
  /* a name in the packet format: 3www7example3com0 */
  static const unsigned char wire[] = { 3,'w','w','w', 7,'e','x','a','m','p','l','e', 3,'c','o','m', 0 };
  memcpy(buf, wire, sizeof wire);
  int n = dn_expand(buf, buf + sizeof wire, buf, name, sizeof name);
  printf("dn_expand: %d %s\n", n, name);
  if (n != (int)sizeof wire || strcmp(name, "www.example.com") != 0) return 1;
  /* res_query only has to link; a name that does not exist fails fast or slowly, do not call it */
  void *p = (void *)res_query;
  return p == 0;
}
