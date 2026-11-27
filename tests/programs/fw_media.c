/* AVFoundation, CoreMedia, ImageIO, Vision, MetalKit (data/symbols/doc/): a program declares the names itself,
   as Rust crates do; the SDK has only link stubs of these frameworks */
#include <CoreFoundation/CoreFoundation.h>
#include <stdio.h>
#include <string.h>

typedef struct { long long value; int timescale; unsigned flags; long long epoch; } TimeX;
typedef struct { double x, y, w, h; } RectX;
extern const CFStringRef AVMediaTypeVideo, AVCaptureSessionPresetHigh;  /* NSString constants */
extern const TimeX kCMTimeZero;
extern TimeX CMTimeMake(long long value, int timescale);
extern double CMTimeGetSeconds(TimeX time);
extern const CFStringRef kCGImagePropertyPixelWidth;
extern CFTypeID CGImageSourceGetTypeID(void);
extern const RectX VNNormalizedIdentityRect;
extern const CFStringRef MTKTextureLoaderOptionSRGB, MTKModelErrorDomain;

static int text(const char *label, CFStringRef s, const char *want) {
  char b[128] = "?";
  if (s) CFStringGetCString(s, b, sizeof b, kCFStringEncodingUTF8);
  printf("%s: %s\n", label, b);
  return want ? strcmp(b, want) != 0 : b[0] == '?';
}

int main(void) {
  int bad = 0;
  bad += text("AVMediaTypeVideo", AVMediaTypeVideo, "vide");
  bad += text("AVCaptureSessionPresetHigh", AVCaptureSessionPresetHigh, "AVCaptureSessionPresetHigh");
  bad += text("kCGImagePropertyPixelWidth", kCGImagePropertyPixelWidth, "PixelWidth");
  bad += text("MTKTextureLoaderOptionSRGB", MTKTextureLoaderOptionSRGB, NULL);
  bad += text("MTKModelErrorDomain", MTKModelErrorDomain, NULL);
  double t = CMTimeGetSeconds(CMTimeMake(1, 30));
  printf("CMTimeMake(1, 30): %.4f s, kCMTimeZero value %lld timescale %d\n", t, kCMTimeZero.value, kCMTimeZero.timescale);
  bad += !(t > 0.033 && t < 0.034) || kCMTimeZero.value != 0;
  printf("CGImageSource type id: %d\n", CGImageSourceGetTypeID() != 0);
  bad += CGImageSourceGetTypeID() == 0;
  printf("VNNormalizedIdentityRect: %g %g %g %g\n", VNNormalizedIdentityRect.x, VNNormalizedIdentityRect.y,
         VNNormalizedIdentityRect.w, VNNormalizedIdentityRect.h);
  bad += VNNormalizedIdentityRect.w != 1 || VNNormalizedIdentityRect.h != 1;
  return bad != 0;
}
