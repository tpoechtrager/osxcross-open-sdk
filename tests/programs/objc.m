#import <objc/NSObject.h>
#import <objc/runtime.h>
#include <stdio.h>

@interface Counter : NSObject { @public int n; }
- (void)bump;
+ (instancetype)make;
@end
@implementation Counter
+ (instancetype)make { return [[self alloc] init]; }
- (void)bump { n++; }
@end

int main(void) {
  @autoreleasepool {
    Counter *c = [Counter make];
    for (int i = 0; i < 5; i++) [c bump];
    printf("objc counter %d class %s\n", c->n, class_getName([c class]));
    @try { @throw [Counter make]; } @catch (Counter *e) { printf("objc caught %s\n", object_getClassName(e)); }
  }
  return 0;
}
