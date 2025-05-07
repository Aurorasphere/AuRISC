const std = @import("std");
const testing = std.testing;
const alu = @import("alu.zig");
const soc_mod = @import("soc.zig");
const SoC = soc_mod.SoC;

test "ALU: add" {
    var cpu: SoC = undefined;
    soc_mod.SoC_init(&cpu);

    const result = alu.ALU(&cpu, 40, 30, .add);
    try testing.expectEqual(@as(u32, 70), result);
}

test "ALU: add with carry/overflow flags" {
    var cpu: SoC = undefined;
    soc_mod.SoC_init(&cpu);

    const result = alu.ALU(&cpu, 0xFFFF_FFF6, 20, .add);
    try testing.expectEqual(@as(u32, 0xA), result);
    try testing.expect((cpu.statusreg & soc_mod.FLAG_C) != 0);
    try testing.expect((cpu.statusreg & soc_mod.FLAG_V) == 0);
}

test "ALU: sub" {
    var cpu: SoC = undefined;
    soc_mod.SoC_init(&cpu);

    const result = alu.ALU(&cpu, 30, 20, .sub);
    try testing.expectEqual(@as(u32, 10), result);
    try testing.expect((cpu.statusreg & soc_mod.FLAG_C) == 0); // borrow occurred
}

test "ALU: sub with carry flag on borrow" {
    var cpu: SoC = undefined;
    soc_mod.SoC_init(&cpu);

    const result = alu.ALU(&cpu, 10, 20, .sub);
    try testing.expectEqual(@as(u32, 0xFFFF_FFF6), result);
    try testing.expect((cpu.statusreg & soc_mod.FLAG_C) != 0); // borrow occurred
}

test "ALU: or" {
    var cpu: SoC = undefined;
    soc_mod.SoC_init(&cpu);

    const result = alu.ALU(&cpu, 0b01010101, 0b10101010, .or_op);
    try testing.expectEqual(@as(u32, 0b1111_1111), result);
}

test "ALU: and" {
    var cpu: SoC = undefined;
    soc_mod.SoC_init(&cpu);

    const result = alu.ALU(&cpu, 0b1010, 0b0011, .and_op);
    try testing.expectEqual(@as(u32, 0b0010), result);
}

test "ALU: xor" {
    var cpu: SoC = undefined;
    soc_mod.SoC_init(&cpu);

    const result = alu.ALU(&cpu, 0b1010, 0b0011, .xor);
    try testing.expectEqual(@as(u32, 0b1001), result);
}

test "ALU cmp operation sets EQ, GT, LT flags properly" {
    var cpu: SoC = undefined;
    soc_mod.SoC_init(&cpu);

    _ = alu.ALU(&cpu, 123, 123, .cmp);
    try testing.expect((cpu.statusreg & soc_mod.FLAG_EQ) != 0);
    try testing.expect((cpu.statusreg & soc_mod.FLAG_GT) == 0);
    try testing.expect((cpu.statusreg & soc_mod.FLAG_LT) == 0);

    _ = alu.ALU(&cpu, 200, 100, .cmp);
    try testing.expect((cpu.statusreg & soc_mod.FLAG_EQ) == 0);
    try testing.expect((cpu.statusreg & soc_mod.FLAG_GT) != 0);
    try testing.expect((cpu.statusreg & soc_mod.FLAG_LT) == 0);

    _ = alu.ALU(&cpu, 50, 100, .cmp);
    try testing.expect((cpu.statusreg & soc_mod.FLAG_EQ) == 0);
    try testing.expect((cpu.statusreg & soc_mod.FLAG_GT) == 0);
    try testing.expect((cpu.statusreg & soc_mod.FLAG_LT) != 0);
}
