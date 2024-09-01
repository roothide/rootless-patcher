#import <Foundation/Foundation.h>
#import "Headers/RPControlHandler.h"

@implementation RPControlHandler {
	NSMutableArray *_keys;
	NSMutableDictionary *_dictionary;
}

+ (instancetype)handlerWithControlFile:(NSString *)controlFile {
	RPControlHandler *const parser = [RPControlHandler new];

	if (parser) {
		NSError *error = nil;

		NSString *const fileContents = [NSString stringWithContentsOfFile:controlFile encoding:NSUTF8StringEncoding error:&error];
		if (!fileContents) {
			fprintf(stderr, "[-] Failed to get control file contents at path: %s. Error: %s\n", controlFile.fileSystemRepresentation, error.localizedDescription.UTF8String);
			return nil;
		}

		NSMutableDictionary *const dictionary = [NSMutableDictionary dictionary];
		NSMutableArray *const keys = [NSMutableArray array];

		NSArray<NSString *> *const lines = [fileContents componentsSeparatedByString:@": "];

		const NSUInteger linesCount = [lines count];

		for (NSUInteger i = 1; i < linesCount; i++) {
			NSArray<NSString *> *const previousTokens = [lines[i - 1] componentsSeparatedByString:@"\n"];
			NSArray<NSString *> *const currentTokens = [lines[i] componentsSeparatedByString:@"\n"];

			NSString *const key = [previousTokens lastObject];
			NSString *const value = [[currentTokens subarrayWithRange:NSMakeRange(0, currentTokens.count - 1)] componentsJoinedByString:@"\n"];

			const NSUInteger keyLength = [key length];
			const NSUInteger valueLength = [value length];

			if (keyLength > 0 && valueLength > 0) {
				if ([value containsString:@", "]) {
					[dictionary setObject:[value componentsSeparatedByString:@", "] forKey:key];
				} else {
					[dictionary setObject:value forKey:key];
				}

				[keys addObject:key];
			}
		}

		parser->_dictionary = dictionary;
		parser->_keys = keys;
	}

	return parser;
}

- (void)setControlValue:(id)value forKey:(NSString *)key {
	if (![_dictionary valueForKey:key]) {
		return;
	}

	[_dictionary setValue:value forKey:key];
}

- (id)controlValueForKey:(NSString *)key {
	return [_dictionary valueForKey:key];
}

- (NSString *)controlFileAsString {
	NSString *string = @"";

	for (NSString *key in _keys) {
		const id value = [self controlValueForKey:key];

		if ([value isKindOfClass:[NSString class]]) {
			string = [string stringByAppendingString:[NSString stringWithFormat:@"%@: %@\n", key, value]];
		} else if ([value isKindOfClass:[NSArray class]]) {
			string = [string stringByAppendingString:[NSString stringWithFormat:@"%@: %@\n", key, [value componentsJoinedByString:@", "]]];
		}
	}

	return string;
}

@end