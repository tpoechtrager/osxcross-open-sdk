/* SPDX-License-Identifier: 0BSD */
/* XPC sessions, listeners and rich errors (xpc/xpc.h, macOS 13.0 and 14.0): sessions to services that
   do not exist and a listener of a name that no launchd job claims.  Every path must end with a rich
   error or an object that is cancelled and released; the flags are 0 (no flag has a public value). */
#include <xpc/xpc.h>
#include <stdio.h>
#include <stdlib.h>

static int report(const char *what, xpc_object_t obj, xpc_rich_error_t err) {
  char *d = err ? xpc_rich_error_copy_description(err) : NULL;
  printf("%s: object=%d error=%d retry=%d%s%s\n", what, obj != NULL, err != NULL,
         err ? (int)xpc_rich_error_can_retry(err) : -1, d ? " description=" : "", d ? "yes" : "");
  int bad = d ? d[0] == 0 : 0;
  free(d);
  return bad;
}

int main(void) {
  dispatch_queue_t q = dispatch_queue_create("xpc_session test", NULL);
  int rc = 0;

  xpc_rich_error_t err = NULL;
  xpc_session_t s = xpc_session_create_mach_service("org.osxcross.open-sdk.no-such-service", q, 0, &err);
  rc |= report("mach service", s, err);
  if (!s && !err) rc |= 1;                     /* a failure must come with its error */
  if (s) {
    char *d = xpc_session_copy_description(s);
    printf("session description %s\n", d ? "yes" : "no");
    free(d);
    xpc_session_cancel(s);
    xpc_release(s);
  }

  err = NULL;
  s = xpc_session_create_xpc_service("org.osxcross.open-sdk.NoSuchService", q, 0, &err);
  rc |= report("xpc service", s, err);
  if (!s && !err) rc |= 2;
  if (s) { xpc_session_cancel(s); xpc_release(s); }

  err = NULL;
  xpc_listener_t l = xpc_listener_create("org.osxcross.open-sdk.no-such-listener", q, 0,
                                         ^(xpc_session_t peer) { xpc_session_cancel(peer); }, &err);
  rc |= report("listener", l, err);
  if (!l && !err) rc |= 4;
  if (l) { xpc_listener_cancel(l); xpc_release(l); }

  puts(rc ? "xpc_session FAILED" : "xpc_session ok");
  return rc;
}
