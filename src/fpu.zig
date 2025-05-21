const SoC = @import("soc.zig").SoC;

pub var FPU = struct {
    pub var fpr: [32]u64 = .{0}; // Floating Point Registers

    pub const fpaluop = enum {
        fadd,
        fsub,
        fmul,
        fdiv,
        fsqrt,
        fcmp,
        dfadd,
        dfsub,
        dfmul,
        dfdiv,
        dfsqrt,
        dfcmp,
    };

    pub fn fpaluop_decode(fn3: u3, fn7: u7) fpaluop {
        switch (fn7) {
            0b0000000 => {
                switch (fn3) {
                    0b000 => return .fadd,
                    0b001 => return .fsub,
                    0b010 => return .fmul,
                    0b011 => return .fdiv,
                    0b100 => return .fsqrt,
                    0b101 => return .fcmp,
                }
            },
            0b0000010 => {
                switch (fn3) {
                    0b000 => return .dfadd,
                    0b001 => return .dfsub,
                    0b010 => return .dfmul,
                    0b011 => return .dfdiv,
                    0b100 => return .dfsqrt,
                    0b101 => return .dfcmp,
                }
            },
        }
    }

    pub fn FP_ALU(a: u64, b: u64, opcode: fpaluop) u64 {
        var result: u64 = 0;

        const f32_a: f32 = @bitCast(a);
        const f32_b: f32 = @bitCast(b);
        const f64_a: f64 = @bitCast(a);
        const f64_b: f64 = @bitCast(b);

        switch (opcode) {
            .fadd => result = @bitCast(f32_a + f32_b),
            .fsub => result = @bitCast(f32_a - f32_b),
            .fmul => result = @bitCast(f32_a * f32_b),
            .fdiv => result = @bitCast(f32_a / f32_b),
            .fsqrt => result = @bitCast(@sqrt(f32_a)),
            .fcmp => {
                SoC.psr.gt = (f32_a > f32_b);
                SoC.psr.lt = (f32_a < f32_b);
                SoC.psr.eq = (f32_a == f32_b);
            },
            .dfadd => result = @bitCast(f64_a + f64_b),
            .dfsub => result = @bitCast(f64_a - f64_b),
            .dfmul => result = @bitCast(f64_a * f64_b),
            .dfdiv => result = @bitCast(f64_a / f64_b),
            .dfsqrt => result = @bitCast(@sqrt(f64_a)),
            .dfcmp => {
                SoC.psr.gt = (f64_a > f64_b);
                SoC.psr.lt = (f64_a < f64_b);
                SoC.psr.eq = (f64_a == f64_b);
            },
            else => SoC.exception_handler(SoC.exception.IllegalALUOperation),
        }
        return result;
    }
};
