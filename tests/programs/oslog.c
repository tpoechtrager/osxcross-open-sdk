/* os_log: every kind of message, the format specifiers of the compiler's
 * checker, a log object of our own.  Built as C and as C++ (tests/run.sh).
 * The messages can be seen with
 *   log show --last 2m --info --debug --predicate 'process == "oslog"'
 * Signposts, activities and os_trace are stand-ins that trace nothing; they
 * must compile, link without a new import and run.
 * Exit status 0 if the program ran. */
#include <os/log.h>
#include <os/signpost.h>
#include <os/activity.h>
#include <os/trace.h>
#include <stdio.h>

int main(void) {
  os_log_t mine = os_log_create("org.osxcross.test", "oslog");
  int n = 42;
  const char *who = "open sdk";

  os_log(OS_LOG_DEFAULT, "oslog test: default message, n=%d", n);
  os_log_info(OS_LOG_DEFAULT, "oslog test: info message, n=%d", n);
  os_log_debug(OS_LOG_DEFAULT, "oslog test: debug message, n=%d", n);
  os_log_error(OS_LOG_DEFAULT, "oslog test: error message, n=%d", n);
  os_log_fault(OS_LOG_DEFAULT, "oslog test: fault message, n=%d", n);
  os_log_with_type(mine, OS_LOG_TYPE_DEFAULT, "oslog test: own log, %{public}s", who);
  os_log(mine, "oslog test: private %{private}s, public %{public}s, long %ld, hex %x", who, who, 1234567890L, 255u);
  os_log(mine, "oslog test: no arguments");
  {
#ifdef __BLOCKS__
    __block
#endif
    int calls = 0;
    os_signpost_id_t id = os_signpost_id_generate(mine);
    os_signpost_id_t id2 = os_signpost_id_make_with_pointer(mine, &calls);
    os_signpost_interval_begin(mine, id, "work", "n=%d", ++calls);
    os_signpost_event_emit(mine, id, "event", OS_SIGNPOST_ENABLE_TELEMETRY);
    os_signpost_interval_end(mine, id, "work", "priority=%{public}d " OS_SIGNPOST_ENABLE_TELEMETRY, ++calls);
    os_signpost_emit_with_type(mine, OS_SIGNPOST_EVENT, id2, "typed", "n=%d", ++calls);
    if (os_signpost_enabled(mine))
      puts("signposts enabled");

    os_activity_t activity = os_activity_create("oslog test", OS_ACTIVITY_CURRENT, OS_ACTIVITY_FLAG_DEFAULT);
    os_activity_scope(activity);
    struct os_activity_scope_state_s state;
    os_activity_scope_enter(activity, &state);
    os_activity_scope_leave(&state);
    os_release(activity);
#ifdef __BLOCKS__
    os_activity_initiate("oslog test block", OS_ACTIVITY_FLAG_DEFAULT, ^{ calls += 10; });
    if (calls != 10) return 1;
#endif
    os_trace("oslog test: trace %d", ++calls);
    os_trace_error("oslog test: trace error");
    os_trace_debug("oslog test: trace debug %s", who);
    if (calls != 10) return 1; /* the arguments of the macros are not evaluated */
  }
  if (os_log_type_enabled(mine, OS_LOG_TYPE_DEFAULT))
    puts("enabled");
  puts("oslog done");
  return 0;
}
