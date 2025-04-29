const std = @import("std");
const SoC = @import("soc.zig");
const file = @import("file_handling.zig");

const Args = struct {
    program_path: []const u8,
    debug: bool = false,
    mem_dump: bool = false,
};

fn parse_args(allocator: *std.mem.Allocator) ![]const u8 {
    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    const i: usize = 1;
    while (i < args.len) {
        if (std.mem.eql(u8, args[1], "-p")) {
            if (i + 1 >= args.len) {
                std.debug.print("Error: Expected file name after -p\n");
                return error.InvalidArgument;
            }
            return args[i + 1];
        }
    }
}

pub fn main() !void {
    const allocator = std.heap.page_allocator;
    var SoC_main: SoC = SoC.SoC_init();

    const program_path = try parse_args(allocator);
    file.load_program(&SoC_main, program_path);
}
