const std = @import("std");
const cpu = @import("main.zig");

test "execR: ADD" {
    var soc = cpu.SoC{ .regs = [_]u32{0} ** 32, .statusreg = 0, .pc = 0, .instruction_memory = [_]u8{0} ** 16777216, .data_memory = [_]u8{0} ** 16777216 };
    soc.regs[1] = 5;
    soc.regs[2] = 10;
    const instr: u32 = (1 << 27) | (2 << 22) | (3 << 10) | (0 << 15) | (0b000 << 7) | (0b0000000);
    cpu.execR(&soc, instr);
    try std.testing.expectEqual(@as(u32, 15), soc.regs[3]);
}

test "execI: ADDI" {
    var soc = cpu.SoC{ .regs = [_]u32{0} ** 32, .statusreg = 0, .pc = 0, .instruction_memory = [_]u8{0} ** 16777216, .data_memory = [_]u8{0} ** 16777216 };
    soc.regs[1] = 7;
    const instr: u32 = (1 << 27) | (3 << 10) | (5 << 15) | (0b000 << 7) | (0b0000001);
    cpu.execI(&soc, instr);
    try std.testing.expectEqual(@as(u32, 12), soc.regs[3]);
}

test "execS: STW/LDW" {
    var soc = cpu.SoC{ .regs = [_]u32{0} ** 32, .statusreg = 0, .pc = 0, .instruction_memory = [_]u8{0} ** 16777216, .data_memory = [_]u8{0} ** 16777216 };
    soc.regs[1] = 0x01020304;
    const addr = 100;
    const store_instr: u32 = (1 << 22) | (2 << 27) | (addr << 10) | (0b000 << 7) | (0b0000010);
    soc.regs[2] = addr;
    cpu.execS(&soc, store_instr);
    try std.testing.expectEqual(@as(u8, 0x04), soc.data_memory[addr]);
    try std.testing.expectEqual(@as(u8, 0x03), soc.data_memory[addr + 1]);
    try std.testing.expectEqual(@as(u8, 0x02), soc.data_memory[addr + 2]);
    try std.testing.expectEqual(@as(u8, 0x01), soc.data_memory[addr + 3]);
}

test "execCB: BEQ branch taken" {
    var soc = cpu.SoC{ .regs = [_]u32{0} ** 32, .statusreg = cpu.SoC.FLAG_EQ, .pc = 0, .instruction_memory = [_]u8{0} ** 16777216, .data_memory = [_]u8{0} ** 16777216 };
    const imm: u32 = 4;
    const instr: u32 = (0 << 27) | (imm << 10) | (0b000 << 7) | (0b0000011);
    cpu.execCB(&soc, instr);
    try std.testing.expectEqual(@as(u24, 16), soc.pc);
}
