#import <Foundation/Foundation.h>
#import "Headers/RPMachOParser.h"

@implementation RPMachOParser {
	struct mach_header_64 *_header;
}

+ (instancetype)parserWithHeader:(struct mach_header_64 *)header {
	RPMachOParser *const parser = [RPMachOParser new];

	if (parser) {
		parser->_header = header;
	}

	return parser;
}

- (struct segment_command_64 *)segmentWithName:(NSString *)segname {
	struct load_command *lc = (struct load_command *)(_header + 1);

	for (uint32_t i = 0; i < _header->ncmds; i++) {
		if (lc->cmd == LC_SEGMENT_64) {
			struct segment_command_64 *segment = (struct segment_command_64 *)lc;

			if (strcmp(segment->segname, segname.UTF8String) == 0) {
				return segment;
			}
		}

		lc = (struct load_command *)((uintptr_t)lc + (uint64_t)lc->cmdsize);
	}

	return nil;
}

- (struct section_64 *)sectionInSegment:(struct segment_command_64 *)segment withName:(NSString *)sectname {
	if (!segment) {
		return nil;
	}

	struct section_64 *sect = (struct section_64 *)(segment + 1);

	for (uint32_t i = 0; i < segment->nsects; i++) {
		if (strcmp(sect->sectname, sectname.UTF8String) == 0) {
			return sect;
		}

		sect = (struct section_64 *)(sect + 1);
	}

	return nil;
}

- (uint64_t)vmEnd {
	uint64_t vmEnd = 0;

	struct load_command *lc = (struct load_command *)(_header + 1);

	for (uint32_t i = 0; i < _header->ncmds; i++) {
		if (lc->cmd == LC_SEGMENT_64) {
			struct segment_command_64 *segment = (struct segment_command_64 *)lc;

			if (segment->vmsize && vmEnd < segment->vmaddr + segment->vmsize) {
				vmEnd = segment->vmaddr + segment->vmsize;
			}
		}

		lc = (struct load_command *)((uint64_t)lc + (uint64_t)lc->cmdsize);
	}

    return vmEnd;
}

- (struct mach_header_64 *)header {
	return _header;
}

@end