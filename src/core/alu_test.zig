const std = @import("std");
const testing = std.testing;
const alu = @import("alu.zig");
const soc = @import("soc.zig");

const SoC = soc.SoC;

// ALU 연산 결과 및 플래그 테스트
test "ALU add operation sets result and flags correctly" {
    var cpu = soc.SoC_create();
    const a: u32 = 10;
    const b: u32 = 20;

    const result: u32 = alu.ALU(&cpu, a, b, .add);
    try testing.expectEqual(result, 30);
    try testing.expect((cpu.statusreg & SoC.FLAG_C) == 0);
    try testing.expect((cpu.statusreg & SoC.FLAG_V) == 0);
}

test "ALU sub operation sets result and carry flag correctly" {
    var cpu = soc.SoC_create();
    const a: u32 = 10;
    const b: u32 = 20;

    const result: u32 = alu.ALU(&cpu, a, b, .sub);
    try testing.expectEqual(result, @as(u32, 0xFFFFFFF6)); // -10 in two's complement
    try testing.expect((cpu.statusreg & SoC.FLAG_C) != 0);
}

test "ALU cmp operation sets correct flags for a > b" {
    var cpu = soc.SoC_create();
    _ = alu.ALU(&cpu, 123, 100, .cmp);
    try testing.expect((cpu.statusreg & SoC.FLAG_GT) != 0);
    try testing.expect((cpu.statusreg & SoC.FLAG_EQ) == 0);
    try testing.expect((cpu.statusreg & SoC.FLAG_LT) == 0);
}

test "ALU cmp operation sets correct flags for a == b" {
    var cpu = soc.SoC_create();
    _ = alu.ALU(&cpu, 200, 200, .cmp);
    try testing.expect((cpu.statusreg & SoC.FLAG_EQ) != 0);
    try testing.expect((cpu.statusreg & SoC.FLAG_GT) == 0);
    try testing.expect((cpu.statusreg & SoC.FLAG_LT) == 0);
}

test "ALU cmp operation sets correct flags for a < b" {
    var cpu = soc.SoC_create();
    _ = alu.ALU(&cpu, 50, 100, .cmp);
    try testing.expect((cpu.statusreg & SoC.FLAG_LT) != 0);
    try testing.expect((cpu.statusreg & SoC.FLAG_EQ) == 0);
    try testing.expect((cpu.statusreg & SoC.FLAG_GT) == 0);
}
