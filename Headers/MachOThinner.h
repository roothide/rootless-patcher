#import <Foundation/NSString.h>
#import <Foundation/NSDictionary.h>

@interface MachOThinner : NSObject
+ (nonnull NSDictionary *)thinnedMachOsFromPaths:(nonnull NSArray<NSString *> *)paths;
@end