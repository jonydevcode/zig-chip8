const std = @import("std");
const sdl = @import("sdl3");
const rom = @import("rom.zig");
const sdl_adapter = @import("sdl_adapter.zig");
const Input = @import("Input.zig");
const Chip8 = @import("Chip8.zig");
const Renderer = @import("Renderer.zig");
const Audio8 = @import("Audio8.zig");

const cpu_hz = 700;
const timer_hz = 60;
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

    // random
    const seed: u64 = 12345;
    // Uncomment this line to make it truly random:
    // try init.io.randomSecure(std.mem.asBytes(&seed));
    var prng: std.Random.DefaultPrng = .init(seed);
    const rng = prng.random();

    // get the rom bytes
    const rom_path = args[1];
    const rom_bytes = rom.getBytes(init.io, allocator, rom_path) catch |err| switch (err) {
        error.FileNotFound => {
            try stderr.interface.print("File not found: {s}\n", .{std.fs.path.basename(args[1])});
            try stderr.interface.flush();
            return;
        },
        else => return err,
    };
    defer allocator.free(rom_bytes);

    // CPU
    var chip8 = Chip8.init(allocator, rng);
    defer chip8.deinit();
    chip8.copyROM(rom_bytes);

    // renderer
    var renderer = try Renderer.init(window_width, window_height, pixel_size);
    defer renderer.deinit();

    // input
    var input = Input{};

    // audio
    var audio = try Audio8.init();

    const cpu_ns_per_cycle = 1_000_000_000 / cpu_hz;
    const timer_ns_per_cycle = 1_000_000_000 / timer_hz;
    var cpu_accumulator: u64 = 0;
    var timer_accumulator: u64 = 0;
    var prev_time = sdl.SDL_GetTicksNS();

    var done = false;
    var cpu_cycles_count: usize = 0;

    while (!done) {
        // Poll events
        var event: sdl.SDL_Event = undefined;
        while (sdl.SDL_PollEvent(&event)) {
            switch (event.type) {
                sdl.SDL_EVENT_QUIT => done = true,
                sdl.SDL_EVENT_KEY_DOWN, sdl.SDL_EVENT_KEY_UP => {
                    switch (input.handleEvent(&event)) {
                        .reset => {},
                        .quit => done = true,
                        .keypad => |action| {
                            // std.debug.print("Setting key {s}: {s}\n", .{ @tagName(action.key), @tagName(action.state) });
                            chip8.setKey(action.key, action.state);
                        },
                        .none => {},
                    }
                },
                else => {},
            }
        }

        const now_time = sdl.SDL_GetTicksNS();
        const tick_time = now_time - prev_time;
        prev_time = now_time;
        cpu_accumulator += tick_time;
        timer_accumulator += tick_time;

        // Step the CPU
        while (cpu_accumulator >= cpu_ns_per_cycle) {
            switch (try chip8.step()) {
                .display_changed => {
                    // std.debug.print("Display changed.\n", .{});
                    try renderer.paint(&chip8.display);
                },
                .ok => {},
            }
            cpu_cycles_count += 1;
            // if (cpu_cycles_count % 700 == 0) {
            //     std.debug.print("Cpu running...\n", .{});
            // }
            cpu_accumulator -= cpu_ns_per_cycle;
        }

        // Decrement the delay and sound timers
        while (timer_accumulator >= timer_ns_per_cycle) {
            chip8.decrementTimers();

            // TODO: Beep if chip8.isSoundOn()
            if (chip8.isSoundOn()) {
                audio.playBeep();
            } else {
                try audio.stopBeep();
            }

            timer_accumulator -= timer_ns_per_cycle;
        }

        try audio.tick();

        // if (cpu_cycles_count > 39) break;

        const sleep_ns = cpu_ns_per_cycle -| cpu_accumulator;
        sdl.SDL_DelayNS(sleep_ns);
    }
}
