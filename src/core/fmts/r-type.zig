const soc = @import("../soc.zig");
const alu = @import("../alu.zig");

pub fn execR(self: *soc.SoC, instr: u32) void {
    const rm = (instr >> 27) & 0b11111;
    const rn = (instr >> 22) & 0b11111;
    const rd = (instr >> 10) & 0b11111;
    const fn7 = (instr >> 15) & 0b1111111;
    const fn3 = (instr >> 7) & 0b111;

    const opcode = alu.decodeALUOpcode(@intCast(fn3), @intCast(fn7));

    const result = alu.ALU(self, self.regs[rm], self.regs[rn], opcode);
    self.regs[rd] = result;
}
