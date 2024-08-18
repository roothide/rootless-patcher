#import <Foundation/NSObject.h>
#import <Foundation/NSString.h>
#import <Foundation/NSDictionary.h>

@interface RPPlistHandler : NSObject
+ (nullable instancetype)handlerWithPlistFile:(nonnull NSString *)file;
- (void)convertStringsUsingConversionRuleset:(nonnull NSDictionary<NSString *, id> *)conversionRuleset;
- (nonnull NSDictionary *)plistContainer;

+ (nullable instancetype)new __attribute__((unavailable("Use +handlerWithPlistFile: instead")));
- (nullable instancetype)init __attribute__((unavailable("Use +handlerWithPlistFile: instead")));
@end