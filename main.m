#import <Foundation/Foundation.h>
#import "Headers/ScriptHandler.h"
#import "Headers/DirectoryScanner.h"
#import "Headers/MachOThinner.h"
#import "Headers/StringScanner.h"
#import "Headers/MachOModifier.h"
#import "Headers/OldABIChecker.h"
#import "Headers/PlistHandler.h"
#import "Headers/ControlScriptHandler.h"
#import "Headers/ControlParser.h"
#import "Headers/MachOMerger.h"

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
		NSArray<NSString *> *const controlScriptFiles = [directoryScanner controlScriptFiles];
		NSString *const controlFile = [directoryScanner controlFile];

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
			}

			NSDictionary<NSFileAttributeKey, id> *const fileAttributes = [fileManager attributesOfItemAtPath:fatMachO error:&error];

			const BOOL successfullyMerged = [MachOMerger mergeMachOsAtPaths:thinnedMachOs outputPath:fatMachO];
			if (!successfullyMerged) {
				printf("Failed to merge Mach-O's!\n");
				break;
			}

			error = nil;
			[fileManager setAttributes:fileAttributes ofItemAtPath:fatMachO error:&error];
			if (error) {
				break;
			}

			for (NSString *file in thinnedMachOs) {
				error = nil;
				[fileManager removeItemAtPath:file error:&error];
				if (error) {
					break;
				}
			}
		}

		printf("Contains old abi? %d\n", containsOldABI);
		error = nil;

		NSDictionary<NSFileAttributeKey, id> *const fileAttributes = [fileManager attributesOfItemAtPath:controlFile error:&error];
		if (error) {
			return 1;
		}

		ControlParser *const controlParser = [ControlParser parserWithControlFile:controlFile];
		if (containsOldABI) {
			NSMutableArray *const dependencies = [controlParser controlValueForKey:@"Depends"];
			[dependencies addObject:@"cy+cpu.arm64v8 | oldabi-xina | oldabi"];
		}

		error = nil;
		[[controlParser controlFileAsString] writeToFile:controlFile atomically:YES encoding:NSUTF8StringEncoding error:&error];
		if (error) {
			return 1;
		}

		error = nil;
		[fileManager setAttributes:fileAttributes ofItemAtPath:controlFile error:&error];
		if (error) {
			return 1;
		}

		error = nil;
		for (NSString *plist in plistFiles) {
			NSDictionary<NSFileAttributeKey, id> *const fileAttributes = [fileManager attributesOfItemAtPath:plist error:&error];
			if (error) {
				break;
			}

			PlistHandler *const handler = [PlistHandler handlerWithPlistFile:plist];
			[handler convertStringsUsingStringMap:conversionRuleset];

			[[handler plistDictionary] writeToFile:plist atomically:YES];

			error = nil;
			[fileManager setAttributes:fileAttributes ofItemAtPath:plist error:&error];
			if (error) {
				break;
			}
		}

		error = nil;
		for (NSString *controlScriptFile in controlScriptFiles) {
			NSDictionary<NSFileAttributeKey, id> *const fileAttributes = [fileManager attributesOfItemAtPath:controlScriptFile error:&error];
			if (error) {
				break;
			}

			ControlScriptHandler *const handler = [ControlScriptHandler handlerWithControlScriptFile:controlScriptFile];
			[handler convertStringsUsingStringMap:conversionRuleset];

			error = nil;
			NSString *const convertedFileContents = [handler fileContents];
			[convertedFileContents writeToFile:controlScriptFile atomically:YES encoding:NSUTF8StringEncoding error:&error];
			if (error) {
				break;
			}

			error = nil;
			[fileManager setAttributes:fileAttributes ofItemAtPath:controlScriptFile error:&error];
			if (error) {
				break;
			}
		}

		return 0;
	}
}
