/* SPDX-License-Identifier: 0BSD */
/* The IOKit device families: the HID devices (IOHIDManager), the statistics of the block storage
   drivers (IOKit/storage), the displays (IOGraphicsLib.h), the constants of hidsystem/ and the
   plug-in interface of the USB devices (IOKit/usb). */
#include <CoreFoundation/CoreFoundation.h>
#include <IOKit/IOKitLib.h>
#include <IOKit/hid/IOHIDManager.h>
#include <IOKit/hid/IOHIDKeys.h>
#include <IOKit/hidsystem/IOHIDLib.h>
#include <IOKit/hidsystem/ev_keymap.h>
#include <IOKit/storage/IOBlockStorageDriver.h>
#include <IOKit/storage/IOMedia.h>
#include <IOKit/graphics/IOGraphicsLib.h>
#include <IOKit/graphics/IOFramebufferShared.h>
#include <IOKit/usb/IOUSBLib.h>
#include <stdio.h>

int main(void) {
  IOHIDManagerRef m = IOHIDManagerCreate(kCFAllocatorDefault, kIOHIDOptionsTypeNone);
  if (!m) return 1;
  IOHIDManagerSetDeviceMatching(m, NULL);
  CFSetRef devs = IOHIDManagerCopyDevices(m);
  long ndev = devs ? (long)CFSetGetCount(devs) : 0;
  if (devs) CFRelease(devs);
  CFRelease(m);

  /* the statistics of every block storage driver, as htop and iostat read them (MACH_PORT_NULL:
     the default main port) */
  io_iterator_t it;
  if (IOServiceGetMatchingServices(MACH_PORT_NULL, IOServiceMatching(kIOBlockStorageDriverClass), &it)
      != KERN_SUCCESS) return 2;
  long ndrv = 0, nstat = 0;
  io_object_t d;
  while ((d = IOIteratorNext(it))) {
    CFDictionaryRef st = IORegistryEntryCreateCFProperty(d, CFSTR(kIOBlockStorageDriverStatisticsKey),
                                                         kCFAllocatorDefault, 0);
    ndrv++;
    if (st) {
      if (CFDictionaryContainsKey(st, CFSTR(kIOBlockStorageDriverStatisticsBytesReadKey))) nstat++;
      CFRelease(st);
    }
    IOObjectRelease(d);
  }
  IOObjectRelease(it);

  io_service_t fb = IOServiceGetMatchingService(MACH_PORT_NULL, IOServiceMatching(IOFRAMEBUFFER_CONFORMSTO));
  if (fb) {
    CFDictionaryRef info = IODisplayCreateInfoDictionary(fb, kIODisplayOnlyPreferredName);
    if (info) CFRelease(info);
    IOObjectRelease(fb);
  }
  /* the USB interfaces of the registry, with the key that hidapi reads; the plug-in interface of a
     USB device is only looked up (no device is opened) */
  CFUUIDRef usbtype = kIOUSBDeviceUserClientTypeID;
  CFUUIDRef usbif = kIOUSBDeviceInterfaceID197;
  IOUSBDeviceInterface197 **usbdev = NULL;
  long nusb = 0;
  if (!usbtype || !usbif || usbdev) return 4;
  io_iterator_t uit;
  if (IOServiceGetMatchingServices(MACH_PORT_NULL, IOServiceMatching(kIOUSBInterfaceClassName), &uit)
      == KERN_SUCCESS) {
    io_object_t u;
    while ((u = IOIteratorNext(uit))) {
      CFTypeRef n = IORegistryEntryCreateCFProperty(u, CFSTR(kUSBInterfaceNumber), kCFAllocatorDefault, 0);
      if (n) { nusb++; CFRelease(n); }
      IOObjectRelease(u);
    }
    IOObjectRelease(uit);
  }
  printf("iokit_families ok: %ld USB interfaces with %s, "
         "%ld HID devices, %ld of %ld block storage drivers with statistics, "
         "key code of caps lock %d, HID access %d\n", nusb, kUSBInterfaceNumber,
         ndev, nstat, ndrv, NX_KEYTYPE_CAPS_LOCK, (int)IOHIDCheckAccess(kIOHIDRequestTypeListenEvent));
  return ndrv > 0 && nstat > 0 ? 0 : 3;
}
