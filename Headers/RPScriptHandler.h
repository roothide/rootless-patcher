#import <Foundation/NSObject.h>
#import <Foundation/NSString.h>

@interface RPScriptHandler : NSObject
+ (nullable instancetype)handlerWithScriptFile:(nonnull NSString *)scriptFile;
- (void)convertStringsUsingConversionRuleset:(nonnull NSDictionary<NSString *, id> *)conversionRuleset;
- (nonnull NSString *)fileContents;

+ (nullable instancetype)new __attribute__((unavailable("Use +handlerWithScriptFile: instead")));
- (nullable instancetype)init __attribute__((unavailable("Use +handlerWithScriptFile: instead")));
@end