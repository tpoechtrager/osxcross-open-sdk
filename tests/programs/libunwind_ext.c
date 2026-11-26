/* SPDX-License-Identifier: 0BSD */
/* Functions of libunwind that no header of the SDK declares (data/symbols/libunwind.txt):
   the way LLVM's JIT registers unwind information.  The declarations are those of
   libunwind/src/libunwind_ext.h.  The program links against the stubs, walks the
   cache of FDEs and asks libdyld for the unwind sections of main. */
#include <libunwind.h>
#include <stdbool.h>
#include <stdio.h>

extern void __unw_add_dynamic_fde(unw_word_t);
extern void __unw_remove_dynamic_fde(unw_word_t);
extern void unw_iterate_dwarf_unwind_cache(void (*)(unw_word_t, unw_word_t, unw_word_t, unw_word_t));
extern bool _dyld_find_unwind_sections(void *, void *);

static int entries;
static void count(unw_word_t a, unw_word_t b, unw_word_t c, unw_word_t d) { (void)a; (void)b; (void)c; (void)d; entries++; }

int main(void) {
  /* not called: they need a real FDE */
  void *volatile fns[] = { (void *)__unw_add_dynamic_fde, (void *)__unw_remove_dynamic_fde };
  unw_iterate_dwarf_unwind_cache(count);
  char info[256] = { 0 };   /* struct dyld_unwind_sections: only has to be big enough */
  int found = _dyld_find_unwind_sections((void *)main, info);
  printf("%d %d\n", found, fns[0] != 0 && fns[1] != 0);
  return found ? 0 : 1;
}
