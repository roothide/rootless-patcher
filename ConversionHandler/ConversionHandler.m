#import <Foundation/Foundation.h>
#import "Headers/ConversionHandler.h"

@implementation ConversionHandler {
	NSArray *_blacklist;
	NSDictionary *_specialCases;
	NSArray *_denylist;
}

+ (instancetype)handlerWithConversionRuleset:(NSDictionary *)conversionRuleset {
	ConversionHandler *const handler = [ConversionHandler new];

	if (handler) {
		handler->_blacklist = [conversionRuleset objectForKey:@"Blacklist"];
		handler->_specialCases = [conversionRuleset objectForKey:@"SpecialCases"];
		handler->_denylist = [conversionRuleset objectForKey:@"Denylist"];
	}

	return handler;
}

- (BOOL)shouldConvertString:(NSString *)string {
	for (NSString *denyString in _denylist) {
		if ([string containsString:denyString]) {
			return NO;
		}
	}

	NSString *const standardizedString = [string stringByStandardizingPath];

	if ([standardizedString length] <= 1 ||
		[standardizedString containsString:@"?"] ||
		(![standardizedString hasPrefix:@"/"] &&
		(![standardizedString containsString:@"/"]))) {
		return NO;
	}

	for (NSString *blacklistedString in _blacklist) {
		if ([standardizedString containsString:blacklistedString] || [blacklistedString containsString:standardizedString]) {
			return NO;
		}
	}

	for (NSString *specialCase in [_specialCases allKeys]) {
		if ([standardizedString containsString:specialCase]) {
			return YES;
		}
	}

	NSArray *const dirs = [string componentsSeparatedByString:@"/"];

	if ([dirs count] == 2 && ([dirs[1] containsString:@"."] || [dirs[1] containsString:@"'"])) {
		return NO;
	}

	return YES;
}

- (NSString *)convertedStringForString:(NSString *)string {
	NSString *convertedString = string;

	for (NSString *specialCase in [_specialCases allKeys]) {
		if ([string containsString:specialCase]) {
			convertedString = [convertedString stringByReplacingOccurrencesOfString:specialCase withString:[_specialCases valueForKey:specialCase]];
		}
	}

	if ([string hasPrefix:@"file://"]) {
		return [@"file:///var/jb" stringByAppendingString:[self _string:string byStrippingPrefix:@"file://"]];
	} else if ([string hasPrefix:@"/"]) {
		return [@"/var/jb" stringByAppendingPathComponent:convertedString];
	} else {
		return [@"var/jb" stringByAppendingPathComponent:convertedString];
	}
}

- (NSString *)_string:(NSString *)string byStrippingPrefix:(NSString *)prefix {
	return [string hasPrefix:prefix] ? [string substringFromIndex:[prefix length]] : string;
}

@end