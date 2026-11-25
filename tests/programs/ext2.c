#include <stdio.h>
#include <string.h>
#include <stdlib.h>
/* libutil.h is not part of the SDK; declare what is used */
#include <stdint.h>
int humanize_number(char *, size_t, int64_t, const char *, int, int);
#define HN_DECIMAL 0x01
#define HN_AUTOSCALE 0x20
#include <pcap.h>
#include <archive.h>
#include <archive_entry.h>
#include <security/pam_appl.h>
#include <curl/curl.h>
#include <libxslt/xslt.h>
#include <libxslt/xsltInternals.h>
#include <libxslt/transform.h>
#include <libxslt/xsltutils.h>
#include <libexslt/exslt.h>
#include <libxml/parser.h>
#include <dns_sd.h>

int main(void) {
  char buf[16]; humanize_number(buf, sizeof buf, 123456789, "", HN_AUTOSCALE, HN_DECIMAL);
  printf("libutil humanize '%s'\n", buf);

  printf("libpcap %s\n", pcap_lib_version());
  struct bpf_program prog; pcap_t *p = pcap_open_dead(DLT_EN10MB, 65535);
  if (!p || pcap_compile(p, &prog, "tcp port 80", 1, PCAP_NETMASK_UNKNOWN) != 0) return 1;
  printf("pcap filter insns %u\n", prog.bf_len); pcap_freecode(&prog); pcap_close(p);

  struct archive *a = archive_write_new(); archive_write_add_filter_none(a); archive_write_set_format_pax_restricted(a);
  static char mem[8192]; size_t used = 0; archive_write_open_memory(a, mem, sizeof mem, &used);
  struct archive_entry *e = archive_entry_new(); archive_entry_set_pathname(e, "x.txt"); archive_entry_set_size(e, 5);
  archive_entry_set_filetype(e, AE_IFREG); archive_entry_set_perm(e, 0644); archive_write_header(a, e); archive_write_data(a, "hello", 5);
  archive_entry_free(e); archive_write_close(a); archive_write_free(a);
  struct archive *r = archive_read_new(); archive_read_support_format_all(r); archive_read_support_filter_all(r);
  if (archive_read_open_memory(r, mem, used) != ARCHIVE_OK) return 2;
  if (archive_read_next_header(r, &e) != ARCHIVE_OK) return 3;
  printf("libarchive entry %s (%s)\n", archive_entry_pathname(e), archive_version_string()); archive_read_free(r);

  pam_handle_t *h = NULL; struct pam_conv conv = {0, 0};
  int pr = pam_start("login", "nobody", &conv, &h); printf("libpam pam_start rc=%d (%s)\n", pr, pr == PAM_SUCCESS ? "ok" : pam_strerror(h, pr)); if (h) pam_end(h, pr);

  curl_global_init(CURL_GLOBAL_NOTHING); curl_version_info_data *vi = curl_version_info(CURLVERSION_NOW);
  CURL *c = curl_easy_init(); char *esc = curl_easy_escape(c, "a b&c", 0); printf("libcurl %s escape '%s'\n", vi->version, esc); curl_free(esc); curl_easy_cleanup(c);

  exsltRegisterAll();
  const char *xsl = "<xsl:stylesheet version='1.0' xmlns:xsl='http://www.w3.org/1999/XSL/Transform'><xsl:output method='text'/>"
                    "<xsl:template match='/r'><xsl:value-of select='count(i)'/></xsl:template></xsl:stylesheet>";
  xmlDocPtr sd = xmlReadMemory(xsl, strlen(xsl), "s.xsl", NULL, 0); xsltStylesheetPtr ss = xsltParseStylesheetDoc(sd);
  xmlDocPtr dd = xmlReadMemory("<r><i/><i/><i/></r>", 19, "d.xml", NULL, 0); xmlDocPtr res = xsltApplyStylesheet(ss, dd, NULL);
  xmlChar *out = NULL; int len = 0; xsltSaveResultToString(&out, &len, res, ss); printf("libxslt count=%s\n", out ? (char *)out : "?");

  DNSServiceErrorType er; TXTRecordRef t; char tb[64]; TXTRecordCreate(&t, sizeof tb, tb); er = TXTRecordSetValue(&t, "k", 1, "v");
  printf("dns_sd txt len=%u rc=%d\n", TXTRecordGetLength(&t), (int)er); TXTRecordDeallocate(&t);
  return 0;
}
