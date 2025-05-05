const soc = @import("soc.zig");
const alu = @import("alu.zig");

pub fn execI(self: *soc.SoC, instr: u32) void {
    const rm = (instr >> 27) & 0b11111;
    const imm_raw = (instr >> 15) & 0xFFF;
    const imm = soc.signExtend12(imm_raw);
    const rd = (instr >> 10) & 0b11111;
    const fn3 = (instr >> 7) & 0b111;
    const opcode = instr & 0b1111111;

    switch (opcode) {
        1 => { // ALU-immediate
            const alu_op = alu.decodeALUOpcode(@intCast(fn3), 0);
            const result = alu.ALU(self, self.regs[rm], @bitCast(imm), alu_op);
            if (result) |value| {
                self.regs[rd] = value;
            }
        },

        9 => { // Load
            const addr_i32: i32 = @as(i32, @bitCast(self.regs[rm])) + imm;

            switch (fn3) {
                0b000 => self.regs[rd] = soc.read_mem_u32(@bitCast(addr_i32)),
                0b001 => self.regs[rd] = soc.read_mem_u16(@bitCast(addr_i32)),
                0b011 => self.regs[rd] = soc.read_mem_u8(@bitCast(addr_i32)),
                else => @panic("Invalid fn3 for Load"),
            }
        },
        else => @panic("Invalid I-Type opcode"),
    }
}
