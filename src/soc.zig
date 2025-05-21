const fpu = @import("fpu.zig");
const mem = @import("memory.zig");

pub var is_vm_enabled: bool = false;
pub var is_m_ext: bool = false;
pub var is_f_ext: bool = false;
pub var is_v_ext: bool = false;

pub const PAGE_TABLE_ENTRIES = 4096;

pub var page_table: [PAGE_TABLE_ENTRIES]SoC.PageTableEntry = .{.{ .pfn = 0, .valid = false, .readable = false, .writeable = false, .executeable = false, .dirty = false, .user = false, .accessed = false, .reserved = 0 } ** PAGE_TABLE_ENTRIES};

pub var SoC = struct {
    pub var registers: [32]u32 = .{0}; // Integer Registers
    //
    // =============== Special Registers ===============
    const privilege = enum(u2) {
        user = 0b00,
        kernel = 0b10,
        hardware = 0b11,
    };
    pub var psr = struct { // Program Status Register
        pub var overflow: bool = false;
        pub var carry: bool = false;
        pub var zero: bool = false;
        pub var negative: bool = false;
        pub var gt: bool = false;
        pub var eq: bool = false;
        pub var lt: bool = false;
        pub var interrupt_mask: bool = false;
        pub var supervisor: privilege = .user;
    };
    pub var enr: u8 = 0; // Exception Number Register
    pub var elr: u32 = 0; // Exception Link Register
    pub var pc: u32 = 0; // Program Counter
    pub var ivt: [256]u32 = .{0}; // Interrupt Vector Table
    pub var svt: [256]u32 = .{0}; // System Call Vector Table

    // =============== Virtual Memory ===============
    pub var PageTableEntry = packed struct {
        pfn: u24, // Page Frame Number
        valid: bool, // Is page vaild?
        readable: bool, // R
        writeable: bool, // W
        executeable: bool, // X
        dirty: bool,
        user: bool, // Accessable by user?
        accessed: bool, // Accessed page
        reserved: u2,
    };

    fn VA_translate(vaddr: u32, is_store: bool, is_exec: bool) !u32 {
        if (!is_vm_enabled) return vaddr;

        const vpn = vaddr >> 12;
        const offset = vaddr & 0xFFF;
        if (vpn >= PAGE_TABLE_ENTRIES)
            return error.PageFault;
        const pte = page_table[vpn];

        if (!pte.valid)
            return error.PageFault;

        if (is_exec and !pte.executeable)
            return error.PermissionFault;

        if (!is_exec and !is_store and !pte.readable)
            return error.PermissionFault;

        if (is_store and !pte.writeable)
            return error.PermissionFault;

        if (psr.supervisor == .user and !pte.user)
            return error.PermissionFault;

        page_table[vpn].accessed = true;
        if (is_store)
            page_table[vpn].dirty = true;

        return (pte.pfn << 12) | offset;
    }

    // =============== Exception Handling ===============
    pub const exception = enum {
        DivisionByZero,
        PageFault,
        PermissionFault,
        InvalidSyscall,
        IllegalOpcode,
        IllegalALUOperation,
        FPTypeMismatch,
    };

    // TODO: 예외처리 구현하기
    fn exception_handler(excp: exception) noreturn {
        elr = pc;
        enr = @intFromEnum(excp);
    }

    // =============== ALU ===============
    const aluop = enum {
        // Basic Integer ALU Operation
        add,
        sub,
        or_op,
        and_op,
        xor_op,
        lsl,
        lsr,
        asr,
        cmp,
        // M-Extension ALU Operation
        mul,
        umul,
        div,
        udiv,
        rem,
        urem,
    };

    fn aluop_decoder(instr_opcode: u7, fn3: u3, fn7: u7) aluop {
        switch (instr_opcode) {
            0b0000000 or 0b0000001 => { // Base Instruction
                switch (fn7) {
                    0b0000000 => {
                        switch (fn3) {
                            0b000 => return .add,
                            0b001 => return .or_op,
                            0b010 => return .and_op,
                            0b011 => return .xor_op,
                            0b100 => return .lsl,
                            0b101 => return .lsr,
                            0b110 => return .cmp,
                            else => {
                                exception_handler(exception.IllegalALUOperation);
                                unreachable;
                            },
                        }
                    },
                    0b0000001 => {
                        switch (fn3) {
                            0b000 => return .sub,
                            0b101 => return .asr,
                            else => {
                                exception_handler(exception.IllegalALUOperation);
                                unreachable;
                            },
                        }
                    },
                    else => {
                        exception_handler(exception.IllegalALUOperation);
                        unreachable;
                    },
                }
            },
            0b0010000 or 0b0010001 => { // M-Extension
                if (!is_m_ext) {
                    exception_handler(exception.IllegalALUOperation);
                    unreachable;
                }
                switch (fn7) {
                    0b0000000 => {
                        switch (fn3) {
                            0b000 => return .mul,
                            0b001 => return .umul,
                            0b010 => return .div,
                            0b011 => return .udiv,
                            0b100 => return .rem,
                            0b101 => return .urem,
                            else => {
                                exception_handler(exception.IllegalALUOperation);
                                unreachable;
                            },
                        }
                    },
                    else => {
                        exception_handler(exception.IllegalALUOperation);
                        unreachable;
                    },
                }
            },
        }
    }

    fn alu(a: u32, b: u32, opcode: aluop) u32 {
        var result: u32 = 0;
        switch (opcode) {
            .add => result = a + b,
            .sub => result = a - b,
            .or_op => result = a | b,
            .and_op => result = a & b,
            .xor_op => result = a ^ b,
            .lsl => result = a << @truncate(b),
            .lsr => result = a >> @truncate(b),
            .asr => result = @bitCast(@as(i32, @bitCast(a)) >> @truncate(b & 0x1F)),
            .cmp => {
                psr.gt = a > b;
                psr.eq = a == b;
                psr.lt = a < b;
            },
            .mul => result = @bitCast(@as(i32, @intCast(a * b))),
            .umul => result = a * b,
            .div => {
                if (b == 0) {
                    exception_handler(exception.DivisionByZero);
                    unreachable;
                } else {
                    result = @bitCast(@as(i32, @bitCast(a)) / @as(i32, @bitCast(b)));
                }
            },
            .udiv => {
                if (b == 0) {
                    exception_handler(exception.DivisionByZero);
                    unreachable;
                } else {
                    result = a / b;
                }
            },
            .rem => {
                if (b == 0) {
                    exception_handler(exception.DivisionByZero);
                    unreachable;
                } else {
                    result = @bitCast(@as(i32, @bitCast(a)) % @as(i32, @bitCast(b)));
                }
            },
            .urem => {
                if (b == 0) {
                    exception_handler(exception.DivisionByZero);
                    unreachable;
                } else {
                    result = a % b;
                }
            },
            else => {
                exception_handler(exception.IllegalALUOperation);
                unreachable;
            },
        }
        return result;
    }

    fn execR(instr: u32) void {
        const rm: u5 = @bitCast((instr >> 27) & 0b11111);
        const rn: u5 = @bitCast((instr >> 22) & 0b11111);
        const rd: u5 = @bitCast((instr >> 10) & 0b11111);
        const fn3: u3 = @bitCast((instr >> 7) & 0b111);
        const fn7: u7 = @bitCast((instr >> 15) & 0b1111111);
        const opcode: u7 = @bitCast(instr & 0b1111111);

        if (opcode == 0b010_0000) { // F-Extension
            const aluop_r = fpu.fpaluop_decode(fn7, fn3);
            fpu.fpr[rd] = fpu.FP_ALU(fpu.fpr[rm], fpu.fpr[rn], aluop_r);
        } else {
            const aluop_r = aluop_decoder(opcode, fn3, fn7);
            registers[rd] = alu(registers[rm], registers[rn], aluop_r);
        }
    }

    fn execI(instr: u32) void {
        const rm: u5 = @bitCast((instr >> 27) & 0b11111);
        const imm: u12 = @bitCast((instr >> 15) & 0b111111111111);
        const rd: u5 = @bitCast((instr >> 10) & 0b11111);
        const fn3: u3 = @bitCast((instr >> 7) & 0b111);
        const opcode: u7 = @bitCast(instr & 0b1111111);

        const imm_signext: u32 = @bitCast(@as(i32, @bitCast(@as(i16, imm << 4))) >> 4);

        if (opcode == 0b0000001 or 0b0010001) {
            const aluop_i = aluop_decoder(opcode, fn3, 0);
            registers[rd] = alu(registers[rm], imm_signext, aluop_i);
        } else if (opcode == 0b0001001) { // Base Load instruction 
            const vaddr = register 
            const paddr 
            switch (fn3) {
                0b000 => { // ldw, Load Word
                    const
                }
            }
        }
    }
};
