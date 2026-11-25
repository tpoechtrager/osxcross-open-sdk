/* build with -framework Foundation: links against the placeholder and does
   not use Foundation; the system's Foundation is loaded at run time */
#include <stdio.h>

int main(void) {
  puts("framework Foundation linked");
  return 0;
}
