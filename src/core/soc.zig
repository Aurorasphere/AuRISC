const std = @import("std");
const alu = @import("alu.zig");
const regs = @import("registers.zig");
const memmap = @import("memory_map.zig");
const r_type = @import("fmts/r-type.zig");
const i_type = @import("fmts/i-type.zig");
const s_type = @import("fmts/s-type.zig");
const cb_type = @import("fmts/cb-type.zig");
const t_type = @import("fmts/t-type.zig");

pub const DM_SIZE: u32 = 0x1000;
pub const IM_SIZE: u32 = 0x1000;

pub const MAX_IRQ: usize = 256;

pub const FLAG_EQ: u8 = 0b00000001;
pub const FLAG_GT: u8 = 0b00000010;
pub const FLAG_LT: u8 = 0b00000100;
pub const FLAG_V: u8 = 0b00001000;
pub const FLAG_C: u8 = 0b00010000;
pub const FLAG_INT: u8 = 0b00100000;
pub const FLAG_SV: u8 = 0b11000000;

pub const SoC = struct {
    regs: [32]u32,
    statusreg: u8,
    pc: u32,
    instruction_memory: [IM_SIZE]u8,
    data_memory: [DM_SIZE]u8,
    irq: bool,
    irq_level: u8,
    current_irq: u8,
    next_irq: u8,
    int_vector: [256]u32,
    halted: bool = false,
};

// irq priority table
// Lesser number means higher priority
pub var irq_priority_table: [MAX_IRQ]u8 = init_irq_priorities();

fn init_irq_priorities() [MAX_IRQ]u8 {
    var table: [MAX_IRQ]u8 = undefined;

    inline for (0..MAX_IRQ) |i| {
        table[i] = @intCast(i);
    }

    return table;
}

pub fn signExtend12(x: u32) i32 {
    // if 0x800th bit == 1, it's a negative number
    const mask: u32 = 0x800;
    const full: u32 = 0xFFFFF000;

    const extended: u32 = if ((x & mask) != 0) (x | full) else x;
    return @bitCast(extended);
}

pub fn write_mem_u8(self: *SoC, addr: u32, value: u8) void {
    if (memmap.is_valid_memory(addr)) {
        self.data_memory[@intCast(addr - memmap.DATA_MEM_SECTOR_START)] = value;
    } else {
        @panic("Invalid address");
    }
}

pub fn write_mem_u16(self: *SoC, addr: u32, value: u16) void {
    write_mem_u8(self, addr, @truncate(value >> 0));
    write_mem_u8(self, addr + 1, @truncate(value >> 8));
}

pub fn write_mem_u32(self: *SoC, addr: u32, value: u32) void {
    write_mem_u8(self, addr, @truncate(value >> 0));
    write_mem_u8(self, addr + 1, @truncate(value >> 8));
    write_mem_u8(self, addr + 2, @truncate(value >> 16));
    write_mem_u8(self, addr + 3, @truncate(value >> 24));
}

pub fn read_mem_u8(self: *SoC, addr: u32) u8 {
    if (memmap.is_valid_memory(addr)) {
        return self.data_memory[@intCast(addr - memmap.DATA_MEM_SECTOR_START)];
    } else {
        @panic("Error: Invalid read_mem_u8, address out of range or unmapped");
    }
}

pub fn read_mem_u16(self: *SoC, addr: u32) u16 {
    const lo = read_mem_u8(self, addr);
    const hi = read_mem_u8(self, addr + 1);
    return (@as(u16, lo) << 0) | (@as(u16, hi) << 8);
}

pub fn read_mem_u32(self: *SoC, addr: u32) u32 {
    return (@as(u32, read_mem_u8(self, addr + 0)) << 0) |
        (@as(u32, read_mem_u8(self, addr + 1)) << 8) |
        (@as(u32, read_mem_u8(self, addr + 2)) << 16) |
        (@as(u32, read_mem_u8(self, addr + 3)) << 24);
}

// ------------------------- Fetch & Decode & Execute -------------------------

pub fn fetch(self: *SoC) u32 {
    var word: u32 = 0;
    word = (@as(u32, self.instruction_memory[self.pc + 0]) << 0) |
        (@as(u32, self.instruction_memory[self.pc + 1]) << 8) |
        (@as(u32, self.instruction_memory[self.pc + 2]) << 16) |
        (@as(u32, self.instruction_memory[self.pc + 3]) << 24);
    return word;
}

pub fn decode_and_execute(self: *SoC, instr: u32) void {
    const opcode = instr & 0b111;
    switch (opcode) {
        0b000 => r_type.execR(self, instr),
        0b001 => i_type.execI(self, instr),
        0b010 => s_type.execS(self, instr),
        0b011 => cb_type.execCB(self, instr),
        0b100 => t_type.execT(self, instr),
        else => @panic("Error: unknown opcode!"),
    }
    self.pc += 4;
}

// ------------------------- SoC-itself Related Functions -------------------------

pub fn SoC_init(self: *SoC) void {
    self.regs = [_]u32{0} ** 32;
    self.statusreg = 0;
    self.pc = 0;
    self.instruction_memory = [_]u8{0} ** IM_SIZE;
    self.data_memory = [_]u8{0} ** DM_SIZE;
    self.irq = false;
    self.irq_level = 0;
    self.current_irq = 0;
    self.next_irq = 0;
    self.halted = false;
    for (self.int_vector[0..], 0..) |*vec, i| {
        vec.* = memmap.INTERRUPT_VECTOR_START + @as(u32, @intCast(i)) * memmap.INT_VECTOR_ENTRY_SIZE;
    }
}

pub fn SoC_main(self: *SoC) void {
    while (true) {
        if (self.halted) {
            // if interrupt occurs, wake cpu from halt
            if (self.irq) {
                self.halted = false;
            } else {
                continue;
            }
        }

        const instr = fetch(self);
        decode_and_execute(self, instr);
    }
}
