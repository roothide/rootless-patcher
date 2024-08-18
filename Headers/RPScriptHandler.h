#import <Foundation/NSObject.h>
#import <Foundation/NSString.h>

@interface RPScriptHandler : NSObject
+ (BOOL)handleScriptForFile:(nonnull NSString *)file;
@end