// Copyright (c) 2024 Nightwind

#include "Headers/assembler.h"

uint32_t generate_adrp(int destination_register, int immediate) {
    uint32_t instruction = ADRP_OPCODE;
	const uint32_t immediate_lo = immediate & 0x3;
	const uint32_t immediate_hi = immediate >> 2 & 0x7ffff;
    instruction |= immediate_lo << 29;
    instruction |= immediate_hi << 5;
    instruction |= destination_register;
    return instruction;
}

uint32_t generate_adr(int destination_register, int immediate) {
    uint32_t instruction = ADR_OPCODE;
	const uint32_t immediate_lo = immediate & 0x3;
	const uint32_t immediate_hi = (immediate >> 2) & 0x7ffff;
    instruction |= immediate_lo << 29;
    instruction |= immediate_hi << 5;
    instruction |= destination_register;
    return instruction;
}

uint32_t generate_add(int destination_register, int source_register, int immediate, int shift) {
    uint32_t instruction = ADD_OPCODE;
    instruction |= immediate << 10;
    instruction |= (shift / 12) << 22;
    instruction |= destination_register;
    instruction |= source_register << 5;
    return instruction;
}

uint32_t generate_mov(int destination_register, int immediate) {
    uint32_t instruction = MOV_OPCODE;
    instruction |= (immediate & 0xFFFF) << 5;
    instruction |= destination_register;
    return instruction;
}