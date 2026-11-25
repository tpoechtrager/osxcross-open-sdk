#include <CoreFoundation/CoreFoundation.h>
#include <stdio.h>

static void timer_cb(CFRunLoopTimerRef t, void *info) { (*(int *)info)++; if (*(int *)info == 3) CFRunLoopStop(CFRunLoopGetCurrent()); }

int main(void) {
  CFStringRef s = CFStringCreateWithFormat(NULL, NULL, CFSTR("%d-%@"), 42, CFSTR("open"));
  char buf[64]; CFStringGetCString(s, buf, sizeof buf, kCFStringEncodingUTF8); printf("CFString '%s' len=%ld\n", buf, (long)CFStringGetLength(s));
  CFMutableArrayRef a = CFArrayCreateMutable(NULL, 0, &kCFTypeArrayCallBacks); CFArrayAppendValue(a, s); CFArrayAppendValue(a, CFSTR("sdk"));
  CFStringRef j = CFStringCreateByCombiningStrings(NULL, a, CFSTR("+")); CFStringGetCString(j, buf, sizeof buf, kCFStringEncodingUTF8); printf("CFArray join '%s' count=%ld\n", buf, (long)CFArrayGetCount(a));
  CFMutableDictionaryRef d = CFDictionaryCreateMutable(NULL, 0, &kCFTypeDictionaryKeyCallBacks, &kCFTypeDictionaryValueCallBacks);
  int n = 7; CFNumberRef num = CFNumberCreate(NULL, kCFNumberIntType, &n); CFDictionarySetValue(d, CFSTR("k"), num);
  CFNumberRef got = CFDictionaryGetValue(d, CFSTR("k")); int back = 0; CFNumberGetValue(got, kCFNumberIntType, &back); printf("CFDictionary k=%d\n", back);
  CFDataRef xml = CFPropertyListCreateData(NULL, d, kCFPropertyListXMLFormat_v1_0, 0, NULL); printf("plist xml bytes=%ld\n", (long)CFDataGetLength(xml));
  CFPropertyListRef pl = CFPropertyListCreateWithData(NULL, xml, kCFPropertyListImmutable, NULL, NULL); printf("plist roundtrip type=%s\n", CFGetTypeID(pl) == CFDictionaryGetTypeID() ? "dict" : "?");
  CFURLRef u = CFURLCreateWithString(NULL, CFSTR("https://example.org/a/b.txt?q=1"), NULL); CFStringRef host = CFURLCopyHostName(u); CFStringGetCString(host, buf, sizeof buf, kCFStringEncodingUTF8); printf("CFURL host=%s\n", buf);
  CFUUIDRef uu = CFUUIDCreate(NULL); CFStringRef us = CFUUIDCreateString(NULL, uu); printf("CFUUID len=%ld\n", (long)CFStringGetLength(us));
  CFAbsoluteTime t0 = CFAbsoluteTimeGetCurrent(); CFGregorianDate g = CFAbsoluteTimeGetGregorianDate(t0, NULL); printf("year>=2024 %d\n", g.year >= 2024);
  int ticks = 0; CFRunLoopTimerContext ctx = {0, &ticks, NULL, NULL, NULL};
  CFRunLoopTimerRef tm = CFRunLoopTimerCreate(NULL, CFAbsoluteTimeGetCurrent() + 0.01, 0.01, 0, 0, timer_cb, &ctx);
  CFRunLoopAddTimer(CFRunLoopGetCurrent(), tm, kCFRunLoopDefaultMode); CFRunLoopRunInMode(kCFRunLoopDefaultMode, 2.0, false); printf("runloop ticks=%d\n", ticks);
  printf("CF version number %.0f\n", kCFCoreFoundationVersionNumber > 1000 ? 1.0 : 0.0);
  return ticks == 3 ? 0 : 1;
}
