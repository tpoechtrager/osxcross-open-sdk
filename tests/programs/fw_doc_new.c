/* names of data/symbols/doc/ that were added later (CoreGraphics, CoreServices, AudioToolbox): a program
   declares them itself, as Rust crates do; the SDK has no headers for these frameworks */
#include <CoreFoundation/CoreFoundation.h>
#include <stdio.h>
#include <string.h>

typedef struct { unsigned char hidden[80]; } FSRefX;
extern CFTypeID CGDisplayStreamGetTypeID(void);
extern CFTypeID CGDisplayStreamUpdateGetTypeID(void);
extern const CFStringRef kCGDisplayStreamSourceRect;
extern int FSPathMakeRef(const unsigned char *path, FSRefX *ref, unsigned char *isDir);
extern int FSRefMakePath(const FSRefX *ref, unsigned char *path, unsigned int maxPathSize);
extern int FSGetCatalogInfo(const FSRefX *ref, unsigned int whichInfo, void *info, void *name, void *spec, FSRefX *parent);
/* linked, never called (CGWindowListCreateImage needs the permission to record the screen) */
extern void *CGWindowListCreateImage(double x, double y, double w, double h, unsigned int option, unsigned int window, unsigned int image);
extern void *CGDisplayStreamCreate(unsigned int display, unsigned long w, unsigned long h, int format, CFDictionaryRef props, void *handler);
extern void AudioServicesPlaySystemSoundWithDetails(unsigned int sound, CFDictionaryRef details, void *completion);

int main(int argc, char **argv) {
  (void)argv;
  int bad = 0;
  CFTypeID a = CGDisplayStreamGetTypeID(), b = CGDisplayStreamUpdateGetTypeID();
  printf("CGDisplayStream type ids differ: %d\n", a != b); bad += a == b;
  char s[64] = "?"; CFStringGetCString(kCGDisplayStreamSourceRect, s, sizeof s, kCFStringEncodingUTF8);
  printf("kCGDisplayStreamSourceRect has text: %d\n", s[0] != '?'); bad += s[0] == '?';
  FSRefX ref; memset(&ref, 0, sizeof ref); unsigned char dir = 0;
  int r = FSPathMakeRef((const unsigned char *)"/tmp", &ref, &dir);
  unsigned char path[1024] = ""; int r2 = r == 0 ? FSRefMakePath(&ref, path, sizeof path) : -1;
  FSRefX parent; int r3 = r == 0 ? FSGetCatalogInfo(&ref, 0, NULL, NULL, NULL, &parent) : -1;
  printf("FSPathMakeRef %d, directory %d, FSRefMakePath %d, FSGetCatalogInfo %d\n", r, dir, r2, r3);
  bad += r != 0 || !dir || r2 != 0 || r3 != 0 || strstr((char *)path, "tmp") == NULL;
  if (argc > 5) {  /* never */
    CGWindowListCreateImage(0, 0, 1, 1, 0, 0, 0); CGDisplayStreamCreate(0, 1, 1, 0, NULL, NULL);
    AudioServicesPlaySystemSoundWithDetails(0, NULL, NULL);
  }
  return bad != 0;
}
