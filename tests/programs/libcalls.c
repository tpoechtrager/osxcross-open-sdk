/* SPDX-License-Identifier: 0BSD */
/* Calls that Clang makes for the Darwin C library: pow(10, x) becomes
   __exp10, sin and cos of the same value become __sincos_stret. */
#include <math.h>
#include <stdio.h>
#include <stdlib.h>

int main(int argc, char **argv) {
  volatile double x = argc > 1 ? atof(argv[1]) : 2.0;
  volatile float f = (float)x;
  double a = pow(10.0, x);
  float b = powf(10.0f, f);
  double s = sin(x), c = cos(x);
  float sf = sinf(f), cf = cosf(f);
  printf("%g %g %g %g %g %g\n", a, (double)b, s, c, (double)sf, (double)cf);
  return a > 99.0 && a < 101.0 ? 0 : 1;
}
