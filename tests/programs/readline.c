/* SPDX-License-Identifier: 0BSD */
/* <readline/readline.h> and -lreadline are libedit's compatibility layer. */
#include <stdio.h>
#include <stdlib.h>
#include <readline/readline.h>
#include <readline/history.h>
int main(void) { char *l = readline("> "); if (!l) return 1; add_history(l); printf("got: %s\n", l); free(l); return 0; }
