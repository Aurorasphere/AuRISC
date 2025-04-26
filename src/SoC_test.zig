const std = @import("std");
const aurosoc = @import("SoC.zig");

test "execR test" {
    var soc = aurosoc.SoC{
        .regs = [_]u32{0} ** 32,
        .statusreg = 0,
        .pc = 0,
        .instruction_memory = [_]u8{0} ** 256,
        .data_memory = [_]u8{0} ** 256,
    };

    // Rm = 1, Rn = 2, Rd = 3
    soc.regs[1] = 7;
    soc.regs[2] = 8;

    // define instr field
    const rm: u32 = 1;
    const rn: u32 = 2;
    const rd: u32 = 3;
    const fn7: u32 = 0b0000000;
    const fn3: u32 = 0b000;
    const opcode: u32 = 0b0000000;

    const instr: u32 =
        (rm << 27) |
        (rn << 22) |
        (fn7 << 15) |
        (rd << 10) |
        (fn3 << 7) |
        opcode;

    // execute
    aurosoc.execR(&soc, instr);

    // conrimation
    try std.testing.expectEqual(@as(u32, 15), soc.regs[rd]);
}
