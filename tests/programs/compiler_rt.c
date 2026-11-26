/* SPDX-License-Identifier: 0BSD */
/* Builtins of compiler-rt that libSystem provides (data/symbols/compiler-rt.txt):
   the program is linked without the compiler's own runtime library (-nodefaultlibs
   -lSystem), so every call that Clang makes for a 128-bit division, a conversion
   or an atomic operation on an object that is not lock-free must be resolved by
   libSystem, at link time (the .tbd) and when the program runs. */
#include <stdatomic.h>
#include <stdio.h>
#include <stdlib.h>

struct big { long a, b, c; };   /* 24 bytes: the atomic operations are library calls */

int main(int argc, char **argv) {
  unsigned long long x = argc > 1 ? strtoull(argv[1], 0, 10) : 123456789ULL;
  unsigned __int128 a = (unsigned __int128)x * 1000000007ULL * 1000000009ULL;
  unsigned __int128 b = x % 1000 + 7;
  unsigned __int128 q = a / b, r = a % b;
  __int128 s = (__int128)a / -(__int128)b, m = (__int128)a % -(__int128)b;
  volatile double d = (double)a;                         /* __floatuntidf */
  unsigned __int128 back = (unsigned __int128)(double)d; /* __fixunsdfti */

  _Atomic struct big v;
  struct big w = { x, x + 1, x + 2 }, e = { 0, 0, 0 }, n = { 1, 2, 3 };
  atomic_init(&v, w);
  struct big l = atomic_load(&v);                        /* __atomic_load */
  atomic_store(&v, n);                                   /* __atomic_store */
  struct big old = atomic_exchange(&v, w);               /* __atomic_exchange */
  int ok = atomic_compare_exchange_strong(&v, &e, n);    /* __atomic_compare_exchange */

  printf("%llu %llu %llu %llu %d %d\n", (unsigned long long)q, (unsigned long long)r,
         (unsigned long long)s, (unsigned long long)m, (int)(back > 0), (int)(l.c - l.a));
  return (q * b + r == a && l.a == (long)x && old.b == 2 && !ok && e.a == (long)x && back > 0) ? 0 : 1;
}
