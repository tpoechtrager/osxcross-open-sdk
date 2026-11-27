/* the typed string aliases, CFRunLoopRunResult, the typed enumerations and the nullability of CoreFoundation
   (data/CF/typed.patch): typed and plain declarations mix, as in programs written for the older headers */
#include <CoreFoundation/CoreFoundation.h>
#include <stdio.h>
#include <string.h>

static CFStringRef plain_modes[] = { NULL, NULL };
static int scheduled;
static void on_schedule(void *info, CFRunLoopRef rl, CFStringRef mode) { (void)info; (void)rl; (void)mode; scheduled++; }
static void on_bytes(CFReadStreamRef s, CFStreamEventType t, void *info) { (void)s; (void)t; (void)info; }

static void str(const char *what, CFStringRef s) {
  char buf[128] = "?"; if (s) CFStringGetCString(s, buf, sizeof buf, kCFStringEncodingUTF8); printf("%s %s\n", what, buf);
}

int main(void) {
  int bad = 0;
  CFStringRef mode = kCFRunLoopDefaultMode;                /* a typed constant into a CFStringRef */
  SInt32 r = CFRunLoopRunInMode(mode, 0.0, false);         /* the result into an SInt32 */
  CFRunLoopRunResult rr = CFRunLoopRunInMode(kCFRunLoopDefaultMode, 0.0, false);
  plain_modes[0] = kCFRunLoopCommonModes;
  printf("run loop %d %d\n", (int)r, (int)rr);
  bad += !(r == kCFRunLoopRunFinished || r == kCFRunLoopRunTimedOut);

  CFLocaleRef loc = CFLocaleCreate(NULL, CFSTR("en_US"));   /* a CFSTR into a CFLocaleIdentifier */
  CFStringRef ident = CFLocaleGetIdentifier(loc);
  CFStringRef key = kCFLocaleCurrencyCode;
  CFTypeRef cur = CFLocaleGetValue(loc, key);
  str("locale", ident); str("currency", (CFStringRef)cur);
  bad += !(cur && CFEqual(cur, CFSTR("USD")));

  CFCalendarRef cal = CFCalendarCreateWithIdentifier(NULL, kCFGregorianCalendar);
  str("calendar", CFCalendarGetIdentifier(cal));
  bad += !(CFCalendarGetIdentifier(cal) && CFEqual(CFCalendarGetIdentifier(cal), kCFGregorianCalendar));

  CFErrorRef err = CFErrorCreate(NULL, kCFErrorDomainPOSIX, 2, NULL);
  CFStringRef dom = CFErrorGetDomain(err);
  bad += !CFEqual(dom, kCFErrorDomainPOSIX);

  CFNumberFormatterRef nf = CFNumberFormatterCreate(NULL, loc, kCFNumberFormatterDecimalStyle);
  int two = 2;
  CFNumberRef n2 = CFNumberCreate(NULL, kCFNumberIntType, &two);
  CFNumberFormatterSetProperty(nf, kCFNumberFormatterMinFractionDigits, n2);
  CFRelease(n2);
  CFStringRef k2 = kCFNumberFormatterMaxFractionDigits;
  CFTypeRef t = CFNumberFormatterCopyProperty(nf, k2);
  if (t) CFRelease(t);
  CFDateFormatterRef df = CFDateFormatterCreate(NULL, loc, kCFDateFormatterShortStyle, kCFDateFormatterNoStyle);
  CFTypeRef tz = CFDateFormatterCopyProperty(df, kCFDateFormatterTimeZone);
  bad += !tz;
  if (tz) CFRelease(tz);

  CFRunLoopSourceContext sc;
  memset(&sc, 0, sizeof sc);
  sc.schedule = on_schedule; sc.cancel = on_schedule;
  CFRunLoopSourceRef src = CFRunLoopSourceCreate(NULL, 0, &sc);
  CFRunLoopAddSource(CFRunLoopGetCurrent(), src, kCFRunLoopDefaultMode);
  CFRunLoopRemoveSource(CFRunLoopGetCurrent(), src, mode);
  bad += (scheduled != 2);
  CFRelease(src);

  static const UInt8 bytes[] = "ab";
  CFReadStreamRef rs = CFReadStreamCreateWithBytesNoCopy(NULL, bytes, 2, kCFAllocatorNull);
  CFStreamClientContext ctx = { 0, NULL, NULL, NULL, NULL };
  bad += !CFReadStreamSetClient(rs, kCFStreamEventHasBytesAvailable, on_bytes, &ctx);
  CFReadStreamScheduleWithRunLoop(rs, CFRunLoopGetCurrent(), kCFRunLoopCommonModes);
  CFReadStreamUnscheduleFromRunLoop(rs, CFRunLoopGetCurrent(), kCFRunLoopCommonModes);
  bad += !CFReadStreamOpen(rs);
  CFReadStreamClose(rs);
  CFRelease(rs);

  /* CFPreferences: the optional pointer and the optional value */
  Boolean exists = true;
  CFPreferencesGetAppBooleanValue(CFSTR("open.sdk.no.such.key"), kCFPreferencesCurrentApplication, &exists);
  CFPreferencesGetAppBooleanValue(CFSTR("open.sdk.no.such.key"), kCFPreferencesCurrentApplication, NULL);
  CFPropertyListRef pv = CFPreferencesCopyAppValue(CFSTR("open.sdk.no.such.key"), kCFPreferencesCurrentApplication);
  bad += (exists || pv != NULL);

  /* enumerations with a type: values and use as plain integers */
  int levels[] = { kCFUserNotificationStopAlertLevel, kCFUserNotificationPlainAlertLevel, kCFUserNotificationCancelResponse };
  CFOptionFlags fl = kCFSocketAutomaticallyReenableReadCallBack | kCFSocketLeaveErrors;
  SInt32 mp = kCFMessagePortSendTimeout;
  CFIndex pe = kCFPropertyListReadCorruptError;
  printf("values %d %d %d %d %ld %d %ld\n", levels[0], levels[1], levels[2], (int)fl, (long)mp, (int)kCFCalendarComponentsWrap, (long)pe);
  bad += !(levels[1] == 3 && fl == 65 && mp == -1 && pe == 3840 && kCFCalendarComponentsWrap == 1);

  CFRelease(nf); CFRelease(df); CFRelease(err); CFRelease(cal); CFRelease(loc);
  printf("%s\n", bad ? "FAIL" : "ok");
  return bad != 0;
}
