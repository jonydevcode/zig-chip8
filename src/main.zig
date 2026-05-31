const std = @import("std");
const sdl = @import("sdl3");
const sdl_adapter = @import("sdl_adapter.zig");

pub fn main(init: std.process.Init) !void {
    _ = init;

    std.debug.print("Hello world!", .{});
}
