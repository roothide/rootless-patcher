#import <Foundation/Foundation.h>
#import "Headers/ScriptHandler.h"
#import "Headers/DirectoryScanner.h"
#import "Headers/MachOThinner.h"
#import "Headers/StringScanner.h"
#import "Headers/MachOModifier.h"
#import "Headers/OldABIChecker.h"
#import "Headers/PlistHandler.h"

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
		if (!debPath || ![fileManager fileExistsAtPath:debPath isDirectory:&isDirectory] || isDirectory) {
			return 1;
		}

		const BOOL handleScript = [ScriptHandler handleScriptForFile:debPath];
		if (!handleScript) {
			return 1;
		}

		NSString *const patchWorkingDirectory = [temporaryDirectory stringByAppendingPathComponent:[NSString stringWithFormat:@"patch_%@", [[debPath lastPathComponent] stringByDeletingPathExtension]]];
		if (![fileManager fileExistsAtPath:patchWorkingDirectory]) {
			return 1;
		}

		DirectoryScanner *const directoryScanner = [DirectoryScanner directoryScannerWithDirectory:patchWorkingDirectory];
		NSArray<NSString *> *const machOFiles = [directoryScanner machOFiles];
		NSArray<NSString *> *const plistFiles = [directoryScanner plistFiles];
		__unused NSArray<NSString *> *const controlScriptFiles = [directoryScanner controlScriptFiles];

		NSDictionary *const allThinnedMachOs = [MachOThinner thinnedMachOsFromPaths:machOFiles];

		NSData *const conversionRulesetData = [NSData dataWithContentsOfFile:@"/var/jb/Library/Application Support/rootless-patcher/ConversionRuleset.json"];

		NSError *error;
		NSDictionary *const conversionRuleset = [NSJSONSerialization JSONObjectWithData:conversionRulesetData options:kNilOptions error:&error];
		if (error) {
			printf("Could not find conversion ruleset.\n");
			return 1;
		}

		BOOL containsOldABI = NO;

		error = nil;
		for (NSString *fatMachO in allThinnedMachOs) {
			NSArray<NSString *> *const thinnedMachOs = [allThinnedMachOs objectForKey:fatMachO];

			for (NSString *file in thinnedMachOs) {
				// Fix perms for actual fat file not thinned
				NSDictionary<NSFileAttributeKey, id> *const fileAttributes = [fileManager attributesOfItemAtPath:fatMachO error:&error];
				if (error) {
					break;
				}

				StringScanner *const stringScanner = [StringScanner stringScannerWithFile:file conversionRuleset:conversionRuleset];
				NSDictionary<NSString *, NSString *> *const stringMap = [stringScanner stringMap];

				MachOModifier *const modifier = [MachOModifier modifierWithFile:file];
				[modifier addSegment:@"__PATCH_ROOTLESS" withSection:@"__cstring" withStringMap:stringMap];
				[modifier rebaseStringsWithStringMap:stringMap];

				NSData *const data = [modifier data];
				[data writeToFile:file options:NSDataWritingAtomic error:nil];

				if (!containsOldABI && [OldABIChecker containsOldABI:data]) {
					containsOldABI = YES;
				}
				// Fix perms for actual fat file not thinned
				error = nil;
				[fileManager setAttributes:fileAttributes ofItemAtPath:file error:&error];
				if (error) {
					break;
				}
			}
		}

		printf("Contains old abi? %d\n", containsOldABI);

		error = nil;
		for (NSString *plist in plistFiles) {
			NSDictionary<NSFileAttributeKey, id> *const fileAttributes = [fileManager attributesOfItemAtPath:plist error:&error];
			if (error) {
				break;
			}

			PlistHandler *const handler = [PlistHandler handlerWithPlistFile:plist];
			[handler convertStringsUsingStringMap:conversionRuleset];

			NSDictionary *const convertedPlist = [handler plistDictionary];
			[convertedPlist writeToFile:plist atomically:YES];

			error = nil;
			[fileManager setAttributes:fileAttributes ofItemAtPath:plist error:&error];
			if (error) {
				break;
			}
		}

		return 0;
	}
}
