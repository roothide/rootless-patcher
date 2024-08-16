#import <Foundation/NSObject.h>
#import <Foundation/NSString.h>

@interface SpawnHandler : NSObject
+ (int)spawnWithArguments:(nonnull NSArray<NSString *> *)arguments;
+ (nonnull NSString *)errorForCode:(int)returnCode;
@end