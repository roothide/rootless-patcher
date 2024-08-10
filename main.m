#import <Foundation/Foundation.h>
#import "Headers/ScriptHandler.h"
#import "Headers/DirectoryScanner.h"
#import "Headers/MachOThinner.h"
#import "Headers/StringScanner.h"
#import "Headers/MachOModifier.h"

int main(int argc, char *argv[], char *envp[]) {
	@autoreleasepool {
		if (argc != 2) {
			printf("\n");
			printf("Usage:\n");
			printf("rootless-patcher <path/to/binary>\n");
			printf("\n");

			return 1;
		}

		NSString *const temporaryDirectory = [NSTemporaryDirectory() stringByAppendingPathComponent:@"rootless-patcher"];
		NSFileManager *const fileManager = [NSFileManager defaultManager];

		NSString *const debPath = [NSString stringWithUTF8String:argv[1]];
		BOOL isDirectory;
		if (!debPath || ![fileManager fileExistsAtPath:debPath isDirectory:&isDirectory] || isDirectory) return 1;

		const BOOL handleScript = [ScriptHandler handleScriptForFile:debPath];
		if (!handleScript) {
			return 1;
		}

		NSString *const patchWorkingDirectory = [temporaryDirectory stringByAppendingPathComponent:[NSString stringWithFormat:@"patch_%@", [[debPath lastPathComponent] stringByDeletingPathExtension]]];
		if (![fileManager fileExistsAtPath:patchWorkingDirectory]) return 1;

		DirectoryScanner *const directoryScanner = [DirectoryScanner directoryScannerWithDirectory:patchWorkingDirectory];
		NSArray<NSString *> *const machOFiles = [directoryScanner machOFiles];
		__unused NSArray<NSString *> *const plistFiles = [directoryScanner plistFiles];
		__unused NSArray<NSString *> *const controlScriptFiles = [directoryScanner controlScriptFiles];

		NSDictionary *const allThinnedMachOs = [MachOThinner thinnedMachOsFromPaths:machOFiles];

		NSData *const conversionRulesetData = [NSData dataWithContentsOfFile:@"/var/jb/Library/Application Support/rootless-patcher/ConversionRuleset.json"];

		NSError *error;
		NSDictionary *const conversionRuleset = [NSJSONSerialization JSONObjectWithData:conversionRulesetData options:kNilOptions error:&error];
		if (error) {
			printf("Could not find conversion ruleset.\n");
			return 1;
		}

		for (NSString *machOKey in [allThinnedMachOs allKeys]) {
			NSArray<NSString *> *const thinnedMachOs = [allThinnedMachOs objectForKey:machOKey];

			for (NSString *file in thinnedMachOs) {
				StringScanner *const stringScanner = [StringScanner stringScannerWithFile:file conversionRuleset:conversionRuleset];
				NSDictionary<NSString *, NSString *> *const stringMap = [stringScanner stringMap];

				MachOModifier *const modifier = [MachOModifier modifierWithFile:file];
				[modifier addSegment:@"__PATCH_ROOTLESS" withSection:@"__cstring" withStringMap:stringMap];
				[modifier rebaseStringsWithStringMap:stringMap];

				NSData *const data = [modifier data];
				[data writeToFile:[[file stringByDeletingPathExtension] stringByAppendingString:@"1"] options:NSDataWritingAtomic error:nil];
			}
		}

		return 0;
	}
}
