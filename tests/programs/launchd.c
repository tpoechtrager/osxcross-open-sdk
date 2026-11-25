/* SPDX-License-Identifier: 0BSD */
/* launchd's API (launch.h, servers/bootstrap.h): launch_data values and a
   lookup in the bootstrap namespace. */
#include <launch.h>
#include <servers/bootstrap.h>
#include <stdio.h>
#include <string.h>

int main(void) {
  launch_data_t d = launch_data_alloc(LAUNCH_DATA_DICTIONARY);
  launch_data_dict_insert(d, launch_data_new_string("hello"), "Label");
  launch_data_dict_insert(d, launch_data_new_integer(42), "Number");
  launch_data_t s = launch_data_dict_lookup(d, "Label");
  launch_data_t n = launch_data_dict_lookup(d, "Number");
  if (!s || strcmp(launch_data_get_string(s), "hello") != 0) return 1;
  if (!n || launch_data_get_integer(n) != 42) return 2;
  if (launch_data_dict_get_count(d) != 2) return 3;
  launch_data_free(d);
  mach_port_t p = MACH_PORT_NULL;
  kern_return_t kr = bootstrap_look_up(bootstrap_port, "com.example.no-such-service", &p);
  if (kr == KERN_SUCCESS) return 4;
  puts("launchd ok");
  return 0;
}
