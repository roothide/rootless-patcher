// Copyright (c) 2024 Nightwind

#ifndef ASSEMBLER_H
#define ASSEMBLER_H

#import <stdint.h>

#define INSTRUCTION_SIZE	0x4

#define ADR_MAX_RANGE		(1024 * 1024)

#define REGISTER_MASK		0x1F
#define PAGE_OFFSET_MASK	0xFFF
#define ARM_PAGE_SIZE		0x1000

#define IMAGE_BASE	0x100000000

#define MOV_OPCODE	0b11010010100000000000000000000000
#define NOP_OPCODE	0b11010101000000110010000000011111
#define ADRP_OPCODE	0b10010000000000000000000000000000
#define ADD_OPCODE	0b10010001000000000000000000000000
#define ADR_OPCODE	0b00010000000000000000000000000000

#define MOV_MASK	0xD2800000
#define ADRP_MASK	0x9F000000
#define ADD_MASK	0xFF000000
#define ADR_MASK	0x9F000000

#define get_adrp_value(instruction, i)				(((int64_t)(((instruction & 0x60000000) >> 18) | ((instruction & 0xffffe0) << 8)) << 1) + (i & ~PAGE_OFFSET_MASK))

#define get_adr_value(instruction, i)				(((int64_t)(((instruction & 0x60000000) >> 18) | ((instruction & 0xffffe0) << 8)) >> 11) + i)

#define get_add_register(instruction)				((instruction >> 5) & REGISTER_MASK)
#define get_add_value(instruction)					((instruction >> 10) & PAGE_OFFSET_MASK)
#define get_add_shift(instruction)					((instruction >> 22) & 3)

#define get_mov_value(instruction)					((instruction >> 5) & 0xFFFF)
#define get_mov_register(instruction)   			(instruction & REGISTER_MASK)

uint32_t generate_adrp(int destination_register, int immediate);
uint32_t generate_adr(int destination_register, int immediate);
uint32_t generate_add(int destination_register, int source_register, int immediate, int shift);
uint32_t generate_mov(int destination_register, int immediate);

#endif // ASSEMBLER_H