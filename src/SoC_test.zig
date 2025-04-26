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

fn execI_instr(rm: u32, imm: u32, rd: u32, fn3: u32, opcode: u32) u32 {
    return (rm << 27) |
        (imm << 15) |
        (rd << 10) |
        (fn3 << 7) |
        (opcode & 0b1111111);
}

// execR 테스트용
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
        try testing.expect(((soc.statusreg & aurosoc.SoC.FLAG_C) != 0) == flags.expected_carry);
        try testing.expect(((soc.statusreg & aurosoc.SoC.FLAG_V) != 0) == flags.expected_overflow);
    }
}

// cmp 테스트용
fn test_cmp(rm_value: u32, rn_value: u32, eq_flag: bool, gt_flag: bool, lt_flag: bool) !void {
    var soc = create_and_init_soc();
    soc.regs[1] = rm_value;
    soc.regs[2] = rn_value;

    const instr = execR_instr(1, 2, 3, 0b110, 0b0000000, 0b0000000);
    aurosoc.SoC_for_test(&soc, instr);

    try testing.expect(((soc.statusreg & aurosoc.SoC.FLAG_EQ) != 0) == eq_flag);
    try testing.expect(((soc.statusreg & aurosoc.SoC.FLAG_GT) != 0) == gt_flag);
    try testing.expect(((soc.statusreg & aurosoc.SoC.FLAG_LT) != 0) == lt_flag);
}

// execI immediate 연산 테스트용
fn test_execI_addi(rm_value: u32, imm_value: u32, expected_result: u32) !void {
    var soc = create_and_init_soc();
    soc.regs[1] = rm_value;

    const instr = execI_instr(1, imm_value, 3, 0b000, 0b0000001); // fn3=0b000, opcode=0b0000001 (ADDI)
    aurosoc.SoC_for_test(&soc, instr);

    try testing.expectEqual(expected_result, soc.regs[3]);
}

// execI load 연산 테스트용
fn test_execI_load(rm_value: u32, imm_value: u32, load_size: enum { Word, Half, Byte }, expected_result: u32) !void {
    var soc = create_and_init_soc();
    soc.regs[1] = rm_value;
    const address = rm_value + imm_value;

    // 메모리에 데이터 세팅 (Little Endian으로)
    switch (load_size) {
        .Word => {
            soc.data_memory[address + 0] = @truncate(expected_result >> 0);
            soc.data_memory[address + 1] = @truncate(expected_result >> 8);
            soc.data_memory[address + 2] = @truncate(expected_result >> 16);
            soc.data_memory[address + 3] = @truncate(expected_result >> 24);
        },
        .Half => {
            soc.data_memory[address + 0] = @truncate(expected_result >> 0);
            soc.data_memory[address + 1] = @truncate(expected_result >> 8);
        },
        .Byte => {
            soc.data_memory[address + 0] = @truncate(expected_result >> 0);
        },
    }
    var fn3: u32 = undefined;
    switch (load_size) {
        .Word => fn3 = 0b000,
        .Half => fn3 = 0b001,
        .Byte => fn3 = 0b011,
    }
    const instr = execI_instr(1, imm_value, 3, fn3, 0b001001);
    aurosoc.SoC_for_test(&soc, instr);

    try testing.expectEqual(expected_result, soc.regs[3]);
}
// ------------------ 테스트 모음 ------------------

// --- Arithmetic ---
test "execR: add" {
    try test_execR(100, 40, 140, 0b000, 0b0000000, null);
}
test "execR: add with carry and overflow" {
    try test_execR(0xFFFF_FFFF, 1, 0, 0b000, 0b0000000, .{ .expected_carry = true, .expected_overflow = false });
}
test "execR: sub" {
    try test_execR(100, 30, 70, 0b000, 0b0000001, null);
}
test "execR: sub with carry" {
    try test_execR(100, 120, 0xFFFFFFEC, 0b000, 0b0000001, .{ .expected_carry = true, .expected_overflow = false });
}

// --- Logic ---
test "execR: OR, AND, XOR" {
    try test_execR(0b0010, 0b0110, 0b0110, 0b001, 0b0000000, null);
    try test_execR(0b0010, 0b0110, 0b0010, 0b010, 0b0000000, null);
    try test_execR(0b0010, 0b0110, 0b0100, 0b011, 0b0000000, null);
}

// --- Shift ---
test "execR: LSL" {
    try test_execR(0b0001, 2, 0b0100, 0b100, 0b0000000, null);
}
test "execR: LSR" {
    try test_execR(0b0100, 2, 0b0001, 0b101, 0b0000000, null);
}
test "execR: ASR" {
    try test_execR(0xFFFF_FF00, 2, 0xFFFFFFC0, 0b101, 0b0000001, null);
}

// --- CMP ---
test "execR: cmp equal" {
    try test_cmp(42, 42, true, false, false);
}
test "execR: cmp greater than" {
    try test_cmp(100, 42, false, true, false);
}
test "execR: cmp less than" {
    try test_cmp(10, 42, false, false, true);
}

// --- Immediate 연산 (ADDI) ---
test "execI: add immediate (ADDI)" {
    try test_execI_addi(100, 23, 123);
}
// --- Load 연산 (LW, LH, LB) ---
test "execI: load word (LW)" {
    try test_execI_load(0, 50, .Word, 0x78563412);
}

test "execI: load half (LH)" {
    try test_execI_load(0, 60, .Half, 0x7856);
}

test "execI: load byte (LB)" {
    try test_execI_load(0, 70, .Byte, 0xAB);
}
