#import <Foundation/Foundation.h>
#import "Headers/CodesignHandler.h"
#import "Headers/SpawnHandler.h"

@implementation CodesignHandler

+ (BOOL)removeCodesignFromFile:(NSString *)file {
	return [SpawnHandler spawnWithCommandPath:@"/var/jb/usr/bin/ldid" arguments:@[
		@"ldid",
		@"-r",
		file
	]];
}

+ (BOOL)addCodesignToFile:(NSString *)file {
	return [SpawnHandler spawnWithCommandPath:@"/var/jb/usr/bin/ldid" arguments:@[
		@"ldid",
		@"-S",
		file
	]];
}

@end