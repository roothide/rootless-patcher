#import <mach-o/loader.h>
#import <mach-o/fat.h>
#import <Foundation/Foundation.h>
#import "Headers/OldABIChecker.h"

@implementation OldABIChecker

+ (BOOL)containsOldABI:(NSData *)machO {
	const struct mach_header_64 *header = (const struct mach_header_64 *)[machO bytes];

	if (header->magic == FAT_MAGIC || header->magic == FAT_CIGAM) {
		const struct fat_header *fatHeader = (const struct fat_header *)header;
		struct fat_arch *arch = (struct fat_arch *)(fatHeader + sizeof(struct fat_header));

		for (uint32_t i = 0; i < OSSwapBigToHostInt32(fatHeader->nfat_arch); i++) {
			const struct mach_header_64 *thinHeader = (const struct mach_header_64 *)(fatHeader + OSSwapBigToHostInt32(arch->offset));

			if ((thinHeader->cpusubtype & ~CPU_SUBTYPE_MASK) == CPU_SUBTYPE_ARM64E) {
				if ((thinHeader->cpusubtype & CPU_SUBTYPE_PTRAUTH_ABI) == 0x0) {
					return YES;
				} else {
					return NO;
				}
			} else {
				return NO;
			}

			arch += 1;
		}
	} else if (header->magic == MH_MAGIC_64 || header->magic == MH_CIGAM_64) {
		if ((header->cpusubtype & ~CPU_SUBTYPE_MASK) == CPU_SUBTYPE_ARM64E) {
			if ((header->cpusubtype & CPU_SUBTYPE_PTRAUTH_ABI) == 0x0) {
				return YES;
			} else {
				return NO;
			}
		} else {
			return NO;
		}
	}

	return NO;
}

@end