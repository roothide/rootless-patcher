#import <Foundation/NSObject.h>
#import <Foundation/NSString.h>
#import <Foundation/NSArray.h>

@interface RPStringScanner : NSObject
+ (nullable instancetype)scannerWithFile:(nonnull NSString *)file conversionRuleset:(nonnull NSDictionary *)conversionRuleset;
- (nonnull NSDictionary<NSString *, NSString *> *)stringMap;

+ (nullable instancetype)new __attribute__((unavailable("Use +stringScannerForFile: instead")));
- (nullable instancetype)init __attribute__((unavailable("Use +stringScannerForFile: instead")));
@end