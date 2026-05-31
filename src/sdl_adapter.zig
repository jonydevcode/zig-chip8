//! Lightweight adapter layer between Zig code and SDL3 function calls.
//! The sole purpose of this layer is to normalise the error model,
//! translating between SDL's return false + SDL_GetError() convention and Zig's !T model.
const std = @import("std");
const sdl = @import("sdl3");

pub const SdlError = error{
    SdlFailure,
};

/// Utility to help make good use of SDL_GetError()
fn check(comptime name: []const u8, ok: bool) SdlError!void {
    if (!ok) {
        std.log.err("{s} failed: {s}", .{ name, std.mem.span(sdl.SDL_GetError()) });
        return error.SdlFailure;
    }
}

/// Breaking the fn naming convention to avoid confusion with the typical Zig init() fn.
pub fn SDL_Init(flags: u32) SdlError!void {
    try check("SDL_Init", sdl.SDL_Init(flags));
}

pub fn setAppMetadata(
    appname: [:0]const u8,
    appversion: [:0]const u8,
    appidentifier: [:0]const u8,
) SdlError!void {
    try check("SDL_SetAppMetadata", sdl.SDL_SetAppMetadata(
        appname.ptr,
        appversion.ptr,
        appidentifier.ptr,
    ));
}

pub const WindowAndRenderer = struct {
    window: *sdl.SDL_Window,
    renderer: *sdl.SDL_Renderer,
};

/// Slight modification of the function signature so that if window or renderer
/// or null, then consider it a failure.
pub fn createWindowAndRenderer(
    title: [:0]const u8,
    width: c_int,
    height: c_int,
    window_flags: u64,
) SdlError!WindowAndRenderer {
    var window: ?*sdl.SDL_Window = null;
    var renderer: ?*sdl.SDL_Renderer = null;

    try check("SDL_CreateWindowAndRenderer", sdl.SDL_CreateWindowAndRenderer(
        title.ptr,
        width,
        height,
        window_flags,
        &window,
        &renderer,
    ));

    return .{
        .window = window orelse return error.SdlFailure,
        .renderer = renderer orelse return error.SdlFailure,
    };
}

pub fn setRenderLogicalPresentation(
    renderer: *sdl.SDL_Renderer,
    w: c_int,
    h: c_int,
    mode: c_uint,
) SdlError!void {
    try check("SDL_SetRenderLogicalPresentation", sdl.SDL_SetRenderLogicalPresentation(
        renderer,
        w,
        h,
        mode,
    ));
}

pub fn setRenderDrawColor(
    renderer: *sdl.SDL_Renderer,
    r: u8,
    g: u8,
    b: u8,
    a: u8,
) SdlError!void {
    try check("SDL_SetRenderDrawColor", sdl.SDL_SetRenderDrawColor(renderer, r, g, b, a));
}

pub fn renderClear(renderer: *sdl.SDL_Renderer) SdlError!void {
    try check("SDL_RenderClear", sdl.SDL_RenderClear(renderer));
}

pub fn renderFillRect(
    renderer: *sdl.SDL_Renderer,
    rect: *sdl.SDL_FRect,
) SdlError!void {
    try check("SDL_RenderFillRect", sdl.SDL_RenderFillRect(renderer, rect));
}

pub fn renderPresent(renderer: *sdl.SDL_Renderer) SdlError!void {
    try check("SDL_RenderPresent", sdl.SDL_RenderPresent(renderer));
}
