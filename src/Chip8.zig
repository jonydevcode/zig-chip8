const Self = @This();
const std = @import("std");
const font = @import("font.zig");
const Keypad = @import("Keypad.zig");
const expect = std.testing.expect;
const expectEqual = std.testing.expectEqual;

const ram_size = 4096;
const reg_v_count = 16;
const font_start = 0x50;
const pc_start = 0x200;
const display_width = 64;
const display_height = 32;

allocator: std.mem.Allocator,

// CHIP-8 components
memory: [ram_size]u8,
pc: u16,
reg_i: u16,
// push = append(), peek top = getLast(), pop = pop()
stack: std.ArrayList(u16),
delay_timer: u8,
sound_timer: u8,
// V0 to VF, and VF is flag register
reg_v: [reg_v_count]u8,
display: [display_height * display_width]bool,
rng: std.Random,
keypad: Keypad,
fx0a_getkey: GetKeyPressState,
// last_unprocessed_keydown: ?Keypad.Key = null,

// STATIC

fn concatBigEndian(comptime T: type, nibbles: []const u4) T {
    var result: T = 0;
    for (nibbles) |nibble| {
        result = (result << 4) | nibble;
    }
    return result;
}

// NON-PUBLIC

const GetKeyPressState = struct {
    in_fx0a: bool = false,
    key: ?Keypad.Key = null,
    hasDown: bool = false,
    hasUp: bool = false,
};

const InstructionLayout = packed struct(u16) {
    // this order is because @bitCast assigns them from LSB to MSB
    nibble4: u4,
    nibble3: u4,
    nibble2: u4,
    nibble1: u4,
};

fn clearDisplay(self: *Self) void {
    self.display = .{false} ** (display_height * display_width);
}

// PUBLIC

pub const Chip8Error = error{PopEmptyStack};

pub const StepResult = enum {
    display_changed,
    ok,
};

/// Copies the font to the memory
pub fn init(allocator: std.mem.Allocator, rng: std.Random) Self {
    var chip8 = Self{
        .allocator = allocator,
        .memory = [_]u8{0} ** ram_size,
        .pc = pc_start,
        .reg_i = 0,
        .stack = .empty,
        .delay_timer = 0,
        .sound_timer = 0,
        .reg_v = [_]u8{0} ** reg_v_count,
        .display = .{false} ** (display_height * display_width),
        .rng = rng,
        .keypad = .init(),
        .fx0a_getkey = .{},
    };
    font.copyFontToMemory(&chip8.memory, font_start);
    return chip8;
}

pub fn deinit(self: *Self) void {
    self.stack.deinit(self.allocator);
    self.* = undefined;
}

pub fn copyROM(self: *Self, rom: []const u8) void {
    std.debug.assert(pc_start + rom.len <= self.memory.len);
    @memcpy(self.memory[pc_start .. pc_start + rom.len], rom);
}

pub fn getPixel(self: *Self, x: usize, y: usize) bool {
    std.debug.assert(0 <= x and x < display_width);
    std.debug.assert(0 <= y and y < display_width);
    return self.display[y * display_width + x];
}

pub fn setPixel(self: *Self, x: usize, y: usize, val: bool) void {
    std.debug.assert(0 <= x and x < display_width);
    std.debug.assert(0 <= y and y < display_width);
    self.display[y * display_width + x] = val;
}

/// Reduces the delay and sound timer registers by 1
pub fn decrementTimers(self: *Self) void {
    self.delay_timer -|= 1;
    self.sound_timer -|= 1;
}

/// Checks if the sound is on
pub fn isSoundOn(self: *Self) bool {
    return self.sound_timer > 0;
}

pub fn setKey(self: *Self, key: Keypad.Key, state: Keypad.KeyState) void {
    self.keypad.putState(key, state);

    if (self.fx0a_getkey.in_fx0a) {
        // first key?
        if (self.fx0a_getkey.key == null) {
            if (state == .down) {
                self.fx0a_getkey.key = key;
                self.fx0a_getkey.hasDown = true;
            } // ignore if state is .up
        } else {
            if (state == .up) {
                self.fx0a_getkey.hasUp = true;
            }
        }
    }
}

pub fn step(self: *Self) !StepResult {
    const instruction = std.mem.readInt(u16, self.memory[self.pc..][0..2], .big);
    self.pc += 2;
    const layout: InstructionLayout = @bitCast(instruction);
    // std.debug.print("{X}\n", .{instruction});

    switch (layout.nibble1) {
        0x0 => {
            if (instruction == 0x00E0) {
                self.clearDisplay();
                std.debug.print("Cleared display.\n", .{});
                return .display_changed;
            } else if (instruction == 0x00EE) {
                // Returns from a subroutine
                const last_address = self.stack.pop() orelse return error.PopEmptyStack;
                self.pc = last_address;
            }
        },
        0x1 => {
            // 1NNN: Jump to NNN
            const new_pc = concatBigEndian(u12, &[_]u4{ layout.nibble2, layout.nibble3, layout.nibble4 });
            self.pc = new_pc;
        },
        0x2 => {
            // 2NNN: calls the subroutine at memory location NNN
            const new_pc = concatBigEndian(u12, &[_]u4{ layout.nibble2, layout.nibble3, layout.nibble4 });
            try self.stack.append(self.allocator, self.pc);
            self.pc = new_pc;
        },
        0x3 => {
            // 3XNN will skip one instruction if the value in VX is equal to NN
            const other_val = concatBigEndian(u8, &[_]u4{ layout.nibble3, layout.nibble4 });
            if (self.reg_v[layout.nibble2] == other_val) {
                self.pc += 2;
            }
        },
        0x4 => {
            // 4XNN will skip one instruction if the value in VX is NOT equal to NN
            const other_val = concatBigEndian(u8, &[_]u4{ layout.nibble3, layout.nibble4 });
            if (self.reg_v[layout.nibble2] != other_val) {
                self.pc += 2;
            }
        },
        0x5 => {
            // 5XY0 skips if the values in VX and VY are equal
            const reg_val1 = self.reg_v[layout.nibble2];
            const reg_val2 = self.reg_v[layout.nibble3];
            if (reg_val1 == reg_val2) {
                self.pc += 2;
            }
        },
        0x6 => {
            // 6XNN: set the register VX to the value NN
            self.reg_v[layout.nibble2] = concatBigEndian(u8, &[_]u4{ layout.nibble3, layout.nibble4 });
        },
        0x7 => {
            // 7XNN: Add the value NN to VX.
            const op_val = concatBigEndian(u8, &[_]u4{ layout.nibble3, layout.nibble4 });
            self.reg_v[layout.nibble2] +%= op_val;
        },
        0x8 => {
            const x = layout.nibble2;
            const y = layout.nibble3;
            switch (layout.nibble4) {
                0x0 => self.reg_v[x] = self.reg_v[y],
                0x1 => self.reg_v[x] |= self.reg_v[y],
                0x2 => self.reg_v[x] &= self.reg_v[y],
                0x3 => self.reg_v[x] ^= self.reg_v[y],
                0x4 => {
                    const ov = @addWithOverflow(self.reg_v[x], self.reg_v[y]);
                    self.reg_v[x] = ov[0];
                    self.reg_v[0xF] = ov[1];
                },
                0x5 => {
                    const ov = @subWithOverflow(self.reg_v[x], self.reg_v[y]);
                    self.reg_v[x] = ov[0];
                    self.reg_v[0xF] = if (ov[1] == 1) 0 else 1;
                },
                0x6 => { // right shift
                    // AMBIGUOUS: (Optional, or configurable step) Set VX to the value of VY
                    const out_bit = self.reg_v[x] & 1;
                    self.reg_v[x] >>= 1;
                    self.reg_v[0xF] = out_bit;
                },
                0x7 => {
                    const ov = @subWithOverflow(self.reg_v[y], self.reg_v[x]);
                    self.reg_v[x] = ov[0];
                    self.reg_v[0xF] = if (ov[1] == 1) 0 else 1;
                },
                // 0x8 => {},
                // 0x9 => {},
                // 0xA => {},
                // 0xB => {},
                // 0xC => {},
                // 0xD => {},
                0xE => { // left shift
                    // AMBIGUOUS: (Optional, or configurable step) Set VX to the value of VY
                    // self.reg_v[x] = self.reg_v[y];
                    const out_bit: u1 = if ((self.reg_v[x] & (1 << 7)) == 0) 0 else 1;
                    self.reg_v[x] <<= 1;
                    self.reg_v[0xF] = out_bit;
                },
                // 0xF => {},
                else => std.debug.panic("Op code not implemented: {X}\n", .{instruction}),
            }
        },
        0x9 => {
            // 9XY0 skips if the values in VX and VY are NOT equal
            const reg_val1 = self.reg_v[layout.nibble2];
            const reg_val2 = self.reg_v[layout.nibble3];
            if (reg_val1 != reg_val2) {
                self.pc += 2;
            }
        },
        0xA => {
            // ANNN sets the index register I to the value NNN
            const op_val = concatBigEndian(u12, &[_]u4{ layout.nibble2, layout.nibble3, layout.nibble4 });
            self.reg_i = op_val;
        },
        0xB => {
            // AMBIGUOUS
            // jumped to the address NNN plus the value in the register V0
            const addr = concatBigEndian(u12, &[_]u4{ layout.nibble2, layout.nibble3, layout.nibble4 });
            const offset = self.reg_v[0];
            self.pc = addr + offset;
        },
        0xC => {
            // generates a random number, binary ANDs it with the value NN, and puts the result in VX
            const mask = concatBigEndian(u8, &[_]u4{ layout.nibble3, layout.nibble4 });
            self.reg_v[layout.nibble2] = self.rng.int(u8) & mask;
        },
        0xD => {
            // DXYN: Display, draw N pixels from mem[I] at (reg[X], reg[Y]), using xor
            const start_x = @mod(self.reg_v[layout.nibble2], display_width);
            const start_y = @mod(self.reg_v[layout.nibble3], display_width);
            const N = layout.nibble4;

            // collision flag
            self.reg_v[0xF] = 0;

            std.debug.assert(self.reg_i +| N <= ram_size);
            // const sprite_byte = self.reg_v[self.reg_i];
            for (self.memory[self.reg_i .. self.reg_i + N], 0..) |byte, i| {
                // std.debug.print("start_y = {d}, i = {d}\n", .{ start_y, i });
                const y = start_y + i;
                if (y >= display_height) break;
                for (0..8) |j| {
                    // MSB to LSB
                    const x = start_x + j;
                    if (x >= display_width) continue;
                    const mask = @as(u8, 1) << @intCast(7 - j);
                    const bit = byte & mask != 0;
                    // do the xor
                    if (bit and self.getPixel(x, y)) {
                        self.setPixel(x, y, false);
                        self.reg_v[0xF] = 1;
                    } else if (bit and !self.getPixel(x, y)) {
                        self.setPixel(x, y, true);
                    }
                }
            }
            return .display_changed;
        },
        0xE => {
            const op2 = concatBigEndian(u8, &[_]u4{ layout.nibble3, layout.nibble4 });
            switch (op2) {
                0x9E => {
                    const key = self.reg_v[layout.nibble2];
                    if (self.keypad.getState(@enumFromInt(key)) == .down) {
                        self.pc += 2;
                    }
                },
                0xA1 => {
                    const key = self.reg_v[layout.nibble2];
                    if (self.keypad.getState(@enumFromInt(key)) == .up) {
                        self.pc += 2;
                    }
                },
                else => std.debug.panic("Op code not implemented: {X}\n", .{instruction}),
            }
        },
        0xF => {
            const op2 = concatBigEndian(u8, &[_]u4{ layout.nibble3, layout.nibble4 });
            switch (op2) {
                0x07 => self.reg_v[layout.nibble2] = self.delay_timer,
                0x15 => self.delay_timer = self.reg_v[layout.nibble2],
                0x18 => self.sound_timer = self.reg_v[layout.nibble2],
                0x1E => {
                    const ov = @addWithOverflow(self.reg_i, self.reg_v[layout.nibble2]);
                    if (self.reg_i <= 0x0FFF and ov[0] >= 0x1000) {
                        self.reg_v[0xF] = 1;
                    }
                    self.reg_i = ov[0];
                },
                0x0A => {
                    self.fx0a_getkey.in_fx0a = true;
                    if (self.fx0a_getkey.hasDown and self.fx0a_getkey.hasUp) {
                        // key down and up = pressed
                        if (self.fx0a_getkey.key) |key| {
                            self.reg_v[layout.nibble2] = key.toUInt();
                        } else {
                            std.debug.panic("self.fx0a_getkey.key is null although up and down pressed.", .{});
                        }
                        self.fx0a_getkey = .{};
                    } else {
                        // blocks until key input
                        self.pc -= 2;
                    }
                },
                0x29 => {
                    self.reg_i = font_start + self.reg_v[layout.nibble2];
                },
                0x33 => {
                    const num = self.reg_v[layout.nibble2];
                    const ones = num % 10;
                    const tens = (num / 10) % 10;
                    const hund = num / 100;
                    self.memory[self.reg_i] = hund;
                    self.memory[self.reg_i + 1] = tens;
                    self.memory[self.reg_i + 2] = ones;
                },
                0x55 => {
                    const x: u8 = layout.nibble2;
                    for (0..x + 1) |i| {
                        self.memory[self.reg_i + i] = self.reg_v[i];
                    }
                },
                0x65 => {
                    const x: u8 = layout.nibble2;
                    for (0..x + 1) |i| {
                        self.reg_v[i] = self.memory[self.reg_i + i];
                    }
                },
                else => std.debug.panic("Op code not implemented: {X}\n", .{instruction}),
            }
        },
    }

    return .ok;
}

test "Check font copied correctly" {
    var chip8 = Self.init(std.testing.allocator);
    defer chip8.deinit();
    try expectEqual(chip8.memory[font_start], font.font[0]);
}
