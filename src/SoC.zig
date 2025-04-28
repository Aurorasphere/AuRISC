pub const DM_SIZE = 0x1000;
pub const IM_SIZE = 0x1000;

pub const SoC = struct {
    regs: [32]u32,
    statusreg: u8,
    pc: u32,
    instruction_memory: [IM_SIZE]u8,
    data_memory: [DM_SIZE]u8,

    // Status register's flags
    pub const FLAG_EQ: u8 = 0b00000001;
    pub const FLAG_GT: u8 = 0b00000010;
    pub const FLAG_LT: u8 = 0b00000100;
    pub const FLAG_V: u8 = 0b00001000;
    pub const FLAG_C: u8 = 0b00010000;
    pub const FLAG_INT: u8 = 0b00100000;
    pub const FLAG_SV: u8 = 0b11000000;
};
fn signExtend12(x: u32) i32 {
    // 0x800 비트가 1이면 음수
    const mask: u32 = 0x800;
    const full: u32 = 0xFFFFF000;

    const extended: u32 = if ((x & mask) != 0) (x | full) else x;
    return @bitCast(extended);
}

fn wrapAddress(addr: i32) usize {
    return @intCast(@mod(addr, @as(i32, DM_SIZE)));
}

fn ALU(self: *SoC, a: u32, b: u32, fn3: u8, fn7: u8) u32 {
    var result: u32 = 0;
    const fn7_masked = fn7 & 1;

    if (fn7_masked == 0) {
        switch (fn3) {
            0b000 => { // add
                const sum = @addWithOverflow(a, b);
                result = sum[0];

                // Carry detection
                if (sum[1] != 0) {
                    self.statusreg |= SoC.FLAG_C;
                } else {
                    self.statusreg &= ~SoC.FLAG_C;
                }

                // Overflow detection
                const signed_a: i32 = @bitCast(a);
                const signed_b: i32 = @bitCast(b);
                const signed_result: i32 = @bitCast(result);
                if ((signed_a > 0 and signed_b > 0 and signed_result < 0) or
                    (signed_a < 0 and signed_b < 0 and signed_result >= 0))
                {
                    self.statusreg |= SoC.FLAG_V;
                } else {
                    self.statusreg &= ~SoC.FLAG_V;
                }
            },
            0b001 => result = a | b,
            0b010 => result = a & b,
            0b011 => result = a ^ b,
            0b100 => result = a << @truncate(b),
            0b101 => result = a >> @truncate(b),
            0b110 => { // cmp
                if (a == b) {
                    self.statusreg |= SoC.FLAG_EQ;
                } else {
                    self.statusreg &= ~SoC.FLAG_EQ;
                }

                if (a > b) {
                    self.statusreg |= SoC.FLAG_GT;
                } else {
                    self.statusreg &= ~SoC.FLAG_GT;
                }

                if (a < b) {
                    self.statusreg |= SoC.FLAG_LT;
                } else {
                    self.statusreg &= ~SoC.FLAG_LT;
                }

                result = 0;
            },
            else => result = 0,
        }
    } else if (fn7_masked == 1) {
        switch (fn3) {
            0b000 => { // sub
                const diff = @subWithOverflow(a, b);
                result = diff[0];

                // Carry detection (borrow 발생)
                if (a < b) {
                    self.statusreg |= SoC.FLAG_C;
                } else {
                    self.statusreg &= ~SoC.FLAG_C;
                }

                // Overflow detection
                const signed_a: i32 = @bitCast(a);
                const signed_b: i32 = @bitCast(b);
                const signed_result: i32 = @bitCast(result);
                if ((signed_a > 0 and signed_b < 0 and signed_result < 0) or
                    (signed_a < 0 and signed_b > 0 and signed_result >= 0))
                {
                    self.statusreg |= SoC.FLAG_V;
                } else {
                    self.statusreg &= ~SoC.FLAG_V;
                }
            },
            0b101 => { // asr (arithmetic shift right)
                const signed_a: i32 = @bitCast(a);
                result = @bitCast(signed_a >> @truncate(b));
            },
            else => result = 0,
        }
    }
    return result;
}

pub fn fetch(self: *SoC) u32 {
    var word: u32 = 0;
    word = (self.instruction_memory[self.pc + 0] << 0) |
        (self.instruction_memory[self.pc + 1] << 8) |
        (self.instruction_memory[self.pc + 2] << 16) |
        (self.instruction_memory[self.pc + 3] << 24);
    return word;
}

pub fn decode_and_execute(self: *SoC, instr: u32) void {
    const opcode = instr & 0b111;
    switch (opcode) {
        0b000 => execR(self, instr),
        0b001 => execI(self, instr),
        0b010 => execS(self, instr),
        0b011 => execCB(self, instr),
        // 0b100 => execT(self, instr),
        else => @panic("Error: unknown opcode!"),
    }
    self.pc += 4;
}

fn execR(self: *SoC, instr: u32) void {
    const rm = (instr >> 27) & 0b11111; // Rm
    const rn = (instr >> 22) & 0b11111; // Rn
    const rd = (instr >> 10) & 0b11111; // Rd
    const fn7 = ((instr >> 15) & 0b1111111); // fn7
    const fn3 = (instr >> 7) & 0b111; // fn3

    self.regs[rd] = ALU(self, self.regs[rm], self.regs[rn], @truncate(fn3), @truncate(fn7));
}

fn execI(self: *SoC, instr: u32) void {
    const rm = (instr >> 27) & 0b11111;
    const imm_raw = (instr >> 15) & 0xFFF; // 12-bit
    const imm = signExtend12(imm_raw); // ← 부호 확장
    const rd = (instr >> 10) & 0b11111;
    const fn3 = (instr >> 7) & 0b111;
    const opcode = instr & 0b1111111;

    switch (opcode) {
        1 => { // ALU-immediate
            self.regs[rd] = ALU(
                self,
                self.regs[rm],
                @bitCast(imm), // b 인자는 u32
                @truncate(fn3),
                0,
            );
        },

        9 => { // Load
            const addr_i32: i32 = @as(i32, @bitCast(self.regs[rm])) + imm;
            const addr = wrapAddress(addr_i32);

            switch (fn3) {
                0b000 => { // LW
                    self.regs[rd] =
                        (@as(u32, self.data_memory[addr + 0]) << 0) |
                        (@as(u32, self.data_memory[addr + 1]) << 8) |
                        (@as(u32, self.data_memory[addr + 2]) << 16) |
                        (@as(u32, self.data_memory[addr + 3]) << 24);
                },
                0b001 => { // LH
                    self.regs[rd] =
                        (@as(u32, self.data_memory[addr + 0]) << 0) |
                        (@as(u32, self.data_memory[addr + 1]) << 8);
                },
                0b011 => { // LB
                    self.regs[rd] = self.data_memory[addr];
                },
                else => @panic("Invalid fn3 for I-Type Load"),
            }
        },

        else => @panic("Invalid I-Type opcode"),
    }
}

fn execS(self: *SoC, instr: u32) void {
    const rm = (instr >> 27) & 0b11111;
    const rn = (instr >> 22) & 0b11111;
    const imm_raw = (instr >> 10) & 0b1111_1111_1111;
    const imm = signExtend12(imm_raw);
    const fn3 = (instr >> 7) & 0b111;

    const address: i32 = @as(i32, @bitCast(self.regs[rm])) + imm;
    const sum_address = if (address < 0) DM_SIZE + address else address;
    const wrapped_address: usize = @intCast(sum_address); // wtf???
    const value = self.regs[rn];

    switch (fn3) {
        0b000 => {
            self.data_memory[wrapped_address + 0] = @truncate(value >> 0);
            self.data_memory[wrapped_address + 1] = @truncate(value >> 8);
            self.data_memory[wrapped_address + 2] = @truncate(value >> 16);
            self.data_memory[wrapped_address + 3] = @truncate(value >> 24);
        },
        0b001 => {
            self.data_memory[wrapped_address + 0] = @truncate(value >> 0);
            self.data_memory[wrapped_address + 1] = @truncate(value >> 8);
        },
        0b011 => {
            self.data_memory[wrapped_address] = @truncate(value >> 0);
        },
        else => @panic("Error: Invalid fn3 on S-Type Store instruction!\n"),
    }
}

fn execCB(self: *SoC, instr: u32) void {
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
                if ((self.statusreg & SoC.FLAG_EQ) != 0) {
                    self.pc = new_pc;
                }
            },
            0b001 => { // bneq
                if ((self.statusreg & SoC.FLAG_EQ) == 0) {
                    self.pc = new_pc;
                }
            },
            0b010 => { // bgt
                if ((self.statusreg & SoC.FLAG_GT) != 0) {
                    self.pc = new_pc;
                }
            },
            0b011 => { // blt
                if ((self.statusreg & SoC.FLAG_LT) != 0) {
                    self.pc = new_pc;
                }
            },
            0b100 => { // begt
                if ((self.statusreg & (SoC.FLAG_GT | SoC.FLAG_EQ)) != 0) {
                    self.pc = new_pc;
                }
            },
            0b101 => { // belt
                if ((self.statusreg & (SoC.FLAG_LT | SoC.FLAG_EQ)) != 0) {
                    self.pc = new_pc;
                }
            },
            0b110 => {
                if ((self.statusreg & SoC.FLAG_C) != 0) {
                    self.pc = new_pc;
                }
            },
            0b111 => {
                if ((self.statusreg & SoC.FLAG_V) != 0) {
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

pub fn SoC_init(self: *SoC) void {
    self.regs = [_]u32{0} ** 32;
    self.statusreg = 0;
    self.pc = 0;
    self.instruction_memory = [_]u8{0} ** IM_SIZE;
    self.data_memory = [_]u8{0} ** DM_SIZE;
}

pub fn SoC_main(self: *SoC) void {
    SoC_init(self);
    while (true) {
        const instr = fetch(self);
        decode_and_execute(self, instr);
    }
}

pub fn SoC_for_test(self: *SoC, instr: u32) void {
    decode_and_execute(self, instr);
}
