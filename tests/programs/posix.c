#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <fcntl.h>
#include <errno.h>
#include <pthread.h>
#include <math.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <sys/socket.h>
#include <netinet/in.h>
#include <arpa/inet.h>
#include <netdb.h>
#include <time.h>
#include <signal.h>
#include <dirent.h>

static void *worker(void *arg) { int *v = arg; *v = 42; return arg; }

int main(void) {
  char path[] = "/tmp/open-sdk-test-XXXXXX";
  int fd = mkstemp(path);
  if (fd < 0) { perror("mkstemp"); return 1; }
  const char msg[] = "file io ok\n";
  if (write(fd, msg, sizeof msg - 1) != (ssize_t)(sizeof msg - 1)) return 2;
  lseek(fd, 0, SEEK_SET);
  char buf[64] = {0};
  if (read(fd, buf, sizeof buf - 1) <= 0) return 3;
  fputs(buf, stdout);
  struct stat st; fstat(fd, &st); printf("size %lld\n", (long long)st.st_size);
  close(fd); unlink(path);

  pthread_t t; int v = 0;
  pthread_create(&t, NULL, worker, &v); pthread_join(t, NULL);
  printf("thread %d\n", v);

  printf("sqrt %.3f pow %.1f\n", sqrt(2.0), pow(2.0, 10.0));

  struct addrinfo hints, *res = NULL; memset(&hints, 0, sizeof hints);
  hints.ai_family = AF_INET; hints.ai_socktype = SOCK_STREAM;
  int rc = getaddrinfo("127.0.0.1", "80", &hints, &res);
  if (rc != 0) { printf("getaddrinfo: %s\n", gai_strerror(rc)); return 4; }
  char ip[INET_ADDRSTRLEN];
  inet_ntop(AF_INET, &((struct sockaddr_in *)res->ai_addr)->sin_addr, ip, sizeof ip);
  printf("addr %s\n", ip); freeaddrinfo(res);
  int s = socket(AF_INET, SOCK_STREAM, 0); printf("socket %s\n", s >= 0 ? "ok" : "fail"); if (s >= 0) close(s);
  time_t now = time(NULL); struct tm tm; gmtime_r(&now, &tm); printf("year>=2024 %d\n", tm.tm_year + 1900 >= 2024);
  return 0;
}
