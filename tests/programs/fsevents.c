/* SPDX-License-Identifier: 0BSD */
/* File System Events: a stream on a new directory sees a file that is created in it. */
#include <CoreServices/CoreServices.h>
#include <dispatch/dispatch.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

static char dir[PATH_MAX];
static dispatch_semaphore_t sem;

static void cb(ConstFSEventStreamRef s, void *info, size_t n, void *paths, const FSEventStreamEventFlags *flags,
               const FSEventStreamEventId *ids) {
  (void)s; (void)info; (void)ids;
  for (size_t i = 0; i < n; i++) {
    const char *p = ((char **)paths)[i];
    if (strstr(p, "/created") && (flags[i] & kFSEventStreamEventFlagItemCreated)) dispatch_semaphore_signal(sem);
  }
}

int main(void) {
  char tmpl[] = "/tmp/fsevents.XXXXXX";
  if (!mkdtemp(tmpl) || !realpath(tmpl, dir)) return 1;
  sem = dispatch_semaphore_create(0);
  CFStringRef path = CFStringCreateWithCString(NULL, dir, kCFStringEncodingUTF8);
  CFArrayRef paths = CFArrayCreate(NULL, (const void **)&path, 1, &kCFTypeArrayCallBacks);
  FSEventStreamRef s = FSEventStreamCreate(NULL, cb, NULL, paths, kFSEventStreamEventIdSinceNow, 0.05,
                                           kFSEventStreamCreateFlagFileEvents | kFSEventStreamCreateFlagNoDefer);
  if (!s) return 2;
  FSEventStreamSetDispatchQueue(s, dispatch_queue_create("fsevents", NULL));
  if (!FSEventStreamStart(s)) return 3;
  FSEventStreamFlushSync(s);
  char f[PATH_MAX + 16];
  snprintf(f, sizeof f, "%s/created", dir);
  FILE *fp = fopen(f, "w");
  if (!fp) return 4;
  fputs("x", fp); fclose(fp);
  long rc = dispatch_semaphore_wait(sem, dispatch_time(DISPATCH_TIME_NOW, 10 * NSEC_PER_SEC));
  FSEventStreamStop(s); FSEventStreamInvalidate(s); FSEventStreamRelease(s);
  CFRelease(paths); CFRelease(path);
  unlink(f); rmdir(dir);
  if (rc != 0) { printf("fsevents: no event\n"); return 5; }
  printf("fsevents: event for %s/created\n", dir);
  return 0;
}
