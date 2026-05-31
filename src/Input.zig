const Self = @This();
const std = @import("std");
const Chip8 = @import("Chip8.zig");
const sdl = @import("sdl3");

joystick: ?*sdl.SDL_Joystick = null,

const EventResult = enum {
    app_continue,
    quit,
};

pub fn handleEvent(self: *Self, event: *sdl.SDL_Event) EventResult {
    switch (event.type) {
        sdl.SDL_EVENT_JOYSTICK_ADDED => {
            if (self.joystick == null) {
                self.joystick = sdl.SDL_OpenJoystick(event.jdevice.which);
                if (self.joystick == null) {
                    std.debug.print("Failed to open joystick ID {d}: {s}\n", .{
                        event.jdevice.which,
                        std.mem.span(sdl.SDL_GetError()),
                    });
                }
            }
        },
        sdl.SDL_EVENT_JOYSTICK_REMOVED => {
            if (self.joystick) |stick| {
                if (sdl.SDL_GetJoystickID(stick) == event.jdevice.which) {
                    sdl.SDL_CloseJoystick(self.joystick);
                    self.joystick = null;
                }
            }
        },
        sdl.SDL_EVENT_KEY_DOWN => {
            return self.handleKeyEvent(event.key.scancode);
        },
        sdl.SDL_EVENT_JOYSTICK_HAT_MOTION => {
            return self.handleHatEvent(event.jhat.value);
        },
        else => {},
    }
    return .app_continue;
}

pub fn handleKeyEvent(self: *Self, key_code: sdl.SDL_Scancode) EventResult {
    _ = self;
    switch (key_code) {
        // quit
        sdl.SDL_SCANCODE_ESCAPE, sdl.SDL_SCANCODE_Q => {
            return .quit;
        },
        // restart the game as if the program was launched
        // sdl.SDL_SCANCODE_R => {
        //     game.reset();
        // },
        // decide new direction of the snake
        // sdl.SDL_SCANCODE_RIGHT => game.setDirection(.right),
        // sdl.SDL_SCANCODE_UP => game.setDirection(.up),
        // sdl.SDL_SCANCODE_LEFT => game.setDirection(.left),
        // sdl.SDL_SCANCODE_DOWN => game.setDirection(.down),
        else => {},
    }
    return .app_continue;
}

pub fn handleHatEvent(self: *Self, hat: u8) EventResult {
    _ = self;
    switch (hat) {
        sdl.SDL_HAT_RIGHT => {},
        sdl.SDL_HAT_UP => {},
        sdl.SDL_HAT_LEFT => {},
        sdl.SDL_HAT_DOWN => {},
        else => {},
    }

    return .app_continue;
}
