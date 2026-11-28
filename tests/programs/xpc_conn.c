/* SPDX-License-Identifier: 0BSD */
/* XPC connections: an anonymous listener, a connection to its endpoint, a message with a reply. */
#include <xpc/xpc.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

int main(void) {
  dispatch_queue_t q = dispatch_queue_create("xpc_conn", NULL);
  xpc_connection_t listener = xpc_connection_create(NULL, q);
  xpc_connection_set_event_handler(listener, ^(xpc_object_t peer) {
    if (xpc_get_type(peer) != XPC_TYPE_CONNECTION) return;
    xpc_connection_set_event_handler(peer, ^(xpc_object_t msg) {
      if (xpc_get_type(msg) != XPC_TYPE_DICTIONARY) return;
      xpc_object_t reply = xpc_dictionary_create_reply(msg);
      int64_t v = xpc_dictionary_get_int64(msg, "n");
      xpc_dictionary_set_int64(reply, "n", v * 2);
      xpc_dictionary_set_string(reply, "s", "pong");
      xpc_connection_send_message(peer, reply);
      xpc_release(reply);
    });
    xpc_connection_resume(peer);
  });
  xpc_connection_resume(listener);

  xpc_endpoint_t ep = xpc_endpoint_create(listener);
  xpc_connection_t c = xpc_connection_create_from_endpoint(ep);
  xpc_connection_set_event_handler(c, ^(xpc_object_t e) { (void)e; });
  xpc_connection_resume(c);
  xpc_object_t msg = xpc_dictionary_create(NULL, NULL, 0);
  xpc_dictionary_set_int64(msg, "n", 21);
  xpc_object_t r = xpc_connection_send_message_with_reply_sync(c, msg);
  int ok = xpc_get_type(r) == XPC_TYPE_DICTIONARY && xpc_dictionary_get_int64(r, "n") == 42 &&
           strcmp(xpc_dictionary_get_string(r, "s"), "pong") == 0;
  char *d = xpc_copy_description(r);
  printf("xpc reply: %s\n", ok ? "ok" : d);
  free(d);
  xpc_release(r); xpc_release(msg);
  xpc_connection_cancel(c); xpc_connection_cancel(listener);
  return ok ? 0 : 1;
}
