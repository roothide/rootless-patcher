#import <Foundation/Foundation.h>
#import "Headers/ConversionHandler.h"

@implementation ConversionHandler {
	NSArray *_blacklist;
	NSDictionary *_specialCases;
	NSArray *_bootstrapList;
}

+ (instancetype)handlerWithConversionRuleset:(NSDictionary *)conversionRuleset {
	ConversionHandler *const handler = [ConversionHandler new];

	if (handler) {
		handler->_blacklist = [conversionRuleset objectForKey:@"Blacklist"];
		handler->_specialCases = [conversionRuleset objectForKey:@"SpecialCases"];
		handler->_bootstrapList = @[@"Applications", @"bin", @"boot", @"dev", @"etc", @"lib", @"Library", @"mnt", @"sbin", @"tmp", @"User", @"usr", @"var"];
	}

	return handler;
}

- (BOOL)shouldConvertString:(NSString *)string {
	if ([string length] == 0) {
		return NO;
	}

	NSArray *const pathComponents = [string pathComponents];
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

	for (NSString *blacklistedString in _blacklist) {
		if ([string containsString:blacklistedString]) {
			return NO;
		}
	}

	for (NSString *specialCase in _specialCases) {
		if ([string containsString:specialCase]) {
			return YES;
		}
	}

	if ([string hasPrefix:@"file://"]) {
		return YES;
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