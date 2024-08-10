#import <mach-o/loader.h>
#import <mach-o/fixup-chains.h>
#import <Foundation/Foundation.h>
#import "Headers/MachOModifier.h"
#import "Headers/MachOParser.h"
#import "Headers/CodesignHandler.h"
#import "Headers/StringPatcher.h"

@implementation MachOModifier {
	NSMutableData *_fileData;
	MachOParser *_parser;
	NSString *_filePath;
}

+ (instancetype)modifierWithFile:(NSString *)file {
	MachOModifier *const modifier = [MachOModifier new];

	if (modifier) {
		NSMutableData *const data = [NSMutableData dataWithContentsOfFile:file];

		modifier->_fileData = data;
		modifier->_parser = [MachOParser parserWithHeader:(struct mach_header_64 *)[data bytes]];
		modifier->_filePath = file;
	}

	return modifier;
}

- (void)addSegment:(NSString *)segname withSection:(NSString *)sectname withStringMap:(NSDictionary<NSString *, NSString *> *)stringMap {
	struct mach_header_64 *header = (struct mach_header_64 *)[_parser header];

	struct segment_command_64 *linkeditSegment = [_parser segmentWithName:@"__LINKEDIT"];
	if (!linkeditSegment) {
		return;
	}

	const uint64_t vmEnd = [_parser vmEnd];

	const NSRange linkeditRange = NSMakeRange(linkeditSegment->fileoff, linkeditSegment->filesize);
	NSData *const linkeditData = [_fileData subdataWithRange:linkeditRange];
	[_fileData replaceBytesInRange:linkeditRange withBytes:nil length:0];

	const struct segment_command_64 newSegment = {
		.cmd = LC_SEGMENT_64,
		.cmdsize = sizeof(struct segment_command_64) + sizeof(struct section_64),
		.vmaddr = vmEnd,
		.vmsize = PAGE_SIZE,
		.fileoff = _fileData.length,
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
		.flags = S_REGULAR,
		.reserved1 = 0,
		.reserved2 = 0,
		.reserved3 = 0
	};

	strncpy((char *)newSection.segname, segname.UTF8String, sizeof(newSection.segname));
	strncpy((char *)newSection.sectname, sectname.UTF8String, sizeof(newSection.sectname));

	uint64_t linkeditSegmentOffset = (uint64_t)linkeditSegment - ((uint64_t)header + sizeof(struct mach_header_64));

	unsigned char *cmds = (unsigned char *)malloc(header->sizeofcmds);
	memcpy(cmds, (unsigned char *)header + sizeof(struct mach_header_64), header->sizeofcmds);

	unsigned char *patch = (unsigned char *)header + sizeof(struct mach_header_64) + linkeditSegmentOffset;

	memcpy(patch, &newSegment, sizeof(newSegment));
	patch += sizeof(newSegment);

	memcpy(patch, &newSection, sizeof(newSection));
	patch += sizeof(newSection);

	memcpy(patch, cmds + linkeditSegmentOffset, header->sizeofcmds - linkeditSegmentOffset);

	linkeditSegment = (struct segment_command_64 *)patch;

	header->ncmds += 1;
	header->sizeofcmds += newSegment.cmdsize;

	linkeditSegment->fileoff = _fileData.length + newSegment.filesize;
	linkeditSegment->vmaddr = vmEnd + newSegment.vmsize;

	free((void *)cmds);

	struct linkedit_data_command *chainedFixups = nil;
	[self _shiftCommandsWithNewSegment:newSegment chainedFixups:&chainedFixups];

	unsigned char *codepage = (unsigned char *)malloc(newSegment.vmsize);
	[self _addPatchedStringsFromStringMap:stringMap toCodepage:codepage];
	[_fileData appendBytes:codepage length:newSegment.vmsize];
	free((void *)codepage);

	[_fileData appendData:linkeditData];

	if (chainedFixups) {
		[self _fixChainedFixups:chainedFixups linkeditSegment:linkeditSegment];
	}
}

- (void)rebaseStringsWithStringMap:(NSDictionary<NSString *, NSString *> *)stringMap {
	StringPatcher *const patcher = [StringPatcher patcherWithData:_fileData];

	const BOOL removedCodesign = [CodesignHandler removeCodesignFromFile:_filePath];
	if (!removedCodesign) {
		printf("Failed to remove code signature from file %s\n", _filePath.fileSystemRepresentation);
		return;
	}

	for (NSString *originalString in stringMap) {
		NSString *patchedString = [stringMap objectForKey:originalString];
		[patcher patchString:originalString toString:patchedString];
	}

	const BOOL addedCodesign = [CodesignHandler addCodesignToFile:_filePath];
	if (!addedCodesign) {
		printf("Failed to add code signature to file: %s\n", _filePath.fileSystemRepresentation);
		return;
	}

	_fileData = [[patcher data] mutableCopy];
}

- (void)_addPatchedStringsFromStringMap:(NSDictionary<NSString *, NSString *> *)stringMap toCodepage:(unsigned char *)codepage {
	NSArray<NSString *> *const patchedStrings = [stringMap allValues];
	uint32_t offset = 0;

	const size_t stringCount = [stringMap count];
	for (int i = 0; i < stringCount; i++) {
		const char *string = [patchedStrings[i] UTF8String];
		strcpy((char *)codepage + offset, string);
		offset += strlen(string) + 1;
	}
}

- (void)_shiftCommandsWithNewSegment:(struct segment_command_64)segment chainedFixups:(struct linkedit_data_command **)chainedFixups {
	const struct mach_header_64 *header = (struct mach_header_64 *)[_fileData bytes];
	const uint64_t fixOffset = segment.filesize;

	struct load_command *lc = (struct load_command *)((uint64_t)header + sizeof(struct mach_header_64));

	for (uint32_t i = 0; i < header->ncmds; i++) {
		const uint32_t cmd = lc->cmd;

		if (cmd == LC_DYLD_INFO || cmd == LC_DYLD_INFO_ONLY) {

			struct dyld_info_command *dyldInfoCommand = (struct dyld_info_command *)lc;

			dyldInfoCommand->rebase_off += fixOffset;
			dyldInfoCommand->bind_off += fixOffset;

			if (dyldInfoCommand->bind_off) dyldInfoCommand->bind_off += fixOffset;
			if (dyldInfoCommand->lazy_bind_off) dyldInfoCommand->lazy_bind_off += fixOffset;
			if (dyldInfoCommand->export_off) dyldInfoCommand->export_off += fixOffset;

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

	const int startsInfoSizeNew = sizeof(struct dyld_chained_starts_in_image) + sizeof(startsInfo->seg_info_offset) * (startsInfo->seg_count + 1);

	NSMutableData *const append = [NSMutableData dataWithLength:startsInfoSizeNew];
	struct dyld_chained_starts_in_image *startsInfoNew = (struct dyld_chained_starts_in_image *)[append mutableBytes];
	bzero(startsInfoNew, startsInfoSizeNew);
	*startsInfoNew = *startsInfo;
	startsInfoNew->seg_count += 2;

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