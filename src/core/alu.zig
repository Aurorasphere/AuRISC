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
    umul, // Unsigned multiply
    div, // Divide
    udiv, // Unsigned divide
    rem, // Remainder
    urem, // Unsigned remainder
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

const M_EXT = 0b001_0000;
const F_EXT = 0b010_0000;

pub fn decodeALUOpcode(fn3: u3, fn7: u7) ALU_OP {
    if (fn7 == 0b0000000) {
        switch (fn3) {
            0b000 => return .add,
            0b001 => return .or_op,
            0b010 => return .and_op,
            0b011 => return .xor,
            0b100 => return .lsl,
            0b101 => return .lsr,
            0b110 => return .cmp,
            else => return .invalid,
        }
    } else if (fn7 == 0b0000001) {
        switch (fn3) {
            0b000 => return .sub,
            0b101 => return .asr,
            else => return .invalid,
        }
    } else if ((fn7 & M_EXT) != 0) {
        switch (fn3) {
            0b000 => return .mul,
            0b001 => return .umul,
            0b010 => return .div,
            0b011 => return .udiv,
            0b100 => return .rem,
            0b101 => return .urem,
            else => return .invalid,
        }
    } else if ((fn7 & F_EXT) != 0 and (fn7 & 0b0001111) == 0) {
        switch (fn3) {
            0b000 => return .fadd,
            0b001 => return .fsub,
            0b010 => return .fmul,
            0b011 => return .fdiv,
            0b100 => return .fsqrt,
            0b101 => return .fcmp,
            else => return .invalid,
        }
    } else if ((fn7 & F_EXT) != 0 and (fn7 & 0b0001111) == 1) {
        switch (fn3) {
            0b000 => return .ftint,
            0b001 => return .ftuint,
            0b010 => return .fmvi,
            0b011 => return .imvf,
            else => return .invalid,
        }
    }
}

fn mext_operation(a: u32, b: u32, opcode: ALU_OP) u32 {
    var result: u32 = 0;
    switch (opcode) {
        .mul => result = @as(i32, a * b),
        .mulu => result = a * b,
        .div => result = @as(i32, a / b),
        .divu => result = a / b,
        .rem => result = @as(i32, a % b),
        .remu => result = a % b,
        else => return 0,
    }

    return result;
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
        else => result = 0,
    }
    return result;
}
