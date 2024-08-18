#import <Foundation/Foundation.h>
#import "Headers/StringPatcher.h"
#import "Headers/MachOParser.h"
#import "Headers/assembler.h"

struct __CFString {
	uint64_t isa;
	uint64_t info;
	uint64_t data;
	uint64_t length;
} __attribute__((aligned(0x8)));

@implementation StringPatcher {
	NSMutableData *_data;
	NSDictionary<NSString *, NSNumber *> *_replacementOffsetMap;
	MachOParser *_parser;
	struct segment_command_64 *_textSegment;
	struct section_64 *_cfstringTableSection;
	struct section_64 *_globalTableSection;
	struct section_64 *_cStringTableSection;
	BOOL _isDylib;
}

+ (instancetype)patcherWithData:(NSData *)data replacementOffsetMap:(NSDictionary<NSString *, NSNumber *> *)offsetMap {
	StringPatcher *const patcher = [StringPatcher new];

	if (patcher) {
		patcher->_data = [data mutableCopy];
		patcher->_replacementOffsetMap = offsetMap;

		struct mach_header_64 *header = (struct mach_header_64 *)[patcher->_data bytes];
		patcher->_parser = [MachOParser parserWithHeader:header];

		struct segment_command_64 *textSegment = [patcher->_parser segmentWithName:@"__TEXT"];
		struct segment_command_64 *dataConstSegment = [patcher->_parser segmentWithName:@"__DATA_CONST"];
		struct segment_command_64 *dataSegment = [patcher->_parser segmentWithName:@"__DATA"];

		patcher->_textSegment = textSegment;

		patcher->_cStringTableSection = [patcher->_parser sectionInSegment:textSegment withName:@"__cstring"];
		patcher->_cfstringTableSection = [patcher->_parser sectionInSegment:dataSegment withName:@"__cfstring"] ?: [patcher->_parser sectionInSegment:dataConstSegment withName:@"__cfstring"];
		patcher->_globalTableSection = [patcher->_parser sectionInSegment:dataSegment withName:@"__data"];

		patcher->_isDylib = header->filetype == MH_DYLIB;
	}

	return patcher;
}

- (void)patchString:(NSString *)originalString toString:(NSString *)patchedString {
	fprintf(stdout, "\t\"%s\" -> \"%s\"", originalString.UTF8String, patchedString.UTF8String);

	const uint64_t originalAddress = [self _getCStringAddress:originalString];
	const uint64_t replacementAddress = [[_replacementOffsetMap valueForKey:patchedString] unsignedLongLongValue];

	if ((!originalAddress || !replacementAddress) || (replacementAddress == originalAddress)) return;

	const size_t newLength = [patchedString length];

	if (_isDylib) {
		if (_cfstringTableSection) {
			[self _patchCFString:originalAddress replacementAddress:replacementAddress newLength:newLength];
		}

		[self _patchCString:originalAddress replacementAddress:replacementAddress];

		if (_globalTableSection) {
			[self _patchGlobalCString:originalAddress replacementAddress:replacementAddress];
		}
	} else {
		if (_cfstringTableSection) {
			[self _patchCFString:originalAddress - IMAGE_BASE replacementAddress:replacementAddress - IMAGE_BASE newLength:newLength];
		}

		[self _patchCString:originalAddress - IMAGE_BASE replacementAddress:replacementAddress - IMAGE_BASE];

		if (_globalTableSection) {
			[self _patchGlobalCString:originalAddress - IMAGE_BASE replacementAddress:replacementAddress];
		}
	}
}

- (void)_patchCFString:(uint32_t)originalAddress replacementAddress:(uint32_t)replacementAddress newLength:(uint32_t)newLength {
	void *buffer = [_data mutableBytes];
	const uint32_t tableAddress = _isDylib ? (uint32_t)(_cfstringTableSection->addr) : (uint32_t)(_cfstringTableSection->addr - IMAGE_BASE);

	for (uint32_t i = 0; i < _cfstringTableSection->size; i += sizeof(struct __CFString)) {
        struct __CFString *cfString = (struct __CFString *)(buffer + tableAddress + i);

		if (OSSwapLittleToHostInt32((uint32_t)cfString->data) == originalAddress) {
			fprintf(stdout, " | cfstring\n");
			*(uint32_t *)(&cfString->data) = OSSwapHostToLittleInt32(replacementAddress);
			*(uint32_t *)(&cfString->length) = OSSwapHostToLittleInt32(newLength);
		}
	}
}

- (void)_patchGlobalCString:(uint64_t)originalAddress replacementAddress:(uint64_t)replacementAddress {
	void *buffer = [_data mutableBytes];
	const uint32_t tableAddress = _isDylib ? (uint32_t)(_globalTableSection->addr) : (uint32_t)(_globalTableSection->addr - IMAGE_BASE);

	for (uint32_t i = 0; i < _globalTableSection->size; i += sizeof(char *)) {
		uint64_t reference = OSSwapLittleToHostInt64(*(uint64_t *)(buffer + tableAddress + i));
		if ((uint32_t)reference == (uint32_t)originalAddress) {
			fprintf(stdout, " | global cstring\n");
            *(uint64_t *)(buffer + tableAddress + i) = OSSwapHostToLittleInt64(replacementAddress);
		}
	}
}

- (void)_patchCString:(uint64_t)originalAddress replacementAddress:(uint64_t)replacementAddress {
	const uint8_t *buffer = (const uint8_t *)[_data mutableBytes];

    uint64_t registers[32];
    bzero(registers, sizeof(registers));

	const uint64_t end = (uint64_t)[_data length] & ~3;

    for (uint64_t i = 0; i < end; i += 4) {
        const uint32_t currentInstruction = *(uint32_t *)(buffer + i);
        const uint32_t currentRegister = currentInstruction & 0x1F;

        if ((currentInstruction & ADRP_MASK) == ADRP_OPCODE) {
			registers[currentRegister] = get_adrp_value(currentInstruction, i);
			continue;
        } else if ((currentInstruction & ADD_MASK) == ADD_OPCODE) {
            const uint32_t addRegister = get_add_register(currentInstruction);
            const uint32_t addShift = get_add_shift(currentInstruction);
            const uint32_t addImmediate = addShift == 1 ? get_add_value(currentInstruction) << 12 : get_add_value(currentInstruction);

			if (addShift > 1) {
				continue;
			}

			registers[currentRegister] = registers[addRegister] + addImmediate;

            if (registers[currentRegister] == originalAddress) {
				fprintf(stdout, " | cstring\n");
				const uint32_t adrpImmediateNew = (uint32_t)(((replacementAddress & ~PAGE_OFFSET_MASK) / ARM_PAGE_SIZE) - ((i & ~PAGE_OFFSET_MASK) / ARM_PAGE_SIZE));
				const uint32_t addImmediateNew = (uint32_t)(replacementAddress & PAGE_OFFSET_MASK);
				const uint32_t adrpInstructionNew = generate_adrp(currentRegister, adrpImmediateNew);
				const uint32_t addInstructionNew = generate_add(currentRegister, addRegister, addImmediateNew, 0);

                *(uint32_t *)(buffer + i - 0x4) = OSSwapHostToLittleInt32(adrpInstructionNew);
                *(uint32_t *)(buffer + i) = OSSwapHostToLittleInt32(addInstructionNew);
            }
		} else if ((currentInstruction & ADR_MASK) == ADR_OPCODE) {
			registers[currentRegister] = get_adr_value(currentInstruction, i);

			if (registers[currentRegister] == originalAddress) {
				fprintf(stdout, " | cstring\n");
				const uint32_t adrImmediateNew = (uint32_t)(replacementAddress - i);
				const uint32_t adrInstructionNew = generate_adr(currentRegister, adrImmediateNew);

				*(uint32_t *)(buffer + i) = OSSwapHostToLittleInt32(adrInstructionNew);
			}
		}
    }
}

- (uint64_t)_getCStringAddress:(NSString *)string {
	const void *fileBytes = [_data bytes];

	const char *cstring = (const char *)(fileBytes + _cStringTableSection->offset);
	const uint64_t mappedOffset = _textSegment->vmaddr - _textSegment->fileoff;

	// Rewrite this
	while (*cstring != '\0') {
		if (strcmp(cstring, string.UTF8String) == 0) {
			return ((uint64_t)cstring - (uint64_t)fileBytes) + mappedOffset;
		}
		cstring += strlen(cstring) + 1;
	}

	const uint8_t *address = memmem(fileBytes, 0x100000, (const uint8_t *)[string UTF8String], [string length]);
	return address ? (uint64_t)address - (uint64_t)fileBytes : 0x0;
}

- (NSData *)data {
	return [_data copy];
}

@end