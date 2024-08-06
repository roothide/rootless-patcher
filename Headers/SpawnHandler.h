#import <Foundation/NSObject.h>
#import <Foundation/NSString.h>

@interface SpawnHandler : NSObject
+ (BOOL)spawnWithCommandPath:(nonnull NSString *)commandPath arguments:(nonnull NSArray<NSString *> *)arguments;
@end