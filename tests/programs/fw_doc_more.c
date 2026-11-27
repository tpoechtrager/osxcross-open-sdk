/* WebKit, UniformTypeIdentifiers, OpenDirectory (data/symbols/doc/): no headers, a program declares the
   names itself; the constants are objects of these frameworks, the functions are those of Open Directory's C interface */
#include <CoreFoundation/CoreFoundation.h>
#include <stdio.h>

typedef const struct __ODSession *ODSessionRef;
typedef const struct __ODNode *ODNodeRef;
typedef const struct __ODRecord *ODRecordRef;

extern const CFStringRef WKErrorDomain, WKWebsiteDataTypeCookies;
extern const CFStringRef UTTagClassFilenameExtension;
extern const void *const UTTypePNG;
extern const CFStringRef kODRecordTypeUsers, kODAttributeTypeRecordName, kODAttributeTypeUniqueID;
extern ODSessionRef ODSessionCreate(CFAllocatorRef, CFDictionaryRef, CFErrorRef *);
extern ODNodeRef ODNodeCreateWithNodeType(CFAllocatorRef, ODSessionRef, unsigned int, CFErrorRef *);
extern ODRecordRef ODNodeCopyRecord(ODNodeRef, CFStringRef, CFStringRef, CFArrayRef, CFErrorRef *);
extern CFArrayRef ODRecordCopyValues(ODRecordRef, CFStringRef, CFErrorRef *);

static void show(const char *label, CFStringRef s) {
  char buf[256] = "(null)";
  if (s) CFStringGetCString(s, buf, sizeof buf, kCFStringEncodingUTF8);
  printf("%s: %s\n", label, buf);
}

int main(void) {
  show("WKErrorDomain", WKErrorDomain);
  show("WKWebsiteDataTypeCookies", WKWebsiteDataTypeCookies);
  show("UTTagClassFilenameExtension", UTTagClassFilenameExtension);
  printf("UTTypePNG: %s\n", UTTypePNG ? "yes" : "no");
  show("kODRecordTypeUsers", kODRecordTypeUsers);
  ODSessionRef s = ODSessionCreate(0, 0, 0);
  printf("ODSessionCreate: %s\n", s ? "yes" : "no");
  ODNodeRef n = ODNodeCreateWithNodeType(0, s, 0x2201 /* kODNodeTypeAuthentication */, 0);
  printf("ODNodeCreateWithNodeType: %s\n", n ? "yes" : "no");
  if (n) {
    CFStringRef r = CFSTR("root");
    ODRecordRef rec = ODNodeCopyRecord(n, kODRecordTypeUsers, r, 0, 0);
    printf("ODNodeCopyRecord: %s\n", rec ? "yes" : "no");
    if (rec) {
      CFArrayRef v = ODRecordCopyValues(rec, kODAttributeTypeUniqueID, 0);
      if (v && CFArrayGetCount(v) > 0) show("root uid", CFArrayGetValueAtIndex(v, 0));
    }
  }
  return 0;
}
