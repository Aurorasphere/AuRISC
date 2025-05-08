const soc = @import("../soc.zig");

pub fn execCB(self: *soc.SoC, instr: u32) void {
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
                if ((self.statusreg & soc.FLAG_EQ) != 0) {
                    self.pc = new_pc;
                }
            },
            0b001 => { // bneq
                if ((self.statusreg & soc.FLAG_EQ) == 0) {
                    self.pc = new_pc;
                }
            },
            0b010 => { // bgt
                if ((self.statusreg & soc.FLAG_GT) != 0) {
                    self.pc = new_pc;
                }
            },
            0b011 => { // blt
                if ((self.statusreg & soc.FLAG_LT) != 0) {
                    self.pc = new_pc;
                }
            },
            0b100 => { // begt
                if ((self.statusreg & (soc.FLAG_GT | soc.FLAG_EQ)) != 0) {
                    self.pc = new_pc;
                }
            },
            0b101 => { // belt
                if ((self.statusreg & (soc.FLAG_LT | soc.FLAG_EQ)) != 0) {
                    self.pc = new_pc;
                }
            },
            0b110 => {
                if ((self.statusreg & soc.FLAG_C) != 0) {
                    self.pc = new_pc;
                }
            },
            0b111 => {
                if ((self.statusreg & soc.FLAG_V) != 0) {
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
