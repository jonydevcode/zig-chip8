const std = @import("std");
const sdl = @import("sdl");
const rom = @import("rom.zig");
const sdl_adapter = @import("sdl_adapter.zig");
const Input = @import("Input.zig");
const Chip8 = @import("Chip8.zig");
const Renderer = @import("Renderer.zig");
const Renderer3D = @import("Renderer3D.zig");
const Audio8 = @import("Audio8.zig");
const SdlGpu = @import("SdlGpu.zig");
const RGBA = SdlGpu.RGBA;

const cpu_hz = 700;
const timer_hz = 60;
const pixel_size = 10;
const window_width = Chip8.display_width * pixel_size;
const window_height = Chip8.display_height * pixel_size;
const target_fps = 60;

const PerformanceMetrics = struct {
    cycles: usize = 0,
    poll_ns: u64 = 0,
    cpu_step_ns: u64 = 0,
    renderer_ns: u64 = 0,
    timers_ns: u64 = 0,
    audio_tick_ns: u64 = 0,
    start_ns: u64 = 0,

    fn start(self: *PerformanceMetrics) void {
        self.start_ns = sdl.SDL_GetTicksNS();
    }

    fn lap(self: *PerformanceMetrics) u64 {
        const old_start = self.start_ns;
        self.start_ns = sdl.SDL_GetTicksNS();
        return self.start_ns - old_start;
    }
};

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
    // var renderer = try Renderer.init(
    //     window_width,
    //     window_height,
    //     pixel_size,
    //     Chip8.display_width,
    //     Chip8.display_height,
    // );
    // defer renderer.deinit();
    var frame_buf = [_]RGBA{Renderer3D.black} ** (Chip8.display_height * Chip8.display_width);
    var renderer = try Renderer3D.init(
        window_width,
        window_height,
        pixel_size,
        Chip8.display_width,
        Chip8.display_height,
        &frame_buf,
    );
    defer renderer.deinit();

    // input
    var input = Input{};

    // audio
    var audio = try Audio8.init();

    const cpu_ns_per_cycle = 1_000_000_000 / cpu_hz;
    const timer_ns_per_cycle = 1_000_000_000 / timer_hz;
    const fps_ns_per_cycle = 1_000_000_000 / target_fps;
    var cpu_accumulator: u64 = 0;
    var timer_accumulator: u64 = 0;
    var fps_accumulator: u64 = 0;
    var prev_time = sdl.SDL_GetTicksNS();
    var display_changed = false;

    var done = false;
    var cpu_cycles_count: usize = 0;

    var perf = PerformanceMetrics{};

    while (!done) {
        perf.start();

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
                            chip8.setKey(action.key, action.state);
                        },
                        .none => {},
                    }
                },
                else => {},
            }
        }

        perf.poll_ns += perf.lap();

        const now_time = sdl.SDL_GetTicksNS();
        const tick_time = now_time - prev_time;
        prev_time = now_time;
        cpu_accumulator += tick_time;
        timer_accumulator += tick_time;
        fps_accumulator += tick_time;

        // Step the CPU
        while (cpu_accumulator >= cpu_ns_per_cycle) {
            const step_result = try chip8.step();
            perf.cpu_step_ns += perf.lap();
            switch (step_result) {
                .display_changed => {
                    display_changed = true;
                    // try renderer.paint(&chip8.display);
                    // perf.renderer_ns += perf.lap();
                },
                .ok => {},
            }
            cpu_cycles_count += 1;
            cpu_accumulator -= cpu_ns_per_cycle;
        }

        // Decrement the delay and sound timers
        while (timer_accumulator >= timer_ns_per_cycle) {
            chip8.decrementTimers();

            if (chip8.isSoundOn()) {
                audio.playBeep();
            } else {
                try audio.stopBeep();
            }

            timer_accumulator -= timer_ns_per_cycle;
        }

        // Present the screen at the target fps
        while (fps_accumulator >= fps_ns_per_cycle) {
            if (display_changed) {
                try renderer.paint(&chip8.display);
                display_changed = false;
                perf.renderer_ns += perf.lap();
            }

            // at most one paint per cycle
            fps_accumulator %= fps_ns_per_cycle;
        }

        perf.timers_ns += perf.lap();

        try audio.tick();

        perf.audio_tick_ns += perf.lap();

        perf.cycles += 1;

        const sleep_ns = cpu_ns_per_cycle -| cpu_accumulator;
        sdl.SDL_DelayNS(sleep_ns);
    }

    // print performance metrics
    std.debug.print("Per cycle performance metrics in ns\n", .{});
    std.debug.print("Cycles:     {d}\n", .{perf.cycles});
    std.debug.print("PollEvent:  {d}\n", .{perf.poll_ns / perf.cycles});
    std.debug.print("CPU step:   {d}\n", .{perf.cpu_step_ns / perf.cycles});
    std.debug.print("Renderer:   {d}\n", .{perf.renderer_ns / perf.cycles});
    std.debug.print("Timers:     {d}\n", .{perf.timers_ns / perf.cycles});
    std.debug.print("Audio tick: {d}\n", .{perf.audio_tick_ns / perf.cycles});
}
