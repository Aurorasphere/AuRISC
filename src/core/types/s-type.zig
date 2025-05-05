const soc = @import("soc.zig");

pub fn execS(self: *soc.SoC, instr: u32) void {
    const rm = (instr >> 27) & 0b11111;
    const rn = (instr >> 22) & 0b11111;
    const imm_raw = (instr >> 10) & 0b1111_1111_1111;
    const imm = soc.signExtend12(imm_raw);
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
