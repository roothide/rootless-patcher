// Copyright (c) 2024 Nightwind

#import <mach-o/loader.h>
#import <Foundation/NSObject.h>
#import <Foundation/NSString.h>

@interface RPMachOParser : NSObject
+ (nullable instancetype)parserWithHeader:(nonnull struct mach_header_64 *)header;
- (nullable struct segment_command_64 *)segmentWithName:(nonnull NSString *)segname;
- (nullable struct section_64 *)sectionInSegment:(nullable struct segment_command_64 *)segment withName:(nonnull NSString *)sectname;
- (uint64_t)vmEnd;
- (nonnull struct mach_header_64 *)header;

+ (nullable instancetype)new __attribute__((unavailable("Use +parserWithHeader: instead")));
- (nullable instancetype)init __attribute__((unavailable("Use +parserWithHeader: instead")));
@end