const Self = @This();
const std = @import("std");
const sdl_adapter = @import("sdl_adapter.zig");
const font = @import("font.zig");
const sdl = @import("sdl");
const SdlGpu = @import("SdlGpu.zig");
const expect = std.testing.expect;
const expectEqual = std.testing.expectEqual;

window: *sdl.SDL_Window,
renderer: *sdl.SDL_Renderer,
pixel_size: usize,
frame_width: usize,
frame_height: usize,

pub fn init(
    comptime window_width: usize,
    comptime window_height: usize,
    comptime pixel_size: usize,
    comptime frame_width: usize,
    comptime frame_height: usize,
) !Self {
    try sdl_adapter.setAppMetadata("CHIP-8 Emulator", "0.1.0", "jonydevcode.chip8");

    try sdl_adapter.SDL_Init(sdl.SDL_INIT_VIDEO | sdl.SDL_INIT_AUDIO);

    std.debug.print(
        "video driver: {s}\n",
        .{sdl.SDL_GetCurrentVideoDriver() orelse @as([*c]const u8, "null")},
    );

    // Create a window and renderer
    var window: *sdl.SDL_Window = undefined;
    var renderer: *sdl.SDL_Renderer = undefined;
    std.debug.print("Creating window of size WxH: {} x {}\n", .{ window_width, window_height });
    const window_and_renderer = try sdl_adapter.createWindowAndRenderer(
        "CHIP-8 Emulator (@jonydevcode)",
        window_width,
        window_height,
        sdl.SDL_WINDOW_RESIZABLE | sdl.SDL_WINDOW_HIGH_PIXEL_DENSITY,
    );
    window = window_and_renderer.window;
    renderer = window_and_renderer.renderer;

    try sdl_adapter.setRenderLogicalPresentation(
        renderer,
        window_width,
        window_height,
        sdl.SDL_LOGICAL_PRESENTATION_LETTERBOX,
    );

    return Self{
        .renderer = renderer,
        .window = window,
        .pixel_size = pixel_size,
        .frame_width = frame_width,
        .frame_height = frame_height,
    };
}

pub fn deinit(self: *Self) void {
    sdl.SDL_DestroyWindow(self.window);
    sdl.SDL_DestroyRenderer(self.renderer);
    sdl.SDL_Quit();
}

fn toDevice(self: *Self, v: usize) usize {
    return v * self.pixel_size;
}

pub fn paint(self: *Self, pixels: []const bool) !void {
    std.debug.assert(pixels.len == self.frame_width * self.frame_height);
    for (0..self.frame_height) |y| {
        for (0..self.frame_width) |x| {
            const pixel = pixels[y * self.frame_width + x];
            switch (pixel) {
                true => try sdl_adapter.setRenderDrawColor(self.renderer, 255, 255, 255, sdl.SDL_ALPHA_OPAQUE),
                false => try sdl_adapter.setRenderDrawColor(self.renderer, 0, 0, 0, sdl.SDL_ALPHA_OPAQUE),
            }
            var rect = sdl.SDL_FRect{
                .x = @as(f32, @floatFromInt(self.toDevice(x))),
                .y = @as(f32, @floatFromInt(self.toDevice(y))),
                .w = @as(f32, @floatFromInt(self.pixel_size)),
                .h = @as(f32, @floatFromInt(self.pixel_size)),
            };
            try sdl_adapter.renderFillRect(self.renderer, &rect);
        }
    }
    try sdl_adapter.renderPresent(self.renderer);
}
