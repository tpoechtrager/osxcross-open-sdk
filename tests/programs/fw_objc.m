#import <objc/NSObject.h>
#import <objc/runtime.h>
#include <CoreFoundation/CoreFoundation.h>
#include <stdio.h>

int main(void) {
  {
    CFStringRef s = CFStringCreateWithCString(NULL, "bridged", kCFStringEncodingUTF8);
    id o = (id)s;                       /* toll-free cast: a CF object is an Objective-C object */
    Class c = object_getClass(o);
    printf("CF object class: %s, CFGetTypeID==CFStringGetTypeID: %d\n", class_getName(c), CFGetTypeID(s) == CFStringGetTypeID());
    id nso = [[NSObject alloc] init]; CFTypeRef kept = (CFTypeRef)nso;   /* ObjC object owned as CF object */
    printf("retain count via CF: %ld\n", (long)CFGetRetainCount(kept));
    CFRelease(kept);
    CFRelease(s);
  }
  return 0;
}
