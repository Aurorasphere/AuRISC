const SoC = @import("soc.zig");

pub const ALU_OP = enum {
    add,
    sub,
    or_op,
    and_op,
    xor,
    lsl,
    lsr,
    asr,
    cmp,
    invalid,
};

pub fn decodeALUOpcode(fn3: u3, fn7: u7) ALU_OP {
    const fn7_masked = (fn7 & 0b1) != 0;

    if (!fn7_masked) {
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

pub fn ALU(self: *SoC.SoC, a: u32, b: u32, opcode: ALU_OP) ?u32 {
    var result: u32 = 0;

    switch (opcode) {
        .add => {
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
        .sub => {
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

            result = null;
        },
        .invalid => result = null,
    }
}
