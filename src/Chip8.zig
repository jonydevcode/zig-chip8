const Self = @This();
const std = @import("std");
const font = @import("font.zig");
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

// STATIC

fn concatBigEndian(comptime T: type, nibbles: []const u4) T {
    var result: T = 0;
    for (nibbles) |nibble| {
        result = (result << 4) | nibble;
    }
    return result;
}

// NON-PUBLIC

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
pub fn init(allocator: std.mem.Allocator) Self {
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

pub fn step(self: *Self) !StepResult {
    const instruction = std.mem.readInt(u16, self.memory[self.pc..][0..2], .big);
    self.pc += 2;
    const layout: InstructionLayout = @bitCast(instruction);
    // std.debug.print("{X} {X} {X} {X}\n", .{ layout.nibble1, layout.nibble2, layout.nibble3, layout.nibble4 });

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
            self.reg_v[layout.nibble2] += op_val;
        },
        0x8 => {},
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
        0xB => {},
        0xC => {},
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
        0xE => {},
        0xF => {},
    }

    return .ok;
}

test "Check font copied correctly" {
    var chip8 = Self.init(std.testing.allocator);
    defer chip8.deinit();
    try expectEqual(chip8.memory[font_start], font.font[0]);
}
