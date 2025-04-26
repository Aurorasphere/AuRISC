const std = @import("std");
const aurosoc = @import("SoC.zig");

test "execR: ADD" {
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

    // 필드 정의
    const rm: u32 = 1;
    const rn: u32 = 2;
    const rd: u32 = 3;
    const fn7: u32 = 0b0000000;
    const fn3: u32 = 0b000;
    const opcode: u32 = 0b0000000;

    // 정확한 비트 배치로 instr 생성
    const instr: u32 =
        (rm << 27) |
        (rn << 22) |
        (fn7 << 15) |
        (rd << 10) |
        (fn3 << 7) |
        opcode;

    // 실행
    aurosoc.execR(&soc, instr);

    // 결과 확인
    try std.testing.expectEqual(@as(u32, 15), soc.regs[rd]);
}
