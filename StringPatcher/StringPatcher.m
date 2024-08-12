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
	MachOParser *_parser;
	struct section_64 *_cfstringTableSection;
	size_t _cfstringTableSectionSize;
	struct section_64 *_globalTableSection;
	size_t _globalTableSectionSize;
	BOOL _isDylib;
}

+ (instancetype)patcherWithData:(NSData *)data {
	StringPatcher *const patcher = [StringPatcher new];

	if (patcher) {
		patcher->_data = [data mutableCopy];

		struct mach_header_64 *header = (struct mach_header_64 *)[patcher->_data bytes];
		patcher->_parser = [MachOParser parserWithHeader:header];

		struct segment_command_64 *dataConstSegment = [patcher->_parser segmentWithName:@"__DATA_CONST"];
		struct segment_command_64 *dataSegment = [patcher->_parser segmentWithName:@"__DATA"];

		patcher->_cfstringTableSection = [patcher->_parser sectionInSegment:dataSegment withName:@"__cfstring"] ?: [patcher->_parser sectionInSegment:dataConstSegment withName:@"__cfstring"];

		if (patcher->_cfstringTableSection) {
			patcher->_cfstringTableSectionSize = patcher->_cfstringTableSection->size;
		}

		patcher->_globalTableSection = [patcher->_parser sectionInSegment:dataSegment withName:@"__data"];
		if (patcher->_globalTableSection) {
			patcher->_globalTableSectionSize = patcher->_globalTableSection->size;
		}

		patcher->_isDylib = header->filetype == MH_DYLIB;
	}

	return patcher;
}

- (void)patchString:(NSString *)originalString toString:(NSString *)patchedString {
	printf("\"%s\" -> \"%s\"", originalString.UTF8String, patchedString.UTF8String);

	uint64_t originalAddress = [self _getCStringAddress:originalString inNewSection:NO];
	uint64_t replacementAddress = [self _getCStringAddress:patchedString inNewSection:YES];

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
			printf(" | cfstring\n");
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
			printf(" | global cstring\n");
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
				printf(" | cstring\n");
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
				printf(" | cstring\n");
				const uint32_t adrImmediateNew = (uint32_t)(replacementAddress - i);
				const uint32_t adrInstructionNew = generate_adr(currentRegister, adrImmediateNew);

				*(uint32_t *)(buffer + i) = OSSwapHostToLittleInt32(adrInstructionNew);
			}
		}
    }
}

- (uint64_t)_getCStringAddress:(NSString *)string inNewSection:(BOOL)inNewSection {
	struct segment_command_64 *segment = [_parser segmentWithName:inNewSection ? @"__PATCH_ROOTLESS" : @"__TEXT"];
	if (!segment) {
		return 0x0;
	}

	struct section_64 *section = [_parser sectionInSegment:segment withName:@"__cstring"];
	if (!section) {
		return 0x0;
	}

	const void *fileBytes = [_data bytes];

	const char *cstring = (const char *)(fileBytes + section->offset);
	const uint64_t mappedOffset = segment->vmaddr - segment->fileoff;

	while (*cstring != '\0') {
		if (!strcmp(cstring, string.UTF8String)) {
			return ((uint64_t)cstring - (uint64_t)fileBytes) + mappedOffset;
		}
		cstring += strlen(cstring) + 1;
	}

	uint8_t *address = [self _bh_memmemWithHaystack:fileBytes haystackLength:0x100000 needle:(const uint8_t *)[string UTF8String] needleLength:[string length]];
	return address ? (uint64_t)address - (uint64_t)fileBytes : 0x0;
}

- (uint8_t *)_bh_memmemWithHaystack:(const uint8_t *)haystack haystackLength:(size_t)hlen needle:(const uint8_t *)needle needleLength:(size_t)nlen {
	size_t skip[256];

    if (nlen <= 0 || !haystack || !needle) {
		return NULL;
	}

    for (size_t scan = 0; scan <= 255; scan = scan + 1) {
		skip[scan] = nlen;
	}

    size_t last = nlen - 1;

    for (size_t scan = 0; scan < last; scan = scan + 1) {
		skip[needle[scan]] = last - scan;
	}

    while (hlen >= nlen) {
        for (size_t scan = last; haystack[scan] == needle[scan]; scan = scan - 1) {
            if (scan == 0) {
				return (void *)haystack;
			}
		}

        hlen -= skip[haystack[last]];
        haystack += skip[haystack[last]];
    }

    return NULL;
}

- (NSData *)data {
	return [_data copy];
}

@end