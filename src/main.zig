const std = @import("std");

pub const SoC = struct {
    regs: [32]u32,
    statusreg: u8,
    pc: u24,
    instruction_memory: [16777216]u8,
    data_memory: [16777216]u8,

    pub const FLAG_EQ: u8 = 0b00000001;
    pub const FLAG_GT: u8 = 0b00000010;
    pub const FLAG_LT: u8 = 0b00000100;
    pub const FLAG_V: u8 = 0b00001000;
    pub const FLAG_C: u8 = 0b00010000;
    pub const FLAG_INT: u8 = 0b00100000;
    pub const FLAG_SV: u8 = 0b11000000;
};

fn fetch(self: *SoC) u32 {
    var word: u32 = 0;
    word = (self.instruction_memory[self.pc + 0] << 0) |
        (self.instruction_memory[self.pc + 1] << 8) |
        (self.instruction_memory[self.pc + 2] << 16) |
        (self.instruction_memory[self.pc + 3] << 24);
    return word;
}

fn decode_and_executeAndExecute(self: *SoC, instr: u32) void {
    const opcode = instr & 0x0000007F;
    switch (opcode) {
        0b0000000 => {
            self.execR(instr);
        },
    }
}

fn execR(self: *SoC, instr: u32) void {
    const rm = (instr >> 27) & 0b11111; // Rm
    const rn = (instr >> 22) & 0b11111; // Rn
    const rd = (instr >> 10) & 0b11111; // Rd
    const fn7 = (instr >> 15) & 0b1111111; // fn7
    const fn3 = (instr >> 7) & 0b111; // fn3

    if (fn7 == 0x0) {
        switch (fn3) {
            0x0 => self.regs[rd] = self.regs[rm] + self.regs[rn], // add
            0x1 => self.regs[rd] = self.regs[rm] | self.regs[rn], // or
            0x2 => self.regs[rd] = self.regs[rm] & self.regs[rn], // and
            0x3 => self.regs[rd] = self.regs[rm] ^ self.regs[rn], // xor
            0x4 => self.regs[rd] = self.regs[rm] << self.regs[rn], // lsl
            0x5 => self.regs[rd] = self.regs[rm] >> self.regs[rn], // lsr
            0x6 => {
                if (self.regs[rm] == self.regs[rn]) {
                    self.statusreg |= self.FLAG_EQ;
                } else {
                    self.statusreg &= !self.FLAG_EQ;
                }

                if (self.regs[rm] > self.regs[rn]) {
                    self.statusreg |= self.FLAG_GT;
                } else {
                    self.statusreg &= !self.FLAG_GT;
                }

                if (self.regs[rm] < self.regs[rn]) {
                    self.statusreg |= self.FLAG_LT;
                } else {
                    self.statusreg &= !self.FLAG_LT;
                }
            },
        }
    }
}

fn execI(self: *SoC, instr: u32) void {
    const rm = (instr >> 27) & 0b11111;
    const imm = (instr >> 15) & 0b1111_1111_1111;
    const rd = (instr >> 10) & 0b11111;
    const fn3 = (instr >> 7) & 0b111;
}

pub fn main() !void {}
