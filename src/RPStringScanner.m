// Copyright (c) 2024 Nightwind

#import <Foundation/Foundation.h>
#import "Headers/RPStringScanner.h"
#import "Headers/RPMachOParser.h"
#import "Headers/RPConversionHandler.h"

@implementation RPStringScanner {
	NSData *_fileData;
	RPConversionHandler *_conversionHandler;
	RPMachOParser *_parser;
	NSDictionary<NSString *, NSString *> *_stringMap;
	NSDictionary<NSString *, NSNumber *> *_offsetMap;
}

+ (instancetype)scannerWithFile:(NSString *)file conversionRuleset:(NSDictionary *)conversionRuleset {
	RPStringScanner *const scanner = [RPStringScanner new];

	if (scanner) {
		scanner->_fileData = [NSData dataWithContentsOfFile:file];
		scanner->_conversionHandler = [RPConversionHandler handlerWithConversionRuleset:conversionRuleset];

		struct mach_header_64 *header = (struct mach_header_64 *)[scanner->_fileData bytes];
		scanner->_parser = [RPMachOParser parserWithHeader:header];

		NSMutableDictionary<NSString *, NSString *> *const stringMap = [NSMutableDictionary dictionary];
		NSMutableDictionary<NSString *, NSNumber *> *const offsetMap = [NSMutableDictionary dictionary];

		NSDictionary<NSString *, NSNumber *> *const textStrings = [scanner _textStrings];
		NSDictionary<NSString *, NSNumber *> *const dataStrings = [scanner _dataStrings];

		for (NSString *origString in textStrings) {
			const BOOL shouldConvert = [scanner->_conversionHandler shouldConvertString:origString];
			if (shouldConvert) {
				NSString *const convertedString = [scanner->_conversionHandler convertedStringForString:origString];
				NSNumber *const offset = [textStrings valueForKey:origString];

				[stringMap setObject:convertedString forKey:origString];
				[offsetMap setObject:offset forKey:origString];
			}
		}

		for (NSString *origString in dataStrings) {
			const BOOL shouldConvert = [scanner->_conversionHandler shouldConvertString:origString];
			if (shouldConvert) {
				NSString *const convertedString = [scanner->_conversionHandler convertedStringForString:origString];
				NSNumber *const offset = [dataStrings valueForKey:origString];

				[stringMap setObject:convertedString forKey:origString];
				[offsetMap setObject:offset forKey:origString];
			}
		}

		scanner->_stringMap = [stringMap copy];
		scanner->_offsetMap = [offsetMap copy];
	}

	return scanner;
}

- (NSDictionary<NSString *, NSString *> *)stringMap {
	return _stringMap;
}

- (NSDictionary<NSString *, NSNumber *> *)offsetMap {
	return _offsetMap;
}

- (NSDictionary<NSString *, NSNumber *> *)_textStrings {
	NSMutableDictionary *const originalStrings = [NSMutableDictionary dictionary];

	struct segment_command_64 *textSegment = [_parser segmentWithName:@"__TEXT"];
	if (!textSegment) {
		return nil;
	}

	struct section_64 *cStringSection = [_parser sectionInSegment:textSegment withName:@"__cstring"];
	if (!cStringSection) {
		return nil;
	}

	const struct mach_header_64 *header = (struct mach_header_64 *)[_fileData bytes];

	const uint64_t mappedOffset = textSegment->vmaddr - textSegment->fileoff;

	const uintptr_t start = (uintptr_t)header + cStringSection->offset;
	const char *cstring = NULL;

	for (uint32_t offset = 0; offset < cStringSection->size; offset++) {
		const char *currentChar = (const char *)(start + offset);

		if (*currentChar == '\0') {
			if (cstring) {
				NSString *const objcString = [NSString stringWithUTF8String:cstring];

				if (objcString) {
					NSNumber *const offset = @(((uint64_t)cstring - (uint64_t)header) + mappedOffset);
					[originalStrings setObject:offset forKey:objcString];
				}

				cstring = NULL;
			}
		} else if (cstring == NULL) {
			cstring = currentChar;
		}
	}

	return [originalStrings copy];
}

- (NSDictionary<NSString *, NSNumber *> *)_dataStrings {
	NSMutableDictionary *const originalStrings = [NSMutableDictionary dictionary];

	struct segment_command_64 *dataSegment = [_parser segmentWithName:@"__DATA"];
	if (!dataSegment) {
		return nil;
	}

	struct section_64 *dataSection = [_parser sectionInSegment:dataSegment withName:@"__data"];
	if (!dataSection) {
		return nil;
	}

	const struct mach_header_64 *header = (struct mach_header_64 *)[_fileData bytes];

	const uint64_t mappedOffset = dataSegment->vmaddr - dataSegment->fileoff;

	const uintptr_t start = (uintptr_t)header + dataSection->offset;
	const char *cstring = NULL;

	for (uint32_t offset = 0; offset < dataSection->size; offset++) {
		const char *currentChar = (const char *)(start + offset);

		if (*currentChar == '\0') {
			if (cstring) {
				NSString *const objcString = [NSString stringWithUTF8String:cstring];

				if (objcString) {
					NSNumber *const offset = @(((uint64_t)cstring - (uint64_t)header) + mappedOffset);
					[originalStrings setObject:offset forKey:objcString];
				}

				cstring = NULL;
			}
		} else if (cstring == NULL) {
			cstring = currentChar;
		}
	}

	return [originalStrings copy];
}

@end