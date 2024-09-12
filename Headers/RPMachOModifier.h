#import <Foundation/NSObject.h>
#import <Foundation/NSString.h>

@interface RPMachOModifier : NSObject
+ (nullable instancetype)modifierWithFile:(nonnull NSString *)file;
- (void)addSegment:(nonnull NSString *)segname section:(nonnull NSString *)sectname stringMap:(nonnull NSDictionary<NSString *, NSString *> *)stringMap;
- (void)rebaseStringsWithStringMap:(nonnull NSDictionary<NSString *, NSString *> *)stringMap originalOffsetMap:(nonnull NSDictionary<NSString *, NSNumber *> *)originalOffsetMap;
- (nonnull NSData *)data;

+ (nullable instancetype)new __attribute__((unavailable("Use +modifierWithFile: instead")));
- (nullable instancetype)init __attribute__((unavailable("Use +modifierWithFile: instead")));
@end