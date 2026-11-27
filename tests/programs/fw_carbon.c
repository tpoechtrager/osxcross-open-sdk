/* Carbon: Text Input Sources and hot keys (data/symbols/Carbon-extra.txt); no headers, a program declares the names itself */
#include <CoreFoundation/CoreFoundation.h>
#include <stdio.h>

typedef const void *TISInputSourceRef;
typedef struct OpaqueEventHotKeyRef *EventHotKeyRef;
typedef struct { unsigned int signature, id; } EventHotKeyID;
typedef void *EventTargetRef;
typedef void *EventHandlerRef;
typedef void *EventRef;
typedef struct { unsigned int eventClass, eventKind; } __attribute__((packed, aligned(2))) EventTypeSpec;
typedef int (*EventHandlerProcPtr)(void *, EventRef, void *);

extern TISInputSourceRef TISCopyCurrentKeyboardInputSource(void);
extern TISInputSourceRef TISCopyCurrentASCIICapableKeyboardLayoutInputSource(void);
extern CFArrayRef TISCreateInputSourceList(CFDictionaryRef, unsigned char);
extern void *TISGetInputSourceProperty(TISInputSourceRef, CFStringRef);
extern const CFStringRef kTISPropertyInputSourceID, kTISPropertyLocalizedName, kTISPropertyInputSourceType,
    kTISTypeKeyboardLayout, kTISNotifySelectedKeyboardInputSourceChanged;
extern int RegisterEventHotKey(unsigned int, unsigned int, EventHotKeyID, EventTargetRef, unsigned int, EventHotKeyRef *);
extern int UnregisterEventHotKey(EventHotKeyRef);
extern int InstallEventHandler(EventTargetRef, EventHandlerProcPtr, unsigned long, const EventTypeSpec *, void *, EventHandlerRef *);
extern int RemoveEventHandler(EventHandlerRef);
extern EventTargetRef GetApplicationEventTarget(void);
extern unsigned int GetEventKind(EventRef);
extern int GetEventParameter(EventRef, unsigned int, unsigned int, unsigned int *, unsigned long, unsigned long *, void *);

static void show(const char *label, CFStringRef s) {
  char buf[256] = "(null)";
  if (s) CFStringGetCString(s, buf, sizeof buf, kCFStringEncodingUTF8);
  printf("%s: %s\n", label, buf);
}

int main(void) {
  TISInputSourceRef cur = TISCopyCurrentKeyboardInputSource();
  if (!cur) { puts("no input source"); return 1; }
  show("id", TISGetInputSourceProperty(cur, kTISPropertyInputSourceID));
  show("name", TISGetInputSourceProperty(cur, kTISPropertyLocalizedName));
  TISInputSourceRef a = TISCopyCurrentASCIICapableKeyboardLayoutInputSource();
  if (a) show("ascii", TISGetInputSourceProperty(a, kTISPropertyInputSourceID));
  const void *k[1] = {kTISPropertyInputSourceType}, *v[1] = {kTISTypeKeyboardLayout};
  CFDictionaryRef f = CFDictionaryCreate(0, k, v, 1, &kCFTypeDictionaryKeyCallBacks, &kCFTypeDictionaryValueCallBacks);
  CFArrayRef l = TISCreateInputSourceList(f, 0);
  printf("layouts: %ld\n", l ? (long)CFArrayGetCount(l) : -1L);
  printf("notify: %s\n", kTISNotifySelectedKeyboardInputSourceChanged ? "yes" : "no");
  /* The hot key functions: they are called, no event loop; the status depends on the session, so it is not checked. */
  EventHotKeyRef hk = 0;
  EventHotKeyID id = {0x4f43, 1};
  int r = RegisterEventHotKey(0x7a /* F1 */, 0, id, GetApplicationEventTarget(), 0, &hk);
  printf("RegisterEventHotKey: %d\n", r);
  if (r == 0) printf("UnregisterEventHotKey: %d\n", UnregisterEventHotKey(hk));
  (void)InstallEventHandler; (void)RemoveEventHandler; (void)GetEventKind; (void)GetEventParameter;
  return 0;
}
