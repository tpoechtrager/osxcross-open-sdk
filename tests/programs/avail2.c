#include <Availability.h>
#include <AvailabilityMacros.h>
#include <os/availability.h>
#include <stdio.h>
API_AVAILABLE(macos(26.0), ios(26.0), tvos(26.0), watchos(26.0), visionos(26.0)) static int a1(void) { return 1; }
API_AVAILABLE(macos(15.1), ios(18.1), macCatalyst(18.1), xros(2.1)) static int a2(void) { return 2; }
API_AVAILABLE(macos(15.4), iosmac(18.4)) static int a3(void) { return 3; }
API_DEPRECATED_WITH_REPLACEMENT("a1", macos(10.13, 26.0)) static int a4(void) { return 4; }
API_UNAVAILABLE(macos) static int a5(void) { return 5; }
API_AVAILABLE_BEGIN(macos(26.0))
static int a6(void) { return 6; }
API_AVAILABLE_END
#if __MAC_OS_X_VERSION_MIN_REQUIRED >= __MAC_26_0
#define MODE "min>=26"
#else
#define MODE "min<26"
#endif
int main(void) {
  int r = 0;
  if (__builtin_available(macOS 26.0, iOS 26.0, *)) { r += a1() + a6(); }
  if (__builtin_available(macOS 15.4, *)) { r += a2() + a3(); }
  printf("%s %d MAC_16_0=%d IPHONE_19_0=%d\n", MODE, r, __MAC_16_0, __IPHONE_19_0);
  return 0;
}
