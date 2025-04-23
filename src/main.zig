const std = @import("std");

pub const SoC = struct {
    register_file: [32]u32,
    statusreg: u8,
    pc: u24,
    instruction_memory: [16777216]u8,
    data_memory: [16777216]u8,
};

fn fetch(self: *SoC) u32 {
    var word: u32 = 0;
    word = (self.instruction_memory[self.pc + 3]) |
        (self.instruction_memory[self.pc + 2]) |
        (self.instruction_memory[self.pc + 1]) |
        (self.instruction_memory[self.pc + 0]);
    return word;
}

fn DecodeAndExecute(self: *SoC, instr: u32) void {
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
    const fn3 = (instr >> 8) & 0b111; // fn3

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
                    self.statusreg |= 0x1;
                } else {
                    self.statusreg &= 0xFE;
                }

                if (self.regs[rm] > self.regs[rn]) {
                    self.statusreg |= 0x2;
                } else {
                    self.statusreg &= 0xFD;
                }

                if (self.regs[rm] < self.regs[rn]) {
                    self.statusreg |= 0x4;
                } else {
                    self.statusreg &= 0xFB;
                }
            },
        }
    }
}

pub fn main() !void {}

test "simple test" {}
