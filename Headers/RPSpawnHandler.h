#import <Foundation/NSObject.h>
#import <Foundation/NSString.h>

@interface RPSpawnHandler : NSObject
+ (int)spawnWithArguments:(nonnull NSArray<NSString *> *)arguments;
@end