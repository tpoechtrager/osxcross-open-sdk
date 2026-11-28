/* SPDX-License-Identifier: 0BSD */
/* The Darwin APIs that runtimes (Go, Rust std, Python, Chromium) call: Mach time, task and host info,
   Mach ports, sysctl, kqueue, posix_spawn, libproc, dyld, dlopen, os_unfair_lock, backtrace. */
#include <mach/mach.h>
#include <mach/mach_time.h>
#include <mach-o/dyld.h>
#include <sys/sysctl.h>
#include <sys/event.h>
#include <sys/wait.h>
#include <sys/random.h>
#include <libproc.h>
#include <spawn.h>
#include <dlfcn.h>
#include <execinfo.h>
#include <os/lock.h>
#include <crt_externs.h>
#include <pthread.h>
#include <setjmp.h>
#include <fcntl.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>
#include <unistd.h>

static jmp_buf jb;
static void jump(void) { longjmp(jb, 7); }

int main(void) {
  mach_timebase_info_data_t tb;
  if (mach_timebase_info(&tb) != KERN_SUCCESS || tb.denom == 0) return 1;
  uint64_t t0 = mach_absolute_time(), t1 = mach_continuous_time();
  if (t0 == 0 || t1 == 0 || clock_gettime_nsec_np(CLOCK_UPTIME_RAW) == 0) return 2;

  struct mach_task_basic_info ti;
  mach_msg_type_number_t n = MACH_TASK_BASIC_INFO_COUNT;
  if (task_info(mach_task_self(), MACH_TASK_BASIC_INFO, (task_info_t)&ti, &n) != KERN_SUCCESS || ti.resident_size == 0) return 3;
  vm_statistics64_data_t vs;
  n = HOST_VM_INFO64_COUNT;
  mach_port_t host = mach_host_self();
  if (host_statistics64(host, HOST_VM_INFO64, (host_info64_t)&vs, &n) != KERN_SUCCESS) return 4;
  mach_port_deallocate(mach_task_self(), host);
  mach_port_t port;
  if (mach_port_allocate(mach_task_self(), MACH_PORT_RIGHT_RECEIVE, &port) != KERN_SUCCESS) return 5;
  mach_port_mod_refs(mach_task_self(), port, MACH_PORT_RIGHT_RECEIVE, -1);
  uint64_t tid = 0;
  if (pthread_threadid_np(NULL, &tid) != 0 || tid == 0) return 6;
  mach_port_t th = pthread_mach_thread_np(pthread_self());
  if (th == MACH_PORT_NULL) return 6;

  int ncpu = 0; size_t len = sizeof ncpu;
  char os[64]; size_t oslen = sizeof os;
  if (sysctlbyname("hw.ncpu", &ncpu, &len, NULL, 0) != 0 || ncpu < 1) return 7;
  int mib[2] = { CTL_KERN, KERN_OSTYPE };
  if (sysctl(mib, 2, os, &oslen, NULL, 0) != 0 || strcmp(os, "Darwin") != 0) return 8;

  int kq = kqueue(), fds[2];
  if (kq < 0 || pipe(fds) != 0) return 9;
  struct kevent ev[2], out;
  EV_SET(&ev[0], fds[0], EVFILT_READ, EV_ADD, 0, 0, NULL);
  EV_SET(&ev[1], 1, EVFILT_TIMER, EV_ADD | EV_ONESHOT, 0, 10, NULL);
  if (kevent(kq, ev, 2, NULL, 0, NULL) != 0) return 10;
  struct timespec to = { 2, 0 };
  if (kevent(kq, NULL, 0, &out, 1, &to) != 1 || out.filter != EVFILT_TIMER) return 11;
  if (write(fds[1], "x", 1) != 1 || kevent(kq, NULL, 0, &out, 1, &to) != 1 || out.filter != EVFILT_READ) return 12;
  close(kq); close(fds[0]); close(fds[1]);

  pid_t pid; int st;
  char *argv[] = { "/bin/sh", "-c", "exit 3", NULL };
  posix_spawn_file_actions_t fa;
  posix_spawn_file_actions_init(&fa);
  posix_spawn_file_actions_addopen(&fa, 1, "/dev/null", O_WRONLY, 0);
  if (posix_spawn(&pid, argv[0], &fa, NULL, argv, *_NSGetEnviron()) != 0) return 13;
  posix_spawn_file_actions_destroy(&fa);
  if (waitpid(pid, &st, 0) != pid || !WIFEXITED(st) || WEXITSTATUS(st) != 3) return 14;

  struct proc_taskinfo pti;
  char name[2 * MAXCOMLEN + 1], path[PROC_PIDPATHINFO_MAXSIZE];
  if (proc_pidinfo(getpid(), PROC_PIDTASKINFO, 0, &pti, sizeof pti) != (int)sizeof pti) return 15;
  if (proc_name(getpid(), name, sizeof name) <= 0 || proc_pidpath(getpid(), path, sizeof path) <= 0) return 16;

  char exe[1024]; uint32_t exelen = sizeof exe;
  if (_NSGetExecutablePath(exe, &exelen) != 0 || _dyld_image_count() < 2 || !_dyld_get_image_name(0)) return 17;
  if (!_dyld_get_image_header(0)) return 17;
  Dl_info di;
  if (!dladdr((void *)&printf, &di) || !di.dli_fname) return 18;
  void *h = dlopen("/usr/lib/libSystem.B.dylib", RTLD_NOW);
  pid_t (*gp)(void) = h ? (pid_t (*)(void))dlsym(h, "getpid") : NULL;
  if (!gp || gp() != getpid()) return 19;
  if (dlopen("/no/such/lib.dylib", RTLD_NOW) || !dlerror()) return 20;

  os_unfair_lock lk = OS_UNFAIR_LOCK_INIT;
  os_unfair_lock_lock(&lk);
  os_unfair_lock_assert_owner(&lk);
  os_unfair_lock_unlock(&lk);
  void *frames[16];
  int nf = backtrace(frames, 16);
  char **syms = backtrace_symbols(frames, nf);
  if (nf < 1 || !syms) return 21;
  free(syms);
  if (setjmp(jb) == 0) jump();
  if (arc4random_uniform(10) >= 10) return 22;
  unsigned char rnd[16];
  if (getentropy(rnd, sizeof rnd) != 0) return 23;

  printf("darwin: %d cpus, %s, images %u, timebase %u/%u, pid name %s\n", ncpu, os, _dyld_image_count(), tb.numer, tb.denom, name);
  return 0;
}
