#import <Foundation/Foundation.h>
#import "Headers/ControlScriptHandler.h"
#import "Headers/ConversionHandler.h"

@implementation ControlScriptHandler {
	NSString *_fileContents;
}

+ (instancetype)handlerWithControlScriptFile:(NSString *)controlScriptFile {
	ControlScriptHandler *const handler = [ControlScriptHandler new];

	if (handler) {
		NSError *error;
		handler->_fileContents = [NSString stringWithContentsOfFile:controlScriptFile encoding:NSUTF8StringEncoding error:&error];
		if (error) {
			fprintf(stderr, "[-] Failed to get control script file contents at path: %s. Error: %s\n", controlScriptFile.fileSystemRepresentation, error.localizedDescription.UTF8String);
			return nil;
		}
	}

	return handler;
}

- (void)convertStringsUsingStringMap:(NSDictionary<NSString *, NSString *> *)stringMap {
	ConversionHandler *const handler = [ConversionHandler handlerWithConversionRuleset:stringMap];

	NSArray *const separatedComponents = [_fileContents componentsSeparatedByCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@" \n\""]];
	NSMutableDictionary *const convertedStrings = [NSMutableDictionary dictionary];

	for (size_t i = 0; i < separatedComponents.count; i++) {
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