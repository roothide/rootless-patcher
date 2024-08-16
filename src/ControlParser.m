#import <Foundation/Foundation.h>
#import "Headers/ControlParser.h"

@implementation ControlParser {
	NSString *_controlFileContents;
	NSMutableArray *_keys;
	NSDictionary *_dictionary;
}

+ (instancetype)parserWithControlFile:(NSString *)controlFile {
	ControlParser *const parser = [ControlParser new];

	if (parser) {
		NSError *error;
		parser->_controlFileContents = [NSString stringWithContentsOfFile:controlFile encoding:NSUTF8StringEncoding error:&error];
		if (error) {
			fprintf(stderr, "[-] Failed to get control file contents at path: %s. Error: %s\n", controlFile.fileSystemRepresentation, error.localizedDescription.UTF8String);
			return nil;
		}
		[parser _parseControlFile];
	}

	return parser;
}

- (void)setControlValue:(id)value forKey:(NSString *)key {
	if (![_dictionary valueForKey:key]) {
		return;
	}

	NSMutableDictionary *const dictionary = [NSMutableDictionary dictionary];
	[dictionary setValue:value forKey:key];
	_dictionary = [dictionary copy];
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

- (void)_parseControlFile {
	NSMutableDictionary *const dictionary = [NSMutableDictionary dictionary];
	_keys = [NSMutableArray array];

	NSArray<NSString *> *const lines = [_controlFileContents componentsSeparatedByString:@"\n"];

	for (NSString *line in lines) {
		if (line.length > 0) {
			NSArray<NSString *> *const keyValue = [line componentsSeparatedByString:@": "];

			if ([keyValue[1] containsString:@", "]) {
				NSArray<NSString *> *const array = [keyValue[1] componentsSeparatedByString:@", "];
				[dictionary setObject:array forKey:keyValue[0]];
			} else {
				[dictionary setObject:keyValue[1] forKey:keyValue[0]];
			}

			[_keys addObject:keyValue[0]];
		}
	}

	_dictionary = [dictionary copy];
}

@end