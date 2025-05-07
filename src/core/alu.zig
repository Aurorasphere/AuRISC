const soc = @import("soc.zig");

pub const ALU_OP = enum {
    add, // Addition
    sub, // Subtraction
    or_op, // Bitwise OR
    and_op, // Bitwise AND
    xor, // Bitwise XOR
    lsl, // Logical left shift
    lsr, // Logical right shift
    asr, // Arithmetic right shift
    cmp, // Compare
    invalid,
    // M-Extension: Multiply and Divide
    mul, // Multiply
    mulu, // Unsigned multiply
    div, // Divide
    divu, // Unsigned divide
    rem, // Remainder
    remu, // Unsigned remainder
    // F-Extension: Floating point extensions
    fadd, // Floating point addition
    fsub, // Floating point subtraction
    fmul, // Floating point multilication
    fdiv, // Floating point division
    fsqrt, // Floating point square root
    fcmp, // Floating point compare
    ftint, // Floating point to Signed integer
    ftuint, // Floating point to Unsigned interger
    fmvi, // Move Floating point bit to integer
    imvf, // Move integer bit to floating point
};

pub fn decodeALUOpcode(fn3: u3, fn7: u7) ALU_OP {
    const M_EXT = 0b0010_0000;
    const F_EXT = 0b0100_0000;

    if (fn7 & M_EXT == 0 and fn7 & F_EXT == 0) {
        return switch (fn3) {
            0b000 => .add,
            0b001 => .or_op,
            0b010 => .and_op,
            0b011 => .xor,
            0b100 => .lsl,
            0b101 => .lsr,
            0b110 => .cmp,
            else => .invalid,
        };
    } else {
        return switch (fn3) {
            0b000 => .sub,
            0b101 => .asr,
            else => .invalid,
        };
    }
}

pub fn ALU(self: *soc.SoC, a: u32, b: u32, opcode: ALU_OP) u32 {
    var result: u32 = 0;

    switch (opcode) {
        .add => {
            const sum = @addWithOverflow(a, b);
            result = sum[0];

            // Carry detection
            if (sum[1] != 0) {
                self.statusreg |= soc.FLAG_C;
            } else {
                self.statusreg &= ~soc.FLAG_C;
            }

            // Overflow detection
            const signed_a: i32 = @bitCast(a);
            const signed_b: i32 = @bitCast(b);
            const signed_result: i32 = @bitCast(result);
            if ((signed_a > 0 and signed_b > 0 and signed_result < 0) or
                (signed_a < 0 and signed_b < 0 and signed_result >= 0))
            {
                self.statusreg |= soc.FLAG_V;
            } else {
                self.statusreg &= ~soc.FLAG_V;
            }
        },
        .sub => {
            const diff = @subWithOverflow(a, b);
            result = diff[0];

            // Carry detection (borrow 발생)
            if (a < b) {
                self.statusreg |= soc.FLAG_C;
            } else {
                self.statusreg &= ~soc.FLAG_C;
            }

            // Overflow detection
            const signed_a: i32 = @bitCast(a);
            const signed_b: i32 = @bitCast(b);
            const signed_result: i32 = @bitCast(result);
            if ((signed_a > 0 and signed_b < 0 and signed_result < 0) or
                (signed_a < 0 and signed_b > 0 and signed_result >= 0))
            {
                self.statusreg |= soc.FLAG_V;
            } else {
                self.statusreg &= ~soc.FLAG_V;
            }
        },
        .or_op => result = a | b,
        .and_op => result = a & b,
        .xor => result = a ^ b,
        .lsl => result = a << @truncate(b),
        .lsr => result = a >> @truncate(b),
        .asr => {
            const signed_a: i32 = @bitCast(a);
            result = @bitCast(signed_a >> @truncate(b));
        },
        .cmp => {
            if (a == b) {
                self.statusreg |= soc.FLAG_EQ;
            } else {
                self.statusreg &= ~soc.FLAG_EQ;
            }

            if (a > b) {
                self.statusreg |= soc.FLAG_GT;
            } else {
                self.statusreg &= ~soc.FLAG_GT;
            }

            if (a < b) {
                self.statusreg |= soc.FLAG_LT;
            } else {
                self.statusreg &= ~soc.FLAG_LT;
            }
        },
        .invalid => result = 0,
    }
    return result;
}
