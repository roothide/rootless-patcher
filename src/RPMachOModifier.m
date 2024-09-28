#import <mach-o/loader.h>
#import <mach-o/fixup-chains.h>
#import <Foundation/Foundation.h>
#import "Headers/RPMachOModifier.h"
#import "Headers/RPMachOParser.h"
#import "Headers/RPStringPatcher.h"

@implementation RPMachOModifier {
	NSMutableData *_fileData;
	RPMachOParser *_parser;
	NSString *_filePath;
	NSMutableDictionary *_replacementOffsetMap;
}

+ (instancetype)modifierWithFile:(NSString *)file {
	RPMachOModifier *const modifier = [RPMachOModifier new];

	if (modifier) {
		NSMutableData *const data = [NSMutableData dataWithContentsOfFile:file];

		modifier->_fileData = data;
		modifier->_parser = [RPMachOParser parserWithHeader:(struct mach_header_64 *)[data bytes]];
		modifier->_filePath = file;

		modifier->_replacementOffsetMap = [NSMutableDictionary dictionary];
	}

	return modifier;
}

- (void)addSegment:(NSString *)segname section:(NSString *)sectname stringMap:(NSDictionary<NSString *, NSString *> *)stringMap {
	struct mach_header_64 *header = (struct mach_header_64 *)[_parser header];

	struct segment_command_64 *llvmSegment = [_parser segmentWithName:@"__LLVM"];
	struct segment_command_64 *linkeditSegment = [_parser segmentWithName:@"__LINKEDIT"];
	if (!linkeditSegment) {
		return;
	}

	const uint64_t vmEnd = [_parser vmEnd];

	const NSRange endRange = llvmSegment ? NSMakeRange(llvmSegment->fileoff, llvmSegment->filesize + linkeditSegment->filesize) : NSMakeRange(linkeditSegment->fileoff, linkeditSegment->filesize);
	NSData *const endData = [_fileData subdataWithRange:endRange];
	[_fileData replaceBytesInRange:endRange withBytes:nil length:0];

	const struct segment_command_64 newSegment = {
		.cmd = LC_SEGMENT_64,
		.cmdsize = sizeof(struct segment_command_64) + sizeof(struct section_64),
		.vmaddr = llvmSegment ? llvmSegment->vmaddr : vmEnd,
		.vmsize = PAGE_SIZE * [self _pagesNeededForStringMap:stringMap],
		.fileoff = llvmSegment ? llvmSegment->fileoff : _fileData.length,
		.filesize = PAGE_SIZE,
		.maxprot = VM_PROT_READ,
		.initprot = VM_PROT_READ,
		.nsects = 1
	};

	strncpy((char *)newSegment.segname, segname.UTF8String, sizeof(newSegment.segname));

	const struct section_64 newSection = {
		.addr = newSegment.vmaddr,
		.size = newSegment.vmsize,
		.offset = (uint32_t)(newSegment.fileoff),
		.align = 0,
		.reloff = 0,
		.nreloc = 0,
		.flags = S_CSTRING_LITERALS,
		.reserved1 = 0,
		.reserved2 = 0,
		.reserved3 = 0
	};

	strncpy((char *)newSection.segname, segname.UTF8String, sizeof(newSection.segname));
	strncpy((char *)newSection.sectname, sectname.UTF8String, sizeof(newSection.sectname));

	const uint64_t insertOffset = (uint64_t)(llvmSegment ?: linkeditSegment) - (uint64_t)(header + 1);

	unsigned char *cmds = (unsigned char *)malloc(header->sizeofcmds);

	memcpy(cmds, header + 1, header->sizeofcmds);

	unsigned char *patch = (unsigned char *)(header + 1) + insertOffset;

	memcpy(patch, &newSegment, sizeof(newSegment));
	patch += sizeof(newSegment);

	memcpy(patch, &newSection, sizeof(newSection));
	patch += sizeof(newSection);

	memcpy(patch, cmds + insertOffset, header->sizeofcmds - insertOffset);

	free((void *)cmds);

	_parser = [RPMachOParser parserWithHeader:header];

	llvmSegment = [_parser segmentWithName:@"__LLVM"];
	linkeditSegment = [_parser segmentWithName:@"__LINKEDIT"];

	header->ncmds += 1;
	header->sizeofcmds += newSegment.cmdsize;

	if (llvmSegment) {
        struct section_64 *sect = (struct section_64 *)(llvmSegment + 1);
        for (uint32_t i = 0; i < llvmSegment->nsects; i++) {
			sect->offset = sect->offset - llvmSegment->fileoff + newSegment.fileoff + newSegment.filesize;
			sect->addr = sect->addr - llvmSegment->vmaddr + newSegment.vmaddr + newSegment.vmsize;
            sect = (struct section_64 *)(sect + 1);
        }

		llvmSegment->fileoff = newSegment.fileoff + newSegment.filesize;
		llvmSegment->vmaddr = newSegment.vmaddr + newSegment.vmsize;

		linkeditSegment->fileoff = llvmSegment->filesize + newSegment.fileoff + newSegment.filesize;
		linkeditSegment->vmaddr = llvmSegment->vmsize + newSegment.vmaddr + newSegment.vmsize;
	} else {
		linkeditSegment->fileoff = newSegment.fileoff + newSegment.filesize;
		linkeditSegment->vmaddr = newSegment.vmaddr + newSegment.vmsize;
	}

	struct linkedit_data_command *chainedFixups = nil;
	[self _shiftCommandsWithOffset:newSegment.filesize chainedFixups:&chainedFixups];

	unsigned char *codepage = (unsigned char *)calloc(newSegment.vmsize, 1);
	[self _addPatchedStringsFromStringMap:stringMap toCodepage:codepage mappedOffset:newSegment.vmaddr - newSegment.fileoff sectionOffset:newSection.offset];
	[_fileData appendBytes:codepage length:newSegment.vmsize];
	free((void *)codepage);

	[_fileData appendData:endData];

	if (chainedFixups) {
		[self _fixChainedFixups:chainedFixups linkeditSegment:linkeditSegment];
	}
}

- (void)rebaseStringsWithStringMap:(NSDictionary<NSString *, NSString *> *)stringMap originalOffsetMap:(NSDictionary<NSString *, NSNumber *> *)originalOffsetMap {
	RPStringPatcher *const patcher = [RPStringPatcher patcherWithData:_fileData replacementOffsetMap:_replacementOffsetMap originalOffsetMap:originalOffsetMap];

	for (NSString *originalString in stringMap) {
		NSString *const patchedString = [stringMap objectForKey:originalString];
		[patcher patchString:originalString toString:patchedString];
	}

	_fileData = [[patcher data] mutableCopy];
}

- (void)_addPatchedStringsFromStringMap:(NSDictionary<NSString *, NSString *> *)stringMap toCodepage:(unsigned char *)codepage mappedOffset:(uint64_t)mappedOffset sectionOffset:(uint64_t)sectionOffset {
	NSArray<NSString *> *const patchedStrings = [stringMap allValues];
	uint32_t offset = 0;

	const NSUInteger stringCount = [stringMap count];
	for (NSUInteger i = 0; i < stringCount; i++) {
		const char *string = [patchedStrings[i] UTF8String];
		strcpy((char *)codepage + offset, string);
		[_replacementOffsetMap setObject:@(sectionOffset + offset + mappedOffset) forKey:patchedStrings[i]];
		offset += strlen(string) + 1;
	}
}

- (NSUInteger)_pagesNeededForStringMap:(NSDictionary<NSString *, NSString *> *)stringMap {
    NSArray<NSString *> *const patchedStrings = [stringMap allValues];
    const NSUInteger stringCount = [stringMap count];

    uint64_t totalSize = 0;
    for (NSUInteger i = 0; i < stringCount; i++) {
        totalSize += strlen([patchedStrings[i] UTF8String]) + 1;
    }

    return (totalSize + PAGE_SIZE - 1) / PAGE_SIZE;
}

- (void)_shiftCommandsWithOffset:(uint64_t)fixOffset chainedFixups:(struct linkedit_data_command **)chainedFixups {
	const struct mach_header_64 *header = (struct mach_header_64 *)[_fileData bytes];

	struct load_command *lc = (struct load_command *)(header + 1);

	for (uint32_t i = 0; i < header->ncmds; i++) {
		const uint32_t cmd = lc->cmd;

		if (cmd == LC_DYLD_INFO || cmd == LC_DYLD_INFO_ONLY) {

			struct dyld_info_command *dyldInfoCommand = (struct dyld_info_command *)lc;

			if (dyldInfoCommand->rebase_size > 0) {
				dyldInfoCommand->rebase_off += fixOffset;
			}

			if (dyldInfoCommand->bind_size > 0 && dyldInfoCommand->bind_off) {
				dyldInfoCommand->bind_off += fixOffset;
			}

			if (dyldInfoCommand->weak_bind_size > 0 && dyldInfoCommand->weak_bind_off) {
				dyldInfoCommand->weak_bind_off += fixOffset;
			}

			if (dyldInfoCommand->lazy_bind_size > 0 && dyldInfoCommand->lazy_bind_off) {
				dyldInfoCommand->lazy_bind_off += fixOffset;
			}

			if (dyldInfoCommand->export_size > 0 && dyldInfoCommand->export_off) {
				dyldInfoCommand->export_off += fixOffset;
			}

		} else if (cmd == LC_SYMTAB) {

			struct symtab_command *symtabCommand = (struct symtab_command *)lc;

			if (symtabCommand->symoff) symtabCommand->symoff += fixOffset;
			if (symtabCommand->stroff) symtabCommand->stroff += fixOffset;

		} else if (cmd == LC_DYSYMTAB) {

			struct dysymtab_command *dysymtabCommand = (struct dysymtab_command *)lc;

			if (dysymtabCommand->tocoff) dysymtabCommand->tocoff += fixOffset;
			if (dysymtabCommand->modtaboff) dysymtabCommand->modtaboff += fixOffset;
			if (dysymtabCommand->extrefsymoff) dysymtabCommand->extrefsymoff += fixOffset;
			if (dysymtabCommand->indirectsymoff) dysymtabCommand->indirectsymoff += fixOffset;
			if (dysymtabCommand->extreloff) dysymtabCommand->extreloff += fixOffset;
			if (dysymtabCommand->locreloff) dysymtabCommand->locreloff += fixOffset;

		} else if (
			cmd == LC_FUNCTION_STARTS ||
			cmd == LC_DATA_IN_CODE ||
			cmd == LC_CODE_SIGNATURE ||
			cmd == LC_SEGMENT_SPLIT_INFO ||
			cmd == LC_DYLIB_CODE_SIGN_DRS ||
			cmd == LC_LINKER_OPTIMIZATION_HINT ||
			cmd == LC_DYLD_EXPORTS_TRIE ||
			cmd == LC_DYLD_CHAINED_FIXUPS) {

			struct linkedit_data_command *dataCommand = (struct linkedit_data_command *)lc;

			if (cmd == LC_DYLD_CHAINED_FIXUPS) {
				*chainedFixups = dataCommand;
			}

			if (dataCommand->dataoff) dataCommand->dataoff += fixOffset;
		}

		lc = (struct load_command *)((uint64_t)lc + (uint64_t)lc->cmdsize);
	}
}

- (void)_fixChainedFixups:(struct linkedit_data_command *)chainedFixups linkeditSegment:(struct segment_command_64 *)linkeditSegment {
	struct mach_header_64 *header = (struct mach_header_64 *)[_fileData mutableBytes];

	const uint32_t offsetInLinkedit = (uint32_t)chainedFixups->dataoff - (uint32_t)linkeditSegment->fileoff;
	const uintptr_t linkeditStartAddress = (uint64_t)header + linkeditSegment->fileoff;

	const struct dyld_chained_fixups_header *chainsHeader = (const struct dyld_chained_fixups_header *)(linkeditStartAddress + offsetInLinkedit);
	const struct dyld_chained_starts_in_image *startsInfo = (const struct dyld_chained_starts_in_image *)((uint8_t *)chainsHeader + chainsHeader->starts_offset);

	const uint64_t startsInfoSizeNew = sizeof(struct dyld_chained_starts_in_image) + sizeof(startsInfo->seg_info_offset) * (startsInfo->seg_count + 1);

	NSMutableData *const append = [NSMutableData dataWithLength:startsInfoSizeNew];
	struct dyld_chained_starts_in_image *startsInfoNew = (struct dyld_chained_starts_in_image *)[append mutableBytes];
	bzero(startsInfoNew, startsInfoSizeNew);
	*startsInfoNew = *startsInfo;
	startsInfoNew->seg_count += 1;

	for (uint32_t i = 0; i < startsInfo->seg_count; i++) {
		const uint32_t segmentInfoOffset = startsInfo->seg_info_offset[i];
		if (!segmentInfoOffset) continue;

		startsInfoNew->seg_info_offset[i] = (uint32_t)[append length];

		const struct dyld_chained_starts_in_segment *segmentInfo = (struct dyld_chained_starts_in_segment *)((uint8_t *)startsInfo + segmentInfoOffset);

		int segmentInfoSize = sizeof(struct dyld_chained_starts_in_segment);

		if (segmentInfo->page_count) {
			segmentInfoSize += sizeof(segmentInfo->page_start) * (segmentInfo->page_count - 1);
		}

		[append appendBytes:segmentInfo length:segmentInfoSize];
	}

	[_fileData appendData:append];
	linkeditSegment->filesize += [append length];
	linkeditSegment->vmsize += ([append length] + PAGE_SIZE - 1) & (~(PAGE_SIZE - 1));
}

- (NSData *)data {
	return [_fileData copy];
}

@end