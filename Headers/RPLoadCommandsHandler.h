#import <Foundation/NSObject.h>
#import <Foundation/NSString.h>

@interface RPLoadCommandsHandler : NSObject
+ (BOOL)handleLoadCommandsForFile:(nonnull NSString *)file;
@end