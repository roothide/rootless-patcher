#import <Foundation/NSObject.h>
#import <Foundation/NSString.h>

@interface RPMachOMerger : NSObject
+ (int)mergeMachOsAtPaths:(nonnull NSArray<NSString *> *)paths outputPath:(nonnull NSString *)outputPath;
@end