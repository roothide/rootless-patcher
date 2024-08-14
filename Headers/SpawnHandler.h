#import <Foundation/NSObject.h>
#import <Foundation/NSString.h>

@interface SpawnHandler : NSObject
+ (BOOL)spawnWithArguments:(nonnull NSArray<NSString *> *)arguments;
@end