/* SPDX-License-Identifier: 0BSD */
/* libdispatch: queues, groups, semaphores, once, apply, timer and signal-free sources, and blocks. */
#include <dispatch/dispatch.h>
#include <Block.h>
#include <stdatomic.h>
#include <stdio.h>

static atomic_int count;
static void add(void *ctx) { atomic_fetch_add(&count, (int)(long)ctx); }
static void apply(void *ctx, size_t i) { (void)ctx; atomic_fetch_add(&count, (int)i); }
static void once(void *ctx) { ++*(int *)ctx; }
static void fire(void *ctx) { dispatch_semaphore_signal((dispatch_semaphore_t)ctx); }

int main(void) {
  dispatch_queue_t conc = dispatch_get_global_queue(QOS_CLASS_DEFAULT, 0);
  dispatch_queue_t ser = dispatch_queue_create("test.serial", DISPATCH_QUEUE_SERIAL);
  dispatch_group_t g = dispatch_group_create();
  for (long i = 1; i <= 10; i++) dispatch_group_async_f(g, conc, (void *)i, add);
  if (dispatch_group_wait(g, dispatch_time(DISPATCH_TIME_NOW, 5 * NSEC_PER_SEC)) != 0 || count != 55) return 1;
  dispatch_apply_f(10, conc, NULL, apply);
  dispatch_sync_f(ser, (void *)100L, add);
  if (count != 200) return 2;

  static dispatch_once_t pred; int n = 0;
  dispatch_once_f(&pred, &n, once); dispatch_once_f(&pred, &n, once);
  if (n != 1) return 3;

  dispatch_semaphore_t sem = dispatch_semaphore_create(0);
  dispatch_source_t t = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, ser);
  dispatch_set_context(t, sem);
  dispatch_source_set_event_handler_f(t, fire);
  dispatch_source_set_timer(t, dispatch_time(DISPATCH_TIME_NOW, 10 * NSEC_PER_MSEC), DISPATCH_TIME_FOREVER, 0);
  dispatch_resume(t);
  if (dispatch_semaphore_wait(sem, dispatch_time(DISPATCH_TIME_NOW, 5 * NSEC_PER_SEC)) != 0) return 4;
  dispatch_source_cancel(t);
  dispatch_release(t);

#ifdef __BLOCKS__
  __block int b = 0;
  void (^inc)(void) = Block_copy(^{ b += 2; });
  dispatch_sync(ser, inc);
  dispatch_group_async(g, conc, ^{ atomic_fetch_add(&count, 1); });
  dispatch_group_wait(g, DISPATCH_TIME_FOREVER);
  dispatch_async(ser, ^{ dispatch_semaphore_signal(sem); });
  dispatch_semaphore_wait(sem, DISPATCH_TIME_FOREVER);
  Block_release(inc);
  if (b != 2 || count != 201) return 5;
  dispatch_data_t d = dispatch_data_create("abc", 3, NULL, DISPATCH_DATA_DESTRUCTOR_DEFAULT);
  if (dispatch_data_get_size(d) != 3) return 6;
  dispatch_release(d);
#endif
  dispatch_release(sem); dispatch_release(g); dispatch_release(ser);
  printf("dispatch: ok (%d)\n", count);
  return 0;
}
