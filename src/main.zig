const std = @import("std");
const sdl = @import("sdl3");
const rom = @import("rom.zig");
const sdl_adapter = @import("sdl_adapter.zig");
const Chip8 = @import("Chip8.zig");
const Renderer = @import("Renderer.zig");
const Input = @import("Input.zig");

const cpu_hz = 700;
const pixel_size = 10;
const window_width = 64 * pixel_size;
const window_height = 32 * pixel_size;

pub fn main(init: std.process.Init) !void {
    const allocator = init.gpa;

    var stderr_buf: [4096]u8 = undefined;
    var stderr = std.Io.File.stderr().writer(init.io, &stderr_buf);

    // cli args
    const args = try init.minimal.args.toSlice(allocator);
    defer allocator.free(args);
    if (args.len <= 1) {
        try stderr.interface.print("Usage: {s} ROM_FILE\n", .{std.fs.path.basename(args[0])});
        try stderr.interface.flush();
        return;
    }

    // get the rom bytes
    const rom_path = args[1];
    const rom_bytes = try rom.getBytes(init.io, allocator, rom_path);
    defer allocator.free(rom_bytes);

    // CPU
    var chip8 = Chip8.init(allocator);
    defer chip8.deinit();
    chip8.copyROM(rom_bytes);

    // renderer
    var renderer = try Renderer.init(window_width, window_height, pixel_size);
    defer renderer.deinit();

    // input
    var input = Input{};

    const ns_per_cycle = 1_000_000_000 / cpu_hz;
    var cpu_accumulator: u64 = 0;
    var prev_time = sdl.SDL_GetTicksNS();

    var done = false;

    while (!done) {
        // Poll events
        var event: sdl.SDL_Event = undefined;
        while (sdl.SDL_PollEvent(&event)) {
            switch (event.type) {
                sdl.SDL_EVENT_QUIT => done = true,
                sdl.SDL_EVENT_JOYSTICK_ADDED, sdl.SDL_EVENT_JOYSTICK_REMOVED, sdl.SDL_EVENT_KEY_DOWN, sdl.SDL_EVENT_JOYSTICK_HAT_MOTION => {
                    switch (input.handleEvent(&event)) {
                        .app_continue => {},
                        .quit => done = true,
                    }
                },
                else => {},
            }
        }

        const now_time = sdl.SDL_GetTicksNS();
        const tick_time = now_time - prev_time;
        prev_time = now_time;
        cpu_accumulator += tick_time;

        while (cpu_accumulator >= ns_per_cycle) {
            switch (try chip8.step()) {
                .display_changed => {
                    std.debug.print("Display changed.\n", .{});
                    try renderer.paint(&chip8.display);
                },
                .ok => {},
            }
            cpu_accumulator -= ns_per_cycle;
        }

        const sleep_ns = ns_per_cycle -| cpu_accumulator;
        sdl.SDL_DelayNS(sleep_ns);
    }
}
