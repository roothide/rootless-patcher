#import <Foundation/NSObject.h>
#import <Foundation/NSString.h>

@interface StringPatcher : NSObject
+ (nullable instancetype)patcherWithData:(nonnull NSData *)data;
- (void)patchString:(nonnull NSString *)string toString:(nonnull NSString *)string;
- (nonnull NSData *)data;

+ (nullable instancetype)new __attribute__((unavailable("Use +patcherWithData: instead")));
- (nullable instancetype)init __attribute__((unavailable("Use +patcherWithData: instead")));
@end