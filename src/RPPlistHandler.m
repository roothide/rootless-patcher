// Copyright (c) 2024 Nightwind

#import <Foundation/Foundation.h>
#import "Headers/RPPlistHandler.h"
#import "Headers/RPConversionHandler.h"

@implementation RPPlistHandler {
	id _plistContainer;
	RPConversionHandler *_conversionHandler;
}

+ (instancetype)handlerWithPlistFile:(NSString *)file {
	RPPlistHandler *const handler = [RPPlistHandler new];

	if (handler) {
		NSData *const data = [NSData dataWithContentsOfFile:file];
		handler->_plistContainer = [NSPropertyListSerialization propertyListWithData:data options:NSPropertyListMutableContainersAndLeaves format:nil error:nil];
	}

	return handler;
}

- (void)convertStringsUsingConversionRuleset:(NSDictionary<NSString *, id> *)conversionRuleset {
	_conversionHandler = [RPConversionHandler handlerWithConversionRuleset:conversionRuleset];
	[self _patchStringValues:_plistContainer];
}

- (void)_patchStringValues:(id)container {
	if ([container isKindOfClass:[NSMutableDictionary class]]) {
		NSMutableDictionary *const dictionary = container;

		for (NSUInteger i = 0; i < dictionary.count; i++) {
			id key = [dictionary allKeys][i];
			id value = [dictionary objectForKey:key];

			if ([value isKindOfClass:[NSString class]]) {
				if ([_conversionHandler shouldConvertString:value]) {
					NSString *const convertedString = [_conversionHandler convertedStringForString:value];
					[dictionary setObject:convertedString forKey:key];
					fprintf(stdout, "\t%s -> %s\n", ((NSString *)value).UTF8String, convertedString.UTF8String);
				}
			} else if ([value isKindOfClass:[NSMutableDictionary class]] || [value isKindOfClass:[NSMutableArray class]]) {
				[self _patchStringValues:value];
			}
		}
	} else if ([container isKindOfClass:[NSMutableArray class]]) {
		NSMutableArray *const array = container;

		for (NSUInteger i = 0; i < array.count; i++) {
			id value = [array objectAtIndex:i];

			if ([value isKindOfClass:[NSString class]]) {
				if ([_conversionHandler shouldConvertString:value]) {
					NSString *const convertedString = [_conversionHandler convertedStringForString:value];
					array[i] = convertedString;
					fprintf(stdout, "\t%s -> %s\n", ((NSString *)value).UTF8String, convertedString.UTF8String);
				}
			} else if ([value isKindOfClass:[NSMutableDictionary class]] || [value isKindOfClass:[NSMutableArray class]]) {
				[self _patchStringValues:value];
			}
		}
	}
}

- (id)plistContainer {
	return [_plistContainer copy];
}

@end