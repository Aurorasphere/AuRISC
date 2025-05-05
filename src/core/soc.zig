const std = @import("std");
const alu = @import("alu.zig");
const regs = @import("registers.zig");

pub const RAM_BASE: u32 = 0x0010_0000;
pub const RAM_SIZE: u32 = 16 * 1024 * 1024;
pub const RAM_END: u32 = RAM_BASE + RAM_SIZE;

pub const DM_SIZE: u32 = 24 * 1024 * 1024;
pub const IM_SIZE: u32 = 0x1000;
pub const RAM_SIZE: u32 = 16 * 1024 * 1024;

pub const SoC = struct {
    regs: [32]u32,
    statusreg: u8,
    pc: u32,
    instruction_memory: [IM_SIZE]u8,
    data_memory: [DM_SIZE]u8,
    irq: bool,
    current_irq: u8,
    int_vector: [256]u32,

    // Status register's flags
    pub const FLAG_EQ: u8 = 0b00000001;
    pub const FLAG_GT: u8 = 0b00000010;
    pub const FLAG_LT: u8 = 0b00000100;
    pub const FLAG_V: u8 = 0b00001000;
    pub const FLAG_C: u8 = 0b00010000;
    pub const FLAG_INT: u8 = 0b00100000;
    pub const FLAG_SV: u8 = 0b11000000;
};

fn signExtend12(x: u32) i32 {
    // if 0x800th bit == 1, it's a negative number
    const mask: u32 = 0x800;
    const full: u32 = 0xFFFFF000;

    const extended: u32 = if ((x & mask) != 0) (x | full) else x;
    return @bitCast(extended);
}

fn write_mem_u8(self: *SoC, addr: u32, value: u8) void {
    if (addr >= RAM_BASE and addr < RAM_END) {
        self.data_memory[@intCast(addr - RAM_BASE)] = value;
    } else if (addr == 0x0000_0002) {
        std.debug.print("{c}", .{value}); // TTY
    } else {
        @panic("Invalid address");
    }
}

fn write_mem_u16(self: *SoC, addr: u32, value: u16) void {
    self.write_mem_u8(addr, @truncate(value >> 0));
    self.write_mem_u8(addr + 1, @truncate(value >> 8));
}

fn write_mem_u32(self: *SoC, addr: u32, value: u32) void {
    self.write_mem_u8(addr, @truncate(value >> 0));
    self.write_mem_u8(addr + 1, @truncate(value >> 8));
    self.write_mem_u8(addr + 2, @truncate(value >> 16));
    self.write_mem_u8(addr + 3, @truncate(value >> 24));
}

fn read_mem_u8(self: *SoC, addr: u32) u8 {
    if (addr < RAM_SIZE) {
        return self.data_memory[@intCast(addr)];
    } else if (addr == 0xFFFF_0000) { // 키보드 입력
        self.keyboard_ready = false;
        return self.keyboard_buffer;
    } else if (addr == 0xFFFF_0001) { // 키보드 상태
        return if (self.keyboard_ready) 1 else 0;
    } else {
        @panic("Error: Invalid read_mem_u8, address out of range or unmapped");
    }
}

fn read_mem_u16(self: *SoC, addr: u32) u16 {
    const lo = self.read_mem_u8(addr);
    const hi = self.read_mem_u8(addr + 1);
    return (@as(u16, lo) << 0) | (@as(u16, hi) << 8);
}

fn read_mem_u32(self: *SoC, addr: u32) u32 {
    return (@as(u32, self.read_mem_u8(addr + 0)) << 0) |
        (@as(u32, self.read_mem_u8(addr + 1)) << 8) |
        (@as(u32, self.read_mem_u8(addr + 2)) << 16) |
        (@as(u32, self.read_mem_u8(addr + 3)) << 24);
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
        0b000 => execR(self, instr),
        0b001 => execI(self, instr),
        0b010 => execS(self, instr),
        0b011 => execCB(self, instr),
        // 0b100 => execT(self, instr),
        else => @panic("Error: unknown opcode!"),
    }
    self.pc += 4;
}

// ------------------------- Instruction Execution -------------------------

fn execR(self: *SoC, instr: u32) void {
    const rm = (instr >> 27) & 0b11111; // Rm
    const rn = (instr >> 22) & 0b11111; // Rn
    const rd = (instr >> 10) & 0b11111; // Rd
    const fn7 = ((instr >> 15) & 0b1111111); // fn7
    const fn3 = (instr >> 7) & 0b111; // fn3
    //
    const opcode = alu.decodeALUOpcode(@intCast(fn3), @intCast(fn7));
    self.regs[rd] = alu.eval(self, opcode, self.regs[rm], self.regs[rn]);
}

fn execI(self: *SoC, instr: u32) void {
    const rm = (instr >> 27) & 0b11111;
    const imm_raw = (instr >> 15) & 0xFFF;
    const imm = signExtend12(imm_raw);
    const rd = (instr >> 10) & 0b11111;
    const fn3 = (instr >> 7) & 0b111;
    const opcode = instr & 0b1111111;

    switch (opcode) {
        1 => { // ALU-immediate
            const alu_op = alu.decodeALUOpcode(@intCast(fn3), 0);
            self.regs[rd] = alu.ALU(self, self.regs[rm], @bitCast(imm), alu_op);
        },

        9 => { // Load
            const addr_i32: i32 = @as(i32, @bitCast(self.regs[rm])) + imm;

            switch (fn3) {
                0b000 => self.regs[rd] = self.read_mem_u32(@bitCast(addr_i32)),
                0b001 => self.regs[rd] = self.read_mem_u16(@bitCast(addr_i32)),
                0b011 => self.regs[rd] = self.read_mem_u8(@bitCast(addr_i32)),
                else => @panic("Invalid fn3 for Load"),
            }
        },
        else => @panic("Invalid I-Type opcode"),
    }
}

fn execS(self: *SoC, instr: u32) void {
    const rm = (instr >> 27) & 0b11111;
    const rn = (instr >> 22) & 0b11111;
    const imm_raw = (instr >> 10) & 0b1111_1111_1111;
    const imm = signExtend12(imm_raw);
    const fn3 = (instr >> 7) & 0b111;

    const addr_i32: i32 = @as(i32, @bitCast(self.regs[rm])) + imm;
    const value = self.regs[rn];

    switch (fn3) {
        0b000 => self.write_mem_u32(@bitCast(addr_i32), value),
        0b001 => self.write_mem_u16(@bitCast(addr_i32), value),
        0b011 => self.write_mem_u8(@bitCast(addr_i32), value),
        else => @panic("Invalid fn3 for Store"),
    }
}

fn execCB(self: *SoC, instr: u32) void {
    const rmd = (instr >> 27) & 0b11111;
    const raw_imm = (instr >> 10) & 0b1_1111_1111_1111_1111;
    const fn3 = (instr >> 7) & 0b111;
    const opcode = instr & 0b1111111;

    const imm_signed: i32 = @intCast(@as(i16, @intCast(raw_imm)));
    const offset = imm_signed << 2;
    const pc_i32: i32 = @intCast(self.pc);
    const new_pc: u32 = @intCast(pc_i32 + offset);

    if (opcode == 3) {
        switch (fn3) {
            0b000 => { // beq
                if ((self.statusreg & SoC.FLAG_EQ) != 0) {
                    self.pc = new_pc;
                }
            },
            0b001 => { // bneq
                if ((self.statusreg & SoC.FLAG_EQ) == 0) {
                    self.pc = new_pc;
                }
            },
            0b010 => { // bgt
                if ((self.statusreg & SoC.FLAG_GT) != 0) {
                    self.pc = new_pc;
                }
            },
            0b011 => { // blt
                if ((self.statusreg & SoC.FLAG_LT) != 0) {
                    self.pc = new_pc;
                }
            },
            0b100 => { // begt
                if ((self.statusreg & (SoC.FLAG_GT | SoC.FLAG_EQ)) != 0) {
                    self.pc = new_pc;
                }
            },
            0b101 => { // belt
                if ((self.statusreg & (SoC.FLAG_LT | SoC.FLAG_EQ)) != 0) {
                    self.pc = new_pc;
                }
            },
            0b110 => {
                if ((self.statusreg & SoC.FLAG_C) != 0) {
                    self.pc = new_pc;
                }
            },
            0b111 => {
                if ((self.statusreg & SoC.FLAG_V) != 0) {
                    self.pc = new_pc;
                }
            },
            else => @panic("D:\n"),
        }
    } else if (opcode == 11) {
        switch (fn3) {
            0b000 => {
                self.regs[rmd] += self.pc + 4;
                self.pc += @intCast(imm_signed << 2);
            },
            else => @panic("Error!"),
        }
    }
}

// ------------------------- SoC-itself Related Functions -------------------------

pub fn SoC_init(self: *SoC) void {
    self.regs = [_]u32{0} ** 32;
    self.statusreg = 0;
    self.pc = 0;
    self.instruction_memory = [_]u8{0} ** IM_SIZE;
    self.data_memory = [_]u8{0} ** DM_SIZE;
}

pub fn SoC_create() SoC {
    return SoC{
        .regs = [_]u32{0} ** 32,
        .statusreg = 0,
        .pc = 0,
        .instruction_memory = [_]u8{0} ** IM_SIZE,
        .data_memory = [_]u8{0} ** DM_SIZE,
    };
}

pub fn SoC_main(self: *SoC) void {
    SoC_init(self);
    while (true) {
        const instr = fetch(self);
        decode_and_execute(self, instr);
    }
}
