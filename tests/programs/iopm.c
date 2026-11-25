/* SPDX-License-Identifier: 0BSD */
/* IOPMLib.h: a power assertion that keeps the system awake while the program runs. */
#include <CoreFoundation/CoreFoundation.h>
#include <IOKit/pwr_mgt/IOPMLib.h>
#include <stdio.h>

int main(void) {
  IOPMAssertionID id = 0;
  IOReturn r = IOPMAssertionCreateWithName(kIOPMAssertionTypeNoIdleSleep, kIOPMAssertionLevelOn,
                                           CFSTR("osxcross-open-sdk test"), &id);
  if (r != kIOReturnSuccess) return 1;
  if (IOPMAssertionRelease(id) != kIOReturnSuccess) return 2;
  puts("iopm ok");
  return 0;
}
