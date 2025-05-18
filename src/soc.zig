pub var is_m_ext: bool = false;
pub var is_f_ext: bool = false;
pub var is_v_ext: bool = false;

const SoC = struct {
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
    };
    pub var enr: u8 = 0; // Exception Number Register
    pub var elr: u32 = 0; // Exception Link Register
    pub var pc: u32 = 0; // Program Counter

    const exception = enum {
        DivisionByZero,
        IllegalOpcode,
        IllegalALUOperation,
    };

    fn exception_handler(excp: exception) void {} // 이거 어떻게 구현하지

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

    fn alu_opcode_decoder(fn3: u8, fn7: u8) aluop {
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
    }

    fn alu(a: u32, b: u32, opcode: aluop) u32 {
        var result: u32 = 0;
        switch (opcode) {
            .add => result = a + b,
            .sub => result = a - b,
            .or_op => result = a | b,
            .and_op => result = a & b,
            .xor_op => result = a ^ b,
            .lsl => result = a << @intCast(b),
            .lsr => result = a >> @intCast(b),
            .asr => {},
            .cmp => {},
            else => exception_handler(exception.IllegalALUOperation),
        }
        return result;
    }
};
