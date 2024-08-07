#import <Foundation/NSObject.h>
#import <Foundation/NSString.h>
#import <Foundation/NSArray.h>

@interface StringScanner : NSObject
+ (nullable instancetype)stringScannerWithFile:(nonnull NSString *)file conversionRuleset:(nonnull NSDictionary *)conversionRuleset;
- (nonnull NSDictionary<NSString *, NSString *> *)stringMap;

+ (nullable instancetype)new __attribute__((unavailable("Use +stringScannerForFile: instead")));
- (nullable instancetype)init __attribute__((unavailable("Use +stringScannerForFile: instead")));
@end