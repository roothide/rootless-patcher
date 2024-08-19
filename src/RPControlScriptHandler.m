#import <Foundation/Foundation.h>
#import "Headers/RPControlScriptHandler.h"
#import "Headers/RPConversionHandler.h"

@implementation RPControlScriptHandler {
	NSString *_fileContents;
}

+ (instancetype)handlerWithControlScriptFile:(NSString *)controlScriptFile {
	RPControlScriptHandler *const handler = [RPControlScriptHandler new];

	if (handler) {
		NSError *error = nil;
		handler->_fileContents = [NSString stringWithContentsOfFile:controlScriptFile encoding:NSUTF8StringEncoding error:&error];
		if (!handler->_fileContents) {
			fprintf(stderr, "[-] Failed to get control script file contents at path: %s. Error: %s\n", controlScriptFile.fileSystemRepresentation, error.localizedDescription.UTF8String);
			return nil;
		}
	}

	return handler;
}

- (void)convertStringsUsingConversionRuleset:(NSDictionary<NSString *, NSString *> *)conversionRuleset {
	RPConversionHandler *const handler = [RPConversionHandler handlerWithConversionRuleset:conversionRuleset];

	NSArray *const separatedComponents = [_fileContents componentsSeparatedByCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@" \n\""]];
	NSMutableDictionary *const convertedStrings = [NSMutableDictionary dictionary];

	const NSUInteger separatedComponentsCount = [separatedComponents count];

	for (NSUInteger i = 0; i < separatedComponentsCount; i++) {
		NSString *const string = [separatedComponents objectAtIndex:i];

		if (![string length]) {
			continue;
		}

		// Do not convert shebang, intended behavior on rootless is for the old rootful paths to work.
		if ([string hasPrefix:@"#!"]) {
			continue;
		}

		NSString *stringToConvert = string;
		if ([stringToConvert characterAtIndex:[stringToConvert length] - 1] == '\\') {
			stringToConvert = [string stringByAppendingString:[NSString stringWithFormat:@" %@", [separatedComponents objectAtIndex:i + 1]]];
		}

		if ([handler shouldConvertString:stringToConvert]) {
			NSString *const convertedString = [handler convertedStringForString:stringToConvert];
			[convertedStrings setObject:convertedString forKey:stringToConvert];
			fprintf(stdout, "\t%s -> %s\n", stringToConvert.UTF8String, convertedString.UTF8String);
		}

		if ([stringToConvert isEqualToString:string]) {
			i += 1;
		}
	}

	for (NSString *originalString in convertedStrings) {
		_fileContents = [_fileContents stringByReplacingOccurrencesOfString:originalString withString:[convertedStrings valueForKey:originalString]];
	}
}

- (NSString *)fileContents {
	return _fileContents;
}

@end