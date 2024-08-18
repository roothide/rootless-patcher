#import <Foundation/NSObject.h>
#import <Foundation/NSString.h>

@interface ControlScriptHandler : NSObject
+ (nullable instancetype)handlerWithControlScriptFile:(nonnull NSString *)controlScriptFile;
- (void)convertStringsUsingConversionRuleset:(nonnull NSDictionary<NSString *, id> *)conversionRuleset;
- (nonnull NSString *)fileContents;

+ (nullable instancetype)new __attribute__((unavailable("Use +handlerWithControlScriptFile: instead")));
- (nullable instancetype)init __attribute__((unavailable("Use +handlerWithControlScriptFile: instead")));
@end