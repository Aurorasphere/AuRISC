const std = @import("std");
const testing = std.testing;
const aurosoc = @import("SoC.zig");

pub fn SoC_create() aurosoc.SoC {
    return aurosoc.SoC{
        .regs = [_]u32{0} ** 32,
        .statusreg = 0,
        .pc = 0,
        .instruction_memory = [_]u8{0} ** aurosoc.IM_SIZE,
        .data_memory = [_]u8{0} ** aurosoc.DM_SIZE,
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

fn execI_instr(rm: u32, imm: i32, rd: u32, fn3: u32, opcode: u32) u32 {
    const imm12: u32 = @intCast(imm & 0xFFF);

    return (rm << 27) |
        (imm12 << 15) |
        (rd << 10) |
        (fn3 << 7) |
        (opcode & 0b1111111);
}

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

fn test_execI(fn3: u32, rm_value: u32, imm_value: i32, expected_result: u32) !void {
    var soc = create_and_init_soc();
    soc.regs[1] = rm_value;

    const instr = execI_instr(1, @intCast(imm_value), 3, fn3, 0b0000001);
    aurosoc.SoC_for_test(&soc, instr);

    try testing.expectEqual(expected_result, soc.regs[3]);
}

fn test_execI_load(rm_value: u32, imm_value: i32, load_size: enum { Word, Half, Byte }, expected_result: u32) !void {
    var soc = create_and_init_soc();
    soc.regs[1] = rm_value;

    const address: i32 = @as(i32, @bitCast(rm_value)) + imm_value;
    const sum_address = if (address < 0) aurosoc.DM_SIZE + address else address;
    const wrapped_address: usize = @intCast(sum_address);
    switch (load_size) {
        .Word => {
            soc.data_memory[wrapped_address + 0] = @truncate(expected_result >> 0);
            soc.data_memory[wrapped_address + 1] = @truncate(expected_result >> 8);
            soc.data_memory[wrapped_address + 2] = @truncate(expected_result >> 16);
            soc.data_memory[wrapped_address + 3] = @truncate(expected_result >> 24);
        },
        .Half => {
            soc.data_memory[wrapped_address + 0] = @truncate(expected_result >> 0);
            soc.data_memory[wrapped_address + 1] = @truncate(expected_result >> 8);
        },
        .Byte => {
            soc.data_memory[wrapped_address + 0] = @truncate(expected_result >> 0);
        },
    }

    const fn3: u32 = switch (load_size) {
        .Word => 0b000,
        .Half => 0b001,
        .Byte => 0b011,
    };

    const instr = execI_instr(1, imm_value, 3, fn3, 0b001001);
    aurosoc.SoC_for_test(&soc, instr);

    try testing.expectEqual(expected_result, soc.regs[3]);
}

fn test_execS_store(base_addr: i32, value_to_store: u32, store_size: enum { Word, Half, Byte }, expected_memory_value: u32) !void {
    var soc = create_and_init_soc();
    soc.regs[1] = @as(u32, @bitCast(base_addr));
    soc.regs[2] = value_to_store;

    const fn3: u32 = switch (store_size) {
        .Word => 0b000,
        .Half => 0b001,
        .Byte => 0b011,
    };

    const imm = 0;
    const instr = (1 << 27) | (2 << 22) | (imm << 10) | (fn3 << 7) | 0b0000010;

    aurosoc.SoC_for_test(&soc, instr);

    const address: i32 = @as(i32, @bitCast(soc.regs[1])) + imm;
    const sum_address = if (address < 0) aurosoc.DM_SIZE + address else address;
    const wrapped_address: usize = @intCast(sum_address);

    switch (store_size) {
        .Word => {
            const actual =
                (@as(u32, soc.data_memory[wrapped_address + 0]) << 0 |
                    (@as(u32, soc.data_memory[wrapped_address + 1]) << 8) |
                    (@as(u32, soc.data_memory[wrapped_address + 2]) << 16) |
                    (@as(u32, soc.data_memory[wrapped_address + 3]) << 24));
            try testing.expectEqual(expected_memory_value, actual);
        },
        .Half => {
            const actual =
                (@as(u32, soc.data_memory[wrapped_address + 0]) << 0 |
                    (@as(u32, soc.data_memory[wrapped_address + 1]) << 8));
            try testing.expectEqual(expected_memory_value & 0xFFFF, actual);
        },
        .Byte => {
            const actual = soc.data_memory[wrapped_address];
            try testing.expectEqual(@as(u8, @truncate(expected_memory_value)), actual);
        },
    }
}

fn test_execCB(fn3: u32, rm_value: u32, offset_value: i32, expected_result: u32, statusreg: u8) !void {
    var soc = create_and_init_soc();
    soc.regs[1] = rm_value;
    const instr = (1 << 27) | (offset_value << 10) | (fn3 << 7) | 0b0000011;

    soc.statusreg = statusreg;
    aurosoc.SoC_for_test(&soc, instr);

    try testing.expectEqual(expected_result, soc.pc);
}
// ----------------- 테스트 케이스 -----------------

// Arithmetic

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

// Logic

test "execR: OR, AND, XOR" {
    try test_execR(0b0010, 0b0110, 0b0110, 0b001, 0b0000000, null);
    try test_execR(0b0010, 0b0110, 0b0010, 0b010, 0b0000000, null);
    try test_execR(0b0010, 0b0110, 0b0100, 0b011, 0b0000000, null);
}

// Shift

test "execR: LSL" {
    try test_execR(0b0001, 2, 0b0100, 0b100, 0b0000000, null);
}
test "execR: LSR" {
    try test_execR(0b0100, 2, 0b0001, 0b101, 0b0000000, null);
}
test "execR: ASR" {
    try test_execR(0xFFFF_FF00, 2, 0xFFFFFFC0, 0b101, 0b0000001, null);
}

// CMP

test "execR: cmp equal" {
    try test_cmp(42, 42, true, false, false);
}
test "execR: cmp greater than" {
    try test_cmp(100, 42, false, true, false);
}
test "execR: cmp less than" {
    try test_cmp(10, 42, false, false, true);
}

// Immediate (Arith-logic)

test "execI: add immediate (ADDI)" {
    try test_execI(0, 100, 23, 123);
}
test "execI: add immediate (ORI)" {
    try test_execI(1, 0b1100, 0b0101, 0b1101);
}
test "execI: add immediate (ANDI)" {
    try test_execI(2, 0b1100, 0b0101, 0b0100);
}
test "execI: add immediate (XORI)" {
    try test_execI(3, 0b1100, 0b0101, 0b1001);
}
test "execI: add immediate (LSLI)" {
    try test_execI(4, 0b0011, 2, 0b1100);
}
test "execI: add immediate (LSRI)" {
    try test_execI(5, 0b1100, 2, 0b0011);
}
// Immediate (Load)

test "execI: load word (LW)" {
    try test_execI_load(0, 0x8, .Word, 0x78563412);
}
test "execI: load half (LH)" {
    try test_execI_load(0, 0x10, .Half, 0x7856);
}
test "execI: load byte (LB)" {
    try test_execI_load(0, 0x20, .Byte, 0xAB);
}
test "execI: load word from back" {
    try test_execI_load(0, -100, .Word, 0x78563412);
}
test "execI: load half from back" {
    try test_execI_load(0, -60, .Half, 0x7856);
}
test "execI: load byte from back" {
    try test_execI_load(0, -70, .Byte, 0xAB);
}

// Store

test "execS: store word (SW)" {
    try test_execS_store(10, 0x12345678, .Word, 0x12345678);
}
test "execS: store half (SH)" {
    try test_execS_store(20, 0x5678, .Half, 0x5678);
}
test "execS: store byte (SB)" {
    try test_execS_store(30, 0x78, .Byte, 0x78);
}
test "execS: store word to back" {
    try test_execS_store(-10, 0x12345678, .Word, 0x12345678);
}
test "execS: store half to back" {
    try test_execS_store(-20, 0x5678, .Half, 0x5678);
}
test "execS: store byte to back" {
    try test_execS_store(-30, 0x78, .Byte, 0x78);
}
