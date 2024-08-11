#import <Foundation/NSObject.h>
#import <Foundation/NSString.h>

@interface MachOMerger : NSObject
+ (BOOL)mergeMachOsAtPaths:(nonnull NSArray<NSString *> *)paths outputPath:(nonnull NSString *)outputPath;
@end