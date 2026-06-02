//! This file is thus named because of some stupid bug in ZLS that prevents me from
//! seeing the autocomplete for sdl when it's named Audio.zig.
const Self = @This();
const std = @import("std");
const sdl = @import("sdl");
const sdlx = @import("sdlx.zig");
const font = @import("font.zig");
const SdlError = sdlx.SdlError;

const audio_channels = 1; // DO NOT CHANGE THIS
const audio_sample_rate = 48000;

const tone_hz: f32 = 440;
const tone_amplitude: f32 = 0.1;
const target_queue_ms = 100;
const chunk_ms = 10;

stream: *sdl.SDL_AudioStream,
phase: f32 = 0,
is_playing: bool = false,

pub fn init() !Self {
    const spec: sdl.SDL_AudioSpec = .{
        .channels = audio_channels,
        .format = sdl.SDL_AUDIO_F32,
        .freq = audio_sample_rate,
    };
    const stream = sdl.SDL_OpenAudioDeviceStream(
        sdl.SDL_AUDIO_DEVICE_DEFAULT_PLAYBACK,
        &spec,
        null,
        null,
    ) orelse return SdlError.SdlFailure;
    try sdlx.check("SDL_ResumeAudioStreamDevice", sdl.SDL_ResumeAudioStreamDevice(stream));
    return .{
        .stream = stream,
    };
}

/// Mono sine wave
fn generateSine(self: *Self, buf: []f32) void {
    const phase_step: f32 = (2.0 * std.math.pi * tone_hz) / @as(f32, @floatFromInt(audio_sample_rate));

    for (0..buf.len) |i| {
        const sample = @sin(self.phase) * tone_amplitude;
        buf[i] = sample;
        self.phase += phase_step;

        if (self.phase >= 2.0 * std.math.pi) {
            self.phase -= 2.0 * std.math.pi;
        }
    }
}

pub fn tick(self: *Self) !void {
    if (!self.is_playing) return;

    const queued = sdl.SDL_GetAudioStreamQueued(self.stream);

    const frames = (audio_sample_rate * target_queue_ms) / 1000;
    const target_bytes = frames * @sizeOf(f32);

    if (queued >= target_bytes) return;

    const chunk_frames = audio_sample_rate * chunk_ms / 1000;
    const chunk_samples = chunk_frames;
    const chunk_bytes = chunk_samples * @sizeOf(f32);

    var buf: [chunk_frames]f32 = undefined;
    self.generateSine(&buf);

    try sdlx.check("SDL_PutAudioStreamData", sdl.SDL_PutAudioStreamData(
        self.stream,
        &buf,
        chunk_bytes,
    ));
}

pub fn playBeep(self: *Self) void {
    self.is_playing = true;
}

pub fn stopBeep(self: *Self) !void {
    self.is_playing = false;
    try sdlx.check("SDL_ClearAudioStream", sdl.SDL_ClearAudioStream(self.stream));
}
