const std = @import("std");
const SoC = @import("soc.zig");
const file = @import("file_handling.zig");

const Args = struct {
    program_path: ?[]const u8 = null,
    debug: bool = false,
    dump_mem: bool = false,
    pc_override: ?u32 = null,
};

fn parse_args(allocator: std.mem.Allocator) !Args {
    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    var result = Args{};
    var i: usize = 1;

    while (i < args.len) {
        const arg = args[i];

        if (std.mem.eql(u8, arg, "-p")) {
            if (i + 1 >= args.len) return error.MissingProgramPath;
            result.program_path = args[i + 1];
            i += 2;
        } else if (std.mem.eql(u8, arg, "-d")) {
            result.debug = true;
            i += 1;
        } else if (std.mem.eql(u8, arg, "--dump-mem")) {
            result.dump_mem = true;
            i += 1;
        } else if (std.mem.eql(u8, arg, "--pc")) {
            if (i + 1 >= args.len) return error.MissingPcValue;
            const pc_str = args[i + 1];
            const parsed = std.fmt.parseInt(u32, pc_str, 0) catch {
                std.debug.print("Invalid PC value: {s}\n", .{pc_str});
                return error.InvalidPcValue;
            };
            result.pc_override = parsed;
            i += 2;
        } else {
            std.debug.print("Invalid argument: {s}\n", .{arg});
            return error.InvalidArgument;
        }
    }

    if (result.program_path == null)
        return error.ProgramFileRequired;

    return result;
}

pub fn main() !void {
    const allocator = std.heap.page_allocator;

    // Parse  command line argument
    const args = try parse_args(allocator);

    // SoC init
    var soc_main: SoC.SoC = SoC.SoC_create();
    SoC.SoC_init(&soc_main);

    // Load binary
    try file.load_program(&soc_main, args.program_path.?);

    // PC override (if specified)
    if (args.pc_override) |pc| {
        soc_main.pc = pc;
        std.debug.print("→ PC value is now 0x{x}\n", .{pc});
    }

    // Debug mode
    if (args.debug) {
        std.debug.print("Debug mod enabled.\n", .{});
    }

    // Memory dump
    if (args.dump_mem) {
        std.debug.print("→ Memory dump (data_memory[0..16]):\n", .{});
        for (soc_main.data_memory[0..16], 0..) |b, idx| {
            std.debug.print("{x:02} ", .{b});
            if ((idx + 1) % 8 == 0) std.debug.print("\n", .{});
        }
        std.debug.print("\n", .{});
    }

    // Execute
    SoC.SoC_main(&soc_main);
}
