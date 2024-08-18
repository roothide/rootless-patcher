#ifndef ASSEMBLER_H
#define ASSEMBLER_H

#import <stdint.h>

#define PAGE_OFFSET_MASK	0xFFF
#define ARM_PAGE_SIZE		0x1000

#define IMAGE_BASE	0x100000000

#define ADRP_MASK	0x9F000000
#define ADRP_OPCODE	0x90000000
#define ADD_MASK	0xFF000000
#define ADD_OPCODE	0x91000000
#define ADR_MASK	0x9F000000
#define ADR_OPCODE	0x10000000

#define get_adrp_value(instruction, i)	(((int64_t)(((instruction & 0x60000000) >> 18) | ((instruction & 0xffffe0) << 8)) << 1) + (i & ~PAGE_OFFSET_MASK))
#define get_adr_value(instruction, i)	(((int64_t)(((instruction & 0x60000000) >> 18) | ((instruction & 0xffffe0) << 8)) >> 11) + i)
#define get_add_register(instruction)	((instruction >> 5) & 0x1f)
#define get_add_value(instruction)		((instruction >> 10) & PAGE_OFFSET_MASK)
#define get_add_shift(instruction)		((instruction >> 22) & 3)

uint32_t generate_adrp(int destination_register, int immediate);
uint32_t generate_adr(int destination_register, int immediate);
uint32_t generate_add(int destination_register, int source_register, int immediate, int shift);

#endif // ASSEMBLER_H