#import <Foundation/Foundation.h>
#import "Headers/CodesignHandler.h"
#import "Headers/SpawnHandler.h"

@implementation CodesignHandler

+ (int)removeCodesignFromFile:(NSString *)file {
	return [SpawnHandler spawnWithArguments:@[
		@"ldid",
		@"-r",
		file
	]];
}

+ (int)addCodesignToFile:(NSString *)file {
	return [SpawnHandler spawnWithArguments:@[
		@"ldid",
		@"-S",
		file
	]];
}

@end