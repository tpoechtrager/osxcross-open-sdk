#include <Availability.h>
#include <AvailabilityMacros.h>
#include <os/availability.h>
#include <stdio.h>

/* declarations with the markup of the newest releases */
API_AVAILABLE(macos(15.0)) static int f15(void) { return 15; }
API_AVAILABLE(macos(15.4), ios(18.4)) static int f154(void) { return 154; }
#ifdef __MAC_26_0
API_AVAILABLE(macos(26.0)) static int f26(void) { return 26; }
#endif
API_DEPRECATED("old", macos(10.9, 15.0)) static int fold(void) { return 1; }
API_UNAVAILABLE(ios) static int fnoios(void) { return 2; }
API_AVAILABLE_BEGIN(macos(15.1))
static int fbegin(void) { return 3; }
API_AVAILABLE_END
API_DEPRECATED_WITH_REPLACEMENT("f15", macos(10.13, 15.2)) static int fold2(void) { return 4; }
#ifdef __API_TO_BE_DEPRECATED_MACOS
static const int tbd = __API_TO_BE_DEPRECATED_MACOS;
#endif

int main(void) {
  printf("MIN_REQUIRED=%d MAX_ALLOWED=%d\n", __MAC_OS_X_VERSION_MIN_REQUIRED, __MAC_OS_X_VERSION_MAX_ALLOWED);
#ifdef __MAC_15_0
  printf("MAC_15_0=%d\n", __MAC_15_0);
#else
  puts("MAC_15_0 undefined");
#endif
#ifdef __MAC_15_5
  printf("MAC_15_5=%d\n", __MAC_15_5);
#else
  puts("MAC_15_5 undefined");
#endif
#ifdef __MAC_26_0
  printf("MAC_26_0=%d MAC_OS_VERSION_26_0=%d\n", __MAC_26_0, MAC_OS_VERSION_26_0);
#else
  puts("MAC_26_0 undefined");
#endif
#if __MAC_OS_X_VERSION_MAX_ALLOWED >= 150000
  puts("max>=15");
#endif
  int r = 0;
  if (__builtin_available(macOS 15.0, *)) { r += f15(); puts("runtime: macOS >= 15"); }
  if (__builtin_available(macOS 26.0, *)) { puts("runtime: macOS >= 26"); }
  return 0;
}
