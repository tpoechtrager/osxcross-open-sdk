/* libpcap: the functions of pcap/bpf.h and pcap/namedb.h (tcpdump uses them) and a filter that is run on a packet. */
#include <pcap.h>
#include <pcap-namedb.h>
#include <netdb.h>
#include <stdio.h>
#include <string.h>
#include <stdlib.h>
#include <unistd.h>

int main(void) {
  /* Ethernet, IPv4 (no options), TCP to port 80 */
  static const u_char pkt[54] = {
    0, 1, 2, 3, 4, 5, 0, 6, 7, 8, 9, 10, 0x08, 0x00,
    0x45, 0, 0, 40, 0, 0, 0x40, 0, 64, 6, 0, 0, 10, 0, 0, 1, 10, 0, 0, 2,
    0x30, 0x39, 0, 80, 0, 0, 0, 0, 0, 0, 0, 0, 0x50, 0x02, 0x20, 0, 0, 0, 0, 0 };
  struct bpf_program prog;
  pcap_t *p = pcap_open_dead(DLT_EN10MB, 65535);
  if (!p || pcap_compile(p, &prog, "tcp dst port 80", 1, PCAP_NETMASK_UNKNOWN) != 0) return 1;
  if (!bpf_validate(prog.bf_insns, (int)prog.bf_len)) return 2;
  if (bpf_filter(prog.bf_insns, pkt, sizeof pkt, sizeof pkt) == 0) return 3;
  char *line = bpf_image(prog.bf_insns, 0);
  if (!line || !*line) return 4;
  printf("filter: %u insns, first: %s\n", prog.bf_len, line);
  bpf_dump(&prog, 0);
  pcap_freecode(&prog); pcap_close(p);

  u_char *mac = pcap_ether_aton("00:11:22:aa:bb:cc");
  if (!mac || mac[0] != 0x00 || mac[5] != 0xcc) return 5;
  free(mac);
  free(pcap_ether_hostton("no-such-host.invalid"));  /* looks in /etc/ethers: NULL is fine */

  char tmp[] = "/tmp/pcap-ethers.XXXXXX";
  int fd = mkstemp(tmp);
  if (fd < 0) return 6;
  FILE *f = fdopen(fd, "w+");
  fputs("00:11:22:33:44:55 box\n", f); rewind(f);
  struct pcap_etherent *e = pcap_next_etherent(f);
  if (!e || strcmp(e->name, "box") != 0 || e->addr[5] != 0x55) return 7;
  fclose(f); unlink(tmp);

  int port, proto, port2;
  if (!pcap_nametoport("http", &port, &proto) || port != 80) return 8;
  if (!pcap_nametoportrange("1000-2000", &port, &port2, &proto) || port != 1000 || port2 != 2000) return 9;
  if (pcap_nametoproto("tcp") != 6) return 10;
  if (pcap_nametoeproto("ip") != 0x0800) return 11;
  if (pcap_nametollc("stp") == PROTO_UNDEF) return 12;
  if (pcap_nametonetaddr("loopback") == 0 && pcap_nametonetaddr("127") == 0) printf("no network loopback in /etc/networks\n");
  struct addrinfo *ai = pcap_nametoaddrinfo("localhost");
  if (!ai) return 13;
  freeaddrinfo(ai);
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
  if (!pcap_nametoaddr("localhost")) return 14;
  printf("libpcap names: ok\n");
  return 0;
}
