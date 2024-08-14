#import <Foundation/Foundation.h>
#import "Headers/CodesignHandler.h"
#import "Headers/SpawnHandler.h"

@implementation CodesignHandler

+ (BOOL)removeCodesignFromFile:(NSString *)file {
	return [SpawnHandler spawnWithArguments:@[
		@"ldid",
		@"-r",
		file
	]];
}

+ (BOOL)addCodesignToFile:(NSString *)file {
	return [SpawnHandler spawnWithArguments:@[
		@"ldid",
		@"-S",
		file
	]];
}

@end