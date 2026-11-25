#include <CoreFoundation/CoreFoundation.h>
#include <DiskArbitration/DiskArbitration.h>
#include <SystemConfiguration/SystemConfiguration.h>
#include <IOKit/IOKitLib.h>
#include <IOKit/ps/IOPowerSources.h>
#include <stdio.h>

int main(void) {
  DASessionRef ses = DASessionCreate(NULL); DADiskRef disk = DADiskCreateFromBSDName(NULL, ses, "disk0");
  CFDictionaryRef desc = disk ? DADiskCopyDescription(disk) : NULL; printf("DiskArbitration session=%d disk0 desc=%s\n", ses != NULL, desc ? "yes" : "none");
  CFStringRef name = SCDynamicStoreCopyLocalHostName(NULL); char buf[128] = "?"; if (name) CFStringGetCString(name, buf, sizeof buf, kCFStringEncodingUTF8);
  printf("SystemConfiguration host name length=%zu\n", strlen(buf));
  SCNetworkReachabilityRef r = SCNetworkReachabilityCreateWithName(NULL, "localhost"); SCNetworkReachabilityFlags fl = 0; Boolean ok = r && SCNetworkReachabilityGetFlags(r, &fl);
  printf("SCNetworkReachability ok=%d reachable=%d\n", ok, (fl & kSCNetworkReachabilityFlagsReachable) != 0);
  io_service_t svc = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("IOPlatformExpertDevice"));
  CFTypeRef model = svc ? IORegistryEntryCreateCFProperty(svc, CFSTR("model"), NULL, 0) : NULL; printf("IOKit service=%d model=%s\n", svc != 0, model ? "yes" : "none");
  CFTypeRef ps = IOPSCopyPowerSourcesInfo(); printf("IOPS info=%s\n", ps ? "yes" : "none");
  return 0;
}
