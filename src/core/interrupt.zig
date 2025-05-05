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

    // Callee-saved 레지스터 복원 (역순)
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

    // 상태 레지스터 복원
    self.statusreg = self.read_mem_u8(sp);
    sp += 1;

    self.regs[@intFromEnum(regs.Abbr.sp)] = sp;
}

pub fn int_call(self: *soc.SoC) void {
    // 인터럽트 비활성 상태면 무시
    if ((self.statusreg & soc.SoC.FLAG_INT) == 0) return;
    if (!self.irq) return;

    // 현재 상태 저장
    soc.save_callee_regs(self);

    // 사용자 모드일 경우에만 Supervisor로 전환
    const curr_priv = (self.statusreg & soc.SoC.FLAG_SV) >> 6;
    if (curr_priv == 0b11) {
        self.statusreg = (self.statusreg & ~soc.SoC.FLAG_SV) | 0b0100_0000;
    }

    // 현재 PC → 링크 레지스터
    self.regs[@intFromEnum(regs.Abbr.lr)] = self.pc + 4;

    // 인터럽트 벡터로 이동
    self.pc = self.interrupt_vector[self.current_irq];
}

pub fn int_return(self: *soc.SoC) void {
    // Callee-saved 레지스터 및 상태 복원
    soc.restore_callee_regs(self);

    // PC 복귀
    self.pc = self.regs[@intFromEnum(regs.Abbr.lr)];

    // 인터럽트 플래그 복구 (보통 OS가 판단)
    self.statusreg |= soc.SoC.FLAG_INT;
}
