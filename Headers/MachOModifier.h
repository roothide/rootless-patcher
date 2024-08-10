#import <Foundation/NSObject.h>
#import <Foundation/NSString.h>

@interface MachOModifier : NSObject
+ (nullable instancetype)modifierWithFile:(nonnull NSString *)file;
- (void)addSegment:(nonnull NSString *)segname withSection:(nonnull NSString *)sectname withStringMap:(nonnull NSDictionary<NSString *, NSString *> *)stringMap;
- (void)rebaseStringsWithStringMap:(nonnull NSDictionary<NSString *, NSString *> *)stringMap;
- (nonnull NSData *)data;

+ (nullable instancetype)new __attribute__((unavailable("Use +modifierWithFile: instead")));
- (nullable instancetype)init __attribute__((unavailable("Use +modifierWithFile: instead")));
@end