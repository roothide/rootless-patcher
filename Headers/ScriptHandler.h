#import <Foundation/NSObject.h>
#import <Foundation/NSString.h>

@interface ScriptHandler : NSObject
+ (BOOL)handleScriptForFile:(nonnull NSString *)file;
@end