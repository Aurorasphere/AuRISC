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
    const rd = (instr >> 17) & 0b11111; // Rd
    const fn3 = (instr >> 8) & 0b111; // fn3
    const opcode = instr & 0b1111111; // opcode
    //
    switch (fn3) {
        0b000 => self.regs[rd] = self.regs[rn] + self.regs[rm], // add
        0b001 => self.regs[rd] = self.regs[rn] - self.regs[rm], // sub
        0b010 => self.regs[rd] = self.regs[rn] | self.regs[rm], // or
        0b011 => self.regs[rd] = self.regs[rn] & self.regs[rm], // and
        0b100 => self.regs[rd] = self.regs[rn] ^ self.regs[rm], // xor
        0b101 => self.regs[rd] = self.regs[rn] << self.regs[rm], // lsl
        0b110 => self.regs[rd] = self.regs[rn] >> self.regs[rm], // lsr
        else => @panic("Unknown R-type instruction"),
    }
}

pub fn main() !void {}

test "simple test" {}
