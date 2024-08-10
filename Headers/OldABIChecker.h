#import <Foundation/NSObject.h>
#import <Foundation/NSData.h>

@interface OldABIChecker : NSObject
+ (BOOL)containsOldABI:(nonnull NSData *)machO;
@end