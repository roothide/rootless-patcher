#import <Foundation/Foundation.h>
#import "Headers/RPCodesignHandler.h"
#import "Headers/RPSpawnHandler.h"

@implementation RPCodesignHandler

+ (int)removeCodesignFromFile:(NSString *)file {
	return [RPSpawnHandler spawnWithArguments:@[
		@"ldid",
		@"-r",
		file
	]];
}

+ (int)addCodesignToFile:(NSString *)file {
	return [RPSpawnHandler spawnWithArguments:@[
		@"ldid",
		@"-S",
		file
	]];
}

@end