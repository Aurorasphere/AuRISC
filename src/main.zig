const std = @import("std");

pub const SoC = struct {
    register_file: [32]u32,
    statusreg: u8,
    pc: u24,
    instruction_memory: [16777216]u8,
    data_memory: [16777216]u8,
    fn execR
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

pub fn main() !void {}

test "simple test" {}
