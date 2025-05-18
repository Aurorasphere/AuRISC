pub var is_m_ext: bool = false;
pub var is_f_ext: bool = false;
pub var is_v_ext: bool = false;

pub var SoC = struct {
    pub var registers: [32]u32 = .{0}; // Integer Registers
    pub var psr = struct { // Program Status Register
        pub var overflow: bool = false;
        pub var carry: bool = false;
        pub var zero: bool = false;
        pub var negative: bool = false;
        pub var gt: bool = false;
        pub var eq: bool = false;
        pub var lt: bool = false;
        pub var interrupt_mask: bool = false;
        pub var supervisor: u2 = 0;
    };
    pub var enr: u8 = 0; // Exception Number Register
    pub var elr: u32 = 0; // Exception Link Register
    pub var pc: u32 = 0; // Program Counter
    pub var ivt: [256]u32 = .{0}; // Interrupt Vector Table
    pub var svt: [256]u32 = .{0}; // System Call Vector Table

    const exception = enum {
        DivisionByZero,
        PermissionFault,
        IllegalOpcode,
        IllegalALUOperation,
    };

    // TODO: 예외처리 구현하기
    fn exception_handler(excp: exception) noreturn {}

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

    fn rtype_alu_decoder(instr_opcode: u8, fn3: u8, fn7: u8) aluop {
        switch (instr_opcode) {
            0b0000000 => { // Base Instruction
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
                            else => exception_handler(exception.IllegalALUOperation),
                        }
                    },
                    0b0000001 => {
                        switch (fn3) {
                            0b000 => return .sub,
                            0b101 => return .asr,
                            else => exception_handler(exception.IllegalALUOperation),
                        }
                    },
                    else => exception_handler(exception.IllegalALUOperation),
                }
            },
            0b0010000 => { // M-Extension
                if (!is_m_ext) exception_handler(exception.IllegalALUOperation);
                switch (fn7) {
                    0b0000000 => {
                        switch (fn3) {
                            0b000 => return .mul,
                            0b001 => return .umul,
                            0b010 => return .div,
                            0b011 => return .udiv,
                            0b100 => return .rem,
                            0b101 => return .urem,
                            else => exception_handler(exception.IllegalALUOperation),
                        }
                    },
                    else => exception_handler(exception.IllegalALUOperation),
                }
            },
        }
    }

    fn itype_alu_decoder(instr_opcode: u8, fn3: u8) aluop {
        switch (instr_opcode) {
            0b0000001 => {
                switch (fn3) {
                    0b000 => return .add,
                    0b001 => return .or_op,
                    0b010 => return .and_op,
                    0b011 => return .xor_op,
                    0b100 => return .lsl,
                    0b101 => return .lsr,
                    0b110 => return .cmp,
                    else => exception_handler(exception.IllegalALUOperation),
                }
            },
            0b0010001 => {
                if (!is_m_ext) exception_handler(exception.IllegalALUOperation);
                switch (fn3) {
                    0b000 => return .mul,
                    0b001 => return .umul,
                    0b010 => return .div,
                    0b011 => return .udiv,
                    0b100 => return .rem,
                    0b101 => return .urem,
                    else => exception_handler(exception.IllegalALUOperation),
                }
            },
            else => exception_handler(exception.IllegalALUOperation),
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
            .asr => {},
            .cmp => {},
            .mul => result = @bitCast(@as(i32, @intCast(a * b))),
            .umul => result = @bitCast(a * b),
            .div => {
                if (b == 0) {
                    exception_handler(exception.DivisionByZero);
                } else {
                    result = @bitCast(@as(i32, @bitCast(a)) / @as(i32, @bitCast(b)));
                }
            },
            .udiv => {
                if (b == 0) {
                    exception_handler(exception.DivisionByZero);
                } else {
                    result = a / b;
                }
            },
            .rem => {
                if (b == 0) {
                    exception_handler(exception.DivisionByZero);
                } else {
                    result = @bitCast(@as(i32, @bitCast(a)) % @as(i32, @bitCast(b)));
                }
            },
            .urem => {
                if (b == 0) {
                    exception_handler(exception.DivisionByZero);
                } else {
                    result = a % b;
                }
            },
            else => exception_handler(exception.IllegalALUOperation),
        }
        return result;
    }
};
