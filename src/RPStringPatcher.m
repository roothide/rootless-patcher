// Copyright (c) 2024 Nightwind

#import <Foundation/Foundation.h>
#import "Headers/RPStringPatcher.h"
#import "Headers/RPMachOParser.h"
#import "Headers/assembler.h"

struct __CFString {
	uint64_t isa;
	uint64_t info;
	uint64_t data;
	uint64_t length;
} __attribute__((aligned(0x8)));

@implementation RPStringPatcher {
	NSMutableData *_data;
	NSDictionary<NSString *, NSNumber *> *_replacementOffsetMap;
	NSDictionary<NSString *, NSNumber *> *_originalOffsetMap;
	RPMachOParser *_parser;
	struct segment_command_64 *_textSegment;
	struct section_64 *_cfstringTableSection;
	struct section_64 *_globalTableSection;
	struct section_64 *_cStringTableSection;
	BOOL _isDylib;
}

+ (instancetype)patcherWithData:(NSData *)data replacementOffsetMap:(NSDictionary<NSString *, NSNumber *> *)replacementOffsetMap originalOffsetMap:(NSDictionary<NSString *, NSNumber *> *)originalOffsetMap {
	RPStringPatcher *const patcher = [RPStringPatcher new];

	if (patcher) {
		patcher->_data = [data mutableCopy];
		patcher->_replacementOffsetMap = replacementOffsetMap;
		patcher->_originalOffsetMap = originalOffsetMap;

		struct mach_header_64 *header = (struct mach_header_64 *)[patcher->_data bytes];
		patcher->_parser = [RPMachOParser parserWithHeader:header];

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
	fprintf(stdout, "\t%s -> %s\n", originalString.UTF8String, patchedString.UTF8String);

	const uint64_t originalAddress = [[_originalOffsetMap valueForKey:originalString] unsignedLongLongValue];
	const uint64_t replacementAddress = [[_replacementOffsetMap valueForKey:patchedString] unsignedLongLongValue];

	if ((!originalAddress || !replacementAddress) || (replacementAddress == originalAddress)) return;

	const size_t oldLength = [originalString length];
	const size_t newLength = [patchedString length];

	if (_isDylib) {
		if (_cfstringTableSection) {
			[self _patchCFString:originalAddress replacementAddress:replacementAddress newLength:newLength];
		}

		[self _patchCString:originalAddress replacementAddress:replacementAddress oldLength:oldLength newLength:newLength];

		if (_globalTableSection) {
			[self _patchGlobalCString:originalAddress replacementAddress:replacementAddress];
		}
	} else {
		if (_cfstringTableSection) {
			[self _patchCFString:originalAddress - IMAGE_BASE replacementAddress:replacementAddress - IMAGE_BASE newLength:newLength];
		}

		[self _patchCString:originalAddress - IMAGE_BASE replacementAddress:replacementAddress - IMAGE_BASE oldLength:oldLength newLength:newLength];

		if (_globalTableSection) {
			[self _patchGlobalCString:originalAddress - IMAGE_BASE replacementAddress:replacementAddress];
		}
	}
}

- (void)_patchCFString:(uint32_t)originalAddress replacementAddress:(uint32_t)replacementAddress newLength:(size_t)newLength {
	const void *buffer = [_data mutableBytes];
	const uint32_t tableAddress = _isDylib ? (uint32_t)(_cfstringTableSection->addr) : (uint32_t)(_cfstringTableSection->addr - IMAGE_BASE);

	for (uint32_t i = 0; i < _cfstringTableSection->size; i += sizeof(struct __CFString)) {
        struct __CFString *cfString = (struct __CFString *)(buffer + tableAddress + i);

		if (OSSwapLittleToHostInt32((uint32_t)cfString->data) == originalAddress) {
			*(uint32_t *)(&cfString->data) = OSSwapHostToLittleInt32(replacementAddress);
			*(uint32_t *)(&cfString->length) = OSSwapHostToLittleInt32(newLength);
		}
	}
}

- (void)_patchGlobalCString:(uint64_t)originalAddress replacementAddress:(uint64_t)replacementAddress {
	const void *buffer = [_data mutableBytes];
	const uint32_t tableAddress = _isDylib ? (uint32_t)(_globalTableSection->addr) : (uint32_t)(_globalTableSection->addr - IMAGE_BASE);

	for (uint32_t i = 0; i < _globalTableSection->size; i += sizeof(char *)) {
		uint64_t reference = OSSwapLittleToHostInt64(*(uint64_t *)(buffer + tableAddress + i));
		if ((uint32_t)reference == (uint32_t)originalAddress) {
            *(uint64_t *)(buffer + tableAddress + i) = OSSwapHostToLittleInt64(replacementAddress);
		}
	}
}

- (void)_patchCString:(uint64_t)originalAddress replacementAddress:(uint64_t)replacementAddress oldLength:(size_t)oldLength newLength:(size_t)newLength {
	const uint8_t *buffer = (const uint8_t *)[_data mutableBytes];

    uint64_t registers[32];
    bzero(registers, sizeof(registers));

	const uint64_t end = (uint64_t)[_data length] & ~3;

    for (uint64_t i = 0; i < end; i += INSTRUCTION_SIZE) {
		const uint32_t previousInstruction = *(uint32_t *)(buffer + i - INSTRUCTION_SIZE);
        const uint32_t currentInstruction = *(uint32_t *)(buffer + i);

		const uint32_t previousRegister = previousInstruction & REGISTER_MASK;
        const uint32_t currentRegister = currentInstruction & REGISTER_MASK;

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
				const uint32_t adrpImmediateNew = (uint32_t)(((replacementAddress & ~PAGE_OFFSET_MASK) / ARM_PAGE_SIZE) - ((i & ~PAGE_OFFSET_MASK) / ARM_PAGE_SIZE));
				const uint32_t adrpInstructionNew = generate_adrp(previousRegister, adrpImmediateNew);
				const uint32_t addImmediateNew = (uint32_t)(replacementAddress & PAGE_OFFSET_MASK);
				const uint32_t addInstructionNew = generate_add(currentRegister, addRegister, addImmediateNew, 0);

                *(uint32_t *)(buffer + i - INSTRUCTION_SIZE) = OSSwapHostToLittleInt32(adrpInstructionNew);
                *(uint32_t *)(buffer + i) = OSSwapHostToLittleInt32(addInstructionNew);
            }
		} else if ((currentInstruction & ADR_MASK) == ADR_OPCODE) {
			registers[currentRegister] = get_adr_value(currentInstruction, i);

			if (registers[currentRegister] == originalAddress) {
				const int64_t offset = (int64_t)replacementAddress - (int64_t)i;

				if (offset >= -ADR_MAX_RANGE && offset <= ADR_MAX_RANGE) {
					const uint32_t adrInstructionNew = generate_adr(currentRegister, (int)offset);
					*(uint32_t *)(buffer + i) = OSSwapHostToLittleInt32(adrInstructionNew);

					[self _patchSwiftInstructionForLengthAt:i + (INSTRUCTION_SIZE * 4) oldLength:oldLength newLength:newLength];
				} else {
					const uint32_t adrpImmediate = (uint32_t)(((replacementAddress & ~PAGE_OFFSET_MASK) - (i & ~PAGE_OFFSET_MASK)) >> 12);
					const uint32_t addImmediate = replacementAddress & PAGE_OFFSET_MASK;

					const uint32_t adrpInstruction = generate_adrp(currentRegister, adrpImmediate);
					const uint32_t addInstruction = generate_add(currentRegister, currentRegister, addImmediate, 0);

					*(uint32_t *)(buffer + i) = OSSwapHostToLittleInt32(adrpInstruction);

					const uint32_t nextInstruction = *(uint32_t *)(buffer + i + INSTRUCTION_SIZE);

					if (i + INSTRUCTION_SIZE < end && nextInstruction == NOP_OPCODE) {
						*(uint32_t *)(buffer + i + INSTRUCTION_SIZE) = OSSwapHostToLittleInt32(addInstruction);

						[self _patchSwiftInstructionForLengthAt:i + (INSTRUCTION_SIZE * 4) oldLength:oldLength newLength:newLength];
					} else {
						fprintf(stderr, "[!] FAILED TO PATCH - Not enough space to write ADD instruction at address 0x%llx\n", i);
					}
				}
			}
		}
    }
}

- (void)_patchSwiftInstructionForLengthAt:(uint64_t)address oldLength:(size_t)oldLength newLength:(size_t)newLength {
    const uint8_t *buffer = (const uint8_t *)[_data mutableBytes];
	const uint64_t end = (uint64_t)[_data length] & ~3;

	const uint32_t movLengthInstruction = *(uint32_t *)(buffer + address);

    if ((movLengthInstruction & MOV_MASK) == MOV_OPCODE && address < end) {
        const uint32_t movImmediate = get_mov_value(movLengthInstruction);

        if (movImmediate == oldLength) {
			fprintf(stdout, "[+] Patching Swift-specific hardcoded length\n");
            const uint32_t movRegister = get_mov_register(movLengthInstruction);
            *(uint32_t *)(buffer + address) = OSSwapHostToLittleInt32(generate_mov(movRegister, newLength));
        }
    }
}

- (NSData *)data {
	return [_data copy];
}

@end