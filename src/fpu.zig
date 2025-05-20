const SoC = @import("soc.zig").SoC;

pub var FPU = struct {
    pub var fpr: [32]u64 = .{0}; // Floating Point Registers

    const fp_aluop = enum {
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

    fn FP_ALU(a: u64, b: u64, opcode: fp_aluop) u64 {
        var result: u64 = 0;

        const f32_a: f32 = @bitCast(a);
        const f32_b: f32 = @bitCast(b);

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
            .dfadd => result = a + b,
            .dfsub => result = a - b,
            .dfmul => result = a * b,
            .dfdiv => result = a / b,
            .dfsqrt => result = @sqrt(a),
            .dfcmp => {
                SoC.psr.gt = (a > b);
                SoC.psr.lt = (a < b);
                SoC.psr.eq = (a == b);
            },
            else => SoC.exception_handler(SoC.exception.IllegalALUOperation),
        }
        return result;
    }
};
