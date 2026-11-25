#include <stdio.h>
#include <string.h>
#include <curses.h>
#include <term.h>
#include <panel.h>
#include <form.h>
#include <menu.h>
#include <sqlite3.h>

int main(void) {
  SCREEN *s = newterm("xterm", fopen("/dev/null", "w"), fopen("/dev/null", "r"));
  if (!s) return 1;
  printf("ncurses %s lines=%d cols=%d\n", curses_version(), LINES, COLS);
  char *cup = tparm(tigetstr("cup"), 3, 4); printf("terminfo cup len=%d\n", (int)strlen(cup));
  WINDOW *w = newwin(5, 20, 1, 1); PANEL *p = new_panel(w); mvwprintw(w, 1, 1, "hi"); update_panels();
  printf("panel above=%p below=%p\n", (void *)panel_above(p), (void *)panel_below(p));
  FIELD *f[2] = { new_field(1, 10, 0, 0, 0, 0), NULL }; set_field_buffer(f[0], 0, "form"); 
  FORM *fm = new_form(f); printf("form field count=%d buf='%.4s'\n", field_count(fm), field_buffer(f[0], 0));
  ITEM *it[3] = { new_item("one", "first"), new_item("two", "second"), NULL }; MENU *m = new_menu(it); printf("menu items=%d\n", item_count(m));
  free_menu(m); free_item(it[0]); free_item(it[1]); free_form(fm); free_field(f[0]); del_panel(p); delwin(w); endwin(); delscreen(s);

  sqlite3 *db; char *err = 0; sqlite3_stmt *st;
  if (sqlite3_open(":memory:", &db)) return 2;
  sqlite3_exec(db, "create table t(a integer, b text); insert into t values (1,'x'),(2,'y'),(3,'z');", 0, 0, &err);
  sqlite3_prepare_v2(db, "select sum(a), group_concat(b) from t", -1, &st, 0); sqlite3_step(st);
  printf("sqlite %s sum=%d b=%s\n", sqlite3_libversion(), sqlite3_column_int(st, 0), sqlite3_column_text(st, 1));
  sqlite3_finalize(st); sqlite3_close(db);
  return 0;
}
