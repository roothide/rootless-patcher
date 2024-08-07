#import <mach-o/loader.h>
#import <mach-o/fat.h>
#import <Foundation/Foundation.h>
#import "Headers/MachOThinner.h"

@implementation MachOThinner

+ (NSDictionary *)thinnedMachOsFromPaths:(NSArray<NSString *> *)paths {
	NSMutableDictionary *const thinnedMachOs = [NSMutableDictionary dictionary];

	for (NSString *path in paths) {
		NSArray *const thinnedMachO = [MachOThinner _thinnedMachOsFromPath:path];
		[thinnedMachOs setObject:thinnedMachO forKey:path];
	}

	return [thinnedMachOs copy];
}

+ (NSArray<NSString *> *)_thinnedMachOsFromPath:(NSString *)path {
	NSMutableArray *const thinnedMachOs = [NSMutableArray array];

	NSData *const data = [NSData dataWithContentsOfFile:path];

	const struct mach_header_64 *header = (const struct mach_header_64 *)[data bytes];
	const uint32_t magic = header->magic;

	if (magic == FAT_MAGIC || magic == FAT_CIGAM) {
		NSArray<NSString *> *const thinnedMachOsFromFAT = [MachOThinner _thinnedMachOsFromFAT:path];
		for (NSString *thinnedMachO in thinnedMachOsFromFAT) {
			[thinnedMachOs addObject:thinnedMachO];
		}
	} else {
		NSString *const thinnedPath = [MachOThinner _thinnedPathForPath:path cpusubtype:header->cpusubtype];

		NSError *error;
		[data writeToFile:thinnedPath options:NSDataWritingAtomic error:&error];

		if (!error) {
			[thinnedMachOs addObject:thinnedPath];
		}
	}

	return [thinnedMachOs copy];
}

+ (NSArray<NSString *> *)_thinnedMachOsFromFAT:(NSString *)path {
	NSMutableArray *const thinnedMachOs = [NSMutableArray array];

	NSData *const data = [NSData dataWithContentsOfFile:path];

	const struct fat_header *header = (const struct fat_header *)[data bytes];
	struct fat_arch *arch = (struct fat_arch *)([data bytes] + sizeof(struct fat_header));

	for (uint32_t i = 0; i < OSSwapBigToHostInt32(header->nfat_arch); i++) {
		const struct mach_header_64 *mh = (const struct mach_header_64 *)([data bytes] + OSSwapBigToHostInt32(arch->offset));

		if (mh->cputype == CPU_TYPE_ARM64) {
			const NSRange sliceRange = NSMakeRange(OSSwapBigToHostInt32(arch->offset), OSSwapBigToHostInt32(arch->size));
			NSData *const subdata = [data subdataWithRange:sliceRange];

			NSString *const thinnedPath = [MachOThinner _thinnedPathForPath:path cpusubtype:mh->cpusubtype];

			NSError *error;
			[subdata writeToFile:thinnedPath options:NSDataWritingAtomic error:&error];

			if (!error) {
				[thinnedMachOs addObject:thinnedPath];
			}
		}

		arch++;
	}

	return thinnedMachOs;
}

+ (NSString *)_thinnedPathForPath:(NSString *)path cpusubtype:(cpu_subtype_t)cpusubtype {
	NSString *const name = [path lastPathComponent];
	NSString *const subtype = [MachOThinner _stringFromCpuSubtype:cpusubtype];
	return [[path stringByDeletingLastPathComponent] stringByAppendingPathComponent:[NSString stringWithFormat:@"%@_%@", subtype, name]];
}

+ (NSString *)_stringFromCpuSubtype:(cpu_subtype_t)cpusubtype {
	if ((cpusubtype & ~CPU_SUBTYPE_MASK) == CPU_SUBTYPE_ARM64E) {
		return @"arm64e";
	} else if ((cpusubtype & ~CPU_SUBTYPE_MASK) == CPU_SUBTYPE_ARM64_ALL) {
		return @"arm64";
	} else {
		return @"unknown";
	}
}

@end