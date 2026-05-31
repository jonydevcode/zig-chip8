const Self = @This();
const std = @import("std");
const font = @import("font.zig");
const expect = std.testing.expect;
const expectEqual = std.testing.expectEqual;

const ram_size = 4096;
const reg_v_count = 16;
const font_start = 0x50;
const pc_start = 0x200;

allocator: std.mem.Allocator,

// CHIP-8 components
memory: [ram_size]u8,
pc: usize,
reg_i: u16,
// push = append(), peek top = getLast(), pop = pop()
stack: std.ArrayList(u16),
delay_timer: u8,
sound_timer: u8,
// V0 to VF, and VF is flag register
reg_v: [reg_v_count]u8,

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
    };
    font.copyFontToMemory(&chip8.memory, font_start);
    return chip8;
}

pub fn deinit(self: *Self) void {
    self.stack.deinit(self.allocator);
    self.* = undefined;
}

pub fn copyROM(self: *Self, rom: []u8) void {
    std.debug.assert(pc_start + rom.len <= self.memory.len);
    @memcpy(self.memory[pc_start .. pc_start + rom.len], rom);
}

pub fn step(self: *Self) void {
    _ = self;
}

test "Check font copied correctly" {
    var chip8 = Self.init(std.testing.allocator);
    defer chip8.deinit();
    try expectEqual(chip8.memory[font_start], font.font[0]);
}
