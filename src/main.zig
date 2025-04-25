const std = @import("std");

pub const SoC = struct {
    regs: [32]u32,
    statusreg: u8,
    pc: u24,
    instruction_memory: [16777216]u8,
    data_memory: [16777216]u8,

    // Status register's flags
    pub const FLAG_EQ: u8 = 0b00000001;
    pub const FLAG_GT: u8 = 0b00000010;
    pub const FLAG_LT: u8 = 0b00000100;
    pub const FLAG_V: u8 = 0b00001000;
    pub const FLAG_C: u8 = 0b00010000;
    pub const FLAG_INT: u8 = 0b00100000;
    pub const FLAG_SV: u8 = 0b11000000;
};

fn ALU(self: *SoC, a: u32, b: u32, fn3: u8, fn7: u8) u32 {
    var result: u32 = 0;
    const fn7_masked = fn7 & 1;

    if (fn7_masked == 0) {
        switch (fn3) {
            0b000 => { // add
                result = a + b;

                // Carry detection
                if (result < a) {
                    self.statusreg |= self.FLAG_C;
                } else {
                    self.statusreg &= ~self.FLAG_C;
                }

                // Overflow detection
                const signed_a = (i32)(a);
                const signed_b = (i32)(b);
                const signed_result = (i32)(result);

                if ((signed_a > 0 and signed_b > 0 and signed_result < 0) or (signed_a < 0 and signed_b < 0 and signed_result >= 0)) {
                    self.statusreg |= self.FLAG_V;
                } else {
                    self.statusreg &= ~self.FLAG_V;
                }
            },
            0b001 => result = a | b,
            0b010 => result = a & b,
            0b011 => result = a ^ b,
            0b100 => result = a << b,
            0b101 => result = a >> b,
            0b110 => { // cmp
                if (a == b) {
                    self.statusreg |= self.FLAG_EQ;
                } else {
                    self.statusreg &= ~self.FLAG_EQ;
                }

                if (a > b) {
                    self.statusreg |= self.FLAG_GT;
                } else {
                    self.statusreg &= ~self.FLAG_GT;
                }

                if (a < b) {
                    self.statusreg |= self.FLAG_LT;
                } else {
                    self.statusreg &= ~self.FLAG_LT;
                }

                return void;
            },
            else => result = 0,
        }
    } else if (fn7_masked == 1) {
        switch (fn3) {
            0b000 => { // sub
                result = a - b;

                // Carry detection
                if (a < b) self.statusreg |= self.FLAG_C;

                // Underflow detection
                const signed_a = (i32)(a);
                const signed_b = (i32)(b);
                const signed_result = (i32)(result);

                if ((signed_a >= 0 and signed_b < 0 and signed_result < 0) or (signed_a < 0 and signed_b >= 0 and signed_result >= 0)) {
                    self.statusreg |= self.FLAG_V;
                }
            },
            0b101 => {
                const sa = (i32)(a);
                result = (u32)(sa >> (b & 0x1F));
            },
            else => result = 0,
        }
    }
    return result;
}

pub fn fetch(self: *SoC) u32 {
    var word: u32 = 0;
    word = (self.instruction_memory[self.pc + 0] << 0) |
        (self.instruction_memory[self.pc + 1] << 8) |
        (self.instruction_memory[self.pc + 2] << 16) |
        (self.instruction_memory[self.pc + 3] << 24);
    return word;
}

pub fn decode_and_executeAndExecute(self: *SoC, instr: u32) void {
    const opcode = instr & 0b111;
    switch (opcode) {
        0b000 => execR(self, instr),
        0b001 => execI(self, instr),
        0b010 => execS(self, instr),
        0b011 => execCB(self, instr),
        // 0b100 => execT(self, instr),
    }
}

pub fn execR(self: *SoC, instr: u32) void {
    const rm = (instr >> 27) & 0b11111; // Rm
    const rn = (instr >> 22) & 0b11111; // Rn
    const rd = (instr >> 10) & 0b11111; // Rd
    const fn7 = ((instr >> 15) & 0b1111111); // fn7
    const fn3 = (instr >> 7) & 0b111; // fn3

    self.regs[rd] = ALU(self, rm, rn, @truncate(fn3), @truncate(fn7));
}

pub fn execI(self: *SoC, instr: u32) void {
    const rm = (instr >> 27) & 0b11111;
    const imm = (instr >> 15) & 0b1111_1111_1111;
    const rd = (instr >> 10) & 0b11111;
    const fn3 = (instr >> 7) & 0b111;
    const opcode = instr & 0b1111111;

    if (opcode == 1) {
        self.regs[rd] = ALU(self, rm, imm, @truncate(fn3), 0);
    } else if (opcode == 9) {
        const address = imm + rm;
        switch (fn3) {
            0b000 => { // Load word
                const mem_word_data: u32 = (@as(u32, self.data_memory[address + 0]) << 0 |
                    @as(u32, self.data_memory[address + 1]) << 8 |
                    @as(u32, self.data_memory[address + 2]) << 16 |
                    @as(u32, self.data_memory[address + 3]) << 24);
                self.regs[rd] = mem_word_data;
            },
            0b001 => { // Load half
                const mem_half_data = (self.data_memory[address + 0] << 0 | self.data_memory[address + 1]);
                self.regs[rd] = mem_half_data;
            },
            0b011 => { // Load byte
                self.regs[rd] = self.data_memory[address];
            },
            else => @panic("Error: Invalid fn3 on I-Type Load instruction!\n"), // invalid operation
        }
    }
}

pub fn execS(self: *SoC, instr: u32) void {
    const rm = (instr >> 27) & 0b11111;
    const rn = (instr >> 22) & 0b11111;
    const imm = (instr >> 10) & 0b1111_1111_1111;
    const fn3 = (instr >> 7) & 0b111;
    const address = imm + rm;
    const value = self.regs[rn];

    switch (fn3) {
        0b000 => { // Store word
            self.data_memory[address + 0] = @truncate(value >> 0);
            self.data_memory[address + 1] = @truncate(value >> 8);
            self.data_memory[address + 2] = @truncate(value >> 16);
            self.data_memory[address + 3] = @truncate(value >> 24);
        },
        0b001 => { // Store half
            self.data_memory[address + 0] = @truncate(value >> 0);
            self.data_memory[address + 1] = @truncate(value >> 8);
        },
        0b011 => { // Store byte
            self.data_memory[address] = @truncate(value);
        },
        else => @panic("Error: Invalid fn3 on S-Type Store instruction!\n"),
    }
}

pub fn execCB(self: *SoC, instr: u32) void {
    const rmd = (instr >> 27) & 0b11111;
    const raw_imm = (instr >> 10) & 0b1_1111_1111_1111_1111;
    const fn3 = (instr >> 7) & 0b111;
    const opcode = instr & 0b1111111;

    const imm_signed = @as(i32, @bitCast(raw_imm));
    const offset = imm_signed << 2;

    if (opcode == 3) {
        switch (fn3) {
            0b000 => { // beq
                if ((self.statusreg & self.FLAG_EQ) != 0) {
                    self.pc += offset;
                }
            },
            0b001 => { // bneq
                if ((self.statusreg & self.FLAG_EQ) == 0) {
                    self.pc += offset;
                }
            },
            0b010 => { // bgt
                if ((self.statusreg & self.FLAG_GT) != 0) {
                    self.pc += offset;
                }
            },
            0b011 => { // blt
                if ((self.statusreg & self.FLAG_LT) != 0) {
                    self.pc += offset;
                }
            },
            0b100 => { // begt
                if ((self.statusreg & (self.FLAG_GT | self.FLAG_EQ)) != 0) {
                    self.pc += offset;
                }
            },
            0b101 => { // belt
                if ((self.statusreg & (self.FLAG_LT | self.FLAG_EQ)) != 0) {
                    self.pc += offset;
                }
            },
            0b110 => {
                if ((self.statusreg & self.FLAG_C) != 0) {
                    self.pc += offset;
                }
            },
            0b111 => {
                if ((self.statusreg & self.FLAG_V) != 0) {
                    self.pc += offset;
                }
            },
        }
    } else if (opcode == 11) {
        switch (fn3) {
            0b000 => {
                self.regs[rmd] += self.pc + 4;
                self.pc += imm_signed << 2;
            },
            else => @panic("Error!"),
        }
    }
}

pub fn main() !void {}

// Jun <3 Jay
