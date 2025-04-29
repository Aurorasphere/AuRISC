const std = @import("std");
const fs = @import("std.fs");
const SoC = @import("soc.zig");

fn formatSize(size: usize) [32]u8 {
    var buffer: [32]u8 = undefined;
    const size_f = @as(f64, @floatFromInt(size));

    if (size < 1024) {
        _ = std.fmt.bufPrint(&buffer, "{d} B", .{size}) catch {};
    } else if (size < 1024 * 1024) {
        _ = std.fmt.bufPrint(&buffer, "{.2} KB", .{size_f / 1024.0}) catch {};
    } else if (size < 1024 * 1024 * 1024) {
        _ = std.fmt.bufPrint(&buffer, "{.2} MB", .{size_f / 1048576.0}) catch {};
    } else {
        _ = std.fmt.bufPrint(&buffer, "{.2} GB", .{size_f / 1073741824.0}) catch {};
    }

    return buffer;
}

pub fn load_program(soc: *SoC, path: []const u8) !void {
    var file = try std.fs.cwd().openFile(path, .{});
    defer file.close();

    const file_size = (try file.stat()).size;
    if (file_size > soc.IM_SIZE) return error.FileTooLarge;

    const bytes_read = try file.readAll(soc.instruction_memory[0..file_size]);
    if (bytes_read != file_size) return error.UnexpectedEof;

    const stdout = std.io.getStdOut().writer();
    const size_str = formatSize(bytes_read);
    try stdout.print("Program loaded. Total program size: {s}.\n", .{size_str});
}
