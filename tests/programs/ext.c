#include <stdio.h>
#include <string.h>
#include <zlib.h>
#include <bzlib.h>
#include <expat.h>
#include <ffi/ffi.h>
#include <histedit.h>
#include <libxml/parser.h>
#include <libxml/tree.h>

static int add(int a, int b) { return a + b; }
static int elements;
static void XMLCALL start(void *d, const XML_Char *n, const XML_Char **a) { (void)d; (void)n; (void)a; elements++; }

int main(void) {
  const char *msg = "hello hello hello hello open sdk";
  unsigned char z[128], back[128]; uLongf zl = sizeof z, bl = sizeof back;
  if (compress(z, &zl, (const Bytef *)msg, strlen(msg) + 1) != Z_OK) return 1;
  if (uncompress(back, &bl, z, zl) != Z_OK || strcmp((char *)back, msg)) return 2;
  printf("zlib %s ok (%lu -> %lu)\n", zlibVersion(), (unsigned long)strlen(msg) + 1, (unsigned long)zl);

  char b[256]; unsigned bn = sizeof b; char o[256]; unsigned on = sizeof o;
  if (BZ2_bzBuffToBuffCompress(b, &bn, (char *)msg, strlen(msg) + 1, 9, 0, 0) != BZ_OK) return 3;
  if (BZ2_bzBuffToBuffDecompress(o, &on, b, bn, 0, 0) != BZ_OK || strcmp(o, msg)) return 4;
  printf("bzip2 ok\n");

  XML_Parser p = XML_ParserCreate(NULL); XML_SetElementHandler(p, start, NULL);
  const char *x = "<a><b/><c><d/></c></a>";
  if (XML_Parse(p, x, (int)strlen(x), 1) != XML_STATUS_OK) return 5;
  XML_ParserFree(p); printf("expat elements %d\n", elements);

  ffi_cif cif; ffi_type *args[2] = {&ffi_type_sint, &ffi_type_sint}; int a1 = 40, a2 = 2; void *av[2] = {&a1, &a2}; ffi_arg r;
  if (ffi_prep_cif(&cif, FFI_DEFAULT_ABI, 2, &ffi_type_sint, args) != FFI_OK) return 6;
  ffi_call(&cif, FFI_FN(add), &r, av); printf("ffi %d\n", (int)r);

  History *h = history_init(); HistEvent ev; history(h, &ev, H_SETSIZE, 10); history(h, &ev, H_ENTER, "first"); 
  history(h, &ev, H_FIRST); printf("libedit history '%s'\n", ev.str); history_end(h);

  xmlDocPtr doc = xmlReadMemory(x, (int)strlen(x), "mem.xml", NULL, 0);
  if (!doc) return 7; printf("libxml2 root %s\n", (const char *)xmlDocGetRootElement(doc)->name); xmlFreeDoc(doc);
  return 0;
}
