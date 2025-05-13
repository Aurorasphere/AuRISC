const soc = @import("../soc.zig");
const regs = @import("../registers.zig");

fn save_callee_regs(self: *soc.SoC) void {
    var sp: u32 = self.regs[@intFromEnum(regs.Abbr.sp)]; // sp

    sp -= 1;
    soc.write_mem_u8(self, sp, self.statusreg);

    inline for (regs.Registers, 0..) |info, i| {
        if (info.saver == .Callee or info.abbr == regs.Abbr.lr) {
            sp -= 4;
            self.write_mem_u32(self, sp, self.regs[i]);
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
            self.regs[idx] = self.read_mem_u32(self, sp);
            sp += 4;
        }
    }

    // Restore status register
    self.statusreg = soc.read_mem_u8(sp);
    sp += 1;

    self.regs[@intFromEnum(regs.Abbr.sp)] = sp;
}

pub fn int_call(self: *soc.SoC) void {
    if ((self.statusreg & soc.FLAG_INT) == 0) return;
    if (!self.irq) return;

    // Compare IRQ priority if already in interrupt
    if (self.irq_level > 0) {
        const curr_priority = soc.irq_priority_table[self.current_irq];
        const new_priority = soc.irq_priority_table[self.next_irq];

        if (new_priority <= curr_priority) {
            return; // Ignore if the priority is lesser or equal
        }
    }

    // Save current registers
    save_callee_regs(self);

    if (((self.statusreg & soc.FLAG_SV) >> 6) == 0b11) {
        self.statusreg = (self.statusreg & ~soc.FLAG_SV) | 0b0100_0000;
    }

    self.regs[@intFromEnum(regs.Abbr.lr)] = self.pc + 4;

    // Update current IRQ
    self.current_irq = self.next_irq;
    self.irq_level += 1;
    self.irq = false;

    self.pc = self.int_vector[self.current_irq];
}

pub fn int_return(self: *soc.SoC) void {
    .restore_callee_regs(self);
    self.pc = self.regs[@intFromEnum(regs.Abbr.lr)];
    self.statusreg |= soc.SoC.FLAG_INT;

    if (self.irq_level > 0) self.irq_level -= 1;
    self.statusreg = (self.statusreg & ~soc.SoC.FLAG_SV) | 0b1100_0000;
}

pub fn syscall(self: *soc.SoC) void {
    const curr_priv = (self.statusreg & soc.FLAG_SV) >> 6;
    if (curr_priv != 0b11) return;

    save_callee_regs(self);

    self.statusreg = (self.statusreg & ~soc.FLAG_SV) | 0b0100_0000;
    self.regs[@intFromEnum(regs.Abbr.lr)] = self.pc + 4;

    const syscall_num: u8 = @truncate(self.regs[12]);
    self.pc = self.int_vector[self.syscall_base + syscall_num];
}

pub fn sysret(self: *soc.SoC) void {
    soc.restore_callee_regs(self);
    self.pc = self.regs[@intFromEnum(regs.Abbr.lr)];

    // Return to user mode
    self.statusreg = (self.statusreg & ~soc.FLAG_SV) | 0b1100_0000;
}

pub fn exec_hlt(self: *soc.SoC) void {
    self.halted = true;
}

pub fn execT(self: *soc.SoC, instr: u32) void {
    const opcode = instr & 0b1111111;
    const imm: u8 = @intCast((instr >> 16) & 0b11111111);
    const fn3 = (instr >> 7) & 0b111;

    if (opcode == 0b0000100) {
        switch (fn3) {
            0b000 => syscall(self),
            0b001 => sysret(self),
            0b010 => {
                self.next_irq = imm;
                self.irq = true;
                int_call(self);
            },
            0b011 => int_return(self),
            else => @panic("Error: Invalid T-Type fn3!"),
        }
    } else if (opcode == 0b1111111) {
        exec_hlt(self);
    } else {
        @panic("Error: Invalid T-Type opcode!");
    }
}
