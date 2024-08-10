#import <Foundation/Foundation.h>
#import "Headers/PlistHandler.h"
#import "Headers/ConversionHandler.h"

@implementation PlistHandler {
	NSMutableDictionary *_plistDictionary;
	ConversionHandler *_conversionHandler;
}

+ (instancetype)handlerWithPlistFile:(nonnull NSString *)file {
	PlistHandler *const handler = [PlistHandler new];

	if (handler) {
		handler->_plistDictionary = [NSMutableDictionary dictionaryWithContentsOfFile:file];
	}

	return handler;
}

- (void)convertStringsUsingStringMap:(NSDictionary<NSString *, NSString *> *)stringMap {
	_conversionHandler = [ConversionHandler handlerWithConversionRuleset:stringMap];
	[self _patchStringValues:_plistDictionary];
}

- (void)_patchStringValues:(id)container {
	if ([container isKindOfClass:[NSDictionary class]]) {
		NSMutableDictionary *const dictionary = container;

		for (int i = dictionary.count - 1; i >= 0; i--) {
			id key = [dictionary allKeys][i];
			id value = [dictionary objectForKey:key];

			if ([value isKindOfClass:[NSString class]]) {
				if ([_conversionHandler shouldConvertString:value]) {
					NSString *const convertedString = [_conversionHandler convertedStringForString:value];
					[dictionary setObject:convertedString forKey:key];
				}
			} else if ([value isKindOfClass:[NSDictionary class]] || [value isKindOfClass:[NSArray class]]) {
				[self _patchStringValues:value];
			}
		}
	} else if ([container isKindOfClass:[NSArray class]]) {
		NSMutableArray *const array = container;

		for (int i = array.count - 1; i >= 0; i--) {
			id value = [array objectAtIndex:i];

			if ([value isKindOfClass:[NSString class]]) {
				if ([_conversionHandler shouldConvertString:value]) {
					NSString *const convertedString = [_conversionHandler convertedStringForString:value];
					array[i] = convertedString;
				}
			} else if ([value isKindOfClass:[NSDictionary class]] || [value isKindOfClass:[NSArray class]]) {
				[self _patchStringValues:value];
			}
		}
	}
}

- (NSDictionary *)plistDictionary {
	return [_plistDictionary copy];
}

@end