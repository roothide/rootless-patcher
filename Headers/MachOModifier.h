#import <Foundation/NSObject.h>
#import <Foundation/NSString.h>

@interface MachOModifier : NSObject
+ (nullable instancetype)modifierWithFile:(nonnull NSString *)file;
- (nullable NSData *)dataWithAddedSegment:(nonnull NSString *)segname withSection:(nonnull NSString *)sectname withStringMap:(nonnull NSDictionary<NSString *, NSString *> *)stringMap;

+ (nullable instancetype)new __attribute__((unavailable("Use +modifierWithFile: instead")));
- (nullable instancetype)init __attribute__((unavailable("Use +modifierWithFile: instead")));
@end