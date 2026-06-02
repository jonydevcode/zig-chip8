const std = @import("std");
const sdl = @import("sdl");
const Keypad = @import("Keypad.zig");

const Self = @This();

pub const InputResult = union(enum) {
    none,
    quit,
    reset,
    keypad: KeypadAction,
};

pub const KeypadAction = struct {
    key: Keypad.Key,
    state: Keypad.KeyState,
};

pub fn handleEvent(self: *Self, event: *sdl.SDL_Event) InputResult {
    switch (event.type) {
        sdl.SDL_EVENT_KEY_DOWN => {
            return self.handleKeyEvent(event.key.scancode, .down);
        },
        sdl.SDL_EVENT_KEY_UP => {
            return self.handleKeyEvent(event.key.scancode, .up);
        },
        else => {},
    }
    return .none;
}

pub fn handleKeyEvent(self: *Self, key_code: sdl.SDL_Scancode, state: Keypad.KeyState) InputResult {
    _ = self;
    switch (key_code) {
        // quit
        sdl.SDL_SCANCODE_ESCAPE => {
            return .quit;
        },
        sdl.SDL_SCANCODE_1 => {
            return .{ .keypad = .{ .key = Keypad.Key.key_1, .state = state } };
        },
        sdl.SDL_SCANCODE_2 => {
            return .{ .keypad = .{ .key = Keypad.Key.key_2, .state = state } };
        },
        sdl.SDL_SCANCODE_3 => {
            return .{ .keypad = .{ .key = Keypad.Key.key_3, .state = state } };
        },
        sdl.SDL_SCANCODE_4 => {
            return .{ .keypad = .{ .key = Keypad.Key.key_c, .state = state } };
        },
        sdl.SDL_SCANCODE_Q => {
            return .{ .keypad = .{ .key = Keypad.Key.key_4, .state = state } };
        },
        sdl.SDL_SCANCODE_W => {
            return .{ .keypad = .{ .key = Keypad.Key.key_5, .state = state } };
        },
        sdl.SDL_SCANCODE_E => {
            return .{ .keypad = .{ .key = Keypad.Key.key_6, .state = state } };
        },
        sdl.SDL_SCANCODE_R => {
            return .{ .keypad = .{ .key = Keypad.Key.key_d, .state = state } };
        },
        sdl.SDL_SCANCODE_A => {
            return .{ .keypad = .{ .key = Keypad.Key.key_7, .state = state } };
        },
        sdl.SDL_SCANCODE_S => {
            return .{ .keypad = .{ .key = Keypad.Key.key_8, .state = state } };
        },
        sdl.SDL_SCANCODE_D => {
            return .{ .keypad = .{ .key = Keypad.Key.key_9, .state = state } };
        },
        sdl.SDL_SCANCODE_F => {
            return .{ .keypad = .{ .key = Keypad.Key.key_e, .state = state } };
        },
        sdl.SDL_SCANCODE_Z => {
            return .{ .keypad = .{ .key = Keypad.Key.key_a, .state = state } };
        },
        sdl.SDL_SCANCODE_X => {
            return .{ .keypad = .{ .key = Keypad.Key.key_0, .state = state } };
        },
        sdl.SDL_SCANCODE_C => {
            return .{ .keypad = .{ .key = Keypad.Key.key_b, .state = state } };
        },
        sdl.SDL_SCANCODE_V => {
            return .{ .keypad = .{ .key = Keypad.Key.key_f, .state = state } };
        },
        sdl.SDL_SCANCODE_BACKSPACE => {
            return .reset;
        },
        else => {},
    }
    return .none;
}
