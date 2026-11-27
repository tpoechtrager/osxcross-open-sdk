/* CoreFoundation declarations that CF-1153.18 lacks (data/CF, data/symbols/doc/CoreFoundation.txt) */
#include <CoreFoundation/CoreFoundation.h>
#include <mach/machine.h>
#include <stdio.h>
#include <string.h>

/* names with no header in the SDK: a program declares them itself */
extern CFTypeID CFStringTokenizerGetTypeID(void);
extern CFTypeID CFFileDescriptorGetTypeID(void);
extern CFTypeID CFFileSecurityGetTypeID(void);
extern CFTypeID CFURLEnumeratorGetTypeID(void);
extern CFTypeRef CFURLEnumeratorCreateForDirectoryURL(CFAllocatorRef, CFURLRef, CFOptionFlags, CFArrayRef);
extern CFIndex CFURLEnumeratorGetNextURL(CFTypeRef, CFURLRef *, CFErrorRef *);
extern const CFStringRef kCFStreamPropertySOCKSProxy;

static int got;
static void note_cb(CFNotificationCenterRef c, void *observer, CFNotificationName name, const void *object, CFDictionaryRef info) {
  (void)c; (void)object; (void)info; got += (observer == &got && CFEqual(name, CFSTR("open.sdk.note")));
}

static void str(const char *what, CFStringRef s) {
  char buf[128] = "?"; if (s) CFStringGetCString(s, buf, sizeof buf, kCFStringEncodingUTF8); printf("%s %s\n", what, buf);
}

int main(void) {
  int bad = 0;
  CFNotificationCenterRef lc = CFNotificationCenterGetLocalCenter();
  CFNotificationCenterAddObserver(lc, &got, note_cb, CFSTR("open.sdk.note"), NULL, CFNotificationSuspensionBehaviorDeliverImmediately);
  CFNotificationCenterPostNotification(lc, CFSTR("open.sdk.note"), NULL, NULL, true);
  CFNotificationCenterRemoveEveryObserver(lc, &got);
  CFNotificationCenterPostNotification(lc, CFSTR("open.sdk.note"), NULL, NULL, true);
  printf("notification delivered %d time(s)\n", got); bad += got != 1;
  bad += CFNotificationCenterGetDarwinNotifyCenter() == NULL;

  CFMutableAttributedStringRef as = CFAttributedStringCreateMutable(NULL, 0);
  CFAttributedStringReplaceString(as, CFRangeMake(0, 0), CFSTR("attributed"));
  CFAttributedStringSetAttribute(as, CFRangeMake(0, 4), CFSTR("k"), CFSTR("v"));
  CFRange r = {0, 0}; CFTypeRef v = CFAttributedStringGetAttribute(as, 1, CFSTR("k"), &r);
  printf("attributed string length %ld, attribute %s on %ld..%ld\n", (long)CFAttributedStringGetLength(as), v ? "set" : "missing", (long)r.location, (long)(r.location + r.length));
  bad += !v || r.location != 0 || r.length != 4;

  CFDateFormatterRef f = CFDateFormatterCreateISO8601Formatter(NULL, kCFISO8601DateFormatWithInternetDateTime);
  CFTimeZoneRef gmt = CFTimeZoneCreateWithTimeIntervalFromGMT(NULL, 0);   // not every system's formatter starts with GMT
  CFDateFormatterSetProperty(f, kCFDateFormatterTimeZone, gmt);
  CFStringRef iso = CFDateFormatterCreateStringWithAbsoluteTime(NULL, f, 0.0);
  str("ISO 8601 of absolute time 0:", iso);
  bad += !iso || !CFEqual(iso, CFSTR("2001-01-01T00:00:00Z"));

  CFLocaleRef en = CFLocaleCreate(NULL, CFSTR("en_US"));
  CFNumberFormatterRef nf = CFNumberFormatterCreate(NULL, en, kCFNumberFormatterOrdinalStyle);
  int two = 2; CFStringRef ord = CFNumberFormatterCreateStringWithValue(NULL, nf, kCFNumberIntType, &two);
  str("ordinal of 2:", ord); bad += !ord || !CFEqual(ord, CFSTR("2nd"));

  cpu_type_t here =
#if defined(__arm64__)
    CPU_TYPE_ARM64;
#else
    CPU_TYPE_X86_64;
#endif
  printf("this architecture is loadable: %d\n", CFBundleIsArchitectureLoadable(here)); bad += !CFBundleIsArchitectureLoadable(here);
  bad += kCFBundleExecutableArchitectureARM64 != CPU_TYPE_ARM64;

  CFURLRef root = CFURLCreateWithFileSystemPath(NULL, CFSTR("/"), kCFURLPOSIXPathStyle, true);
  CFTypeRef isroot = NULL; CFURLCopyResourcePropertyForKey(root, kCFURLVolumeIsRootFileSystemKey, &isroot, NULL);
  printf("kCFURLVolumeIsRootFileSystemKey of /: %s\n", isroot == kCFBooleanTrue ? "true" : "not true"); bad += isroot != kCFBooleanTrue;
  CFTypeRef canon = NULL; CFURLCopyResourcePropertyForKey(root, kCFURLCanonicalPathKey, &canon, NULL);
  str("kCFURLCanonicalPathKey of /:", canon);
  CFTypeRef isapp = NULL; CFURLCopyResourcePropertyForKey(root, kCFURLIsApplicationKey, &isapp, NULL);
  printf("kCFURLIsApplicationKey of /: %s\n", isapp == kCFBooleanFalse ? "false" : "not false"); bad += isapp != kCFBooleanFalse;
  CFShow(kCFErrorLocalizedFailureKey); CFShow(kCFUserNotificationAlertTopMostKey);

  printf("type IDs: tokenizer %d, file descriptor %d, file security %d, url enumerator %d\n", CFStringTokenizerGetTypeID() != 0,
         CFFileDescriptorGetTypeID() != 0, CFFileSecurityGetTypeID() != 0, CFURLEnumeratorGetTypeID() != 0);
  bad += !CFStringTokenizerGetTypeID() || !CFFileDescriptorGetTypeID() || !CFFileSecurityGetTypeID() || !CFURLEnumeratorGetTypeID();
  CFURLRef sys = CFURLCreateWithFileSystemPath(NULL, CFSTR("/System"), kCFURLPOSIXPathStyle, true);
  CFTypeRef en2 = CFURLEnumeratorCreateForDirectoryURL(NULL, sys, 0, NULL);
  CFURLRef next = NULL; CFIndex res = en2 ? CFURLEnumeratorGetNextURL(en2, &next, NULL) : -1;
  printf("URL enumerator of /System: first result %ld (1 is success)\n", (long)res); bad += res != 1;
  printf("kCFStreamPropertySOCKSProxy is %s\n", kCFStreamPropertySOCKSProxy ? "there" : "missing"); bad += !kCFStreamPropertySOCKSProxy;
  printf("version number of 10.11 %.0f\n", kCFCoreFoundationVersionNumber10_11_Max + 0.0);
  return bad ? 1 : 0;
}
