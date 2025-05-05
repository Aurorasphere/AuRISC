const soc = @import("soc.zig");
const regs = @import("registers.zig");

fn save_callee_regs(self: *soc.SoC) void {
    var sp: u32 = self.regs[regs.Abbr.sp]; // sp

    sp -= 1;
    soc.write_mem_u8(sp, self.statusreg);

    inline for (regs.Registers, 0..) |info, i| {
        if (info.saver == .Callee or info.abbr == regs.Abbr.lr) {
            sp -= 4;
            self.write_mem_u32(sp, self.regs[i]);
        }
    }
    self.regs[@intFromEnum(regs.Abbr.sp)] = sp;
}

fn restore_callee_registers(self: *soc.SoC) void {
    var sp = self.regs[@intFromEnum(regs.Abbr.sp)];

    // Restore Callee-saved registers in reverse order
    const total = regs.Registers.len;
    var idx: usize = total;
    while (idx > 0) {
        idx -= 1;
        const info = regs.Registers[idx];
        if (info.saver == .Callee or info.abbr == regs.Abbr.lr) {
            self.regs[idx] = self.read_mem_u32(sp);
            sp += 4;
        }
    }

    // Restore status register
    self.statusreg = self.read_mem_u8(sp);
    sp += 1;

    self.regs[@intFromEnum(regs.Abbr.sp)] = sp;
}

pub fn int_call(self: *soc.SoC) void {
    // If the current FLAG_INT == 0, return
    if ((self.statusreg & soc.SoC.FLAG_INT) == 0) return;
    if (!self.irq) return;

    // Save callee-saved registers and status register
    soc.save_callee_regs(self);

    // If the current mode is user mode, change the current mode to kernel mode
    const curr_priv = (self.statusreg & soc.SoC.FLAG_SV) >> 6;
    if (curr_priv == 0b11) {
        self.statusreg = (self.statusreg & ~soc.SoC.FLAG_SV) | 0b0100_0000;
    }

    // Current PC + 4 → link register
    self.regs[@intFromEnum(regs.Abbr.lr)] = self.pc + 4;

    // 인터럽트 벡터로 이동
    self.pc = self.interrupt_vector[self.current_irq];
}

pub fn int_return(self: *soc.SoC) void {
    // Restore Callee-saved and status register
    soc.restore_callee_regs(self);

    // Restore PC from link register
    self.pc = self.regs[@intFromEnum(regs.Abbr.lr)];

    // Restore interrupt flag
    self.statusreg |= soc.SoC.FLAG_INT;
}

pub fn syscall(self: *soc.SoC) void {
    const curr_priv = (self.statusreg & self.FLAG_SV) >> 6;
    if (curr_priv != 0b11) return;

    save_callee_regs(self);

    self.statusreg = (self.statusreg & ~self.FLAG_SV) | 0b0100_0000;
    self.regs[@intFromEnum(regs.Abbr.lr)] = self.pc + 4;

    const syscall_num: u8 = @truncate(self.regs[12]);
    self.pc = self.int_vector[self.syscall_base + syscall_num];
}

pub fn sysret(self: *soc.SoC) void {
    soc.restore_callee_regs(self);
    self.pc = self.regs[@intFromEnum(regs.Abbr.lr)];

    // Return to user mode
    self.statusreg = (self.statusreg & ~soc.SoC.FLAG_SV) | 0b1100_0000;
}

pub fn exec_hlt(self: *soc.SoC) void {
    self.halted = true;
}
