/* SPDX-License-Identifier: 0BSD */
/* The USB constants of IOKit/usb/USB.h that the open headers lack and the keys of
   IOKit/IOUserServer.h in use: the USB devices in the registry, the user servers of DriverKit. */
#include <CoreFoundation/CoreFoundation.h>
#include <IOKit/IOKitLib.h>
#include <IOKit/IOUserServer.h>
#include <IOKit/usb/IOUSBLib.h>
#include <stdio.h>
#include <string.h>

_Static_assert(kUSBHubPortConnectionFeature == 0 && kUSBHubPortResetChangeFeature == 20, "hub features");
_Static_assert(kUSBBillBoardClass == 17 && kUSBRootHubPollingRate == 32, "classes");
_Static_assert(kUSBDeviceSpeedSuperPlus == 4 && kUSBReEnumerateReleaseDeviceBit == 29, "speeds, re-enumerate");

static long count(const char *cls) {
  io_iterator_t it;
  long n = 0;
  io_object_t o;
  if (IOServiceGetMatchingServices(MACH_PORT_NULL, IOServiceMatching(cls), &it) != KERN_SUCCESS) return -1;
  while ((o = IOIteratorNext(it))) { n++; IOObjectRelease(o); }
  IOObjectRelease(it);
  return n;
}

int main(void) {
  long hosts = count("IOUSBHostDevice"), servers = count(kIOUserServerClassKey);
  if (hosts < 0 || servers < 0) return 1;
  if ((kUSBReEnumerateReleaseDeviceMask >> kUSBReEnumerateReleaseDeviceBit) != 1) return 2;
  if (strcmp(kIOUserServerNameKey, "IOUserServerName") || strcmp(kIOUserServerTagKey, "IOUserServerTag")) return 3;
  printf("iokit_usb ok: %ld USB host devices, %ld user servers\n", hosts, servers);
  return 0;
}
