#import <Foundation/Foundation.h>
#import "Headers/StringScanner.h"
#import "Headers/MachOParser.h"
#import "Headers/ConversionHandler.h"

@implementation StringScanner {
	NSData *_fileData;
	ConversionHandler *_conversionHandler;
}

+ (instancetype)stringScannerWithFile:(NSString *)file conversionRuleset:(NSDictionary *)conversionRuleset {
	StringScanner *const scanner = [StringScanner new];

	if (scanner) {
		scanner->_fileData = [NSData dataWithContentsOfFile:file];
		scanner->_conversionHandler = [ConversionHandler handlerWithConversionRuleset:conversionRuleset];
	}

	return scanner;
}

- (NSDictionary<NSString *, NSString *> *)stringMap {
	NSMutableDictionary<NSString *, NSString *> *const stringMap = [NSMutableDictionary dictionary];

	NSArray<NSString *> *const textStrings = [self _textStrings];
	NSArray<NSString *> *const dataStrings = [self _dataStrings];

	for (NSString *origString in textStrings) {
		const BOOL shouldConvert = [_conversionHandler shouldConvertString:origString];
		if (shouldConvert) {
			NSString *const convertedString = [_conversionHandler convertedStringForString:origString];
			[stringMap setObject:convertedString forKey:origString];
		}
	}

	for (NSString *origString in dataStrings) {
		const BOOL shouldConvert = [_conversionHandler shouldConvertString:origString];
		if (shouldConvert) {
			NSString *const convertedString = [_conversionHandler convertedStringForString:origString];
			[stringMap setObject:convertedString forKey:origString];
		}
	}

	return [stringMap copy];
}

- (NSArray<NSString *> *)_textStrings {
	NSMutableArray *const originalStrings = [NSMutableArray array];

	struct mach_header_64 *header = (struct mach_header_64 *)[_fileData bytes];
	MachOParser *const parser = [MachOParser parserWithHeader:header];

	struct segment_command_64 *textSegment = [parser segmentWithName:@"__TEXT"];
	if (!textSegment) {
		return nil;
	}

	struct section_64 *cStringSection = [parser sectionInSegment:textSegment withName:@"__cstring"];
	if (!cStringSection) {
		return nil;
	}

	const uintptr_t start = (uintptr_t)header + cStringSection->offset;
	const char *string = NULL;

	for (uint32_t offset = 0; offset < cStringSection->size; offset++) {
		const char *currentChar = (const char *)(start + offset);

		if (*currentChar == '\0') {
			if (string) {
				NSString *const objcString = [NSString stringWithUTF8String:string];

				if (objcString) {
					[originalStrings addObject:objcString];
				}

				string = NULL;
			}
		} else if (string == NULL) {
			string = currentChar;
		}
	}

	return [originalStrings copy];
}

- (NSArray<NSString *> *)_dataStrings {
	NSMutableArray *const originalStrings = [NSMutableArray array];

	struct mach_header_64 *header = (struct mach_header_64 *)[_fileData bytes];
	MachOParser *const parser = [MachOParser parserWithHeader:header];

	struct segment_command_64 *dataSegment = [parser segmentWithName:@"__DATA"];
	if (!dataSegment) {
		return nil;
	}

	struct section_64 *dataSection = [parser sectionInSegment:dataSegment withName:@"__data"];
	if (!dataSection) {
		return nil;
	}

	const uintptr_t start = (uintptr_t)header + dataSection->offset;
	const char *string = NULL;

	for (uint32_t offset = 0; offset < dataSection->size; offset++) {
		const char *currentChar = (const char *)(start + offset);

		if (*currentChar == '\0') {
			if (string) {
				NSString *const objcString = [NSString stringWithUTF8String:string];

				if (objcString) {
					[originalStrings addObject:objcString];
				}

				string = NULL;
			}
		} else if (string == NULL) {
			string = currentChar;
		}
	}

	return [originalStrings copy];
}

@end