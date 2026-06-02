const Self = @This();
const std = @import("std");
const sdl_adapter = @import("sdl_adapter.zig");
const font = @import("font.zig");
const sdl = @import("sdl");
const SdlGpu = @import("SdlGpu.zig");
const RGBA = SdlGpu.RGBA;
const expect = std.testing.expect;
const expectEqual = std.testing.expectEqual;

window: *sdl.SDL_Window,
// renderer: *sdl.SDL_Renderer,
pixel_size: usize,
frame_width: usize,
frame_height: usize,
frame_buf: []RGBA,
sdlgpu: SdlGpu,

pub fn init(
    comptime window_width: usize,
    comptime window_height: usize,
    comptime pixel_size: usize,
    comptime frame_width: usize,
    comptime frame_height: usize,
    frame_buf: *[frame_width * frame_height]RGBA,
) !Self {
    try sdl_adapter.setAppMetadata("CHIP-8 Emulator", "0.1.0", "jonydevcode.chip8");

    try sdl_adapter.SDL_Init(sdl.SDL_INIT_VIDEO | sdl.SDL_INIT_AUDIO);

    std.debug.print(
        "video driver: {s}\n",
        .{sdl.SDL_GetCurrentVideoDriver() orelse @as([*c]const u8, "null")},
    );

    // Create a window and renderer
    // var window: *sdl.SDL_Window = undefined;
    // var renderer: *sdl.SDL_Renderer = undefined;
    // std.debug.print("Creating window of size WxH: {} x {}\n", .{ window_width, window_height });
    // const window_and_renderer = try sdl_adapter.createWindowAndRenderer(
    //     "CHIP-8 Emulator (@jonydevcode)",
    //     window_width,
    //     window_height,
    //     sdl.SDL_WINDOW_RESIZABLE | sdl.SDL_WINDOW_HIGH_PIXEL_DENSITY,
    // );
    // window = window_and_renderer.window;
    // renderer = window_and_renderer.renderer;
    const window = sdl.SDL_CreateWindow(
        "CHIP-8 Emulator (@jonydevcode)",
        window_width,
        window_height,
        sdl.SDL_WINDOW_RESIZABLE | sdl.SDL_WINDOW_HIGH_PIXEL_DENSITY,
    ) orelse return error.SdlError;

    // try sdl_adapter.setRenderLogicalPresentation(
    //     renderer,
    //     window_width,
    //     window_height,
    //     sdl.SDL_LOGICAL_PRESENTATION_LETTERBOX,
    // );

    // var frame_buf = [_]RGBA{black} ** (frame_height * frame_width);
    const sdlgpu = try SdlGpu.init(window, frame_width, frame_height, frame_buf[0..]);

    return Self{
        // .renderer = renderer,
        .window = window,
        .pixel_size = pixel_size,
        .frame_width = frame_width,
        .frame_height = frame_height,
        .sdlgpu = sdlgpu,
        .frame_buf = frame_buf,
    };
}

pub fn deinit(self: *Self) void {
    self.sdlgpu.deinit();
    sdl.SDL_DestroyWindow(self.window);
    // sdl.SDL_DestroyRenderer(self.renderer);
    sdl.SDL_Quit();
}

fn toDevice(self: *Self, v: usize) usize {
    return v * self.pixel_size;
}

pub const black = RGBA{ .r = 0, .g = 0, .b = 0, .a = 0 };
pub const white = RGBA{ .r = 255, .g = 255, .b = 255, .a = 255 };

fn buildRGBAFrame(source_screen: []const bool, dest_frame: []RGBA) void {
    for (source_screen, 0..) |p, i| {
        const color = if (p) white else black;
        dest_frame[i] = color;
    }
}

pub fn paint(self: *Self, source_display: []const bool) !void {
    // convert the bool array to RGBA array
    buildRGBAFrame(source_display, self.frame_buf);
    self.sdlgpu.markFramebufferDirty();
    try self.sdlgpu.present();
}
