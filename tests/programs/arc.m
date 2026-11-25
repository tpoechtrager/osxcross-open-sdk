/* -fobjc-arc without Foundation: the SDK only has a placeholder for it. */
#import <objc/NSObject.h>
#include <stdio.h>

@interface Box : NSObject { @public int v; }
@end
@implementation Box
@end

int main(void) {
  @autoreleasepool {
    Box *b = [Box new];
    b->v = 42;
    printf("arc box %d\n", b->v);
  }
  return 0;
}
