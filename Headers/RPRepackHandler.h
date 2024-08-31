#import <Foundation/NSObject.h>
#import <Foundation/NSString.h>

@interface RPRepackHandler : NSObject
+ (BOOL)repackFile:(nonnull NSString *)file toDirectory:(nonnull NSString *)directory;
@end