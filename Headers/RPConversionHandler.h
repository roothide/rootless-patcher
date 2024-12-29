// Copyright (c) 2024 Nightwind

#import <Foundation/NSObject.h>
#import <Foundation/NSString.h>

@interface RPConversionHandler : NSObject
+ (nullable instancetype)handlerWithConversionRuleset:(nonnull NSDictionary *)conversionRuleset;
- (BOOL)shouldConvertString:(nonnull NSString *)string;
- (nonnull NSString *)convertedStringForString:(nonnull NSString *)string;

+ (nullable instancetype)new __attribute__((unavailable("Use +handlerWithConversionRuleset: instead")));
- (nullable instancetype)init __attribute__((unavailable("Use +handlerWithConversionRuleset: instead")));
@end