// Copyright (c) 2024 Nightwind

#import <Foundation/Foundation.h>
#import "Headers/RPConversionHandler.h"

@implementation RPConversionHandler {
	NSArray *_blacklist;
	NSDictionary *_specialCases;
	NSArray *_bootstrapList;
}

+ (instancetype)handlerWithConversionRuleset:(NSDictionary *)conversionRuleset {
	RPConversionHandler *const handler = [RPConversionHandler new];

	if (handler) {
		handler->_blacklist = [conversionRuleset objectForKey:@"Blacklist"];
		handler->_specialCases = [conversionRuleset objectForKey:@"SpecialCases"];
		handler->_bootstrapList = @[@"Applications", @"bin", @"boot", @"etc", @"lib", @"Library", @"mnt", @"sbin", @"tmp", @"User", @"usr", @"var"];
	}

	return handler;
}

- (BOOL)shouldConvertString:(NSString *)string {
	if ([string length] == 0) {
		return NO;
	}

	NSArray *const pathComponents = [[self _string:string byStrippingPrefix:@"file://"] pathComponents];
	if (!pathComponents || [pathComponents count] == 1) {
		return NO;
	}

	NSString *firstPathComponent = pathComponents.firstObject;

	for (NSString *pathComponent in pathComponents) {
		if (![pathComponent isEqualToString:@"/"]) {
			firstPathComponent = pathComponent;
			break;
		}
	}

	if (![_bootstrapList containsObject:firstPathComponent]) {
		return NO;
	}

	for (NSString *specialCase in _specialCases) {
		if ([string containsString:specialCase]) {
			return YES;
		}
	}

	if ([string hasPrefix:@"file://"]) {
		return YES;
	}

	for (NSString *blacklistedString in _blacklist) {
		if ([string containsString:blacklistedString]) {
			return NO;
		}
	}

	return YES;
}

- (NSString *)convertedStringForString:(NSString *)string {
	NSString *convertedString = string;

	for (NSString *specialCase in _specialCases) {
		if ([string containsString:specialCase]) {
			convertedString = [convertedString stringByReplacingOccurrencesOfString:specialCase withString:[_specialCases valueForKey:specialCase]];
		}
	}

	/**
	 * Specifically using stringByAppendingString: instead of stringByAppendingPathComponent: to handle cases with a trailing /.
	 * Example:
	 * /Applications/ -> /var/jb/Applications | stringByAppendingPathComponent:
	 * /Applications/ -> /var/jb/Applications/ | stringByAppendingString:
	 */
	if ([string hasPrefix:@"file://"]) {
		return [@"file:///var/jb" stringByAppendingString:[self _string:string byStrippingPrefix:@"file://"]];
	} else if ([string hasPrefix:@"/"]) {
		return [@"/var/jb" stringByAppendingString:convertedString];
	} else {
		return [@"var/jb/" stringByAppendingString:convertedString];
	}
}

- (NSString *)_string:(NSString *)string byStrippingPrefix:(NSString *)prefix {
	return [string hasPrefix:prefix] ? [string substringFromIndex:[prefix length]] : string;
}

@end