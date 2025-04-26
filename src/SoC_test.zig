const std = @import("std");
const testing = std.testing;
const aurosoc = @import("SoC.zig");

pub fn SoC_create() aurosoc.SoC {
    return aurosoc.SoC{
        .regs = [_]u32{0} ** 32,
        .statusreg = 0,
        .pc = 0,
        .instruction_memory = [_]u8{0} ** 256,
        .data_memory = [_]u8{0} ** 256,
    };
}

fn create_and_init_soc() aurosoc.SoC {
    var soc = SoC_create();
    aurosoc.SoC_init(&soc);
    return soc;
}

fn execR_instr(rm: u32, rn: u32, rd: u32, fn3: u32, fn7: u32, opcode: u32) u32 {
    return (rm << 27) |
        (rn << 22) |
        (fn7 << 15) |
        (rd << 10) |
        (fn3 << 7) |
        opcode;
}

/// instr 실행하고 결과값 검증
fn test_execR(
    rm_value: u32,
    rn_value: u32,
    expected_result: u32,
    fn3: u32,
    fn7: u32,
    check_flags: ?struct {
        expected_carry: bool,
        expected_overflow: bool,
    },
) !void {
    var soc = create_and_init_soc();
    soc.regs[1] = rm_value;
    soc.regs[2] = rn_value;

    const instr = execR_instr(1, 2, 3, fn3, fn7, 0b0000000);
    aurosoc.SoC_for_test(&soc, instr);

    try testing.expectEqual(expected_result, soc.regs[3]);

    if (check_flags) |flags| {
        if (flags.expected_carry) {
            try testing.expect((soc.statusreg & aurosoc.SoC.FLAG_C) != 0);
        } else {
            try testing.expect((soc.statusreg & aurosoc.SoC.FLAG_C) == 0);
        }
        if (flags.expected_overflow) {
            try testing.expect((soc.statusreg & aurosoc.SoC.FLAG_V) != 0);
        } else {
            try testing.expect((soc.statusreg & aurosoc.SoC.FLAG_V) == 0);
        }
    }
}

// --- Arithmetic tests ---
test "execR: add test" {
    try test_execR(100, 40, 140, 0b000, 0b0000000, null);
}

test "execR: add with carry and overflow test" {
    try test_execR(0xFFFF_FFFF, 1, 0, 0b000, 0b0000000, .{
        .expected_carry = true,
        .expected_overflow = false,
    });
}

test "execR: sub test" {
    try test_execR(100, 30, 70, 0b000, 0b0000001, null);
}

test "execR: sub with carry test" {
    try test_execR(100, 120, 0xFFFFFFEC, 0b000, 0b0000001, .{
        .expected_carry = true,
        .expected_overflow = false,
    });
}

// --- Logic operation tests ---
test "execR: logic OR, AND, XOR test" {
    try test_execR(0b0010, 0b0110, 0b0110, 0b001, 0b0000000, null); // OR
    try test_execR(0b0010, 0b0110, 0b0010, 0b010, 0b0000000, null); // AND
    try test_execR(0b0010, 0b0110, 0b0100, 0b011, 0b0000000, null); // XOR
}

// --- Shift tests ---
test "execR: shift LSL" {
    try test_execR(0b0001, 2, 0b0100, 0b100, 0b0000000, null);
}

test "execR: shift LSR" {
    try test_execR(0b0100, 2, 0b0001, 0b101, 0b0000000, null);
}

test "execR: shift ASR" {
    try test_execR(0xFFFF_FF00, 2, 0xFFFFFFC0, 0b101, 0b0000001, null);
}

// --- CMP tests ---
test "execR: cmp equal test" {
    var soc = create_and_init_soc();
    soc.regs[1] = 42;
    soc.regs[2] = 42;

    const instr = execR_instr(1, 2, 3, 0b110, 0b0000000, 0b0000000);
    aurosoc.SoC_for_test(&soc, instr);

    try testing.expect((soc.statusreg & aurosoc.SoC.FLAG_EQ) != 0); // EQ ON
    try testing.expect((soc.statusreg & aurosoc.SoC.FLAG_GT) == 0); // GT OFF
    try testing.expect((soc.statusreg & aurosoc.SoC.FLAG_LT) == 0); // LT OFF
}

test "execR: cmp greater than test" {
    var soc = create_and_init_soc();
    soc.regs[1] = 100;
    soc.regs[2] = 42;

    const instr = execR_instr(1, 2, 3, 0b110, 0b0000000, 0b0000000);
    aurosoc.SoC_for_test(&soc, instr);

    try testing.expect((soc.statusreg & aurosoc.SoC.FLAG_EQ) == 0);
    try testing.expect((soc.statusreg & aurosoc.SoC.FLAG_GT) != 0);
    try testing.expect((soc.statusreg & aurosoc.SoC.FLAG_LT) == 0);
}

test "execR: cmp less than test" {
    var soc = create_and_init_soc();
    soc.regs[1] = 10;
    soc.regs[2] = 42;

    const instr = execR_instr(1, 2, 3, 0b110, 0b0000000, 0b0000000);
    aurosoc.SoC_for_test(&soc, instr);

    try testing.expect((soc.statusreg & aurosoc.SoC.FLAG_EQ) == 0);
    try testing.expect((soc.statusreg & aurosoc.SoC.FLAG_GT) == 0);
    try testing.expect((soc.statusreg & aurosoc.SoC.FLAG_LT) != 0);
}
